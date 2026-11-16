import 'package:flutter/material.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/shimmer.dart';

/// Jumlah kolom grid menurut lebar: 2 di HP, 3 di tablet kecil, 4 di layar lebar.
int productGridColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// Grid produk responsif. Dengan [loading] = true menampilkan kerangka
/// berkilau (shimmer) sebagai pengganti kartu.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final bool loading;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final int skeletonCount;

  const ProductGrid({
    super.key,
    required this.products,
    this.loading = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.skeletonCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = productGridColumns(constraints.maxWidth);
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: loading ? skeletonCount : products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.md + 2,
            crossAxisSpacing: AppSpacing.md + 2,
            mainAxisExtent: ProductCard.extent,
          ),
          itemBuilder: (context, index) {
            if (loading) return const ProductCardSkeleton();
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(product: product),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Kerangka kartu produk saat data dimuat.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: const Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(height: 108, radius: AppRadius.md),
            SizedBox(height: AppSpacing.md),
            ShimmerBox(height: 14),
            SizedBox(height: AppSpacing.sm),
            ShimmerBox(width: 80, height: 12),
            Spacer(),
            ShimmerBox(width: 90, height: 18),
            SizedBox(height: AppSpacing.md),
            ShimmerBox(width: 60, height: 12),
            SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
