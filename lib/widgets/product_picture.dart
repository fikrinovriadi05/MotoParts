import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/theme/app_theme.dart';

/// Gambar produk: foto jika ada dan filenya masih ada, selain itu ikon di atas
/// gradien. Foto yang rusak/hilang otomatis kembali ke ikon.
class ProductPicture extends StatelessWidget {
  final String? imagePath;
  final IconData icon;
  final double? width;
  final double? height;
  final double iconSize;
  final double radius;

  /// Cara foto mengisi kotaknya (bawaan memotong agar penuh).
  final BoxFit fit;

  const ProductPicture({
    super.key,
    required this.imagePath,
    required this.icon,
    this.width,
    this.height,
    this.iconSize = 32,
    this.radius = AppRadius.md,
    this.fit = BoxFit.cover,
  });

  /// Untuk produk; produk null (sudah dihapus) memakai ikon umum.
  factory ProductPicture.forProduct(
    Product? product, {
    Key? key,
    double? width,
    double? height,
    double iconSize = 32,
    double radius = AppRadius.md,
    BoxFit fit = BoxFit.cover,
  }) {
    return ProductPicture(
      key: key,
      imagePath: product?.imagePath,
      icon: product?.icon ?? Icons.inventory_2_rounded,
      width: width,
      height: height,
      iconSize: iconSize,
      radius: radius,
      fit: fit,
    );
  }

  /// Foto berupa data URL (`data:image/...;base64,...`), dipakai di web yang
  /// tidak punya folder berkas aplikasi.
  static bool isDataUrl(String? path) =>
      path != null &&
      path.startsWith('data:image/') &&
      path.contains(';base64,');

  static final _decoded = <String, Uint8List>{};

  /// Isi foto dari data URL; null jika rusak. Hasil disimpan sementara supaya
  /// tidak didekode ulang di setiap penggambaran.
  static Uint8List? bytesOf(String? dataUrl) {
    if (!isDataUrl(dataUrl)) return null;
    final cached = _decoded[dataUrl!];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      if (_decoded.length >= 48) _decoded.remove(_decoded.keys.first);
      return _decoded[dataUrl] = bytes;
    } on FormatException {
      return null;
    }
  }

  /// Apakah [imagePath] menunjuk ke foto yang bisa dipakai: data URL yang
  /// valid, atau (di luar web) file yang masih ada.
  static bool hasPhoto(String? imagePath) {
    if (imagePath == null) return false;
    if (isDataUrl(imagePath)) return bytesOf(imagePath) != null;
    return !kIsWeb && File(imagePath).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            palette.surfaceAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: palette.primaryText),
    );

    if (!hasPhoto(imagePath)) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: isDataUrl(imagePath)
          ? Image.memory(
              bytesOf(imagePath)!,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => fallback,
            )
          : Image.file(
              File(imagePath!),
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}
