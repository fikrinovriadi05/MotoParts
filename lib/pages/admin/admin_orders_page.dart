import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/status_badge.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final searchController = TextEditingController();
  String query = '';
  String? statusFilter; // null = semua status

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int _countFor(String? status) =>
      store.orders.where((o) => status == null || o.status == status).length;

  Widget _filterChip(String label, String? status) {
    final selected = statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label (${_countFor(status)})'),
        selected: selected,
        onSelected: (_) => setState(() => statusFilter = status),
        selectedColor: context.palette.accent,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? context.palette.onAccent : context.palette.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final orders = store.filterOrders(query: query, status: statusFilter);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: 'Cari kode atau nama pelanggan',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _filterChip('Semua', null),
                    for (final status in Store.orderStatuses)
                      _filterChip(status, status),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 48,
                              color: context.palette.textMuted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Tidak ada pesanan yang cocok.',
                              style: TextStyle(
                                color: context.palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Container(
                            key: ValueKey(order.code),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          order.code,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: AppTextSizes.body,
                                            color: context.palette.text,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      StatusBadge(order.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${order.customer} • ${formatRupiah(order.total)}',
                                    style: TextStyle(
                                      color: context.palette.textMuted,
                                    ),
                                  ),
                                  if (order.createdAt != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      formatTanggal(order.createdAt!),
                                      style: TextStyle(
                                        color: context.palette.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: order.status,
                                    decoration: const InputDecoration(
                                      labelText: 'Status Pesanan',
                                    ),
                                    items: [
                                      for (final status in Store.orderStatuses)
                                        DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        store.updateOrderStatus(order, value);
                                      }
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailPage(
                                            order: order,
                                            isAdmin: true,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Lihat Detail'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
