import 'package:excel/excel.dart';
import 'package:flutter/material.dart' hide BorderStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/report_exporter.dart';
import 'package:motopart/core/report_xlsx.dart';
import 'package:motopart/core/sales_report.dart';
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

Excel decode(List<int> bytes) => Excel.decodeBytes(bytes);

/// Isi sel (teks/angka) sebagai String agar mudah dibandingkan.
String? cell(Sheet sheet, int column, int row) => sheet
    .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
    .value
    ?.toString();

Data data(Sheet sheet, int column, int row) =>
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row));

/// Seluruh isi satu baris (kolom 0 sampai [width]-1).
List<String?> row(Sheet sheet, int r, int width) => [
  for (var c = 0; c < width; c++) cell(sheet, c, r),
];

void main() {
  final at = DateTime(2026, 11, 17, 9, 5);

  group('ReportRange', () {
    test('7 hari terakhir termasuk hari ini', () {
      final r = ReportRange.lastDays(7, DateTime(2026, 11, 17, 15));
      expect(r.start, DateTime(2026, 11, 11));
      expect(r.end, DateTime(2026, 11, 17));
      expect(r.days, 7);
    });

    test('bulan ini dimulai tanggal 1', () {
      final r = ReportRange.thisMonth(DateTime(2026, 11, 17));
      expect(r.start, DateTime(2026, 11, 1));
      expect(r.days, 17);
    });

    test('ujung terbalik ditukar; jam diabaikan; kedua ujung termasuk', () {
      final r = ReportRange(
        DateTime(2026, 11, 20, 23),
        DateTime(2026, 11, 18, 5),
      );
      expect(r.start, DateTime(2026, 11, 18));
      expect(r.end, DateTime(2026, 11, 20));
      expect(r.contains(DateTime(2026, 11, 18, 0, 0)), isTrue);
      expect(r.contains(DateTime(2026, 11, 20, 23, 59)), isTrue);
      expect(r.contains(DateTime(2026, 11, 21, 0, 1)), isFalse);
      expect(r.contains(DateTime(2026, 11, 17, 23, 59)), isFalse);
      expect(r.contains(null), isFalse);
    });

    test('jumlah hari benar melewati pergantian bulan dan tahun', () {
      expect(ReportRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)).days, 4);
    });

    test('keterangan rentang', () {
      expect(
        ReportRange(DateTime(2026, 11, 1), DateTime(2026, 11, 17)).description,
        '1 Nov 2026 - 17 Nov 2026',
      );
      expect(
        ReportRange(DateTime(2026, 11, 5), DateTime(2026, 11, 5)).description,
        '5 Nov 2026',
      );
    });
  });

  group('SalesReport', () {
    final orders = [
      order('A', 'Selesai', total: 100000, at: DateTime(2026, 11, 16, 10)),
      order('B', 'Dikirim', total: 50000, at: DateTime(2026, 11, 10)),
      order('C', 'Dibatalkan', total: 999000, at: DateTime(2026, 11, 16)),
      order(
        'D',
        Store.awaitingPaymentStatus,
        total: 777000,
        at: DateTime(2026, 11, 16),
      ),
      order('E', 'Selesai', total: 20000), // tanpa tanggal
    ];

    test(
      'tanpa rentang: semua pesanan; penjualan tidak termasuk batal/menunggu',
      () {
        final r = SalesReport.build(orders);
        expect(r.orders, hasLength(5));
        expect(r.sales.map((o) => o.code), ['A', 'B', 'E']);
        expect(r.totalSales, 170000);
        expect(r.totalUnits, 9);
        expect(r.average, 56667);
        expect(r.cancelledCount, 1);
        expect(r.awaitingCount, 1);
      },
    );

    test(
      'dengan rentang: hanya pesanan di rentang (tanpa tanggal tersingkir)',
      () {
        final r = SalesReport.build(
          orders,
          range: ReportRange(DateTime(2026, 11, 15), DateTime(2026, 11, 17)),
        );
        expect(r.orders.map((o) => o.code), ['A', 'C', 'D']);
        expect(r.totalSales, 100000);
        expect(r.sales, hasLength(1));
      },
    );

    test('per produk diurutkan dari yang terbanyak, batal tidak dihitung', () {
      final r = SalesReport.build([
        order('A', 'Selesai'),
        order(
          'B',
          'Selesai',
          lines: const [
            OrderLine(productId: 2, name: 'Oli', qty: 5, price: 36000),
          ],
        ),
        order('C', 'Dibatalkan'),
      ]);
      expect(r.products.map((p) => (p.name, p.qty, p.revenue)), [
        ('Oli', 6, 216000),
        ('Busi NGK', 2, 64000),
      ]);
    });

    test('penjualan per hari memenuhi seluruh rentang', () {
      final r = SalesReport.build(
        orders,
        range: ReportRange(DateTime(2026, 11, 10), DateTime(2026, 11, 16)),
      );
      final days = r.dailySales();
      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 11, 10));
      expect(days.first.total, 50000);
      expect(days.last.total, 100000); // pesanan batal/menunggu tidak ikut
    });

    test('rentang panjang dipotong ke hari terakhir', () {
      final r = SalesReport.build(
        [],
        range: ReportRange(DateTime(2026, 1, 1), DateTime(2026, 11, 17)),
      );
      final days = r.dailySales(maxDays: 31);
      expect(days, hasLength(31));
      expect(days.last.day, DateTime(2026, 11, 17));
    });

    test('tanpa pesanan: nol tanpa pembagian dengan nol', () {
      final r = SalesReport.build([]);
      expect(r.average, 0);
      expect(r.totalSales, 0);
    });
  });

  group('ReportXlsx', () {
    final orders = [
      order(
        'MP-1',
        'Selesai',
        customer: 'Siti Aminah',
        address: 'Siti, Jl. Merdeka 1',
        method: 'COD',
        at: DateTime(2026, 11, 16, 14, 30),
      ),
      order('MP-2', 'Dibatalkan', at: DateTime(2026, 11, 15, 8)),
      order(
        'MP-3',
        Store.awaitingPaymentStatus,
        total: 50000,
        at: DateTime(2026, 11, 14, 8),
      ),
    ];
    late Excel book;
    late SalesReport report;

    setUp(() {
      report = SalesReport.build(
        orders,
        range: ReportRange(DateTime(2026, 11, 1), DateTime(2026, 11, 17)),
      );
      book = decode(ReportXlsx.build(report, generatedAt: at));
    });

    test('tiga lembar dengan nama yang jelas', () {
      expect(book.tables.keys.toList(), [
        ReportXlsx.summarySheet,
        ReportXlsx.productsSheet,
        ReportXlsx.ordersSheet,
      ]);
    });

    test('nama berkas memuat rentang', () {
      expect(
        ReportXlsx.fileName(report, at),
        'laporan-penjualan_2026-11-01_sd_2026-11-17.xlsx',
      );
      expect(
        ReportXlsx.fileName(SalesReport.build(orders), at),
        'laporan-penjualan_semua_2026-11-17.xlsx',
      );
    });

    test('lembar ringkasan: judul, periode, dan angka', () {
      final s = book[ReportXlsx.summarySheet];
      expect(cell(s, 0, 0), 'Laporan Penjualan MotoPart');
      expect(cell(s, 0, 2), 'Periode');
      expect(cell(s, 1, 2), '1 Nov 2026 - 17 Nov 2026');
      expect(row(s, 5, 2), ['Keterangan', 'Nilai']);
      expect(row(s, 6, 2), ['Total penjualan', '100000']);
      expect(row(s, 7, 2), ['Jumlah pesanan terhitung', '1']);
      expect(row(s, 8, 2), ['Barang terjual', '3']);
      expect(row(s, 9, 2), ['Rata-rata per pesanan', '100000']);
      expect(row(s, 10, 2), ['Pesanan dibatalkan', '1']);
      expect(row(s, 11, 2), ['Pesanan menunggu pembayaran', '1']);
    });

    test('angka disimpan sebagai angka (bisa dijumlahkan), bukan teks', () {
      final s = book[ReportXlsx.summarySheet];
      expect(data(s, 1, 6).value, isA<IntCellValue>());
      final o = book[ReportXlsx.ordersSheet];
      expect(data(o, 9, 4).value, isA<IntCellValue>());
      expect(data(o, 2, 4).value, isA<DateTimeCellValue>());
    });

    test('format Rupiah dan tanggal terpasang di sel', () {
      final s = book[ReportXlsx.summarySheet];
      expect(data(s, 1, 6).cellStyle!.numberFormat.formatCode, contains('Rp'));
      final o = book[ReportXlsx.ordersSheet];
      expect(
        data(o, 2, 4).cellStyle!.numberFormat.formatCode,
        'dd/mm/yyyy hh:mm',
      );
      expect(data(o, 9, 4).cellStyle!.numberFormat.formatCode, contains('Rp'));
    });

    test('lembar per produk: header, baris, dan total', () {
      final s = book[ReportXlsx.productsSheet];
      expect(row(s, 3, 4), [
        'No',
        'Produk',
        'Jumlah Terjual',
        'Pendapatan Barang',
      ]);
      expect(row(s, 4, 4), ['1', 'Busi NGK', '2', '64000']);
      expect(row(s, 5, 4), ['2', 'Oli', '1', '36000']);
      expect(row(s, 6, 4), [null, 'Total', '3', '100000']);
    });

    test('lembar pesanan: header, semua pesanan, dan baris total', () {
      final s = book[ReportXlsx.ordersSheet];
      expect(row(s, 3, 10), [
        'No',
        'Kode Pesanan',
        'Tanggal',
        'Pelanggan',
        'Status',
        'Metode Pembayaran',
        'Alamat Pengiriman',
        'Barang',
        'Jumlah Barang',
        'Total',
      ]);
      expect(cell(s, 1, 4), 'MP-1');
      expect(cell(s, 3, 4), 'Siti Aminah');
      expect(cell(s, 4, 4), 'Selesai');
      expect(cell(s, 5, 4), 'COD');
      expect(cell(s, 6, 4), 'Siti, Jl. Merdeka 1');
      expect(cell(s, 7, 4), 'Busi NGK x2\nOli x1');
      expect(cell(s, 8, 4), '3');
      expect(cell(s, 9, 4), '100000');
      // Pesanan tanpa alamat/metode tidak meninggalkan sel kosong.
      expect(cell(s, 5, 5), '-');
      expect(cell(s, 4, 5), 'Dibatalkan');
      expect(cell(s, 4, 6), Store.awaitingPaymentStatus);
      // Baris total hanya menghitung penjualan.
      expect(cell(s, 1, 7), 'Total penjualan');
      expect(cell(s, 2, 7), isNull); // sel pengisi benar-benar kosong
      expect(data(s, 2, 7).cellStyle!.backgroundColor.colorHex, isNot('none'));
      expect(cell(s, 8, 7), '3');
      expect(cell(s, 9, 7), '100000');
    });

    test('header berwarna, tebal, dan bergaris; status diberi warna', () {
      final o = book[ReportXlsx.ordersSheet];
      final header = data(o, 1, 3).cellStyle!;
      expect(header.isBold, isTrue);
      expect(header.backgroundColor.colorHex, isNot('none'));
      expect(header.fontColor.colorHex, 'FFFFFFFF');
      expect(header.topBorder.borderStyle, BorderStyle.Thin);

      final done = data(o, 4, 4).cellStyle!.backgroundColor.colorHex;
      final cancelled = data(o, 4, 5).cellStyle!.backgroundColor.colorHex;
      final waiting = data(o, 4, 6).cellStyle!.backgroundColor.colorHex;
      expect({done, cancelled, waiting}, hasLength(3));
    });

    test('lebar kolom diatur dan alamat/barang membungkus teks', () {
      final o = book[ReportXlsx.ordersSheet];
      expect(o.getColumnWidth(6), greaterThan(30));
      expect(o.getColumnWidth(0), lessThan(10));
      expect(data(o, 7, 4).cellStyle!.wrap, TextWrapping.WrapText);
    });

    test('judul digabung selebar tabel', () {
      final o = book[ReportXlsx.ordersSheet];
      expect(o.spannedItems, isNotEmpty);
    });

    test('periode kosong: lembar tetap rapi dengan keterangan', () {
      final empty = decode(
        ReportXlsx.build(
          SalesReport.build(
            orders,
            range: ReportRange(DateTime(2020, 1, 1), DateTime(2020, 1, 2)),
          ),
          generatedAt: at,
        ),
      );
      expect(
        cell(empty[ReportXlsx.productsSheet], 1, 4),
        'Belum ada penjualan pada periode ini.',
      );
      expect(
        cell(empty[ReportXlsx.ordersSheet], 1, 4),
        'Belum ada pesanan pada periode ini.',
      );
    });

    test('teks pengguna yang diawali rumus tetap disimpan sebagai teks', () {
      final tricky = decode(
        ReportXlsx.build(
          SalesReport.build([
            order('MP-1', 'Selesai', customer: '=HYPERLINK("http://x")'),
          ]),
          generatedAt: at,
        ),
      );
      final value = data(tricky[ReportXlsx.ordersSheet], 3, 4).value;
      expect(value, isA<TextCellValue>());
      expect(
        cell(tricky[ReportXlsx.ordersSheet], 3, 4),
        '=HYPERLINK("http://x")',
      );
    });
  });

  group('halaman laporan admin', () {
    late FakeReportExporter exporter;
    late List<OrderItem> savedOrders;
    final now = DateTime(2026, 11, 16, 10);

    setUp(() {
      exporter = FakeReportExporter();
      reportExporter = exporter;
      savedOrders = [...store.orders];
      store.orders
        ..clear()
        ..addAll([
          order('MP-OLD', 'Selesai', total: 80000, at: DateTime(2026, 9, 1, 9)),
          order(
            'MP-NEW',
            'Selesai',
            total: 120000,
            at: DateTime(2026, 11, 15, 9),
          ),
          order(
            'MP-CXL',
            'Dibatalkan',
            total: 5000,
            at: DateTime(2026, 11, 15, 10),
          ),
        ]);
    });

    tearDown(() {
      reportExporter = FakeReportExporter();
      store.orders
        ..clear()
        ..addAll(savedOrders);
    });

    Future<void> open(
      WidgetTester tester, {
      Size size = const Size(400, 1800),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: AdminReportsPage(now: now)));
      await tester.pumpAndSettle();
    }

    testWidgets('bawaan semua waktu; memilih 7 Hari menyaring angka', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.textContaining('Dari 2 pesanan (tidak termasuk'),
        findsOneWidget,
      );
      expect(find.text('Penjualan 7 Hari Terakhir'), findsOneWidget);

      await tester.tap(find.text('7 Hari'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Dari 1 pesanan · 10 Nov 2026 - 16 Nov 2026'),
        findsOneWidget,
      );
      expect(find.text('Penjualan per Hari'), findsOneWidget);
    });

    testWidgets('Bulan Ini dan 30 Hari menyaring', (tester) async {
      await open(tester);
      await tester.tap(find.text('Bulan Ini'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dari 1 pesanan · 1 Nov 2026 - 16 Nov 2026'),
        findsOneWidget,
      );

      await tester.tap(find.text('30 Hari'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dari 1 pesanan · 18 Okt 2026 - 16 Nov 2026'),
        findsOneWidget,
      );

      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dari 2 pesanan (tidak termasuk'),
        findsOneWidget,
      );
    });

    testWidgets('periode tanpa penjualan: keterangan kosong', (tester) async {
      store.orders.removeWhere((o) => o.code != 'MP-OLD');
      await open(tester);
      await tester.tap(find.text('7 Hari'));
      await tester.pumpAndSettle();
      expect(
        find.text('Belum ada penjualan pada periode ini.'),
        findsOneWidget,
      );
    });

    testWidgets('Pilih Tanggal membuka pemilih rentang dan menerapkannya', (
      tester,
    ) async {
      await open(tester, size: const Size(1200, 800));
      await tester.tap(find.text('Pilih Tanggal'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih rentang tanggal'), findsOneWidget);

      // Terbuka dengan pekan terakhir sudah terpilih; terapkan.
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('10 Nov 2026 - 16 Nov 2026'), findsWidgets);
      expect(find.textContaining('Dari 1 pesanan'), findsOneWidget);
      expect(find.text('Penjualan per Hari'), findsOneWidget);
    });

    testWidgets('batal di pemilih tanggal: pilihan lama dipertahankan', (
      tester,
    ) async {
      await open(tester, size: const Size(1200, 800));
      await tester.tap(find.text('Pilih Tanggal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Dari 2 pesanan (tidak termasuk'),
        findsOneWidget,
      );
      expect(find.text('Pilih Tanggal'), findsOneWidget);
    });

    testWidgets('ekspor mengikuti periode terpilih', (tester) async {
      await open(tester);
      await tester.tap(find.text('7 Hari'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekspor ke Excel (.xlsx)'));
      await tester.pumpAndSettle();

      expect(exporter.saved, hasLength(1));
      final file = exporter.saved.single;
      expect(file.fileName, 'laporan-penjualan_2026-11-10_sd_2026-11-16.xlsx');
      expect(file.mimeType, ReportXlsx.mimeType);
      final sheet = decode(file.bytes)[ReportXlsx.ordersSheet];
      final codes = [for (var r = 4; r < 6; r++) cell(sheet, 1, r)];
      expect(codes, ['MP-NEW', 'MP-CXL']); // MP-OLD di luar rentang
      expect(
        find.text(
          'Laporan diekspor: laporan-penjualan_2026-11-10_sd_2026-11-16.xlsx',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ekspor semua waktu memuat semua pesanan', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Ekspor laporan (Excel)'));
      await tester.pumpAndSettle();
      final sheet = decode(exporter.saved.single.bytes)[ReportXlsx.ordersSheet];
      expect(cell(sheet, 1, 4), 'MP-OLD');
      expect(cell(sheet, 1, 6), 'MP-CXL');
    });

    testWidgets('batal di lembar berbagi: tanpa pesan sukses', (tester) async {
      exporter.result = ExportResult.cancelled;
      await open(tester);
      await tester.tap(find.text('Ekspor ke Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Laporan diekspor'), findsNothing);
    });

    testWidgets('gagal mengekspor: pesan galat ditampilkan', (tester) async {
      exporter.failure = const ExportException('Tidak bisa menyimpan.');
      await open(tester);
      await tester.tap(find.text('Ekspor ke Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak bisa menyimpan.'), findsOneWidget);
    });

    testWidgets('periode tanpa pesanan: tidak ada berkas, ada keterangan', (
      tester,
    ) async {
      store.orders.removeWhere((o) => o.code != 'MP-OLD');
      await open(tester);
      await tester.tap(find.text('7 Hari'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekspor ke Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(exporter.saved, isEmpty);
      expect(
        find.text('Tidak ada pesanan pada periode ini untuk diekspor.'),
        findsOneWidget,
      );
    });

    testWidgets('tanpa pesanan sama sekali: keterangan', (tester) async {
      store.orders.clear();
      await open(tester);
      await tester.tap(find.text('Ekspor ke Excel (.xlsx)'));
      await tester.pumpAndSettle();
      expect(exporter.saved, isEmpty);
      expect(find.text('Belum ada pesanan untuk diekspor.'), findsOneWidget);
    });
  });
}
