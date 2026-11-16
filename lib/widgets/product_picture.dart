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

  const ProductPicture({
    super.key,
    required this.imagePath,
    required this.icon,
    this.width,
    this.height,
    this.iconSize = 32,
    this.radius = AppRadius.md,
  });

  /// Untuk produk; produk null (sudah dihapus) memakai ikon umum.
  factory ProductPicture.forProduct(
    Product? product, {
    Key? key,
    double? width,
    double? height,
    double iconSize = 32,
    double radius = AppRadius.md,
  }) {
    return ProductPicture(
      key: key,
      imagePath: product?.imagePath,
      icon: product?.icon ?? Icons.inventory_2_rounded,
      width: width,
      height: height,
      iconSize: iconSize,
      radius: radius,
    );
  }

  /// Apakah [imagePath] menunjuk ke file foto yang bisa dipakai.
  static bool hasPhoto(String? imagePath) =>
      !kIsWeb && imagePath != null && File(imagePath).existsSync();

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
      child: Image.file(
        File(imagePath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}
