import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';

/// Tombol hati untuk menambah/menghapus produk dari wishlist.
class WishlistButton extends StatelessWidget {
  final Product product;
  final double size;

  const WishlistButton({super.key, required this.product, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final wishlisted = store.isWishlisted(product);
        return IconButton(
          tooltip: wishlisted ? 'Hapus dari wishlist' : 'Tambah ke wishlist',
          iconSize: size,
          onPressed: () => store.toggleWishlist(product),
          icon: Icon(
            wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: wishlisted ? AppColors.danger : context.palette.textMuted,
          ),
        );
      },
    );
  }
}
