import 'package:flutter/material.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/user/addresses_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/payment_methods_page.dart';
import 'package:motopart/pages/user/wishlist_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.16),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: palette.primaryText,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.currentAccount?.name ?? 'Tamu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.currentAccount?.email ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textMuted),
                        ),
                        if (auth.currentAccount?.hasMotor ?? false) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.two_wheeler_rounded,
                                size: 16,
                                color: palette.primaryText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  auth.currentAccount!.motorSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ThemeSwitcher(),
            const SizedBox(height: AppSpacing.lg),
            _menu(
              context,
              Icons.receipt_long_rounded,
              'Pesanan Saya',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrdersPage()),
              ),
            ),
            _menu(
              context,
              Icons.favorite_border_rounded,
              'Wishlist',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistPage()),
              ),
            ),
            _menu(
              context,
              Icons.person_outline_rounded,
              'Data Akun',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ),
            ),
            _menu(
              context,
              Icons.lock_outline_rounded,
              'Ganti Password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
            _menu(
              context,
              Icons.location_on_outlined,
              'Alamat Pengiriman',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddressesPage()),
              ),
            ),
            _menu(
              context,
              Icons.credit_card_rounded,
              'Metode Pembayaran',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentMethodsPage()),
              ),
            ),
            _menu(context, Icons.notifications_none_rounded, 'Notifikasi'),
            _menu(context, Icons.info_outline_rounded, 'Tentang MotoPart'),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              text: 'Keluar',
              icon: Icons.logout_rounded,
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

  Widget _menu(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        // Material sendiri agar efek tap ListTile tidak tertutup warna kartu.
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: onTap,
            leading: Icon(icon, color: palette.primaryText),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilihan tampilan: ikuti sistem, terang, atau gelap.
class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tampilan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppTextSizes.bodyLarge,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeController,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
                selectedBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.2,
                ),
                selectedForegroundColor: palette.primaryText,
                foregroundColor: palette.textMuted,
                side: BorderSide(color: palette.border),
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistem'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Terang'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Gelap'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) =>
                  themeController.setMode(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}
