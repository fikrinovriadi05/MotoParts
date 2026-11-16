import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  final String title;
  final IconData icon;

  const CategoryChip({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  context.palette.text.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: context.palette.text,
            ),
          ),
        ],
      ),
    );
  }
}
