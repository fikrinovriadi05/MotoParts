import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/section_title.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([store, auth]),
        builder: (context, _) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.charcoal,
                        AppColors.charcoalSoft,
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard Admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kelola seluruh aktivitas toko dari satu tempat.',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          auth.logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (auth.adminUsesDefaultPassword) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Anda masih memakai password admin bawaan. '
                            'Segera ganti demi keamanan.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordPage(),
                            ),
                          ),
                          child: const Text('Ganti'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
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
                        label: const Text('Kelola Pengguna'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Ganti Password'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.22,
                  children: [
                    _statCard(
                      context,
                      title: 'Total Produk',
                      value: '${store.products.length}',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.primary,
                    ),
                    _statCard(
                      context,
                      title: 'Total Pesanan',
                      value: '${store.orders.length}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.success,
                    ),
                    _statCard(
                      context,
                      title: 'Stok Menipis',
                      value:
                          '${store.products.where((p) => p.stock < 10).length}',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.warning,
                    ),
                    _statCard(
                      context,
                      title: 'Pelanggan',
                      value: '3',
                      icon: Icons.people_outline_rounded,
                      color: context.palette.text,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionTitle(title: 'Pesanan Terbaru'),
                const SizedBox(height: 10),
                ...store.orders
                    .take(3)
                    .map(
                      (order) => GlassCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            order.code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${order.customer} • ${formatRupiah(order.total)}',
                            style: TextStyle(color: context.palette.textMuted),
                          ),
                          trailing: _badge(order.status),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: context.palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: context.palette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String status) {
    Color color = AppColors.primary;
    if (status == 'Selesai') color = AppColors.success;
    if (status == 'Dikirim') color = AppColors.warning;

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
