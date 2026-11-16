import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Memilih dan menyimpan foto produk di perangkat. Diabstraksikan agar bisa
/// diganti di tes (tanpa galeri sungguhan).
abstract class ProductImageStorage {
  /// Membuka galeri; mengembalikan jalur file salinan foto di folder data
  /// aplikasi, atau null jika dibatalkan.
  Future<String?> pickFromGallery();

  /// Menghapus file foto milik aplikasi. Aman dipanggil dengan null, jalur
  /// yang tidak ada, atau jalur di luar folder foto produk (dibiarkan).
  Future<void> delete(String? path);
}

class DeviceProductImageStorage implements ProductImageStorage {
  static const folderName = 'product_images';

  final ImagePicker _picker = ImagePicker();

  /// Hanya file di folder foto produk yang boleh dihapus.
  static bool isManagedPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.contains('/$folderName/');
  }

  @override
  Future<String?> pickFromGallery() async {
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
