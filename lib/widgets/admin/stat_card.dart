import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/hover.dart';
import 'package:motopart/widgets/motion.dart';

/// Kartu statistik dasbor admin: ikon berwarna, angka yang berhitung naik
/// (angka tabular agar tidak bergoyang), dan judul. Terangkat saat kursor di
/// atasnya.
class AdminStatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  /// Mengubah angka menjadi teks (bawaan: bilangan biasa; mis. Rupiah).
  final String Function(int value)? format;

  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hovered) => AnimatedContainer(
        duration: UiConfig.motion(const Duration(milliseconds: 160)),
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        transform: Matrix4.translationValues(0, hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hovered ? color.withValues(alpha: 0.6) : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: hovered ? color.withValues(alpha: 0.25) : palette.shadow,
              blurRadius: hovered ? 22 : 12,
              offset: Offset(0, hovered ? 10 : 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: hovered ? 1.12 : 1,
              duration: UiConfig.motion(const Duration(milliseconds: 180)),
              curve: Curves.easeOutBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: hovered ? 0.28 : 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const Spacer(),
            // Angka berhitung naik dari 0 saat kartu pertama tampil. Menyusut
            // (bukan meluap) untuk angka panjang seperti Rupiah.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedCount(
                value: value,
                fromZero: true,
                builder: format ?? (v) => '$v',
                style: TextStyle(
                  fontSize: AppTextSizes.display,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: AppTextSizes.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
