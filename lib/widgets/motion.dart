import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/theme/app_theme.dart';

/// Getaran halus sebagai umpan balik sentuhan. Aman dipanggil di platform
/// yang tidak mendukungnya (tanpa efek).
class Haptics {
  const Haptics._();

  /// Aksi kecil yang berhasil, mis. menambah ke keranjang.
  static void light() => HapticFeedback.lightImpact();

  /// Memilih pilihan, mis. chip filter.
  static void selection() => HapticFeedback.selectionClick();
}

/// Muncul dengan memudar sambil naik sedikit. Dipakai untuk item daftar/grid;
/// [index] menunda item berikutnya sedikit sehingga muncul bergantian (tertunda
/// maksimal [maxStaggered] langkah agar daftar panjang tidak terasa lambat).
/// Tanpa animasi (`UiConfig.animate` mati) anaknya langsung tampil.
class FadeSlideIn extends StatelessWidget {
  static const maxStaggered = 8;
  static const _step = Duration(milliseconds: 45);
  static const _base = Duration(milliseconds: 380);

  final Widget child;
  final int index;

  /// Jarak geser awal (piksel) ke bawah.
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (!UiConfig.animate) return child;

    final delay = _step * index.clamp(0, maxStaggered);
    final total = delay + _base;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Angka bulat yang "berhitung" ke nilai barunya (mis. total belanja).
/// [builder] mengubah angka menjadi teks; nilai awal langsung tampil tanpa
/// animasi.
class AnimatedCount extends StatelessWidget {
  final int value;
  final String Function(int value) builder;
  final TextStyle? style;
  final Duration duration;

  /// true: saat pertama tampil angka berhitung naik dari 0 ke [value] (mis.
  /// kartu statistik). Perubahan berikutnya tetap berhitung dari nilai
  /// sekarang.
  final bool fromZero;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.style,
    this.duration = const Duration(milliseconds: 380),
    this.fromZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(
        begin: fromZero && UiConfig.animate ? 0 : null,
        end: value,
      ),
      duration: UiConfig.motion(duration),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(builder(v), style: style),
    );
  }
}

/// Angka kecil (mis. jumlah di keranjang) yang berganti dengan efek geser dan
/// memudar.
class AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const AnimatedNumber({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: UiConfig.motion(const Duration(milliseconds: 220)),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Text('$value', key: ValueKey(value), style: style),
    );
  }
}

/// Muncul dengan "melompat": membesar dari kecil sambil memudar masuk. [index]
/// menunda item berikutnya sedikit (maksimal [FadeSlideIn.maxStaggered]
/// langkah). Tanpa animasi anaknya langsung tampil.
class PopIn extends StatelessWidget {
  final Widget child;
  final int index;

  /// Skala awal.
  final double from;

  const PopIn({
    super.key,
    required this.child,
    this.index = 0,
    this.from = 0.6,
  });

  static const _step = Duration(milliseconds: 55);
  static const _base = Duration(milliseconds: 420);

  @override
  Widget build(BuildContext context) {
    if (!UiConfig.animate) return child;

    final delay = _step * index.clamp(0, FadeSlideIn.maxStaggered);
    final total = delay + _base;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1,
      curve: Curves.easeOutBack,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: curve,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: from + (1 - from) * value, child: child),
      ),
      child: child,
    );
  }
}

/// Memiringkan [child] secara 3D mengikuti posisi kursor mouse (hingga
/// [maxAngle] radian) dan kembali tegak saat kursor pergi. Tidak berpengaruh di
/// layar sentuh.
class TiltOnHover extends StatefulWidget {
  final Widget child;
  final double maxAngle;
  final bool enabled;

  const TiltOnHover({
    super.key,
    required this.child,
    this.maxAngle = 0.07,
    this.enabled = true,
  });

  @override
  State<TiltOnHover> createState() => _TiltOnHoverState();
}

class _TiltOnHoverState extends State<TiltOnHover> {
  /// Posisi kursor dinormalkan -1..1 (kiri/atas = -1).
  Offset tilt = Offset.zero;

  void _onHover(PointerHoverEvent event) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      tilt = Offset(
        (event.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (event.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => setState(() => tilt = Offset.zero),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: tilt),
        duration: UiConfig.motion(const Duration(milliseconds: 160)),
        curve: Curves.easeOut,
        builder: (context, t, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012) // perspektif
            ..rotateX(-t.dy * widget.maxAngle)
            ..rotateY(t.dx * widget.maxAngle),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Kilau cahaya yang menyapu [child] dari kiri ke kanan setiap kali [active]
/// berubah menjadi true (mis. saat kursor masuk ke tombol). Tidak menangkap
/// sentuhan dan tidak mengubah ukuran.
class ShineSweep extends StatefulWidget {
  static const duration = Duration(milliseconds: 650);

  final Widget child;
  final bool active;
  final double radius;

  const ShineSweep({
    super.key,
    required this.child,
    required this.active,
    this.radius = 0,
  });

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: ShineSweep.duration,
  );

  @override
  void didUpdateWidget(ShineSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && UiConfig.animate) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => !controller.isAnimating
                  ? const SizedBox.shrink()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: CustomPaint(
                        painter: ShinePainter(
                          Curves.easeInOut.transform(controller.value),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Menggambar pita cahaya miring pada posisi [progress] (0 = di kiri luar,
/// 1 = di kanan luar).
class ShinePainter extends CustomPainter {
  final double progress;

  const ShinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width * 0.35;
    final x = -band + (size.width + band * 2) * progress;
    final path = Path()
      ..moveTo(x, 0)
      ..lineTo(x + band, 0)
      ..lineTo(x + band - size.height * 0.4, size.height)
      ..lineTo(x - size.height * 0.4, size.height)
      ..close();
    final paint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.38),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromLTWH(
              x - size.height * 0.4,
              0,
              band + size.height * 0.4,
              size.height,
            ),
          );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ShinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
