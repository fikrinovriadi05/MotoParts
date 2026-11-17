import 'package:excel/excel.dart';
import 'package:motopart/core/sales_report.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/store/store.dart';

/// Membuat berkas Excel (.xlsx) laporan penjualan dengan tiga lembar yang
/// ditata rapi: judul, header berwarna, garis tabel, lebar kolom, format
/// Rupiah dan tanggal, serta baris total.
class ReportXlsx {
  const ReportXlsx._();

  static const mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const summarySheet = 'Ringkasan';
  static const productsSheet = 'Per Produk';
  static const ordersSheet = 'Pesanan';

  // Warna merek MotoPart.
  static final _primary = ExcelColor.fromHexString('#E8590C');
  static final _headerFill = ExcelColor.fromHexString('#2B2D33');
  static final _band = ExcelColor.fromHexString('#FFF4EC');
  static final _totalFill = ExcelColor.fromHexString('#FFE3CF');
  static final _okFill = ExcelColor.fromHexString('#D8F3DC');
  static final _badFill = ExcelColor.fromHexString('#FFD6D6');
  static final _waitFill = ExcelColor.fromHexString('#FFF3BF');
  static final _white = ExcelColor.fromHexString('#FFFFFF');
  static final _grey = ExcelColor.fromHexString('#6B7280');

  static final _rupiah = NumFormat.custom(formatCode: '"Rp "#,##0');
  static final _date = NumFormat.custom(formatCode: 'dd/mm/yyyy hh:mm');

  static final _line = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#C9CDD3'),
  );

  /// Nama berkas, mis. `laporan-penjualan_2026-11-01_sd_2026-11-17.xlsx`.
  static String fileName(SalesReport report, DateTime now) {
    final range = report.range;
    if (range == null) return 'laporan-penjualan_semua_${_iso(now)}.xlsx';
    return 'laporan-penjualan_${_iso(range.start)}_sd_${_iso(range.end)}.xlsx';
  }

  static List<int> build(SalesReport report, {required DateTime generatedAt}) {
    final excel = Excel.createExcel();
    final first = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(first, summarySheet);

    _summary(excel[summarySheet], report, generatedAt);
    _products(excel[productsSheet], report);
    _orders(excel[ordersSheet], report);

    excel.setDefaultSheet(summarySheet);
    return excel.encode() ?? (throw StateError('Gagal membuat berkas Excel.'));
  }

  // ------------------------------------------------------------ lembar

  static void _summary(Sheet sheet, SalesReport r, DateTime generatedAt) {
    sheet.setColumnWidth(0, 34);
    sheet.setColumnWidth(1, 30);

    _title(sheet, 'Laporan Penjualan MotoPart', columns: 2);
    sheet.setRowHeight(0, 30);

    _put(
      sheet,
      0,
      2,
      TextCellValue('Periode'),
      CellStyle(bold: true, fontColorHex: _grey),
    );
    _put(
      sheet,
      1,
      2,
      TextCellValue(r.range?.description ?? 'Semua waktu'),
      CellStyle(horizontalAlign: HorizontalAlign.Left),
    );
    _put(
      sheet,
      0,
      3,
      TextCellValue('Dibuat'),
      CellStyle(bold: true, fontColorHex: _grey),
    );
    _put(
      sheet,
      1,
      3,
      DateTimeCellValue.fromDateTime(generatedAt),
      CellStyle(numberFormat: _date, horizontalAlign: HorizontalAlign.Left),
    );

    const headerRow = 5;
    _header(sheet, headerRow, ['Keterangan', 'Nilai']);
    final rows = <(String, CellValue, NumFormat?)>[
      ('Total penjualan', IntCellValue(r.totalSales), _rupiah),
      ('Jumlah pesanan terhitung', IntCellValue(r.sales.length), null),
      ('Barang terjual', IntCellValue(r.totalUnits), null),
      ('Rata-rata per pesanan', IntCellValue(r.average), _rupiah),
      ('Pesanan dibatalkan', IntCellValue(r.cancelledCount), null),
      ('Pesanan menunggu pembayaran', IntCellValue(r.awaitingCount), null),
    ];
    for (var i = 0; i < rows.length; i++) {
      final row = headerRow + 1 + i;
      final fill = i.isOdd ? _band : null;
      _put(sheet, 0, row, TextCellValue(rows[i].$1), _cell(fill: fill));
      _put(
        sheet,
        1,
        row,
        rows[i].$2,
        _cell(
          fill: fill,
          align: HorizontalAlign.Right,
          format: rows[i].$3 ?? NumFormat.standard_3,
          bold: i == 0,
        ),
      );
    }

    final note = headerRow + rows.length + 2;
    _put(
      sheet,
      0,
      note,
      TextCellValue(
        'Pesanan dibatalkan dan yang menunggu pembayaran tidak dihitung '
        'sebagai penjualan.',
      ),
      CellStyle(italic: true, fontColorHex: _grey),
    );
  }

  static void _products(Sheet sheet, SalesReport r) {
    const widths = [6.0, 38.0, 18.0, 26.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
    _title(sheet, 'Penjualan per Produk', columns: 4);
    sheet.setRowHeight(0, 30);
    _put(
      sheet,
      0,
      1,
      TextCellValue(r.range?.description ?? 'Semua waktu'),
      CellStyle(fontColorHex: _grey),
    );

    const headerRow = 3;
    _header(sheet, headerRow, [
      'No',
      'Produk',
      'Jumlah Terjual',
      'Pendapatan Barang',
    ]);
    for (var i = 0; i < r.products.length; i++) {
      final p = r.products[i];
      final row = headerRow + 1 + i;
      final fill = i.isOdd ? _band : null;
      _put(
        sheet,
        0,
        row,
        IntCellValue(i + 1),
        _cell(fill: fill, align: HorizontalAlign.Center),
      );
      _put(sheet, 1, row, TextCellValue(p.name), _cell(fill: fill));
      _put(
        sheet,
        2,
        row,
        IntCellValue(p.qty),
        _cell(
          fill: fill,
          align: HorizontalAlign.Right,
          format: NumFormat.standard_3,
        ),
      );
      _put(
        sheet,
        3,
        row,
        IntCellValue(p.revenue),
        _cell(fill: fill, align: HorizontalAlign.Right, format: _rupiah),
      );
    }
    if (r.products.isEmpty) {
      _put(
        sheet,
        1,
        headerRow + 1,
        TextCellValue('Belum ada penjualan pada periode ini.'),
        CellStyle(italic: true, fontColorHex: _grey),
      );
      return;
    }

    final totalRow = headerRow + 1 + r.products.length;
    final totalRevenue = r.products.fold<int>(0, (s, p) => s + p.revenue);
    _put(sheet, 0, totalRow, null, _cell(fill: _totalFill));
    _put(
      sheet,
      1,
      totalRow,
      TextCellValue('Total'),
      _cell(fill: _totalFill, bold: true),
    );
    _put(
      sheet,
      2,
      totalRow,
      IntCellValue(r.totalUnits),
      _cell(
        fill: _totalFill,
        bold: true,
        align: HorizontalAlign.Right,
        format: NumFormat.standard_3,
      ),
    );
    _put(
      sheet,
      3,
      totalRow,
      IntCellValue(totalRevenue),
      _cell(
        fill: _totalFill,
        bold: true,
        align: HorizontalAlign.Right,
        format: _rupiah,
      ),
    );
  }

  static void _orders(Sheet sheet, SalesReport r) {
    const widths = [6.0, 20.0, 18.0, 24.0, 20.0, 22.0, 40.0, 44.0, 14.0, 20.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
    _title(sheet, 'Daftar Pesanan', columns: widths.length);
    sheet.setRowHeight(0, 30);
    _put(
      sheet,
      0,
      1,
      TextCellValue(r.range?.description ?? 'Semua waktu'),
      CellStyle(fontColorHex: _grey),
    );

    const headerRow = 3;
    _header(sheet, headerRow, [
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

    for (var i = 0; i < r.orders.length; i++) {
      final o = r.orders[i];
      final row = headerRow + 1 + i;
      final fill = i.isOdd ? _band : null;
      final units = o.lines.fold<int>(0, (s, l) => s + l.qty);

      _put(
        sheet,
        0,
        row,
        IntCellValue(i + 1),
        _cell(fill: fill, align: HorizontalAlign.Center),
      );
      _put(sheet, 1, row, TextCellValue(o.code), _cell(fill: fill));
      _put(
        sheet,
        2,
        row,
        o.createdAt == null
            ? TextCellValue('-')
            : DateTimeCellValue.fromDateTime(o.createdAt!),
        _cell(fill: fill, format: _date, align: HorizontalAlign.Left),
      );
      _put(sheet, 3, row, TextCellValue(o.customer), _cell(fill: fill));
      _put(
        sheet,
        4,
        row,
        TextCellValue(o.status),
        _cell(
          fill: _statusFill(o) ?? fill,
          align: HorizontalAlign.Center,
          bold: true,
        ),
      );
      _put(
        sheet,
        5,
        row,
        TextCellValue(o.paymentMethod ?? '-'),
        _cell(fill: fill),
      );
      _put(
        sheet,
        6,
        row,
        TextCellValue(o.address ?? '-'),
        _cell(fill: fill, wrap: true),
      );
      _put(
        sheet,
        7,
        row,
        TextCellValue(
          o.lines.isEmpty
              ? '-'
              : o.lines.map((l) => '${l.name} x${l.qty}').join('\n'),
        ),
        _cell(fill: fill, wrap: true),
      );
      _put(
        sheet,
        8,
        row,
        IntCellValue(units),
        _cell(
          fill: fill,
          align: HorizontalAlign.Right,
          format: NumFormat.standard_3,
        ),
      );
      _put(
        sheet,
        9,
        row,
        IntCellValue(o.total),
        _cell(fill: fill, align: HorizontalAlign.Right, format: _rupiah),
      );
    }

    final rowCount = r.orders.length;
    if (rowCount == 0) {
      _put(
        sheet,
        1,
        headerRow + 1,
        TextCellValue('Belum ada pesanan pada periode ini.'),
        CellStyle(italic: true, fontColorHex: _grey),
      );
      return;
    }
    final totalRow = headerRow + 1 + rowCount;
    for (var c = 0; c < widths.length; c++) {
      _put(sheet, c, totalRow, null, _cell(fill: _totalFill));
    }
    _put(
      sheet,
      1,
      totalRow,
      TextCellValue('Total penjualan'),
      _cell(fill: _totalFill, bold: true),
    );
    _put(
      sheet,
      8,
      totalRow,
      IntCellValue(r.totalUnits),
      _cell(
        fill: _totalFill,
        bold: true,
        align: HorizontalAlign.Right,
        format: NumFormat.standard_3,
      ),
    );
    _put(
      sheet,
      9,
      totalRow,
      IntCellValue(r.totalSales),
      _cell(
        fill: _totalFill,
        bold: true,
        align: HorizontalAlign.Right,
        format: _rupiah,
      ),
    );
    _put(
      sheet,
      1,
      totalRow + 2,
      TextCellValue(
        'Total hanya menghitung pesanan yang bukan dibatalkan dan bukan '
        'menunggu pembayaran.',
      ),
      CellStyle(italic: true, fontColorHex: _grey),
    );
  }

  // ------------------------------------------------------------ bantu

  /// Judul besar di baris pertama, digabung selebar [columns] kolom.
  static void _title(Sheet sheet, String text, {required int columns}) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: 0),
      customValue: TextCellValue(text),
    );
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue(text)
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: _white,
        backgroundColorHex: _primary,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Left,
      );
  }

  static void _header(Sheet sheet, int row, List<String> labels) {
    for (var c = 0; c < labels.length; c++) {
      _put(
        sheet,
        c,
        row,
        TextCellValue(labels[c]),
        CellStyle(
          bold: true,
          fontColorHex: _white,
          backgroundColorHex: _headerFill,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
          leftBorder: _line,
          rightBorder: _line,
          topBorder: _line,
          bottomBorder: _line,
        ),
      );
    }
    sheet.setRowHeight(row, 24);
  }

  /// Gaya sel tabel: garis tipis, isi di bagian atas sel.
  static CellStyle _cell({
    ExcelColor? fill,
    HorizontalAlign align = HorizontalAlign.Left,
    NumFormat? format,
    bool bold = false,
    bool wrap = false,
  }) {
    return CellStyle(
      backgroundColorHex: fill ?? ExcelColor.none,
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Top,
      numberFormat: format ?? NumFormat.standard_0,
      bold: bold,
      textWrapping: wrap ? TextWrapping.WrapText : null,
      leftBorder: _line,
      rightBorder: _line,
      topBorder: _line,
      bottomBorder: _line,
    );
  }

  static void _put(
    Sheet sheet,
    int column,
    int row,
    CellValue? value,
    CellStyle style,
  ) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      value,
      cellStyle: style,
    );
  }

  static ExcelColor? _statusFill(OrderItem o) {
    switch (o.status) {
      case 'Selesai':
        return _okFill;
      case Store.cancelledStatus:
        return _badFill;
      case Store.awaitingPaymentStatus:
        return _waitFill;
    }
    return null;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _iso(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
}
