import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

IconData orderStatusIcon(String status) => switch (status) {
  'Dikemas' => Icons.inventory_2_rounded,
  'Dikirim' => Icons.local_shipping_rounded,
  'Selesai' => Icons.check_circle_rounded,
  'Dibatalkan' => Icons.cancel_rounded,
  _ => Icons.hourglass_top_rounded, // Diproses
};

/// Warna status. Di mode terang dipakai varian lebih gelap agar teksnya
/// terbaca di atas latar putih.
Color orderStatusColor(BuildContext context, String status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    'Selesai' => dark ? AppColors.success : const Color(0xFF15803D),
    'Dikirim' => dark ? AppColors.warning : const Color(0xFFB45309),
    'Dibatalkan' => context.palette.dangerText,
    _ => context.palette.primaryText, // Diproses, Dikemas
  };
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(context, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(orderStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: AppTextSizes.small,
            ),
          ),
        ],
      ),
    );
  }
}
