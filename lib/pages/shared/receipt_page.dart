import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/receipt.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/brand_mark.dart';
import 'package:motopart/widgets/motopart_wordmark.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:share_plus/share_plus.dart';

/// Struk pembelian satu pesanan, bisa dibagikan atau disalin sebagai teks.
class ReceiptPage extends StatelessWidget {
  final OrderItem order;

  /// Membagikan teks struk. Bawaan: lembar berbagi sistem; diganti di tes.
  final Future<void> Function(String text)? onShare;

  const ReceiptPage({super.key, required this.order, this.onShare});

  Future<void> _share(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (onShare != null) {
        await onShare!(text);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'Struk MotoPart ${order.code}'),
        );
      }
    } on Object {
      // Perangkat tanpa lembar berbagi (mis. peramban tertentu): salin saja.
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Berbagi tidak tersedia, struk disalin ke papan klip.'),
        ),
      );
    }
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Struk disalin.')));
  }

  @override
  Widget build(BuildContext context) {
    final receipt = Receipt.of(order);
    final text = receipt.toText();

    return Scaffold(
      appBar: AppBar(title: const Text('Struk Pembelian')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _Paper(receipt: receipt),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Bagikan Struk',
                    icon: Icons.share_rounded,
                    onPressed: () => _share(context, text),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    text: 'Salin Struk',
                    icon: Icons.copy_rounded,
                    outline: true,
                    onPressed: () => _copy(context, text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lembar struk: kepala toko, rincian barang, total, dan keterangan bayar.
class _Paper extends StatelessWidget {
  final Receipt receipt;

  const _Paper({required this.receipt});

  OrderItem get order => receipt.order;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final paid = receipt.paymentStatus == 'LUNAS';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 52)),
          const SizedBox(height: AppSpacing.sm),
          const Center(child: MotoPartWordmark(fontSize: 22)),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'STRUK PEMBELIAN',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: AppTextSizes.small,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const _Dashed(),
          _info(context, 'No. Pesanan', order.code),
          if (order.createdAt != null)
            _info(context, 'Tanggal', formatTanggal(order.createdAt!)),
          _info(context, 'Pelanggan', order.customer),
          if (order.address != null) _info(context, 'Alamat', order.address!),
          const _Dashed(),
          if (order.lines.isEmpty)
            Text(
              'Rincian barang tidak tersedia untuk pesanan ini.',
              style: TextStyle(color: palette.textMuted),
            )
          else
            for (final line in order.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            '${line.qty} x ${formatRupiah(line.price)}',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: AppTextSizes.small,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatRupiah(line.price * line.qty),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
              ),
          const _Dashed(),
          if (order.lines.isNotEmpty) ...[
            _amount(context, 'Subtotal', receipt.subtotal),
            if (receipt.shipping > 0)
              _amount(context, 'Ongkos Kirim', receipt.shipping),
            const SizedBox(height: 4),
          ],
          _amount(context, 'TOTAL', order.total, bold: true),
          const _Dashed(),
          if (order.paymentMethod != null)
            _info(context, 'Pembayaran', order.paymentMethod!),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: (paid ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                receipt.paymentStatus,
                key: const ValueKey('receipt-status'),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: paid
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.success
                            : const Color(0xFF15803D))
                      : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.warning
                            : const Color(0xFFB45309)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'Terima kasih sudah belanja di MotoPart!',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(color: palette.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amount(
    BuildContext context,
    String label,
    int value, {
    bool bold = false,
  }) {
    final palette = context.palette;
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      fontSize: bold ? AppTextSizes.title : AppTextSizes.body,
      color: bold ? palette.primaryText : palette.text,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style.copyWith(
                color: bold ? palette.text : palette.textMuted,
              ),
            ),
          ),
          Text(formatRupiah(value), style: style),
        ],
      ),
    );
  }
}

/// Garis putus-putus pemisah bagian struk.
class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) {
    final color = context.palette.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 8).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(width: 4, height: 1.5, color: color),
            ],
          );
        },
      ),
    );
  }
}
