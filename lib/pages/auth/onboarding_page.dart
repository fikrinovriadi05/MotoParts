import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/widgets/primary_button.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      context.palette.text.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 120,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 36),
              Text(
                'Lengkap & Berkualitas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.palette.text,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Temukan ribuan sparepart motor dengan tampilan modern dan pengalaman belanja yang nyaman.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(context, true),
                  _dot(context, false),
                  _dot(context, false),
                ],
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                text: 'Mulai Sekarang',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(BuildContext context, bool active) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary
            : context.palette.textMuted.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
