import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/payment_waiting_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/order_timeline.dart';
import 'package:motopart/widgets/primary_button.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/review_section.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Detail satu pesanan. Dipakai pembeli (hanya lihat) dan admin
/// ([isAdmin] = true, bisa mengubah status).
class OrderDetailPage extends StatelessWidget {
  final OrderItem order;
  final bool isAdmin;

  const OrderDetailPage({super.key, required this.order, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final itemsTotal = order.lines.fold<int>(
            0,
            (sum, line) => sum + line.price * line.qty,
          );
          final shipping = order.total - itemsTotal;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: AppTextSizes.bodyLarge,
                              color: palette.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StatusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pelanggan: ${order.customer}',
                      style: TextStyle(color: palette.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tanggal: ${order.createdAt == null ? '-' : formatTanggal(order.createdAt!)}',
                      style: TextStyle(color: palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OrderTimeline(status: order.status),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Barang Dipesan',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: AppSpacing.sm),
              GlassCard(
                child: order.lines.isEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rincian barang tidak tersedia untuk pesanan ini.',
                            style: TextStyle(color: palette.textMuted),
                          ),
                          const Divider(height: AppSpacing.xl),
                          _summaryRow(
                            context,
                            'Total',
                            order.total,
                            bold: true,
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final line in order.lines)
                            _lineRow(context, line),
                          const Divider(height: AppSpacing.xl),
                          _summaryRow(context, 'Subtotal Barang', itemsTotal),
                          if (shipping > 0)
                            _summaryRow(context, 'Ongkos Kirim', shipping),
                          const SizedBox(height: 4),
                          _summaryRow(
                            context,
                            'Total',
                            order.total,
                            bold: true,
                          ),
                        ],
                      ),
              ),
              if (order.address != null || order.paymentMethod != null) ...[
                const SizedBox(height: AppSpacing.lg),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.address != null)
                        _infoBlock(
                          context,
                          Icons.location_on_rounded,
                          'Alamat Pengiriman',
                          order.address!,
                        ),
                      if (order.address != null && order.paymentMethod != null)
                        const Divider(height: AppSpacing.xl),
                      if (order.paymentMethod != null)
                        _infoBlock(
                          context,
                          Icons.payment_rounded,
                          'Metode Pembayaran',
                          order.paymentMethod!,
                        ),
                    ],
                  ),
                ),
              ],
              if (!isAdmin &&
                  order.status == Store.awaitingPaymentStatus &&
                  order.payment != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  text: 'Lanjutkan Pembayaran',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentWaitingPage(orderCode: order.code),
                    ),
                  ),
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Ubah Status',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 17),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: order.status,
                  decoration: const InputDecoration(
                    labelText: 'Status Pesanan',
                  ),
                  items: [
                    for (final status in Store.orderStatuses)
                      DropdownMenuItem(value: status, child: Text(status)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateOrderStatus(order, value);
                    }
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoBlock(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: palette.primaryText),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: TextStyle(color: palette.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineRow(BuildContext context, OrderLine line) {
    final palette = context.palette;
    // Gambar diambil dari produknya; produk yang sudah dihapus memakai ikon umum.
    final index = store.products.indexWhere((p) => p.id == line.productId);
    final product = index >= 0 ? store.products[index] : null;

    // Penilaian hanya untuk pembeli, pada pesanan selesai, dan produk yang
    // masih ada.
    final canRate = !isAdmin && order.status == 'Selesai' && product != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProductPicture.forProduct(
                product,
                width: 44,
                height: 44,
                iconSize: 22,
                radius: AppRadius.sm,
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: 2),
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
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ],
          ),
          if (canRate) _rateRow(context, product),
        ],
      ),
    );
  }

  /// Baris penilaian di bawah satu barang pada pesanan yang sudah selesai:
  /// tombol "Beri Penilaian", atau bintang + komentar milik pembeli.
  Widget _rateRow(BuildContext context, Product product) {
    final palette = context.palette;
    final mine = store.myReviewFor(product);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: mine == null
            ? Row(
                children: [
                  const Icon(
                    Icons.star_border_rounded,
                    color: AppColors.star,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bagaimana barang ini?',
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showReviewDialog(context, product),
                    child: const Text('Beri Penilaian'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StarRating(rating: mine.rating.toDouble(), size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Penilaianmu',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: AppTextSizes.small,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showReviewDialog(context, product),
                        child: const Text('Ubah'),
                      ),
                    ],
                  ),
                  if (mine.comment.isNotEmpty)
                    Text(
                      mine.comment,
                      style: TextStyle(color: palette.text, height: 1.4),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    int value, {
    bool bold = false,
  }) {
    final palette = context.palette;
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? palette.primaryText : palette.textMuted,
      fontSize: bold ? AppTextSizes.title : AppTextSizes.body,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style.copyWith(
              color: bold ? palette.text : palette.textMuted,
              fontSize: bold ? AppTextSizes.bodyLarge : AppTextSizes.body,
            ),
          ),
        ),
        Text(formatRupiah(value), style: style),
      ],
    );
  }
}
