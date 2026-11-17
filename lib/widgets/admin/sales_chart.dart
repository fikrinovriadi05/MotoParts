import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/theme/app_theme.dart';

/// Inisial hari (Senin = indeks 0).
const _hari = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

/// Grafik batang penjualan harian. [days] berurutan dari hari terlama; satu
/// batang per hari. Ketuk/tahan batang untuk melihat nominalnya.
class SalesChart extends StatelessWidget {
  final List<({DateTime day, int total})> days;
  final double height;

  const SalesChart({super.key, required this.days, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxValue = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    // Sedikit ruang di atas batang tertinggi.
    final maxY = maxValue == 0 ? 1.0 : maxValue * 1.2;

    return Semantics(
      label:
          'Grafik penjualan ${days.length} hari terakhir: '
          '${days.map((d) => '${_hari[d.day.weekday - 1]} ${formatRupiah(d.total)}').join(', ')}',
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: palette.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days.length) return const SizedBox();
                    final d = days[i].day;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days.length > 7 ? '${d.day}' : _hari[d.weekday - 1],
                        style: TextStyle(
                          color: palette.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: days.length > 7 ? 10 : 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => palette.surfaceAlt,
                tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final d = days[group.x];
                  return BarTooltipItem(
                    '${formatTanggalSingkat(d.day)}\n${formatRupiah(d.total)}',
                    TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: days[i].total == 0
                          ? maxY * 0.02
                          : days[i].total.toDouble(),
                      width: days.length > 14 ? 6 : 18,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      gradient: days[i].total == 0
                          ? null
                          : LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [palette.accent, palette.accentSoft],
                            ),
                      color: days[i].total == 0 ? palette.surfaceAlt : null,
                    ),
                  ],
                ),
            ],
          ),
          duration: UiConfig.motion(const Duration(milliseconds: 500)),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}
