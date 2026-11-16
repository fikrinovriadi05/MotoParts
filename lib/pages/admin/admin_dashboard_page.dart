import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/press_scale.dart';
import 'package:motopart/widgets/section_title.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Jumlah kolom kartu statistik: 2 di HP, 4 di layar lebar.
int statColumns(double width) => width >= 700 ? 4 : 2;

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  void _logout(BuildContext context) {
    auth.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([store, auth]),
        builder: (context, _) {
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    _Header(
                      name: auth.currentAccount?.name ?? 'Admin',
                      onLogout: () => _logout(context),
                    ),
                    if (auth.adminUsesDefaultPassword) ...[
                      const SizedBox(height: AppSpacing.md),
                      _DefaultPasswordBanner(),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersPage(),
                              ),
                            ),
                            icon: const Icon(Icons.group_outlined),
                            label: const Text('Pengguna'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            ),
                            icon: const Icon(Icons.lock_outline_rounded),
                            label: const Text('Password'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: statColumns(constraints.maxWidth),
                      crossAxisSpacing: AppSpacing.md + 2,
                      mainAxisSpacing: AppSpacing.md + 2,
                      childAspectRatio: 1.25,
                      children: [
                        _StatCard(
                          title: 'Total Produk',
                          value: '${store.products.length}',
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.primary,
                        ),
                        _StatCard(
                          title: 'Total Pesanan',
                          value: '${store.orders.length}',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.success,
                        ),
                        _StatCard(
                          title: 'Stok Menipis',
                          value:
                              '${store.products.where((p) => p.stock < 10).length}',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        _StatCard(
                          title: 'Pelanggan',
                          value: '${auth.userAccounts.length}',
                          icon: Icons.people_alt_rounded,
                          color: palette.primaryText,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionTitle(title: 'Pesanan Terbaru'),
                    const SizedBox(height: AppSpacing.sm),
                    if (store.orders.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Center(
                          child: Text(
                            'Belum ada pesanan.',
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ),
                      ),
                    for (final order in store.orders.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: PressScale(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderDetailPage(order: order, isAdmin: true),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md + 2),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.code,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: palette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order.customer} • ${formatRupiah(order.total)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge(order.status),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Header gelap: sapaan admin dan tombol keluar.
class _Header extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;

  const _Header({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.charcoal,
            AppColors.charcoalSoft,
            Color(0xFF7A3510),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSizes.heading,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Halo, $name. Kelola seluruh aktivitas toko dari satu tempat.',
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: onLogout,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.10),
            ),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _DefaultPasswordBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Anda masih memakai password admin bawaan. '
              'Segera ganti demi keamanan.',
              style: TextStyle(
                fontSize: AppTextSizes.small,
                height: 1.4,
                color: palette.text,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: AppTextSizes.display,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: AppTextSizes.small,
            ),
          ),
        ],
      ),
    );
  }
}
