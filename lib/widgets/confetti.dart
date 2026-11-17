import 'dart:math';

import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Hujan konfeti singkat untuk momen berhasil (mis. pembayaran). Tidak
/// menangkap sentuhan dan berhenti sendiri. Tanpa animasi (`UiConfig.animate`
/// mati) tidak menampilkan apa pun.
class Confetti extends StatefulWidget {
  static const duration = Duration(milliseconds: 2600);
  static const colors = [
    AppColors.primary,
    AppColors.primarySoft,
    AppColors.success,
    Color(0xFFFFC107),
    Color(0xFF42A5F5),
  ];

  final int count;
  final int seed;

  const Confetti({super.key, this.count = 46, this.seed = 7});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: Confetti.duration,
  );
  late final List<_Piece> pieces = _makePieces(widget.count, widget.seed);

  @override
  void initState() {
    super.initState();
    if (UiConfig.animate) controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static List<_Piece> _makePieces(int count, int seed) {
    final random = Random(seed);
    return [
      for (var i = 0; i < count; i++)
        _Piece(
          x: random.nextDouble(),
          drift: (random.nextDouble() - 0.5) * 0.35,
          delay: random.nextDouble() * 0.35,
          speed: 0.65 + random.nextDouble() * 0.5,
          size: 6 + random.nextDouble() * 6,
          spin: (random.nextDouble() - 0.5) * 14,
          color: Confetti.colors[random.nextInt(Confetti.colors.length)],
          round: random.nextBool(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!UiConfig.animate) return const SizedBox.shrink();

    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => controller.isCompleted
              ? const SizedBox.shrink()
              : CustomPaint(
                  painter: _ConfettiPainter(pieces, controller.value),
                  size: Size.infinite,
                ),
        ),
      ),
    );
  }
}

class _Piece {
  final double x;
  final double drift;
  final double delay;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  final bool round;

  const _Piece({
    required this.x,
    required this.drift,
    required this.delay,
    required this.speed,
    required this.size,
    required this.spin,
    required this.color,
    required this.round,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Jatuh makin cepat (gravitasi), memudar di akhir.
      final fall = local * local * p.speed + local * 0.25;
      final y = -20 + fall * (size.height + 40);
      final x = (p.x + p.drift * local) * size.width;
      final opacity = local < 0.75 ? 1.0 : (1 - local) / 0.25;

      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
