import 'package:flutter/material.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/appearance_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/hover.dart';

/// Pengaturan admin: tampilan, pengguna, laporan, password, data contoh, dan
/// keluar.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// Konfirmasi lalu keluar dari akun admin.
  void confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, size: 32),
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              auth.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi lalu mengembalikan produk & pesanan ke data contoh.
  void confirmResetSampleData(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.palette;
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: palette.dangerText,
            size: 32,
          ),
          title: const Text('Reset Data Contoh?'),
          content: const Text(
            'Semua produk, kategori, pesanan, keranjang, wishlist, dan ulasan '
            'saat ini akan dihapus lalu diganti dengan data contoh '
            '(${Store.sampleProductCount} produk dan '
            '${Store.sampleOrderCount} pesanan). Foto produk yang sudah '
            'diunggah ikut terhapus.\n\n'
            'Akun pengguna tidak berubah. Tindakan ini tidak bisa dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                final photos = store.resetSampleData();
                for (final path in photos) {
                  productImageStorage.delete(path);
                }
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Data contoh dikembalikan.')),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          final admin = auth.currentAccount;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                      child: Text(
                        (admin?.name.isNotEmpty ?? false)
                            ? admin!.name[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin?.name ?? 'Admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: AppTextSizes.bodyLarge,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            admin?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Group(
                children: [
                  _Tile(
                    icon: Icons.palette_outlined,
                    title: 'Pengaturan Tampilan',
                    subtitle: 'Mode terang/gelap dan warna aksen',
                    onTap: () => _push(context, const AppearancePage()),
                  ),
                  _Tile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Laporan Penjualan',
                    subtitle: 'Per periode, ekspor ke Excel',
                    onTap: () => _push(context, const AdminReportsPage()),
                  ),
                  _Tile(
                    icon: Icons.group_outlined,
                    title: 'Pengguna',
                    subtitle: 'Daftar pembeli dan reset password',
                    onTap: () => _push(context, const AdminUsersPage()),
                  ),
                  _Tile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Ganti Password',
                    subtitle: 'Ubah password akun admin',
                    onTap: () => _push(context, const ChangePasswordPage()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Group(
                children: [
                  _Tile(
                    icon: Icons.restart_alt_rounded,
                    title: 'Reset Data Contoh',
                    subtitle: 'Kembalikan produk dan pesanan ke data awal',
                    danger: true,
                    onTap: () => confirmResetSampleData(context),
                  ),
                  _Tile(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    subtitle: 'Keluar dari akun admin',
                    danger: true,
                    onTap: () => confirmLogout(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sekelompok baris pengaturan dalam satu kartu.
class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = danger ? palette.dangerText : palette.primaryText;
    return HoverBuilder(
      builder: (context, hovered) => Material(
        color: hovered ? palette.surfaceAlt : Colors.transparent,
        child: ListTile(
          onTap: onTap,
          minVerticalPadding: 12,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: danger ? palette.dangerText : palette.text,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: AppTextSizes.small,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: palette.textMuted),
        ),
      ),
    );
  }
}
