import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Detail satu pesanan. Dipakai pembeli (hanya lihat) dan admin
/// ([isAdmin] = true, bisa mengubah status).
class OrderDetailPage extends StatelessWidget {
  final OrderItem order;
  final bool isAdmin;

  const OrderDetailPage({super.key, required this.order, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final itemsTotal = order.lines.fold<int>(
            0,
            (sum, line) => sum + line.price * line.qty,
          );
          final shipping = order.total - itemsTotal;

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pelanggan: ${order.customer}',
                      style: const TextStyle(color: AppColors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Barang Dipesan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              GlassCard(
                child: order.lines.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rincian barang tidak tersedia untuk pesanan ini.',
                            style: TextStyle(color: AppColors.grey),
                          ),
                          const Divider(height: 24),
                          _summaryRow('Total', order.total, bold: true),
                        ],
                      )
                    : Column(
                        children: [
                          for (final line in order.lines) _lineRow(line),
                          const Divider(height: 24),
                          _summaryRow('Subtotal Barang', itemsTotal),
                          if (shipping > 0)
                            _summaryRow('Ongkos Kirim', shipping),
                          const SizedBox(height: 4),
                          _summaryRow('Total', order.total, bold: true),
                        ],
                      ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: order.status,
                  decoration: const InputDecoration(
                    labelText: 'Status Pesanan',
                  ),
                  items: [
                    for (final status in Store.orderStatuses)
                      DropdownMenuItem(value: status, child: Text(status)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateOrderStatus(order, value);
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _lineRow(OrderLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.qty} x ${formatRupiah(line.price)}',
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(line.price * line.qty),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      color: bold ? AppColors.black : AppColors.grey,
      fontSize: bold ? 16 : 14,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(formatRupiah(value), style: style),
      ],
    );
  }
}
