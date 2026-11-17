import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';
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
                builder: (context, hovered) => AnimatedContainer(
                  duration: UiConfig.motion(const Duration(milliseconds: 160)),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hovered
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : palette.surface,
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: hovered ? 0.9 : 0.45,
                      ),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: hovered
                            ? AppColors.primary.withValues(alpha: 0.28)
                            : palette.shadow,
                        blurRadius: hovered ? 16 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: palette.primaryText, size: 28),
                ),
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
