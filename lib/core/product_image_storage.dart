import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Memilih dan menyimpan foto produk di perangkat. Diabstraksikan agar bisa
/// diganti di tes (tanpa galeri sungguhan).
/// Kesalahan memilih foto dengan pesan yang bisa ditampilkan.
class ProductImageException implements Exception {
  final String message;
  const ProductImageException(this.message);

  @override
  String toString() => message;
}

abstract class ProductImageStorage {
  /// Membuka galeri; mengembalikan jalur file salinan foto di folder data
  /// aplikasi (di web: data URL foto), atau null jika dibatalkan. Melempar
  /// [ProductImageException] jika foto tidak bisa dipakai.
  Future<String?> pickFromGallery();

  /// Menghapus file foto milik aplikasi. Aman dipanggil dengan null, jalur
  /// yang tidak ada, atau jalur di luar folder foto produk (dibiarkan).
  Future<void> delete(String? path);
}

class DeviceProductImageStorage implements ProductImageStorage {
  static const folderName = 'product_images';

  /// Batas ukuran foto di web, yang menyimpannya di penyimpanan browser
  /// (sekitar 5 MB untuk seluruh data aplikasi).
  static const maxWebPhotoBytes = 350 * 1024;

  /// Simpan foto sebagai data URL (bukan berkas lokal) di perangkat non-web.
  /// Dipakai mode database agar foto ikut tersimpan di server.
  static bool storeInline = false;

  final ImagePicker _picker = ImagePicker();

  /// Data URL dari isi foto, mis. `data:image/jpeg;base64,/9j/...`.
  static String dataUrlFromBytes(List<int> bytes, String mimeType) =>
      'data:$mimeType;base64,${base64Encode(bytes)}';

  /// Web: foto disimpan sebagai data URL (tidak ada folder berkas aplikasi).
  Future<String?> _pickForWeb() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.length > maxWebPhotoBytes) {
      throw ProductImageException(
        'Foto terlalu besar untuk versi web '
        '(${(bytes.length / 1024).round()} KB, maksimal '
        '${maxWebPhotoBytes ~/ 1024} KB). Pilih foto yang lebih kecil.',
      );
    }
    return dataUrlFromBytes(bytes, picked.mimeType ?? 'image/jpeg');
  }

  /// Hanya file di folder foto produk yang boleh dihapus.
  static bool isManagedPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.contains('/$folderName/');
  }

  @override
  Future<String?> pickFromGallery() async {
    if (kIsWeb || storeInline) return _pickForWeb();

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // Diperkecil agar penyimpanan dan pemuatan tetap ringan.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/$folderName');
    await folder.create(recursive: true);

    final dot = picked.path.lastIndexOf('.');
    final ext = dot >= 0 && picked.path.length - dot <= 5
        ? picked.path.substring(dot)
        : '.jpg';
    final target =
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(picked.path).copy(target);
    return target;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null || !isManagedPath(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Gagal menghapus file bukan masalah besar; abaikan.
    }
  }
}

/// Penyimpanan foto yang dipakai aplikasi (bisa diganti di tes).
ProductImageStorage productImageStorage = DeviceProductImageStorage();
