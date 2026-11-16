import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/store/store.dart';

void main() {
  late OrderItem order;

  setUp(() {
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.cart.clear();
    store.orders
      ..clear()
      ..addAll(fresh.orders);

    store.addToCart(store.products[0]); // 45.000
    store.addToCart(store.products[0]);
    store.addToCart(store.products[1]); // 25.000
    store.checkout(customer: 'Siti', shippingCost: 10000);
    order = store.orders.first;
  });

  Future<void> show(WidgetTester tester, {bool isAdmin = false}) {
    return tester.pumpWidget(
      MaterialApp(
        home: OrderDetailPage(order: order, isAdmin: isAdmin),
      ),
    );
  }

  testWidgets('menampilkan barang, subtotal, ongkir, dan total', (
    tester,
  ) async {
    await show(tester);

    expect(find.text(order.code), findsOneWidget);
    expect(find.text('Pelanggan: Siti'), findsOneWidget);
    expect(find.text('Kampas Rem Depan'), findsOneWidget);
    expect(find.text('2 x Rp 45.000'), findsOneWidget);
    expect(find.text('Rp 90.000'), findsOneWidget);
    expect(find.text('Filter Oli Honda'), findsOneWidget);
    expect(find.text('Subtotal Barang'), findsOneWidget);
    expect(find.text('Rp 115.000'), findsOneWidget); // 90.000 + 25.000
    expect(find.text('Ongkos Kirim'), findsOneWidget);
    expect(find.text('Rp 10.000'), findsOneWidget);
    expect(find.text('Rp 125.000'), findsOneWidget); // total
  });

  testWidgets('pembeli tidak melihat pilihan status', (tester) async {
    await show(tester);

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('admin melihat pilihan status', (tester) async {
    await show(tester, isAdmin: true);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('pesanan tanpa rincian menampilkan pesan dan total', (
    tester,
  ) async {
    order = store.orders.last; // pesanan contoh, tanpa daftar barang
    await show(tester);

    expect(
      find.text('Rincian barang tidak tersedia untuk pesanan ini.'),
      findsOneWidget,
    );
    expect(find.text(formatRupiah(order.total)), findsOneWidget);
  });

  testWidgets('tap pesanan di riwayat pembeli membuka detail', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrdersPage()));

    await tester.tap(find.text(order.code));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailPage), findsOneWidget);
    expect(find.text('Kampas Rem Depan'), findsOneWidget);
  });

  testWidgets('tombol Lihat Detail di admin membuka detail admin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminOrdersPage()));

    await tester.tap(find.text('Lihat Detail').first);
    await tester.pumpAndSettle();

    final page = tester.widget<OrderDetailPage>(find.byType(OrderDetailPage));
    expect(page.isAdmin, isTrue);
    expect(page.order.code, order.code);
  });
}
