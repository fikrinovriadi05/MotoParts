import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.blue.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budi Santoso',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'budi@email.com',
                        style: TextStyle(color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _menu(Icons.person_outline, 'Data Akun'),
          _menu(Icons.location_on_outlined, 'Alamat Pengiriman'),
          _menu(Icons.credit_card, 'Metode Pembayaran'),
          _menu(Icons.notifications_none, 'Notifikasi'),
          _menu(Icons.info_outline, 'Tentang MotoPart'),
          const SizedBox(height: 12),
          PrimaryButton(
            text: 'Keluar',
            outline: true,
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _menu(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.blue),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
