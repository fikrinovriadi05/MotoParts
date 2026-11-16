import 'package:flutter/material.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/press_scale.dart';

/// Jumlah kolom kartu kategori: 2 di HP, 3 di tablet kecil, 4 di layar lebar.
int categoryGridColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: productCategories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: categoryGridColumns(constraints.maxWidth),
                  mainAxisSpacing: AppSpacing.md + 2,
                  crossAxisSpacing: AppSpacing.md + 2,
                  mainAxisExtent: 140,
                ),
                itemBuilder: (context, index) {
                  final category = productCategories[index];
                  final count = store.products
                      .where((p) => p.category == category.name)
                      .length;
                  return PressScale(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CatalogPage(selectedCategory: category.name),
                      ),
                    ),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.16),
                            ),
                            child: Icon(
                              category.icon,
                              size: 28,
                              color: palette.primaryText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTextSizes.bodyLarge,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            '$count produk',
                            style: TextStyle(
                              fontSize: AppTextSizes.small,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
