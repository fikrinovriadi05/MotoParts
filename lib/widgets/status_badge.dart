import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.primary;
    if (status == 'Selesai') color = AppColors.success;
    if (status == 'Dikirim') color = AppColors.warning;
    if (status == 'Dibatalkan') color = AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
