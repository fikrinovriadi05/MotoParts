import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/report_csv.dart';
import 'package:motopart/core/report_exporter.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/store/store.dart';

import 'support/fakes.dart';

OrderItem order(
  String code,
  String status, {
  String customer = 'Budi',
  int total = 100000,
  List<OrderLine>? lines,
  String? address,
  String? method,
  DateTime? at,
}) => OrderItem(
  code: code,
  customer: customer,
  total: total,
  status: status,
  createdAt: at,
  address: address,
  paymentMethod: method,
  lines:
      lines ??
      const [
        OrderLine(productId: 1, name: 'Busi NGK', qty: 2, price: 32000),
        OrderLine(productId: 2, name: 'Oli', qty: 1, price: 36000),
      ],
);

List<String> rowsOf(String csv) =>
    csv.replaceFirst(ReportCsv.bom, '').split('\r\n');

void main() {
  group('ReportCsv', () {
    final at = DateTime(2026, 11, 17, 9, 5);

    test('berkas diawali BOM dan memakai pemisah titik koma', () {
      final csv = ReportCsv.build(orders: [], generatedAt: at);
      expect(csv.startsWith(ReportCsv.bom), isTrue);
      expect(rowsOf(csv).first, 'Laporan Penjualan MotoPart');
      expect(rowsOf(csv)[1], 'Dibuat;2026-11-17 09:05');
    });

    test('nama berkas memuat tanggal', () {
      expect(ReportCsv.fileName(at), 'laporan-penjualan-2026-11-17.csv');
    });

    test('ringkasan tidak menghitung pesanan dibatalkan/menunggu bayar', () {
      final csv = ReportCsv.build(
        orders: [
          order('A', 'Selesai', total: 100000),
          order('B', 'Dikirim', total: 50000),
          order('C', 'Dibatalkan', total: 999000),
          order('D', Store.awaitingPaymentStatus, total: 777000),
        ],
        generatedAt: at,
      );
      final rows = rowsOf(csv);
      expect(rows, contains('Total penjualan (Rp);150000'));
      expect(rows, contains('Jumlah pesanan terhitung;2'));
      expect(rows, contains('Barang terjual;6'));
      expect(rows, contains('Rata-rata per pesanan (Rp);75000'));
      expect(rows, contains('Pesanan dibatalkan;1'));
      expect(rows, contains('Pesanan menunggu pembayaran;1'));
    });

    test('penjualan per produk diurutkan dari yang terbanyak', () {
      final csv = ReportCsv.build(
        orders: [
          order('A', 'Selesai'),
          order(
            'B',
            'Selesai',
            lines: const [
              OrderLine(productId: 2, name: 'Oli', qty: 5, price: 36000),
            ],
          ),
          // Dibatalkan: tidak ikut dihitung.
          order('C', 'Dibatalkan'),
        ],
        generatedAt: at,
      );
      final rows = rowsOf(csv);
      final start = rows.indexOf(
        'Produk;Jumlah terjual;Pendapatan barang (Rp)',
      );
      expect(rows[start + 1], 'Oli;6;216000');
      expect(rows[start + 2], 'Busi NGK;2;64000');
    });

    test('daftar pesanan memuat semua pesanan beserta rinciannya', () {
      final csv = ReportCsv.build(
        orders: [
          order(
            'MP-1',
            'Selesai',
            customer: 'Siti Aminah',
            address: 'Siti, Jl. Merdeka 1',
            method: 'COD',
            at: DateTime(2026, 11, 16, 14, 30),
          ),
          order('MP-2', 'Dibatalkan'),
        ],
        generatedAt: at,
      );
      final rows = rowsOf(csv);
      final header = rows.indexWhere((r) => r.startsWith('Kode;Tanggal'));
      expect(
        rows[header],
        'Kode;Tanggal;Pelanggan;Status;Metode pembayaran;Alamat;Barang;Jumlah barang;Total (Rp)',
      );
      expect(
        rows[header + 1],
        'MP-1;2026-11-16 14:30;Siti Aminah;Selesai;COD;Siti, Jl. Merdeka 1;'
        'Busi NGK x2, Oli x1;3;100000',
      );
      // Pesanan lama tanpa tanggal/alamat tetap tampil dengan kolom kosong.
      expect(rows[header + 2], startsWith('MP-2;;Budi;Dibatalkan;;;'));
    });

    test('teks dengan pemisah, petik, atau baris baru dikutip', () {
      final csv = ReportCsv.build(
        orders: [
          order(
            'MP-1',
            'Selesai',
            customer: 'Toko "Jaya"; Motor',
            address: 'Jl. A\nNo. 5',
          ),
        ],
        generatedAt: at,
      );
      expect(csv, contains('"Toko ""Jaya""; Motor"'));
      expect(csv, contains('"Jl. A\nNo. 5"'));
    });

    test('nama yang diawali rumus tidak dijalankan Excel', () {
      final csv = ReportCsv.build(
        orders: [
          order('MP-1', 'Selesai', customer: '=HYPERLINK("http://x")'),
          order('MP-2', 'Selesai', customer: '+62 812'),
          order('MP-3', 'Selesai', customer: '@SUM(A1)'),
        ],
        generatedAt: at,
      );
      expect(csv, contains(";\"'=HYPERLINK(\"\"http://x\"\")\";"));
      expect(csv, contains(";'+62 812;"));
      expect(csv, contains(";'@SUM(A1);"));
      expect(csv, isNot(contains(';=HYPERLINK')));
    });

    test('tanpa pesanan: ringkasan nol tanpa error pembagian', () {
      final rows = rowsOf(ReportCsv.build(orders: [], generatedAt: at));
      expect(rows, contains('Total penjualan (Rp);0'));
      expect(rows, contains('Rata-rata per pesanan (Rp);0'));
    });
  });

  group('tombol ekspor di laporan admin', () {
    late FakeReportExporter exporter;
    late List<OrderItem> savedOrders;

    setUp(() {
      exporter = FakeReportExporter();
      reportExporter = exporter;
      savedOrders = [...store.orders];
    });

    tearDown(() {
      reportExporter = FakeReportExporter();
      store.orders
        ..clear()
        ..addAll(savedOrders);
    });

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: AdminReportsPage(now: DateTime(2026, 11, 16, 10))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mengekspor semua pesanan sebagai CSV', (tester) async {
      await open(tester);

      await tester.tap(find.text('Ekspor ke CSV (Excel)'));
      await tester.pumpAndSettle();

      expect(exporter.saved, hasLength(1));
      expect(
        exporter.saved.single.fileName,
        'laporan-penjualan-2026-11-16.csv',
      );
      expect(exporter.saved.single.content, contains('MP-250118-0001'));
      expect(exporter.saved.single.content, contains('Andi Pratama'));
      expect(
        find.text('Laporan diekspor: laporan-penjualan-2026-11-16.csv'),
        findsOneWidget,
      );
    });

    testWidgets('ikon di bilah atas juga mengekspor', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Ekspor laporan (CSV)'));
      await tester.pumpAndSettle();
      expect(exporter.saved, hasLength(1));
    });

    testWidgets('batal di lembar berbagi: tanpa pesan sukses', (tester) async {
      exporter.result = ExportResult.cancelled;
      await open(tester);
      await tester.tap(find.text('Ekspor ke CSV (Excel)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Laporan diekspor'), findsNothing);
    });

    testWidgets('gagal mengekspor: pesan galat ditampilkan', (tester) async {
      exporter.failure = const ExportException('Tidak bisa menyimpan.');
      await open(tester);
      await tester.tap(find.text('Ekspor ke CSV (Excel)'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak bisa menyimpan.'), findsOneWidget);
    });

    testWidgets('tanpa pesanan: tidak ada berkas, ada keterangan', (
      tester,
    ) async {
      store.orders.clear();
      await open(tester);
      await tester.tap(find.text('Ekspor ke CSV (Excel)'));
      await tester.pumpAndSettle();
      expect(exporter.saved, isEmpty);
      expect(find.text('Belum ada pesanan untuk diekspor.'), findsOneWidget);
    });
  });
}
