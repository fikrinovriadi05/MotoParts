import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/report_csv.dart';
import 'package:motopart/core/report_exporter.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/motion.dart';

/// Inisial hari dalam bahasa Indonesia, diindeks dengan `DateTime.weekday`
/// (1 = Senin ... 7 = Minggu).
const _hari = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

class AdminReportsPage extends StatelessWidget {
  /// Waktu acuan "hari ini" (bisa diatur di tes).
  final DateTime? now;

  const AdminReportsPage({super.key, this.now});

  /// Mengekspor semua pesanan dan ringkasannya ke berkas CSV (Excel).
  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.orders.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Belum ada pesanan untuk diekspor.')),
      );
      return;
    }
    final time = now ?? DateTime.now();
    final fileName = ReportCsv.fileName(time);
    try {
      final result = await reportExporter.saveCsv(
        fileName: fileName,
        content: ReportCsv.build(orders: store.orders, generatedAt: time),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor laporan (CSV)',
            onPressed: () => _export(context),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final days = store.salesLast7Days(now ?? DateTime.now());
          final maxDay = days.fold<int>(
            0,
            (max, d) => d.total > max ? d.total : max,
          );
          final salesCount = store.salesOrders.length;
          final average = salesCount == 0
              ? 0
              : (store.totalSales / salesCount).round();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
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
                      value: store.totalSales,
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
                      'Dari $salesCount pesanan (tidak termasuk yang dibatalkan)',
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
                      value: '${store.totalUnitsSold}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.payments_rounded,
                      label: 'Rata-rata Pesanan',
                      value: formatRupiah(average),
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
                      'Penjualan 7 Hari Terakhir',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (maxDay == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Center(
                          child: Text(
                            'Belum ada penjualan dalam 7 hari terakhir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.palette.textMuted),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final d in days)
                              _Bar(
                                label: _hari[d.day.weekday - 1],
                                total: d.total,
                                fraction: d.total / maxDay,
                              ),
                          ],
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
                      'Simpan ringkasan, penjualan per produk, dan daftar '
                      'semua pesanan sebagai berkas CSV yang bisa dibuka di '
                      'Excel atau Google Sheets.',
                      style: TextStyle(color: context.palette.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _export(context),
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Ekspor ke CSV (Excel)'),
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

  const _Bar({
    required this.label,
    required this.total,
    required this.fraction,
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
              width: 26,
              height: total == 0 ? 4 : (maxHeight * value).clamp(6, maxHeight),
              decoration: BoxDecoration(
                gradient: total == 0
                    ? null
                    : const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.primary, AppColors.primarySoft],
                      ),
                color: total == 0 ? palette.surfaceAlt : null,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
