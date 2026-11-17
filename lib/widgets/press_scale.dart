import 'package:flutter/material.dart';
import 'package:motopart/widgets/hover.dart';

/// Membungkus [child] agar sedikit mengecil saat ditekan dan sedikit membesar
/// saat kursor mouse berada di atasnya (kursor berubah menjadi tangan), lalu
/// memanggil [onTap]. Memberi umpan balik tanpa mengubah tata letak.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  /// Skala saat kursor di atas widget (1 = tanpa efek hover).
  final double hoverScale;

  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.hoverScale = 1.025,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool pressed = false;

  void _set(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      enabled: widget.onTap != null,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: pressed ? widget.scale : (hovered ? widget.hoverScale : 1),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Mengecilkan [child] sedikit selama disentuh dan membesarkannya sedikit saat
/// kursor di atasnya, tanpa mengambil alih sentuhan (tombol di dalamnya tetap
/// menerima ketukan). Dipakai untuk tombol.
class PressEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;
  final double hoverScale;

  const PressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
    this.hoverScale = 1.02,
  });

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool pressed = false;

  void _set(bool value) {
    if (pressed != value && mounted) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      enabled: widget.enabled,
      builder: (context, hovered) => Listener(
        onPointerDown: (_) => widget.enabled ? _set(true) : null,
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: pressed && widget.enabled
              ? widget.scale
              : (hovered ? widget.hoverScale : 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
