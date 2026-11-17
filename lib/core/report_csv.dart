import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';

/// Membuat berkas CSV laporan penjualan yang bisa dibuka di Excel/Google Sheets.
///
/// * Pemisah kolom `;` (bawaan Excel berbahasa Indonesia; Google Sheets
///   mengenalinya otomatis).
/// * Angka ditulis polos (tanpa "Rp" dan titik ribuan) supaya bisa dijumlahkan.
/// * Teks yang diawali `= + - @` diberi tanda petik di depan agar tidak
///   dijalankan sebagai rumus oleh Excel (nama pelanggan berasal dari
///   pengguna).
class ReportCsv {
  const ReportCsv._();

  static const separator = ';';

  /// Penanda urutan byte UTF-8 supaya Excel membaca huruf berakses dengan benar.
  static const bom = '﻿';

  /// Nama berkas, mis. `laporan-penjualan-2026-11-17.csv`.
  static String fileName(DateTime now) => 'laporan-penjualan-${_date(now)}.csv';

  /// Isi CSV. [orders] adalah semua pesanan (pesanan yang dibatalkan atau
  /// belum dibayar tetap tampil di daftar, tetapi tidak dihitung sebagai
  /// penjualan di ringkasan).
  static String build({
    required List<OrderItem> orders,
    required DateTime generatedAt,
  }) {
    final sales = [
      for (final o in orders)
        if (o.status != Store.cancelledStatus &&
            o.status != Store.awaitingPaymentStatus)
          o,
    ];
    final totalSales = sales.fold<int>(0, (sum, o) => sum + o.total);
    final unitsByProduct = <String, ({int qty, int revenue})>{};
    var totalUnits = 0;
    for (final order in sales) {
      for (final line in order.lines) {
        totalUnits += line.qty;
        final old = unitsByProduct[line.name];
        unitsByProduct[line.name] = (
          qty: (old?.qty ?? 0) + line.qty,
          revenue: (old?.revenue ?? 0) + line.qty * line.price,
        );
      }
    }
    final ranked = unitsByProduct.entries.toList()
      ..sort((a, b) {
        final byQty = b.value.qty.compareTo(a.value.qty);
        return byQty != 0 ? byQty : a.key.compareTo(b.key);
      });

    final rows = <List<Object?>>[
      ['Laporan Penjualan MotoPart'],
      ['Dibuat', _dateTime(generatedAt)],
      [],
      ['RINGKASAN'],
      ['Total penjualan (Rp)', totalSales],
      ['Jumlah pesanan terhitung', sales.length],
      ['Barang terjual', totalUnits],
      [
        'Rata-rata per pesanan (Rp)',
        sales.isEmpty ? 0 : (totalSales / sales.length).round(),
      ],
      ['Pesanan dibatalkan', _count(orders, Store.cancelledStatus)],
      [
        'Pesanan menunggu pembayaran',
        _count(orders, Store.awaitingPaymentStatus),
      ],
      [],
      ['PENJUALAN PER PRODUK'],
      ['Produk', 'Jumlah terjual', 'Pendapatan barang (Rp)'],
      for (final e in ranked) [e.key, e.value.qty, e.value.revenue],
      [],
      ['DAFTAR PESANAN'],
      [
        'Kode',
        'Tanggal',
        'Pelanggan',
        'Status',
        'Metode pembayaran',
        'Alamat',
        'Barang',
        'Jumlah barang',
        'Total (Rp)',
      ],
      for (final o in orders)
        [
          o.code,
          o.createdAt == null ? '' : _dateTime(o.createdAt!),
          o.customer,
          o.status,
          o.paymentMethod ?? '',
          o.address ?? '',
          o.lines.map((l) => '${l.name} x${l.qty}').join(', '),
          o.lines.fold<int>(0, (sum, l) => sum + l.qty),
          o.total,
        ],
    ];

    return bom + rows.map((r) => r.map(_cell).join(separator)).join('\r\n');
  }

  static int _count(List<OrderItem> orders, String status) =>
      orders.where((o) => o.status == status).length;

  static String _cell(Object? value) {
    if (value == null) return '';
    if (value is num) return '$value';
    var text = value.toString().replaceAll('\r\n', '\n');
    // Cegah penyuntikan rumus (CSV injection).
    if (text.isNotEmpty && '=+-@\t'.contains(text[0])) text = "'$text";
    if (text.contains(separator) || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _date(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';

  static String _dateTime(DateTime t) =>
      '${_date(t)} ${_two(t.hour)}:${_two(t.minute)}';
}
