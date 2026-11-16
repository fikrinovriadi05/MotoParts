import 'package:flutter/material.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/checkout_steps.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/order_summary_card.dart';
import 'package:motopart/widgets/selectable_card.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final name = TextEditingController(text: auth.currentAccount?.name ?? '');
  final phone = TextEditingController(text: auth.currentAccount?.phone ?? '');
  final address = TextEditingController();
  String shipping = 'JNE Regular';
  int shippingCost = 10000;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  void next() {
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi alamat pengiriman terlebih dahulu.'),
        ),
      );
      return;
    }

    final problems = store.cartStockProblems;
    if (problems.isNotEmpty) {
      store.trimCartToStock();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${problems.join(' ')} Keranjang disesuaikan, periksa kembali.',
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentPage(customerName: name.text, shippingCost: shippingCost),
      ),
    );
  }

  void _selectCourier(String courier, int cost) {
    setState(() {
      shipping = courier;
      shippingCost = cost;
    });
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.primaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTextSizes.bodyLarge,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const CheckoutSteps(current: 0),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle(
            context,
            Icons.location_on_rounded,
            'Alamat Pengiriman',
          ),
          GlassCard(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Penerima',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: address,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap',
                    prefixIcon: Icon(Icons.home_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _sectionTitle(
            context,
            Icons.local_shipping_rounded,
            'Kurir Pengiriman',
          ),
          SelectableCard(
            selected: shipping == 'JNE Regular',
            onTap: () => _selectCourier('JNE Regular', 10000),
            icon: Icons.local_shipping_rounded,
            title: 'JNE Regular',
            subtitle: 'Estimasi 2–4 hari',
            trailing: 'Rp 10.000',
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableCard(
            selected: shipping == 'J&T Express',
            onTap: () => _selectCourier('J&T Express', 12000),
            icon: Icons.rocket_launch_rounded,
            title: 'J&T Express',
            subtitle: 'Estimasi 2–3 hari',
            trailing: 'Rp 12.000',
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedBuilder(
            animation: store,
            builder: (context, _) =>
                OrderSummaryCard(shippingCost: shippingCost),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: store,
        builder: (context, _) => CheckoutBottomBar(
          total: store.cartTotal + shippingCost,
          buttonText: 'Lanjutkan Pembayaran',
          icon: Icons.arrow_forward_rounded,
          onPressed: next,
        ),
      ),
    );
  }
}
