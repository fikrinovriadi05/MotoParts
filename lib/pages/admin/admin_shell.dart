import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';

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
    AdminReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.blue.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.blue),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppColors.blue),
            label: 'Produk',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.blue),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.blue),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}
