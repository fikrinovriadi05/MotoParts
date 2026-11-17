import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/report_exporter.dart';
import 'package:motopart/core/report_xlsx.dart';
import 'package:motopart/core/sales_report.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/motion.dart';

/// Inisial hari dalam bahasa Indonesia, diindeks dengan `DateTime.weekday`
/// (1 = Senin ... 7 = Minggu).
const _hari = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

/// Pilihan rentang waktu di bagian atas laporan.
enum _Preset {
  all('Semua'),
  week('7 Hari'),
  month30('30 Hari'),
  thisMonth('Bulan Ini'),
  custom('Pilih Tanggal');

  final String label;
  const _Preset(this.label);
}

class AdminReportsPage extends StatefulWidget {
  /// Waktu acuan "hari ini" (bisa diatur di tes).
  final DateTime? now;

  const AdminReportsPage({super.key, this.now});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  _Preset preset = _Preset.all;
  ReportRange? customRange;

  DateTime get now => widget.now ?? DateTime.now();

  /// Rentang yang sedang dipilih; null = semua waktu.
  ReportRange? get range {
    switch (preset) {
      case _Preset.all:
        return null;
      case _Preset.week:
        return ReportRange.lastDays(7, now);
      case _Preset.month30:
        return ReportRange.lastDays(30, now);
      case _Preset.thisMonth:
        return ReportRange.thisMonth(now);
      case _Preset.custom:
        return customRange;
    }
  }

  Future<void> _pick(_Preset value) async {
    if (value != _Preset.custom) {
      setState(() => preset = value);
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      currentDate: today,
      // Dibuka di pekan terakhir (atau pilihan sebelumnya) agar tidak perlu
      // menggulir jauh dari tahun 2020.
      initialDateRange: customRange == null
          ? ReportRange.lastDays(7, today).asDateTimeRange
          : customRange!.asDateTimeRange,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
      cancelText: 'Batal',
    );
    if (picked == null || !mounted) return;
    setState(() {
      customRange = ReportRange(picked.start, picked.end);
      preset = _Preset.custom;
    });
  }

  /// Mengekspor laporan periode terpilih ke berkas Excel.
  Future<void> _export(BuildContext context, SalesReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    if (report.orders.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            report.range == null
                ? 'Belum ada pesanan untuk diekspor.'
                : 'Tidak ada pesanan pada periode ini untuk diekspor.',
          ),
        ),
      );
      return;
    }
    final time = now;
    final fileName = ReportXlsx.fileName(report, time);
    try {
      final result = await reportExporter.saveFile(
        fileName: fileName,
        bytes: ReportXlsx.build(report, generatedAt: time),
        mimeType: ReportXlsx.mimeType,
      );
      if (result == ExportResult.done) {
        messenger.showSnackBar(
          SnackBar(content: Text('Laporan diekspor: $fileName')),
        );
      }
    } on ExportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _rangeChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final p in _Preset.values)
          ChoiceChip(
            avatar: p == _Preset.custom
                ? const Icon(Icons.date_range_rounded, size: 18)
                : null,
            label: Text(
              p == _Preset.custom && customRange != null
                  ? customRange!.description
                  : p.label,
            ),
            selected: preset == p,
            onSelected: (_) => _pick(p),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor laporan (Excel)',
            onPressed: () =>
                _export(context, SalesReport.build(store.orders, range: range)),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final r = range;
          final report = SalesReport.build(store.orders, range: r);
          final days = r == null
              ? store.salesLast7Days(now)
              : report.dailySales();
          final maxDay = days.fold<int>(
            0,
            (max, d) => d.total > max ? d.total : max,
          );
          final salesCount = report.sales.length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _rangeChips(),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.charcoal,
                      AppColors.charcoalSoft,
                      Color(0xFF7A3510),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Penjualan',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Total berhitung naik dari 0 saat halaman dibuka.
                    AnimatedCount(
                      value: report.totalSales,
                      fromZero: true,
                      builder: formatRupiah,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r == null
                          ? 'Dari $salesCount pesanan (tidak termasuk yang dibatalkan)'
                          : 'Dari $salesCount pesanan · ${r.description}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.shopping_bag_rounded,
                      label: 'Barang Terjual',
                      value: '${report.totalUnits}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.payments_rounded,
                      label: 'Rata-rata Pesanan',
                      value: formatRupiah(report.average),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r == null
                          ? 'Penjualan 7 Hari Terakhir'
                          : 'Penjualan per Hari',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 17),
                    ),
                    if (r != null && r.days > days.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Menampilkan ${days.length} hari terakhir dari rentang.',
                          style: TextStyle(
                            color: context.palette.textMuted,
                            fontSize: AppTextSizes.small,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    if (maxDay == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Center(
                          child: Text(
                            r == null
                                ? 'Belum ada penjualan dalam 7 hari terakhir.'
                                : 'Belum ada penjualan pada periode ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.palette.textMuted),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final slot = box.maxWidth / days.length;
                            final dense = days.length > 7;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final d in days)
                                  SizedBox(
                                    width: slot,
                                    child: _Bar(
                                      label: dense
                                          ? '${d.day.day}'
                                          : _hari[d.day.weekday - 1],
                                      total: d.total,
                                      fraction: d.total / maxDay,
                                      width: (slot - 4).clamp(5.0, 26.0),
                                      compact: dense,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ekspor Laporan',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Simpan laporan periode terpilih sebagai berkas Excel '
                      '(.xlsx) dengan tabel yang rapi: ringkasan, penjualan '
                      'per produk, dan daftar pesanan.',
                      style: TextStyle(color: context.palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _export(context, report),
                        icon: const Icon(Icons.table_chart_rounded),
                        label: const Text('Ekspor ke Excel (.xlsx)'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primaryText),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTextSizes.title,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: AppTextSizes.small,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu batang grafik yang "tumbuh" saat tampil.
class _Bar extends StatelessWidget {
  static const maxHeight = 140.0;

  final String label;
  final int total;
  final double fraction;
  final double width;

  /// Rentang panjang: label kecil (nomor tanggal).
  final bool compact;

  const _Bar({
    required this.label,
    required this.total,
    required this.fraction,
    this.width = 26,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: '$label: ${formatRupiah(total)}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Container(
              width: width,
              height: total == 0 ? 4 : (maxHeight * value).clamp(6, maxHeight),
              decoration: BoxDecoration(
                gradient: total == 0
                    ? null
                    : LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          context.palette.accent,
                          context.palette.accentSoft,
                        ],
                      ),
                color: total == 0 ? palette.surfaceAlt : null,
                borderRadius: BorderRadius.circular(compact ? 3 : AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9 : null,
            ),
          ),
        ],
      ),
    );
  }
}
