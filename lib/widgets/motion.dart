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

  const AnimatedCount({
    super.key,
    required this.value,
    required this.builder,
    this.style,
    this.duration = const Duration(milliseconds: 380),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(end: value),
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
