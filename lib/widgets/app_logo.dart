import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final bool light;
  final double size;

  const AppLogo({super.key, this.light = false, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : context.palette.text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size + 12,
          height: size + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primarySoft, AppColors.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: AppColors.onPrimary,
            size: 28,
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: size * 0.80,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
            children: [
              TextSpan(
                text: 'Moto',
                style: TextStyle(color: textColor),
              ),
              const TextSpan(
                text: 'Part',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
