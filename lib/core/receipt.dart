import 'package:motopart/core/format.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';

/// Rincian struk yang dihitung dari sebuah pesanan.
class Receipt {
  final OrderItem order;

  /// Jumlah harga barang (tanpa ongkir). 0 jika rincian barang tidak tercatat.
  final int subtotal;

  /// Ongkos kirim = total - subtotal (0 jika rincian barang tidak tercatat).
  final int shipping;

  /// "LUNAS" atau keterangan COD yang belum dibayar.
  final String paymentStatus;

  const Receipt._(this.order, this.subtotal, this.shipping, this.paymentStatus);

  factory Receipt.of(OrderItem order) {
    final subtotal = order.lines.fold<int>(0, (s, l) => s + l.price * l.qty);
    final shipping = order.lines.isEmpty
        ? 0
        : (order.total - subtotal).clamp(0, order.total);
    // Online: struk baru ada setelah lunas. COD: dibayar tunai saat barang
    // diterima, jadi lunas ketika pesanan Selesai.
    final paid = order.payment != null || order.status == 'Selesai';
    return Receipt._(
      order,
      subtotal,
      shipping,
      paid ? 'LUNAS' : 'BAYAR DI TEMPAT (COD)',
    );
  }

  /// Struk tersedia setelah pesanan dibayar/diterima toko: tidak untuk pesanan
  /// yang masih menunggu pembayaran atau yang dibatalkan.
  static bool availableFor(OrderItem order) =>
      order.status != Store.awaitingPaymentStatus &&
      order.status != Store.cancelledStatus;

  /// Struk sebagai teks polos, untuk dibagikan (WhatsApp, email) atau disalin.
  String toText() {
    final b = StringBuffer()
      ..writeln('MOTOPART')
      ..writeln('Struk Pembelian')
      ..writeln('--------------------------------')
      ..writeln('No. Pesanan : ${order.code}');
    if (order.createdAt != null) {
      b.writeln('Tanggal     : ${formatTanggal(order.createdAt!)}');
    }
    b.writeln('Pelanggan   : ${order.customer}');
    if (order.address != null) b.writeln('Alamat      : ${order.address}');
    b.writeln('--------------------------------');
    for (final line in order.lines) {
      b
        ..writeln(line.name)
        ..writeln(
          '  ${line.qty} x ${formatRupiah(line.price)}'
          ' = ${formatRupiah(line.price * line.qty)}',
        );
    }
    if (order.lines.isNotEmpty) {
      b
        ..writeln('--------------------------------')
        ..writeln('Subtotal    : ${formatRupiah(subtotal)}');
      if (shipping > 0) b.writeln('Ongkir      : ${formatRupiah(shipping)}');
    }
    b
      ..writeln('TOTAL       : ${formatRupiah(order.total)}')
      ..writeln('--------------------------------');
    if (order.paymentMethod != null) {
      b.writeln('Pembayaran  : ${order.paymentMethod}');
    }
    b
      ..writeln('Status      : $paymentStatus')
      ..writeln()
      ..writeln('Terima kasih sudah belanja di MotoPart!');
    return b.toString();
  }
}
