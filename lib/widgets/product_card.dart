import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/widgets/glass_card.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.blue.withValues(alpha: 0.12),
                    AppColors.black.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                product.icon,
                size: 54,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              formatRupiah(product.price),
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
