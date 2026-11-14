import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';

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
        selectedColor: AppColors.blue,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.black,
        ),
        showCheckmark: false,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.border),
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
                    hintText: 'Cari kode pesanan atau nama pelanggan',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.close),
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
                    ? const Center(
                        child: Text(
                          'Tidak ada pesanan yang cocok.',
                          style: TextStyle(color: AppColors.grey),
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
                                  Text(
                                    order.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${order.customer} • ${formatRupiah(order.total)}',
                                    style: const TextStyle(
                                      color: AppColors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
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
