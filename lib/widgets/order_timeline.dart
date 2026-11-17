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

    if (status == Store.awaitingPaymentStatus) {
      final color = orderStatusColor(context, status);
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Menunggu pembayaran. Pesanan diproses setelah dibayar.',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      );
    }

    final current = steps.indexOf(status).clamp(0, steps.length - 1);

    // Garis terisi bertahap dari langkah pertama sampai status sekarang. Saat
    // status berubah, hanya selisihnya yang beranimasi.
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: UiConfig.animate ? 0 : current.toDouble(),
        end: current.toDouble(),
      ),
      duration: UiConfig.motion(Duration(milliseconds: 380 * current)),
      curve: Curves.easeInOut,
      builder: (context, progress, _) => _steps(palette, progress, current),
    );
  }

  /// Jarak [progress] melewati ambang [from]..[from]+0.5, dibatasi 0..1.
  static double _fill(double progress, double from) =>
      ((progress - from) / 0.5).clamp(0.0, 1.0);

  Widget _steps(AppPalette palette, double progress, int current) {
    const duration = Duration(milliseconds: 180);

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
                      child: i == 0
                          ? const SizedBox(height: 3)
                          : _Bar(
                              fill: _fill(progress, i - 0.5),
                              track: palette.border,
                            ),
                    ),
                    // Langkah menyala saat garis sampai ke sana.
                    Builder(
                      builder: (context) {
                        final reached = progress >= i - 0.01;
                        final passed = progress >= i + 0.5;
                        return AnimatedContainer(
                          duration: UiConfig.motion(duration),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: reached
                                ? context.palette.accent
                                : palette.surfaceAlt,
                            border: Border.all(
                              color: reached
                                  ? context.palette.accent
                                  : palette.border,
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            passed
                                ? Icons.check_rounded
                                : orderStatusIcon(steps[i]),
                            size: 16,
                            color: reached
                                ? context.palette.onAccent
                                : palette.textMuted,
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox(height: 3)
                          : _Bar(
                              fill: _fill(progress, i.toDouble()),
                              track: palette.border,
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

/// Garis penghubung setebal 3 yang terisi warna utama sebesar [fill] (0..1)
/// dari kiri.
class _Bar extends StatelessWidget {
  final double fill;
  final Color track;

  const _Bar({required this.fill, required this.track});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: track)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: ColoredBox(color: context.palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
