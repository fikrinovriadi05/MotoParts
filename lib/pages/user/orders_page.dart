import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/press_scale.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/status_badge.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  /// Ringkasan isi pesanan, mis. "Busi NGK dan 2 lainnya".
  static String itemsSummary(OrderItem order) {
    if (order.lines.isEmpty) return order.customer;
    final first = order.lines.first.name;
    final others = order.lines.length - 1;
    return others == 0 ? first : '$first dan $others lainnya';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final orders = store.ordersForCurrentAccount;
          if (orders.isEmpty) return const _EmptyOrders();

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderItem order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = orderStatusColor(context, order.status);

    return PressScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
      ),
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                orderStatusIcon(order.status),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    OrdersPage.itemsSummary(order),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: AppTextSizes.small,
                    ),
                  ),
                  if (order.createdAt != null)
                    Text(
                      formatTanggal(order.createdAt!),
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: AppTextSizes.caption,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    formatRupiah(order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: palette.primaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(order.status),
                const SizedBox(height: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 52,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Belum ada pesanan.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pesanan yang kamu buat akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: 'Mulai Belanja',
                icon: Icons.storefront_rounded,
                onPressed: () {
                  userTabIndex.value = UserTab.home;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
