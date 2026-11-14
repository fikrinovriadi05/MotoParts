import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

class PaymentPage extends StatefulWidget {
  final String customerName;
  final int shippingCost;

  const PaymentPage({
    super.key,
    required this.customerName,
    required this.shippingCost,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'Transfer Bank';

  void pay() {
    store.checkout(
      customer: widget.customerName,
      shippingCost: widget.shippingCost,
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const PaymentSuccessPage(),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = store.cartTotal + widget.shippingCost;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pilih Metode Pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: method,
            onChanged: (value) => setState(() => method = value!),
            child: Column(
              children: [
                _paymentTile('Transfer Bank', Icons.account_balance),
                _paymentTile(
                    'E-Wallet', Icons.account_balance_wallet_outlined),
                _paymentTile('Virtual Account', Icons.receipt_long),
                _paymentTile('COD', Icons.payments_outlined),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Ini hanya simulasi pembayaran untuk tugas kuliah, bukan transaksi nyata.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Bayar Sekarang',
            onPressed: pay,
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(String title, IconData icon) {
    return Card(
      child: RadioListTile<String>(
        value: title,
        activeColor: AppColors.blue,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        secondary: Icon(icon, color: AppColors.blue),
      ),
    );
  }
}
