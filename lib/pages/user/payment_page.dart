import 'package:flutter/material.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/checkout_steps.dart';
import 'package:motopart/widgets/order_summary_card.dart';
import 'package:motopart/widgets/selectable_card.dart';

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
  static const methods = [
    (
      'Transfer Bank',
      Icons.account_balance_rounded,
      'Transfer manual ke rekening toko',
    ),
    (
      'E-Wallet',
      Icons.account_balance_wallet_outlined,
      'Bayar lewat dompet digital',
    ),
    (
      'Virtual Account',
      Icons.receipt_long_rounded,
      'Nomor virtual account khusus pesanan',
    ),
    ('COD', Icons.payments_outlined, 'Bayar tunai saat barang tiba'),
  ];

  String method = 'Transfer Bank';

  void pay() {
    final problems = store.cartStockProblems;
    final ok = store.checkout(
      customer: widget.customerName,
      shippingCost: widget.shippingCost,
    );

    if (!ok) {
      // Stok berubah sejak checkout dimulai: sesuaikan keranjang lalu kembali.
      store.trimCartToStock();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            problems.isEmpty
                ? 'Keranjang kosong.'
                : '${problems.join(' ')} Keranjang disesuaikan, periksa kembali.',
          ),
        ),
      );
      Navigator.of(context)
        ..pop() // PaymentPage
        ..pop(); // CheckoutPage -> kembali ke keranjang
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const CheckoutSteps(current: 1),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Icon(Icons.payment_rounded, size: 20, color: palette.primaryText),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Pilih Metode Pembayaran',
                style: TextStyle(
                  fontSize: AppTextSizes.bodyLarge,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (title, icon, subtitle) in methods) ...[
            SelectableCard(
              selected: method == title,
              onTap: () => setState(() => method = title),
              icon: icon,
              title: title,
              subtitle: subtitle,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          AnimatedBuilder(
            animation: store,
            builder: (context, _) =>
                OrderSummaryCard(shippingCost: widget.shippingCost),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: palette.primaryText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Ini hanya simulasi pembayaran, bukan transaksi nyata.',
                    style: TextStyle(
                      fontSize: AppTextSizes.small,
                      color: palette.text,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: store,
        builder: (context, _) => CheckoutBottomBar(
          total: store.cartTotal + widget.shippingCost,
          buttonText: 'Bayar Sekarang',
          icon: Icons.lock_rounded,
          onPressed: pay,
        ),
      ),
    );
  }
}
