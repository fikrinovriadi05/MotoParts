import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';

class AdminOrdersPage extends StatelessWidget {
  const AdminOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: store.orders.length,
            itemBuilder: (context, index) {
              final order = store.orders[index];
              return Container(
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
                        items: const [
                          DropdownMenuItem(
                            value: 'Diproses',
                            child: Text('Diproses'),
                          ),
                          DropdownMenuItem(
                            value: 'Dikemas',
                            child: Text('Dikemas'),
                          ),
                          DropdownMenuItem(
                            value: 'Dikirim',
                            child: Text('Dikirim'),
                          ),
                          DropdownMenuItem(
                            value: 'Selesai',
                            child: Text('Selesai'),
                          ),
                          DropdownMenuItem(
                            value: 'Dibatalkan',
                            child: Text('Dibatalkan'),
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
          );
        },
      ),
    );
  }
}
