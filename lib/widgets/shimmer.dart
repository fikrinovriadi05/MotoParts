import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Efek kilau yang bergerak di atas [child] (biasanya kotak-kotak abu-abu
/// sebagai kerangka konten yang sedang dimuat). Dibuat manual, tanpa package.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final t = controller.value;
            return LinearGradient(
              begin: Alignment(-1.6 + 3.2 * t, -0.3),
              end: Alignment(-0.6 + 3.2 * t, 0.3),
              colors: [
                palette.surfaceAlt,
                Color.lerp(palette.surfaceAlt, palette.text, 0.14)!,
                palette.surfaceAlt,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

/// Kotak penanda posisi konten yang sedang dimuat.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
