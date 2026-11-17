import 'package:flutter/material.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/hover_icon_circle.dart';
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
                itemCount: store.categories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: categoryGridColumns(constraints.maxWidth),
                  mainAxisSpacing: AppSpacing.md + 2,
                  crossAxisSpacing: AppSpacing.md + 2,
                  mainAxisExtent: 140,
                ),
                itemBuilder: (context, index) {
                  final category = store.categories[index];
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
                    // Saat kursor di atas: kartu terangkat, bingkai oranye, dan
                    // lingkaran ikon terisi penuh.
                    child: HoverBuilder(
                      builder: (context, hovered) => AnimatedContainer(
                        duration: UiConfig.motion(
                          const Duration(milliseconds: 160),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: hovered
                                ? context.palette.accent.withValues(alpha: 0.7)
                                : palette.border,
                            width: hovered ? 1.6 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hovered
                                  ? context.palette.accent.withValues(
                                      alpha: 0.22,
                                    )
                                  : palette.shadow,
                              blurRadius: hovered ? 22 : 12,
                              offset: Offset(0, hovered ? 10 : 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HoverIconCircle(
                              icon: category.icon,
                              hovered: hovered,
                              size: 56,
                              outlined: false,
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
