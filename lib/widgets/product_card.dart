import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/cart_feedback.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/motion.dart';
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
        // Saat kursor di atas: bayangan mengangkat dan bingkai berwarna utama.
        child: HoverBuilder(
          builder: (context, hovered) => AnimatedContainer(
            duration: UiConfig.motion(const Duration(milliseconds: 160)),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: hovered
                    ? AppColors.primary.withValues(alpha: 0.55)
                    : palette.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: hovered
                      ? AppColors.primary.withValues(alpha: 0.22)
                      : palette.shadow,
                  blurRadius: hovered ? 22 : 12,
                  offset: Offset(0, hovered ? 10 : 5),
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
      ),
    );
  }
}

/// Tombol "+" kecil. Area sentuhnya 48x48 walau tampilannya lebih kecil. Setelah
/// berhasil menambah, sesaat berubah menjadi centang hijau.
class _AddButton extends StatefulWidget {
  final Product product;

  const _AddButton({required this.product});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  static const confirmDuration = Duration(milliseconds: 1100);

  bool justAdded = false;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _add() {
    final added = addToCartWithFeedback(context, widget.product);
    if (added == 0) return;
    Haptics.light();
    if (!UiConfig.animate) return;

    timer?.cancel();
    setState(() => justAdded = true);
    timer = Timer(confirmDuration, () {
      if (mounted) setState(() => justAdded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final product = widget.product;
    final enabled = product.stock > 0;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Tambah ${product.name} ke keranjang',
      child: InkResponse(
        onTap: enabled ? _add : null,
        radius: 26,
        child: SizedBox(
          width: AppSizes.minTap,
          height: AppSizes.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: UiConfig.motion(const Duration(milliseconds: 200)),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !enabled
                    ? palette.surfaceAlt
                    : (justAdded ? AppColors.success : AppColors.primary),
              ),
              child: AnimatedSwitcher(
                duration: UiConfig.motion(const Duration(milliseconds: 220)),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  justAdded ? Icons.check_rounded : Icons.add_rounded,
                  key: ValueKey(justAdded),
                  size: 22,
                  color: enabled ? AppColors.onPrimary : palette.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
