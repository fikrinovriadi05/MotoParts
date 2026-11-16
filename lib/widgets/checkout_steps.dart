import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

/// Indikator langkah checkout: Alamat → Pembayaran → Selesai.
class CheckoutSteps extends StatelessWidget {
  static const labels = ['Alamat', 'Pembayaran', 'Selesai'];

  /// Langkah aktif (0 = Alamat, 1 = Pembayaran, 2 = Selesai).
  final int current;

  const CheckoutSteps({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget dot(int i) {
      final done = i < current;
      final active = i == current;
      final filled = done || active;
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.primary : palette.surfaceAlt,
          border: Border.all(
            color: filled ? AppColors.primary : palette.border,
            width: 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.onPrimary,
              )
            : Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: AppTextSizes.small,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.onPrimary : palette.textMuted,
                ),
              ),
      );
    }

    Widget line(int i) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        color: i < current ? AppColors.primary : palette.border,
      ),
    );

    return Semantics(
      label: 'Langkah ${current + 1} dari ${labels.length}: ${labels[current]}',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                dot(i),
                if (i < labels.length - 1) line(i),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Align(
                    alignment: i == 0
                        ? Alignment.centerLeft
                        : i == labels.length - 1
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: AppTextSizes.small,
                          fontWeight: i == current
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: i <= current
                              ? palette.text
                              : palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
