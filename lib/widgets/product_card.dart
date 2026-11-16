import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/cart_feedback.dart';
import 'package:motopart/widgets/press_scale.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/wishlist_button.dart';

/// Tag Hero yang sama dipakai kartu dan halaman detail agar gambar "terbang".
String productHeroTag(Product product) => 'product-${product.id}';

/// Gambar produk (foto, atau ikon di atas gradien). Dipakai kartu dan halaman
/// detail; tag Hero yang sama membuatnya "terbang" di antara keduanya.
class ProductImage extends StatelessWidget {
  final Product product;
  final double height;
  final double iconSize;
  final double radius;

  const ProductImage({
    super.key,
    required this.product,
    required this.height,
    required this.iconSize,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: productHeroTag(product),
      child: ProductPicture.forProduct(
        product,
        width: double.infinity,
        height: height,
        iconSize: iconSize,
        radius: radius,
      ),
    );
  }
}

/// Label stok: merah jika menipis (< 5) atau habis.
class StockLabel extends StatelessWidget {
  static const lowStockThreshold = 5;

  final Product product;
  final double fontSize;

  const StockLabel({
    super.key,
    required this.product,
    this.fontSize = AppTextSizes.small,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stock = product.stock;
    final String text;
    final Color color;
    if (stock <= 0) {
      text = 'Stok habis';
      color = palette.dangerText;
    } else if (stock < lowStockThreshold) {
      text = 'Stok tinggal $stock';
      color = palette.dangerText;
    } else {
      text = 'Stok $stock';
      color = palette.textMuted;
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: stock < lowStockThreshold
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  /// Tinggi sel kartu di grid.
  static const double extent = 292;

  final Product product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Batasi pembesaran teks agar kartu tidak meluap di layar kecil.
    final media = MediaQuery.of(context);
    final scaler = media.textScaler.clamp(maxScaleFactor: 1.15);

    return MediaQuery(
      data: media.copyWith(textScaler: scaler),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ProductImage(product: product, height: 108, iconSize: 48),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: WishlistButton(product: product, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppTextSizes.body,
                  height: 1.25,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: AppTextSizes.small,
                ),
              ),
              const Spacer(),
              Text(
                formatRupiah(product.price),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: AppTextSizes.bodyLarge,
                ),
              ),
              Row(
                children: [
                  Expanded(child: StockLabel(product: product)),
                  _AddButton(product: product),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol "+" kecil. Area sentuhnya 48x48 walau tampilannya lebih kecil.
class _AddButton extends StatelessWidget {
  final Product product;

  const _AddButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = product.stock > 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Tambah ${product.name} ke keranjang',
      child: InkResponse(
        onTap: enabled ? () => addToCartWithFeedback(context, product) : null,
        radius: 26,
        child: SizedBox(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? AppColors.primary : palette.surfaceAlt,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: enabled ? AppColors.onPrimary : palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
