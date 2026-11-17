import 'package:flutter/material.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/motion.dart';

/// Tombol hati untuk menambah/menghapus produk dari wishlist. Saat ditambahkan,
/// hati "membal" dan perangkat bergetar halus.
class WishlistButton extends StatefulWidget {
  final Product product;
  final double size;

  const WishlistButton({super.key, required this.product, this.size = 24});

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.4,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.4,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(controller);

  /// Status sebelumnya, untuk mendeteksi perubahan menjadi disukai. Dihitung
  /// di [initState] (bukan `late`) agar tidak terbaca setelah berubah.
  bool wasWishlisted = false;

  @override
  void initState() {
    super.initState();
    wasWishlisted = store.isWishlisted(widget.product);
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    controller.dispose();
    super.dispose();
  }

  /// Memutar animasi saat produk berubah menjadi disukai (dari mana pun
  /// perubahannya, mis. halaman lain).
  void _onStore() {
    final now = store.isWishlisted(widget.product);
    if (now && !wasWishlisted && UiConfig.animate && mounted) {
      controller.forward(from: 0);
    }
    wasWishlisted = now;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final wishlisted = store.isWishlisted(widget.product);
        return IconButton(
          tooltip: wishlisted ? 'Hapus dari wishlist' : 'Tambah ke wishlist',
          iconSize: widget.size,
          onPressed: () {
            if (!wishlisted) Haptics.light();
            store.toggleWishlist(widget.product);
          },
          icon: ScaleTransition(
            scale: scale,
            child: Icon(
              wishlisted
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: wishlisted ? AppColors.danger : context.palette.textMuted,
            ),
          ),
        );
      },
    );
  }
}
