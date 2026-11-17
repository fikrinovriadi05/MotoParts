import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/notifications_page.dart';
import 'package:motopart/store/notification_store.dart';
import 'package:motopart/store/store.dart';

void main() {
  setUp(() {
    notifications.clear('A');
    notifications.clear('B');
    notifications.clear(Store.guestId);
    notifications.clear(NotificationStore.adminAudience);
    store.setCurrentAccount('A');
    store.cart.clear();
  });

  group('Notifikasi pesanan', () {
    test(
      'pesanan dibuat dan status berubah memunculkan notifikasi pembeli',
      () {
        final product = store.products[0]..stock = 10;
        store.addToCart(product);
        store.checkout(customer: 'A', shippingCost: 0);
        final order = store.orders.first;

        var list = notifications.forAccount('A');
        expect(list.single.title, 'Pesanan berhasil dibuat');
        expect(list.single.orderCode, order.code);
        expect(notifications.unreadCount('A'), 1);

        store.updateOrderStatus(order, 'Dikirim');
        store.updateOrderStatus(order, 'Selesai');

        list = notifications.forAccount('A');
        expect(list.length, 3);
        expect(list.map((n) => n.title), contains('Pesanan dikirim'));
        expect(list.map((n) => n.title), contains('Pesanan selesai'));
      },
    );

    test('status yang sama tidak membuat notifikasi baru', () {
      store.products[0].stock = 10;
      store.addToCart(store.products[0]);
      store.checkout(customer: 'A', shippingCost: 0);
      final order = store.orders.first;

      store.updateOrderStatus(order, order.status);
      expect(notifications.forAccount('A').length, 1);
    });

    test('notifikasi terpisah per akun', () {
      store.products[0].stock = 10;
      store.addToCart(store.products[0]);
      store.checkout(customer: 'A', shippingCost: 0);

      expect(notifications.forAccount('A'), isNotEmpty);
      expect(notifications.forAccount('B'), isEmpty);
      expect(notifications.unreadCount('B'), 0);
    });

    test('tandai dibaca dan hapus semua', () {
      store.products[0].stock = 10;
      store.addToCart(store.products[0]);
      store.checkout(customer: 'A', shippingCost: 0);

      notifications.markAllRead('A');
      expect(notifications.unreadCount('A'), 0);

      notifications.clear('A');
      expect(notifications.forAccount('A'), isEmpty);
    });

    test('pembayaran diterima punya pesan sendiri', () {
      final (title, _) = NotificationStore.orderMessage(
        'MP-1',
        'Diproses',
        from: 'Menunggu Pembayaran',
      );
      expect(title, 'Pembayaran diterima');
    });
  });

  group('Notifikasi admin', () {
    const admin = NotificationStore.adminAudience;

    test('pesanan baru memberi tahu admin, bukan pembeli lain', () {
      store.products[0].stock = 10;
      store.addToCart(store.products[0]);
      store.checkout(customer: 'Siti', shippingCost: 0);

      final list = notifications.forAccount(admin);
      expect(list.single.title, 'Pesanan baru');
      expect(list.single.body, contains('Siti'));
      expect(list.single.orderCode, store.orders.first.code);
      expect(notifications.forAccount('B'), isEmpty);
    });

    test('stok menipis dicatat sekali saat melewati batas', () {
      final p = store.products[0]..stock = Store.lowStockThreshold + 1;
      store.addToCart(p);
      store.checkout(customer: 'A', shippingCost: 0); // stok = batas (aman)
      expect(
        notifications.forAccount(admin).map((n) => n.title),
        isNot(contains('Stok menipis')),
      );

      store.addToCart(p);
      store.checkout(customer: 'A', shippingCost: 0); // stok < batas
      expect(
        notifications.forAccount(admin).where((n) => n.title == 'Stok menipis'),
        hasLength(1),
      );

      store.addToCart(p);
      store.checkout(
        customer: 'A',
        shippingCost: 0,
      ); // sudah menipis: tidak lagi
      expect(
        notifications.forAccount(admin).where((n) => n.title == 'Stok menipis'),
        hasLength(1),
      );
    });

    test('pembayaran diterima dan ulasan baru', () {
      final p = store.products[0]..stock = 10;
      store.addToCart(p);
      store.checkout(customer: 'Siti', shippingCost: 0);
      final order = store.orders.first;
      order.status = Store.awaitingPaymentStatus;

      store.markOrderPaid(order);
      expect(
        notifications.forAccount(admin).map((n) => n.title),
        contains('Pembayaran diterima'),
      );

      store.updateOrderStatus(order, 'Selesai');
      store.submitReview(p, rating: 5, comment: 'Bagus', authorName: 'Siti');
      expect(
        notifications.forAccount(admin).map((n) => n.title),
        contains('Ulasan baru'),
      );
    });

    testWidgets('halaman admin hanya memuat notifikasi toko', (tester) async {
      notifications.add(accountId: 'A', title: 'Milik pembeli', body: 'x');
      notifications.add(accountId: admin, title: 'Pesanan baru', body: 'y');
      await tester.pumpWidget(
        const MaterialApp(home: NotificationsPage(admin: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pesanan baru'), findsOneWidget);
      expect(find.text('Milik pembeli'), findsNothing);
    });
  });

  group('Halaman notifikasi', () {
    testWidgets('kosong menampilkan pesan', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotificationsPage()));
      expect(find.text('Belum ada notifikasi.'), findsOneWidget);
    });

    testWidgets('daftar, titik belum dibaca hilang saat diketuk', (
      tester,
    ) async {
      notifications.add(
        accountId: 'A',
        title: 'Pesanan dikirim',
        body: 'Pesanan MP-1 dalam perjalanan.',
      );
      await tester.pumpWidget(const MaterialApp(home: NotificationsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Pesanan dikirim'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);

      await tester.tap(find.text('Pesanan dikirim'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(notifications.unreadCount('A'), 0);
    });
  });
}
