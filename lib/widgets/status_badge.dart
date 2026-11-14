import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.blue;
    if (status == 'Selesai') color = AppColors.green;
    if (status == 'Dikirim') color = AppColors.orange;
    if (status == 'Dibatalkan') color = AppColors.red;

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
