import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/wishlist_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) => ListView(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.currentAccount?.name ?? 'Tamu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          auth.currentAccount?.email ?? '-',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _menu(
              Icons.favorite_border,
              'Wishlist',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistPage()),
              ),
            ),
            _menu(
              Icons.person_outline,
              'Data Akun',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ),
            ),
            _menu(
              Icons.lock_outline,
              'Ganti Password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
            _menu(Icons.location_on_outlined, 'Alamat Pengiriman'),
            _menu(Icons.credit_card, 'Metode Pembayaran'),
            _menu(Icons.notifications_none, 'Notifikasi'),
            _menu(Icons.info_outline, 'Tentang MotoPart'),
            const SizedBox(height: 12),
            PrimaryButton(
              text: 'Keluar',
              outline: true,
              onPressed: () {
                auth.logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        // Material sendiri agar efek tap ListTile tidak tertutup warna kartu.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: onTap,
            leading: Icon(icon, color: AppColors.blue),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }
}
