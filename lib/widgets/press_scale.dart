import 'package:flutter/material.dart';

/// Membungkus [child] agar sedikit mengecil saat ditekan, lalu memanggil
/// [onTap]. Memberi umpan balik sentuhan tanpa mengubah tata letak.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Mengecilkan [child] sedikit selama disentuh, tanpa mengambil alih sentuhan
/// (tombol di dalamnya tetap menerima ketukan). Dipakai untuk tombol.
class PressEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scale;

  const PressEffect({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
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
    return Listener(
      onPointerDown: (_) => widget.enabled ? _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed && widget.enabled ? widget.scale : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
