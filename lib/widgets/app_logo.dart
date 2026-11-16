import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/brand_mark.dart';

/// Logo + nama "MotoPart". [light] = teks putih untuk latar gelap.
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
        BrandMark(size: size + 14),
        const SizedBox(width: 10),
        // Menyusut (bukan meluap) jika ruang sempit atau font sistem besar.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
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
          ),
        ),
      ],
    );
  }
}
