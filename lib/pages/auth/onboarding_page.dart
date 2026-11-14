import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/widgets/primary_button.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      AppColors.blue.withValues(alpha: 0.12),
                      AppColors.black.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 120,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Lengkap & Berkualitas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Temukan ribuan sparepart motor dengan tampilan modern dan pengalaman belanja yang nyaman.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(true),
                  _dot(false),
                  _dot(false),
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

  Widget _dot(bool active) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.blue : AppColors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
