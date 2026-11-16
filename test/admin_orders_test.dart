import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/store/store.dart';

void main() {
  group('Store.filterOrders', () {
    late Store s;
    setUp(() => s = Store());

    test('tanpa filter mengembalikan semua pesanan', () {
      expect(s.filterOrders().length, s.orders.length);
    });

    test('filter status', () {
      final result = s.filterOrders(status: 'Selesai');

      expect(result, isNotEmpty);
      expect(result.every((o) => o.status == 'Selesai'), isTrue);
    });

    test('pencarian nama pelanggan tidak membedakan huruf besar/kecil', () {
      final result = s.filterOrders(query: 'bUdI');

      expect(result.length, 1);
      expect(result.first.customer, 'Budi Santoso');
    });

    test('pencarian kode pesanan', () {
      final result = s.filterOrders(query: '0002');

      expect(result.length, 1);
      expect(result.first.code, 'MP-250118-0002');
    });

    test('status dan pencarian digabung', () {
      expect(s.filterOrders(query: 'budi', status: 'Dikirim'), isEmpty);
      expect(s.filterOrders(query: 'budi', status: 'Selesai').length, 1);
    });

    test('pesanan baru dari checkout ikut terfilter sebagai Diproses', () {
      s.addToCart(s.products[0]);
      s.checkout(customer: 'Siti', shippingCost: 0);

      final result = s.filterOrders(status: 'Diproses');

      expect(result.length, 1);
      expect(result.first.customer, 'Siti');
    });
  });

  group('AdminOrdersPage', () {
    setUp(() {
      store.orders
        ..clear()
        ..addAll(Store().orders);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdminOrdersPage()));
    }

    testWidgets('menampilkan semua pesanan lalu memfilter dengan chip', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Budi Santoso • Rp 80.000'), findsOneWidget);
      expect(find.text('Andi Pratama • Rp 125.000'), findsOneWidget);

      await tester.tap(find.text('Dikirim (1)'));
      await tester.pump();

      expect(find.text('Budi Santoso • Rp 80.000'), findsNothing);
      expect(find.text('Andi Pratama • Rp 125.000'), findsOneWidget);
    });

    testWidgets('pencarian menyaring dan menampilkan pesan saat kosong', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'andi');
      await tester.pump();
      expect(find.text('Budi Santoso • Rp 80.000'), findsNothing);
      expect(find.text('Andi Pratama • Rp 125.000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tidak ada');
      await tester.pump();
      expect(find.text('Tidak ada pesanan yang cocok.'), findsOneWidget);
    });
  });
}
