import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/glass_card.dart';

/// Ringkasan isi keranjang + ongkir + total, dipakai di checkout dan
/// pembayaran.
class OrderSummaryCard extends StatelessWidget {
  final int shippingCost;

  const OrderSummaryCard({super.key, required this.shippingCost});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bold ? palette.text : palette.textMuted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: bold ? AppTextSizes.bodyLarge : AppTextSizes.body,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              color: bold ? palette.primaryText : palette.text,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? AppTextSizes.title : AppTextSizes.body,
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Pesanan',
            style: TextStyle(
              fontSize: AppTextSizes.bodyLarge,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in store.checkoutItems)
            row(
              '${item.product.name} × ${item.qty}',
              formatRupiah(item.product.price * item.qty),
            ),
          const Divider(height: AppSpacing.xl),
          row('Subtotal', formatRupiah(store.checkoutTotal)),
          row('Ongkos Kirim', formatRupiah(shippingCost)),
          const SizedBox(height: AppSpacing.xs),
          row(
            'Total Pembayaran',
            formatRupiah(store.checkoutTotal + shippingCost),
            bold: true,
          ),
        ],
      ),
    );
  }
}

/// Bar bawah yang menempel: total di kiri, tombol aksi di kanan/bawah.
class CheckoutBottomBar extends StatelessWidget {
  final int total;
  final String buttonText;
  final IconData icon;

  /// Null menonaktifkan tombol (mis. saat sedang diproses).
  final VoidCallback? onPressed;

  const CheckoutBottomBar({
    super.key,
    required this.total,
    required this.buttonText,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(color: palette.textMuted),
                    ),
                  ),
                  Text(
                    formatRupiah(total),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppTextSizes.title,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(text: buttonText, icon: icon, onPressed: onPressed),
            ],
          ),
        ),
      ),
    );
  }
}
