import 'package:flutter/material.dart';

/// Ikon keranjang dengan badge jumlah. Badge "melompat" sesaat setiap kali
/// jumlah bertambah.
class CartBadgeIcon extends StatefulWidget {
  final int count;
  final IconData icon;

  const CartBadgeIcon({super.key, required this.count, required this.icon});

  @override
  State<CartBadgeIcon> createState() => _CartBadgeIconState();
}

class _CartBadgeIconState extends State<CartBadgeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.45,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.45,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.bounceOut)),
      weight: 60,
    ),
  ]).animate(controller);

  @override
  void didUpdateWidget(CartBadgeIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) controller.forward(from: 0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: widget.count > 0,
      label: ScaleTransition(scale: scale, child: Text('${widget.count}')),
      child: ScaleTransition(scale: scale, child: Icon(widget.icon)),
    );
  }
}
