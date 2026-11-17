import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Tulisan logo "MOTOPART": Inter w800 miring, "MOTO" warna teks utama dan
/// "PART" warna aksen yang dipilih pengguna.
class MotoPartWordmark extends StatelessWidget {
  final double fontSize;

  /// Warna "MOTO"; bawaan warna teks tema (putih di latar gelap).
  final Color? motoColor;

  const MotoPartWordmark({super.key, this.fontSize = 20, this.motoColor});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: 'MotoPart',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
            height: 1.1,
          ),
          children: [
            TextSpan(
              text: 'MOTO',
              style: TextStyle(color: motoColor ?? palette.text),
            ),
            TextSpan(
              text: 'PART',
              // Aksen terang di mode gelap, aksen yang dibuat lebih tua di
              // mode terang: tetap terbaca di kedua latar.
              style: TextStyle(color: palette.primaryText),
            ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      ),
    );
  }
}
