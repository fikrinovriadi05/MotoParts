import 'package:flutter/material.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/widgets/primary_button.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 76,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pembayaran Berhasil!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.palette.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pesanan kamu telah diterima dan sedang diproses.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textMuted, height: 1.6),
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: 'Kembali ke Beranda',
                onPressed: () {
                  userTabIndex.value = UserTab.home;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const UserShell()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
