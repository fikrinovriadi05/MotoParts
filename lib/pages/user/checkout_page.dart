import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final name = TextEditingController(text: 'Budi Santoso');
  final phone = TextEditingController(text: '081234567890');
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          customerName: name.text,
          shippingCost: shippingCost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = store.cartTotal + shippingCost;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Alamat Pengiriman',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Nama Penerima',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Nomor HP',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: address,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap',
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Kurir Pengiriman',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: shipping,
            onChanged: (value) {
              setState(() {
                shipping = value!;
                shippingCost = value == 'JNE Regular' ? 10000 : 12000;
              });
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  value: 'JNE Regular',
                  activeColor: AppColors.blue,
                  title: Text('JNE Regular'),
                  subtitle: Text('Estimasi 2–4 hari'),
                  secondary: Text('Rp10.000'),
                ),
                RadioListTile<String>(
                  value: 'J&T Express',
                  activeColor: AppColors.blue,
                  title: Text('J&T Express'),
                  subtitle: Text('Estimasi 2–3 hari'),
                  secondary: Text('Rp12.000'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(
                    color: AppColors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Lanjutkan Pembayaran',
            onPressed: next,
          ),
        ],
      ),
    );
  }
}
