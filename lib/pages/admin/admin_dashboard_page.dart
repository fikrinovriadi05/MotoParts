import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/section_title.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.black, AppColors.dark, AppColors.blue],
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
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
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
                      title: 'Total Produk',
                      value: '${store.products.length}',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.blue,
                    ),
                    _statCard(
                      title: 'Total Pesanan',
                      value: '${store.orders.length}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.green,
                    ),
                    _statCard(
                      title: 'Stok Menipis',
                      value:
                          '${store.products.where((p) => p.stock < 10).length}',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.orange,
                    ),
                    _statCard(
                      title: 'Pelanggan',
                      value: '3',
                      icon: Icons.people_outline,
                      color: AppColors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SectionTitle(title: 'Pesanan Terbaru'),
                const SizedBox(height: 10),
                ...store.orders.take(3).map(
                  (order) => GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        order.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${order.customer} • ${formatRupiah(order.total)}',
                        style: const TextStyle(color: AppColors.grey),
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

  Widget _statCard({
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String status) {
    Color color = AppColors.blue;
    if (status == 'Selesai') color = AppColors.green;
    if (status == 'Dikirim') color = AppColors.orange;

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
