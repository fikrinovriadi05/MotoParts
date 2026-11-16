import 'package:flutter/material.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Lini masa status pesanan: Diproses → Dikemas → Dikirim → Selesai.
/// Pesanan yang dibatalkan menampilkan banner pembatalan.
class OrderTimeline extends StatelessWidget {
  static const steps = ['Diproses', 'Dikemas', 'Dikirim', 'Selesai'];

  final String status;

  const OrderTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (status == Store.cancelledStatus) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: palette.dangerText),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Pesanan ini dibatalkan.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.dangerText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final current = steps.indexOf(status).clamp(0, steps.length - 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= current
                                  ? AppColors.primary
                                  : palette.border),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current
                            ? AppColors.primary
                            : palette.surfaceAlt,
                        border: Border.all(
                          color: i <= current
                              ? AppColors.primary
                              : palette.border,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        i < current
                            ? Icons.check_rounded
                            : orderStatusIcon(steps[i]),
                        size: 16,
                        color: i <= current
                            ? AppColors.onPrimary
                            : palette.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == steps.length - 1
                            ? Colors.transparent
                            : (i < current
                                  ? AppColors.primary
                                  : palette.border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  steps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextSizes.caption,
                    fontWeight: i == current
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i <= current ? palette.text : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
