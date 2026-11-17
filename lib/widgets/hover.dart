import 'package:flutter/material.dart';

/// Memberi tahu [builder] apakah kursor mouse sedang berada di atas widget, dan
/// mengubah kursor menjadi tangan (atau [cursor]) saat [enabled]. Di layar
/// sentuh tidak pernah "hovered", jadi aman dipakai di semua platform.
class HoverBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  final bool enabled;

  const HoverBuilder({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
    this.enabled = true,
  });

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool hovered = false;

  void _set(bool value) {
    if (hovered != value && mounted) setState(() => hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? widget.cursor : MouseCursor.defer,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: widget.builder(context, hovered && widget.enabled),
    );
  }
}
