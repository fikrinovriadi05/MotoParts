import 'package:flutter/material.dart';
import 'package:motopart/core/app_colors.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/store/store.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int index = 0;

  final pages = const [
    HomePage(),
    CategoryPage(),
    CartPage(),
    OrdersPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          return NavigationBar(
            height: 72,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.blue.withValues(alpha: 0.12),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: AppColors.blue),
                label: 'Beranda',
              ),
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view, color: AppColors.blue),
                label: 'Kategori',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: store.cartCount > 0,
                  label: Text('${store.cartCount}'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                selectedIcon:
                    const Icon(Icons.shopping_bag, color: AppColors.blue),
                label: 'Keranjang',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon:
                    Icon(Icons.receipt_long, color: AppColors.blue),
                label: 'Pesanan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: AppColors.blue),
                label: 'Profil',
              ),
            ],
          );
        },
      ),
    );
  }
}
