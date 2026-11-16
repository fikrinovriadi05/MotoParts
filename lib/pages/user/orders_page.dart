import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/status_badge.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final orders = store.ordersForCurrentAccount;
          if (orders.isEmpty) {
            return Center(
              child: Text(
                'Belum ada pesanan.',
                style: TextStyle(color: context.palette.textMuted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return GlassCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(order: order),
                      ),
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      order.code,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${formatRupiah(order.total)} • ${order.customer}'
                        '${order.createdAt == null ? '' : '\n${formatTanggal(order.createdAt!)}'}',
                        style: TextStyle(color: context.palette.textMuted),
                      ),
                    ),
                    trailing: StatusBadge(order.status),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
