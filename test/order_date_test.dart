import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('formatTanggal', () {
    test('memakai bulan singkat Indonesia dan jam 24 jam', () {
      expect(formatTanggal(DateTime(2026, 11, 14, 9, 5)), '14 Nov 2026, 09:05');
      expect(formatTanggal(DateTime(2026, 8, 1, 23, 59)), '1 Agu 2026, 23:59');
      expect(formatTanggal(DateTime(2027, 5, 30, 0, 0)), '30 Mei 2027, 00:00');
    });
  });

  group('createdAt', () {
    test('checkout mencatat waktu pesanan', () {
      final store = Store();
      final now = DateTime(2026, 11, 14, 9, 5);
      store.addToCart(store.products[0]);

      store.checkout(customer: 'Siti', shippingCost: 0, now: now);

      expect(store.orders.first.createdAt, now);
      expect(store.orders.first.code, 'MP-${now.millisecondsSinceEpoch}');
    });

    test('pesanan contoh punya tanggal 18 Jan 2025', () {
      final orders = Store().orders;

      expect(orders.first.createdAt, DateTime(2025, 1, 18, 10, 30));
      expect(orders.last.createdAt, DateTime(2025, 1, 18, 14, 15));
    });

    test('waktu pesanan tersimpan dan dimuat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      final now = DateTime(2026, 11, 14, 9, 5);
      first.addToCart(first.products[0]);
      first.checkout(customer: 'Siti', shippingCost: 0, now: now);

      final reloaded = Store();
      await reloaded.attach(prefs);

      expect(reloaded.orders.first.createdAt, now);
      expect(reloaded.orders.last.createdAt, DateTime(2025, 1, 18, 14, 15));
    });

    test('data lama tanpa createdAt tetap terbaca', () {
      final order = OrderItem.fromJson({
        'code': 'MP-1',
        'customer': 'Lama',
        'total': 1000,
        'status': 'Selesai',
      });

      expect(order.createdAt, isNull);
    });
  });

  group('tampilan detail', () {
    Future<void> show(WidgetTester tester, OrderItem order) {
      return tester.pumpWidget(
        MaterialApp(home: OrderDetailPage(order: order)),
      );
    }

    testWidgets('menampilkan tanggal pesanan', (tester) async {
      await show(
        tester,
        OrderItem(
          code: 'MP-1',
          customer: 'Siti',
          total: 1000,
          status: 'Diproses',
          createdAt: DateTime(2026, 11, 14, 9, 5),
        ),
      );

      expect(find.text('Tanggal: 14 Nov 2026, 09:05'), findsOneWidget);
    });

    testWidgets('menampilkan tanda - jika tanggal tidak ada', (tester) async {
      await show(
        tester,
        OrderItem(
          code: 'MP-2',
          customer: 'Budi',
          total: 1000,
          status: 'Selesai',
        ),
      );

      expect(find.text('Tanggal: -'), findsOneWidget);
    });
  });
}
