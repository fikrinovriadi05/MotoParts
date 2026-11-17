import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/admin/sales_chart.dart';
import 'package:motopart/widgets/admin/stat_card.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/press_scale.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/section_title.dart';
import 'package:motopart/widgets/shimmer.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Jumlah kolom kartu statistik: 2 di HP, 4 di layar lebar.
int statColumns(double width) => width >= 700 ? 4 : 2;

/// Jumlah pesanan terbaru yang ditampilkan di dasbor.
const dashboardRecentOrders = 5;

class AdminDashboardPage extends StatefulWidget {
  /// Waktu acuan "sekarang" (bisa diatur di tes).
  final DateTime? now;

  const AdminDashboardPage({super.key, this.now});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  /// Kerangka shimmer sesaat saat dasbor dibuka (dimatikan di tes).
  bool loading = UiConfig.simulateLoading;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (loading) {
      _timer = Timer(UiConfig.loadingDuration, () {
        if (mounted) setState(() => loading = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime get now => widget.now ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([store, auth]),
          builder: (context, _) {
            if (loading) return const _DashboardSkeleton();
            return LayoutBuilder(
              builder: (context, constraints) =>
                  _content(context, constraints.maxWidth),
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, double width) {
    final palette = context.palette;
    final columns = statColumns(width);
    final low = store.lowStockProducts;
    final recent = store.orders.take(dashboardRecentOrders).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        _Header(name: auth.currentAccount?.firstName ?? 'Admin', now: now),
        if (auth.adminUsesDefaultPassword) ...[
          const SizedBox(height: AppSpacing.md),
          const _DefaultPasswordBanner(),
        ],
        const SizedBox(height: AppSpacing.lg),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md + 2,
            mainAxisSpacing: AppSpacing.md + 2,
            // 4 kolom (layar lebar): tinggi tetap agar kartu tidak terlalu
            // tinggi dan kosong; 2 kolom: rasio tetap.
            mainAxisExtent: columns == 4 ? 136 : null,
            childAspectRatio: 1.25,
          ),
          children: [
            FadeSlideIn(
              index: 0,
              child: AdminStatCard(
                title: 'Total Produk',
                value: store.products.length,
                icon: Icons.inventory_2_rounded,
                color: palette.accent,
              ),
            ),
            FadeSlideIn(
              index: 1,
              child: AdminStatCard(
                title: 'Pesanan Hari Ini',
                value: store.ordersOn(now),
                icon: Icons.receipt_long_rounded,
                color: AppColors.success,
              ),
            ),
            FadeSlideIn(
              index: 2,
              child: AdminStatCard(
                title: 'Pendapatan',
                value: store.totalSales,
                format: formatRupiah,
                icon: Icons.payments_rounded,
                color: AppColors.info,
              ),
            ),
            FadeSlideIn(
              index: 3,
              child: AdminStatCard(
                title: 'Stok Menipis',
                value: low.length,
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionTitle(
          title: 'Penjualan 7 Hari Terakhir',
          action: 'Laporan',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminReportsPage()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassCard(child: _salesChart(context)),
        const SizedBox(height: AppSpacing.xl),
        const SectionTitle(title: 'Stok Menipis'),
        const SizedBox(height: AppSpacing.sm),
        if (low.isEmpty)
          const _EmptyHint(
            icon: Icons.check_circle_outline_rounded,
            text:
                'Semua stok aman. Tidak ada produk di bawah '
                '${Store.lowStockThreshold}.',
          ),
        for (final product in low)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _LowStockTile(product: product),
          ),
        const SizedBox(height: AppSpacing.lg),
        const SectionTitle(title: 'Pesanan Terbaru'),
        const SizedBox(height: AppSpacing.sm),
        if (recent.isEmpty)
          const _EmptyHint(
            icon: Icons.inbox_rounded,
            text: 'Belum ada pesanan.',
          ),
        for (final order in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: PressScale(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(order: order, isAdmin: true),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md + 2),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.customer} • ${formatRupiah(order.total)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(order.status),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _salesChart(BuildContext context) {
    final days = store.salesLast7Days(now);
    final hasSales = days.any((d) => d.total > 0);
    if (!hasSales) {
      return const _EmptyHint(
        icon: Icons.bar_chart_rounded,
        text: 'Belum ada penjualan dalam 7 hari terakhir.',
      );
    }
    return SalesChart(days: days);
  }
}

/// Header gelap: sapaan menurut jam dan tanggal hari ini.
class _Header extends StatelessWidget {
  final String name;
  final DateTime now;

  const _Header({required this.name, required this.now});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            '${salamWaktu(now)}, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTextSizes.heading,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  formatTanggalLengkap(now),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Kelola seluruh aktivitas toko dari satu tempat.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DefaultPasswordBanner extends StatelessWidget {
  const _DefaultPasswordBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Anda masih memakai password admin bawaan. '
              'Segera ganti demi keamanan.',
              style: TextStyle(
                fontSize: AppTextSizes.small,
                height: 1.4,
                color: palette.text,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
            child: const Text('Ganti'),
          ),
        ],
      ),
    );
  }
}

/// Produk bernstok menipis; ketuk untuk langsung mengeditnya.
class _LowStockTile extends StatelessWidget {
  final Product product;

  const _LowStockTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PressScale(
      onTap: () =>
          const AdminProductsPage().productDialog(context, product: product),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            ProductPicture.forProduct(product, width: 48, height: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    product.category,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: AppTextSizes.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (product.stock == 0 ? AppColors.danger : AppColors.warning)
                        .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                product.stock == 0 ? 'Habis' : 'Sisa ${product.stock}',
                style: TextStyle(
                  color: product.stock == 0
                      ? palette.dangerText
                      : palette.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: AppTextSizes.small,
                ),
              ),
            ),
            Icon(Icons.edit_outlined, color: palette.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Keterangan kosong yang ramah (ikon besar + teks).
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: palette.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka shimmer saat dasbor dimuat.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const ShimmerBox(height: 120, radius: AppRadius.xl),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 120, radius: AppRadius.lg)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerBox(height: 120, radius: AppRadius.lg)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 120, radius: AppRadius.lg)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: ShimmerBox(height: 120, radius: AppRadius.lg)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerBox(height: 220, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 64, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBox(height: 64, radius: AppRadius.lg),
        ],
      ),
    );
  }
}
