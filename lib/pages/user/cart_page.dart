import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/user/checkout_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          if (store.cart.isEmpty) {
            return const Center(
              child: Text(
                'Keranjang masih kosong',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 16,
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: store.cart.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = store.cart[index];
                    return GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.blue.withValues(alpha: 0.12),
                                  AppColors.black.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              item.product.icon,
                              color: AppColors.blue,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatRupiah(item.product.price),
                                  style: const TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _qtyButton(
                                      icon: Icons.remove,
                                      onTap: () {
                                        store.decreaseQty(item.product);
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        '${item.qty}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    _qtyButton(
                                      icon: Icons.add,
                                      onTap: () {
                                        store.increaseQty(item.product);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              store.removeCart(item.product);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(color: AppColors.grey),
                        ),
                        Text(
                          formatRupiah(store.cartTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      text: 'Checkout (${store.cartCount})',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.blue,
        ),
      ),
    );
  }
}
