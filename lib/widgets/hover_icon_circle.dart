import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Lingkaran berisi ikon yang bereaksi jelas saat kursor di atasnya
/// ([hovered]): terisi warna utama penuh, ikon berganti ke warna kontras
/// (`onPrimary`), sedikit membesar, dan bersinar. Dipakai untuk ikon kategori.
class HoverIconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool hovered;

  /// true: latar putih dengan garis tepi (Beranda); false: latar oranye tipis
  /// tanpa garis (halaman Kategori).
  final bool outlined;

  const HoverIconCircle({
    super.key,
    required this.icon,
    required this.hovered,
    this.size = 64,
    this.iconSize = 28,
    this.outlined = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = UiConfig.motion(const Duration(milliseconds: 180));

    return AnimatedScale(
      scale: hovered ? 1.1 : 1,
      duration: duration,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: duration,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hovered
              ? AppColors.primary
              : (outlined
                    ? palette.surface
                    : AppColors.primary.withValues(alpha: 0.16)),
          border: outlined
              ? Border.all(
                  color: AppColors.primary.withValues(
                    alpha: hovered ? 1 : 0.45,
                  ),
                  width: 1.4,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: hovered
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : (outlined ? palette.shadow : Colors.transparent),
              blurRadius: hovered ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              end: hovered ? AppColors.onPrimary : palette.primaryText,
            ),
            duration: duration,
            builder: (context, color, _) =>
                Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }
}
