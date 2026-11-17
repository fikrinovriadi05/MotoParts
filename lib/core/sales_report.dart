import 'package:flutter/material.dart' show DateTimeRange;
import 'package:motopart/core/format.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';

/// Rentang tanggal laporan (kedua ujung termasuk, hanya tanggal).
class ReportRange {
  final DateTime start;
  final DateTime end;

  /// Nama pilihan, mis. "7 Hari" atau "Kustom".
  final String label;

  ReportRange(DateTime start, DateTime end, {this.label = 'Kustom'})
    : start = _day(start.isAfter(end) ? end : start),
      end = _day(start.isAfter(end) ? start : end);

  /// [days] hari terakhir sampai hari ini ([now] termasuk).
  factory ReportRange.lastDays(int days, DateTime now, {String? label}) {
    final today = _day(now);
    return ReportRange(
      DateTime(today.year, today.month, today.day - (days - 1)),
      today,
      label: label ?? '$days Hari',
    );
  }

  /// Tanggal 1 bulan ini sampai hari ini.
  factory ReportRange.thisMonth(DateTime now) =>
      ReportRange(DateTime(now.year, now.month), now, label: 'Bulan Ini');

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  DateTimeRange get asDateTimeRange => DateTimeRange(start: start, end: end);

  /// Jumlah hari dalam rentang.
  int get days =>
      DateTime(
        end.year,
        end.month,
        end.day,
        12,
      ).difference(DateTime(start.year, start.month, start.day, 12)).inDays +
      1;

  /// Apakah [time] jatuh dalam rentang. Pesanan tanpa tanggal tidak termasuk.
  bool contains(DateTime? time) {
    if (time == null) return false;
    final day = _day(time);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Contoh: `1 Nov 2026 - 17 Nov 2026`, atau `17 Nov 2026` untuk satu hari.
  String get description {
    final a = formatTanggalSingkat(start);
    final b = formatTanggalSingkat(end);
    return a == b ? a : '$a - $b';
  }

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Penjualan satu produk dalam laporan.
class ProductSales {
  final String name;
  final int qty;

  /// Pendapatan barang (harga x jumlah), tanpa ongkos kirim.
  final int revenue;

  const ProductSales({
    required this.name,
    required this.qty,
    required this.revenue,
  });
}

/// Angka-angka laporan penjualan untuk satu rentang tanggal (atau semua
/// pesanan bila [range] null).
class SalesReport {
  /// Null = semua waktu.
  final ReportRange? range;

  /// Semua pesanan dalam rentang, apa pun statusnya (terbaru di depan).
  final List<OrderItem> orders;

  /// Pesanan yang dihitung sebagai penjualan (bukan dibatalkan atau menunggu
  /// pembayaran).
  final List<OrderItem> sales;

  final int totalSales;
  final int totalUnits;
  final int cancelledCount;
  final int awaitingCount;

  /// Penjualan per produk, dari yang paling banyak terjual.
  final List<ProductSales> products;

  const SalesReport._({
    required this.range,
    required this.orders,
    required this.sales,
    required this.totalSales,
    required this.totalUnits,
    required this.cancelledCount,
    required this.awaitingCount,
    required this.products,
  });

  factory SalesReport.build(List<OrderItem> all, {ReportRange? range}) {
    final orders = [
      for (final o in all)
        if (range == null || range.contains(o.createdAt)) o,
    ];
    final sales = [
      for (final o in orders)
        if (o.status != Store.cancelledStatus &&
            o.status != Store.awaitingPaymentStatus)
          o,
    ];

    final byName = <String, ({int qty, int revenue})>{};
    var units = 0;
    for (final order in sales) {
      for (final line in order.lines) {
        units += line.qty;
        final old = byName[line.name];
        byName[line.name] = (
          qty: (old?.qty ?? 0) + line.qty,
          revenue: (old?.revenue ?? 0) + line.qty * line.price,
        );
      }
    }
    final products =
        [
          for (final e in byName.entries)
            ProductSales(
              name: e.key,
              qty: e.value.qty,
              revenue: e.value.revenue,
            ),
        ]..sort((a, b) {
          final byQty = b.qty.compareTo(a.qty);
          return byQty != 0 ? byQty : a.name.compareTo(b.name);
        });

    return SalesReport._(
      range: range,
      orders: orders,
      sales: sales,
      totalSales: sales.fold(0, (sum, o) => sum + o.total),
      totalUnits: units,
      cancelledCount: orders
          .where((o) => o.status == Store.cancelledStatus)
          .length,
      awaitingCount: orders
          .where((o) => o.status == Store.awaitingPaymentStatus)
          .length,
      products: products,
    );
  }

  /// Rata-rata total per pesanan yang dihitung.
  int get average => sales.isEmpty ? 0 : (totalSales / sales.length).round();

  /// Penjualan per hari untuk seluruh [range] (maksimal [maxDays] hari
  /// terakhir dalam rentang). Hari terlama di depan.
  List<({DateTime day, int total})> dailySales({int maxDays = 31}) {
    final r = range;
    if (r == null) return const [];
    final count = r.days > maxDays ? maxDays : r.days;
    return [
      for (var i = count - 1; i >= 0; i--)
        (
          day: DateTime(r.end.year, r.end.month, r.end.day - i),
          total: sales
              .where((o) {
                final t = o.createdAt;
                return t != null &&
                    DateTime(t.year, t.month, t.day) ==
                        DateTime(r.end.year, r.end.month, r.end.day - i);
              })
              .fold(0, (sum, o) => sum + o.total),
        ),
    ];
  }
}
