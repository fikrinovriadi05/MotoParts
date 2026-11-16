import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/widgets/cart_badge_icon.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell>
    with SingleTickerProviderStateMixin {
  final pages = const [HomePage(), CategoryPage(), CartPage(), ProfilePage()];

  /// Memudar halus saat berpindah tab (halaman tetap hidup di IndexedStack).
  late final AnimationController fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    userTabIndex.addListener(_onTabChanged);
    // Pesanan yang menunggu pembayaran mungkin sudah lunas/kedaluwarsa selama
    // aplikasi ditutup.
    unawaited(store.refreshPendingPayments(paymentApi));
  }

  void _onTabChanged() {
    fade.forward(from: 0.35);
  }

  @override
  void dispose() {
    userTabIndex.removeListener(_onTabChanged);
    fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: userTabIndex,
      builder: (context, index, _) {
        return Scaffold(
          body: FadeTransition(
            opacity: CurvedAnimation(parent: fade, curve: Curves.easeOut),
            child: IndexedStack(index: index, children: pages),
          ),
          bottomNavigationBar: AnimatedBuilder(
            animation: store,
            builder: (context, _) {
              return NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (value) => userTabIndex.value = value,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Beranda',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Kategori',
                  ),
                  NavigationDestination(
                    icon: CartBadgeIcon(
                      count: store.cartCount,
                      icon: Icons.shopping_bag_outlined,
                    ),
                    selectedIcon: CartBadgeIcon(
                      count: store.cartCount,
                      icon: Icons.shopping_bag_rounded,
                    ),
                    label: 'Keranjang',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Akun',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
