import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/press_scale.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outline;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.outline = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = icon != null ? Icon(icon, size: 20) : null;

    if (outline) {
      return PressEffect(
        enabled: onPressed != null,
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: iconWidget ?? const SizedBox.shrink(),
            label: Text(text),
          ),
        ),
      );
    }

    final enabled = onPressed != null;
    final palette = context.palette;

    return PressEffect(
      enabled: enabled,
      // Kilau cahaya menyapu tombol saat kursor masuk.
      child: HoverBuilder(
        enabled: enabled,
        builder: (context, hovered) => ShineSweep(
          active: hovered,
          radius: AppRadius.lg,
          child: SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        colors: [AppColors.primarySoft, AppColors.primary],
                      )
                    : null,
                color: enabled ? null : palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: iconWidget ?? const SizedBox.shrink(),
                label: Text(text),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.onPrimary,
                  disabledForegroundColor: palette.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
