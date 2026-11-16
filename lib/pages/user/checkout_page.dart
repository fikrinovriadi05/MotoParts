import 'package:flutter/material.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/pages/user/address_form_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/checkout_steps.dart';
import 'package:motopart/widgets/order_summary_card.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/selectable_card.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  /// Id alamat yang dipilih; awalnya alamat utama akun.
  String? addressId = auth.currentAccount?.defaultAddress?.id;
  String shipping = 'JNE Regular';
  int shippingCost = 10000;

  ShippingAddress? get selectedAddress {
    final list = auth.currentAccount?.addresses ?? const <ShippingAddress>[];
    return list.where((a) => a.id == addressId).firstOrNull ??
        auth.currentAccount?.defaultAddress;
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.push<ShippingAddress>(
      context,
      MaterialPageRoute(builder: (_) => const AddressFormPage()),
    );
    if (saved != null && mounted) setState(() => addressId = saved.id);
  }

  void next() {
    final address = selectedAddress;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih atau tambah alamat pengiriman terlebih dahulu.'),
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
        builder: (_) => PaymentPage(
          customerName: address.recipient,
          shippingCost: shippingCost,
          address: address.orderText,
        ),
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
          AnimatedBuilder(
            animation: auth,
            builder: (context, _) {
              final addresses =
                  auth.currentAccount?.addresses ?? const <ShippingAddress>[];
              final current = selectedAddress;
              return Column(
                children: [
                  for (final a in addresses) ...[
                    SelectableCard(
                      selected: current?.id == a.id,
                      onTap: () => setState(() => addressId = a.id),
                      icon: Icons.location_on_rounded,
                      title: a.label,
                      subtitle: '${a.recipient} · ${a.phone}\n${a.fullText}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  PrimaryButton(
                    text: addresses.isEmpty
                        ? 'Tambah Alamat Pengiriman'
                        : 'Tambah Alamat Baru',
                    icon: Icons.add_location_alt_rounded,
                    outline: addresses.isNotEmpty,
                    onPressed: _addAddress,
                  ),
                ],
              );
            },
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
