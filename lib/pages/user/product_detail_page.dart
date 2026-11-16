import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/review_section.dart';
import 'package:motopart/widgets/wishlist_button.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [WishlistButton(product: product)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  context.palette.text.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(product.icon, color: AppColors.primary, size: 100),
          ),
          const SizedBox(height: 22),
          Text(
            product.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.palette.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatRupiah(product.price),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RatingSummary(product: product),
              const SizedBox(width: 10),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: context.palette.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Stok ${product.stock}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Produk',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _detailRow(context, 'Kategori', product.category),
                _detailRow(context, 'Tipe Motor', product.type),
                _detailRow(context, 'Stok', '${product.stock} unit'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deskripsi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  product.description,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ReviewSection(product: product),
          const SizedBox(height: 24),
          PrimaryButton(
            text: product.stock > 0 ? 'Masukkan ke Keranjang' : 'Stok Habis',
            icon: Icons.shopping_cart_outlined,
            outline: product.stock <= 0,
            onPressed: product.stock <= 0
                ? null
                : () {
                    final added = store.addToCart(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? '${product.name} ditambahkan ke keranjang.'
                              : 'Stok ${product.name} hanya ${product.stock} unit.',
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: context.palette.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: context.palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
