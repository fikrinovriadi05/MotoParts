import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/product_grid.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final products = store.wishlistProducts;

          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 56,
                      color: context.palette.textMuted,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Wishlist masih kosong',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tekan ikon hati pada produk untuk menyimpannya di sini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.palette.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ProductGrid(
            products: products,
            padding: const EdgeInsets.all(AppSpacing.page),
          );
        },
      ),
    );
  }
}
