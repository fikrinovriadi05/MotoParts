import 'package:flutter/material.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/remote_gateway.dart';
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
    if (store.checkoutItems.isEmpty || problems.isNotEmpty) {
      _stockChanged(problems);
      return;
    }

    // COD: tidak lewat server pembayaran, pesanan langsung diproses.
    if (!choice.isOnline) {
      setState(() => paying = true);
      try {
        final failed = await store.placeOrder(
          customer: widget.customerName,
          shippingCost: widget.shippingCost,
          address: widget.address,
          paymentMethod: choice.label,
        );
        if (!mounted) return;
        if (failed != null) {
          _stockChanged(failed);
          return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PaymentSuccessPage()),
          (route) => route.isFirst,
        );
      } on RemoteException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      } finally {
        if (mounted) setState(() => paying = false);
      }
      return;
    }

    // Online: buat tagihan di server dulu; pesanan baru disimpan jika berhasil
    // (stok ditahan sampai dibayar atau kedaluwarsa).
    setState(() => paying = true);
    final code = store.newOrderCode();
    final amount = store.checkoutTotal + widget.shippingCost;
    try {
      final snapshot = await paymentApi.create(
        orderCode: code,
        choice: choice,
        amount: amount,
        customerName: widget.customerName,
      );
      if (!mounted) return;

      final failed = await store.placeOrder(
        customer: widget.customerName,
        shippingCost: widget.shippingCost,
        address: widget.address,
        paymentMethod: choice.label,
        payment: snapshot.info,
        code: code,
      );
      if (!mounted) return;
      if (failed != null) {
        // Stok habis selama menunggu server; tagihan di server kedaluwarsa sendiri.
        _stockChanged(failed);
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
    } on RemoteException catch (e) {
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
          if (PaymentMethods.demoMode) ...[
            _DemoNotice(
              text:
                  'Mode demo: QRIS disimulasikan di aplikasi, tanpa uang '
                  'sungguhan. Virtual Account dan e-wallet butuh server '
                  'pembayaran.',
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (!PaymentMethods.onlineAvailable) ...[
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
              color: context.palette.accent.withValues(alpha: 0.10),
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
          total: store.checkoutTotal + widget.shippingCost,
          buttonText: paying ? 'Membuat tagihan...' : 'Bayar Sekarang',
          icon: Icons.lock_rounded,
          onPressed: paying ? null : pay,
        ),
      ),
    );
  }
}

/// Catatan kecil bahwa pembayaran yang dipilih hanya simulasi.
class _DemoNotice extends StatelessWidget {
  final String text;

  const _DemoNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const ValueKey('demo-notice'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.text,
                fontSize: AppTextSizes.small,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
