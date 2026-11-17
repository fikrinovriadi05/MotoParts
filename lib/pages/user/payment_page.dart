import 'package:flutter/material.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/payment_waiting_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/checkout_steps.dart';
import 'package:motopart/widgets/order_summary_card.dart';
import 'package:motopart/widgets/payment_method_picker.dart';

class PaymentPage extends StatefulWidget {
  final String customerName;
  final int shippingCost;

  /// Alamat pengiriman (teks) yang dicatat di pesanan.
  final String? address;

  const PaymentPage({
    super.key,
    required this.customerName,
    required this.shippingCost,
    this.address,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  PaymentChoice choice = PaymentMethods.usable(
    PaymentMethods.decode(auth.currentAccount?.preferredPayment),
  );

  bool paying = false;

  /// Stok berubah sejak checkout dimulai: sesuaikan keranjang lalu kembali.
  void _stockChanged(List<String> problems) {
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
  }

  Future<void> pay() async {
    if (paying) return;
    final problems = store.cartStockProblems;
    if (store.cart.isEmpty || problems.isNotEmpty) {
      _stockChanged(problems);
      return;
    }

    // COD: tidak lewat server, pesanan langsung diproses.
    if (!choice.isOnline) {
      final ok = store.checkout(
        customer: widget.customerName,
        shippingCost: widget.shippingCost,
        address: widget.address,
        paymentMethod: choice.label,
      );
      if (!ok) {
        _stockChanged(problems);
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
        (route) => route.isFirst,
      );
      return;
    }

    // Online: buat tagihan di server dulu; pesanan baru disimpan jika berhasil
    // (stok ditahan sampai dibayar atau kedaluwarsa).
    setState(() => paying = true);
    final code = store.newOrderCode();
    final amount = store.cartTotal + widget.shippingCost;
    try {
      final snapshot = await paymentApi.create(
        orderCode: code,
        choice: choice,
        amount: amount,
        customerName: widget.customerName,
      );
      if (!mounted) return;

      final ok = store.checkout(
        customer: widget.customerName,
        shippingCost: widget.shippingCost,
        address: widget.address,
        paymentMethod: choice.label,
        payment: snapshot.info,
        code: code,
      );
      if (!ok) {
        // Stok habis selama menunggu server; tagihan di server kedaluwarsa sendiri.
        _stockChanged(store.cartStockProblems);
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PaymentWaitingPage(orderCode: code)),
        (route) => route.isFirst,
      );
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => paying = false);
    }
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
              Expanded(
                child: Text(
                  'Pilih Metode Pembayaran',
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
          const SizedBox(height: AppSpacing.md),
          if (!PaymentMethods.onlineAvailable) ...[
            Text(
              'Pembayaran online (QRIS, Virtual Account, GoPay) tersedia di '
              'aplikasi dengan server pembayaran. Di sini hanya COD.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: AppTextSizes.small,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          PaymentMethodPicker(
            value: choice,
            onChanged: (c) => setState(() => choice = c),
          ),
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
                    choice.isOnline
                        ? 'Tagihan dibuat setelah Anda menekan tombol bayar. '
                              'Pembayaran dicek otomatis, tidak perlu konfirmasi manual.'
                        : 'Bayar tunai ke kurir saat barang tiba. Pesanan '
                              'langsung diproses.',
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
          buttonText: paying ? 'Membuat tagihan...' : 'Bayar Sekarang',
          icon: Icons.lock_rounded,
          onPressed: paying ? null : pay,
        ),
      ),
    );
  }
}
