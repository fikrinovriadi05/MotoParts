import 'package:flutter/material.dart';
import 'package:motopart/pages/admin/admin_categories_page.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_settings_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/brand_mark.dart';
import 'package:motopart/widgets/motopart_wordmark.dart';

/// Lebar layar (dp) di atas ini memakai sidebar di kiri, bukan bilah bawah.
const adminWideBreakpoint = 900.0;

/// Lebar layar yang cukup untuk sidebar dengan label dan logo lengkap.
const adminExtendedRailBreakpoint = 1200.0;

class _AdminDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _AdminDestination(this.label, this.icon, this.selectedIcon);
}

const _destinations = [
  _AdminDestination(
    'Dashboard',
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
  ),
  _AdminDestination(
    'Produk',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
  ),
  _AdminDestination(
    'Pesanan',
    Icons.receipt_long_outlined,
    Icons.receipt_long_rounded,
  ),
  _AdminDestination(
    'Kategori',
    Icons.category_outlined,
    Icons.category_rounded,
  ),
  _AdminDestination(
    'Pengaturan',
    Icons.settings_outlined,
    Icons.settings_rounded,
  ),
];

/// Kerangka halaman admin. HP: bilah navigasi bawah. Layar lebar (> 900):
/// sidebar di kiri dengan logo dan nama admin. Hanya admin yang sudah masuk
/// yang bisa melihat isinya; selain itu diarahkan ke halaman login.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;

  final pages = const [
    AdminDashboardPage(),
    AdminProductsPage(),
    AdminOrdersPage(),
    AdminCategoriesPage(),
    AdminSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        // Penjaga: tanpa login admin, isi admin tidak boleh terbuka.
        if (!auth.isAdmin) return const LoginPage();

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > adminWideBreakpoint;
            final body = IndexedStack(index: index, children: pages);
            if (!wide) {
              return Scaffold(
                body: body,
                bottomNavigationBar: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                  ],
                ),
              );
            }

            final extended =
                constraints.maxWidth >= adminExtendedRailBreakpoint;
            return Scaffold(
              body: Row(
                children: [
                  _Sidebar(
                    extended: extended,
                    index: index,
                    onSelected: (value) => setState(() => index = value),
                  ),
                  VerticalDivider(width: 1, color: context.palette.border),
                  Expanded(child: body),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool extended;
  final int index;
  final ValueChanged<int> onSelected;

  const _Sidebar({
    required this.extended,
    required this.index,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = auth.currentAccount?.name ?? 'Admin';
    return NavigationRail(
      extended: extended,
      selectedIndex: index,
      onDestinationSelected: onSelected,
      backgroundColor: palette.surface,
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      indicatorColor: palette.accent.withValues(alpha: 0.2),
      selectedIconTheme: IconThemeData(color: palette.primaryText),
      selectedLabelTextStyle: TextStyle(
        color: palette.primaryText,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: palette.textMuted),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 44),
            if (extended) ...[
              const SizedBox(height: AppSpacing.sm),
              const MotoPartWordmark(fontSize: 18),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: extended ? 160 : 72,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: AppTextSizes.small,
                  color: palette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}
