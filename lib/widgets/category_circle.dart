import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/hover_icon_circle.dart';
import 'package:motopart/widgets/press_scale.dart';

/// Ikon kategori berbentuk lingkaran dengan label di bawahnya.
class CategoryCircle extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const CategoryCircle({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: 'Kategori $title',
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HoverBuilder(
                builder: (context, hovered) =>
                    HoverIconCircle(icon: icon, hovered: hovered),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppTextSizes.small,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
