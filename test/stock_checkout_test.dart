import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/checkout_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';

void main() {
  group('Store: stok dipakai bersama antar akun', () {
    late Store s;
    late Product product;

    /// Dua akun sama-sama punya [qty] unit produk (stok 5) di keranjang.
    void bothHaveInCart(int qty) {
      product = s.products[0];
      product.stock = 5;
      for (final id in ['A', 'B']) {
        s.setCurrentAccount(id);
        for (var i = 0; i < qty; i++) {
          s.addToCart(product);
        }
      }
    }

    setUp(() => s = Store());

    test('checkout pertama berhasil, kedua ditolak tanpa mengubah apa pun', () {
      bothHaveInCart(4);

      s.setCurrentAccount('A');
      expect(s.checkout(customer: 'A', shippingCost: 0), isTrue);
      expect(product.stock, 1);

      s.setCurrentAccount('B');
      final ordersBefore = s.orders.length;
      expect(s.checkout(customer: 'B', shippingCost: 0), isFalse);

      expect(s.orders.length, ordersBefore);
      expect(product.stock, 1);
      expect(s.qtyInCart(product), 4, reason: 'keranjang B tidak berubah');
    });

    test('cartStockProblems menjelaskan sisa stok atau stok habis', () {
      bothHaveInCart(4);
      s.setCurrentAccount('A');
      s.checkout(customer: 'A', shippingCost: 0);
      s.setCurrentAccount('B');

      expect(s.cartStockProblems, ['Stok Kampas Rem Depan tinggal 1.']);

      product.stock = 0;
      expect(s.cartStockProblems, ['Kampas Rem Depan sudah habis.']);
    });

    test('trimCartToStock memangkas qty, lalu checkout berhasil', () {
      bothHaveInCart(4);
      s.setCurrentAccount('A');
      s.checkout(customer: 'A', shippingCost: 0);
      s.setCurrentAccount('B');

      s.trimCartToStock();

      expect(s.qtyInCart(product), 1);
      expect(s.cartStockProblems, isEmpty);
      expect(s.checkout(customer: 'B', shippingCost: 0), isTrue);
      expect(product.stock, 0);
    });

    test('trimCartToStock mengeluarkan item yang stoknya habis', () {
      bothHaveInCart(2);
      product.stock = 0;
      s.setCurrentAccount('B');

      s.trimCartToStock();

      expect(s.cart, isEmpty);
    });

    test('keranjang kosong tidak bisa checkout', () {
      final orders = s.orders.length;

      expect(s.checkout(customer: 'X', shippingCost: 0), isFalse);
      expect(s.orders.length, orders);
    });
  });

  group('alur pembayaran', () {
    setUp(() {
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
      store.orders
        ..clear()
        ..addAll(fresh.orders);
      store.setCurrentAccount('A');
      store.cart.clear();
      store.setCurrentAccount('B');
      store.cart.clear();
    });

    /// Root -> halaman perantara -> [page], seperti Keranjang -> Checkout ->
    /// Pembayaran.
    Future<void> pumpStack(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: Center(
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => page),
                            ),
                            child: const Text('buka halaman'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('root'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('buka halaman'));
      await tester.pumpAndSettle();
    }

    testWidgets('stok berubah saat bayar: keranjang disesuaikan, kembali', (
      tester,
    ) async {
      final product = store.products[0];
      product.stock = 5;
      store.setCurrentAccount('B');
      for (var i = 0; i < 4; i++) {
        store.addToCart(product);
      }
      await pumpStack(
        tester,
        const PaymentPage(customerName: 'B', shippingCost: 0),
      );

      // Pembeli lain menghabiskan stok saat B berada di halaman pembayaran.
      product.stock = 1;
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentSuccessPage), findsNothing);
      expect(find.byType(PaymentPage), findsNothing);
      expect(
        find.textContaining('Stok Kampas Rem Depan tinggal 1.'),
        findsOneWidget,
      );
      expect(store.qtyInCart(product), 1);
      expect(store.orders.where((o) => o.customer == 'B'), isEmpty);
    });

    testWidgets('stok cukup: pembayaran berhasil', (tester) async {
      final product = store.products[0];
      store.setCurrentAccount('B');
      store.addToCart(product);
      await pumpStack(
        tester,
        const PaymentPage(customerName: 'B', shippingCost: 0),
      );

      await tester.tap(find.text('COD')); // tanpa server pembayaran
      await tester.pump();
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      expect(store.orders.first.customer, 'B');
    });

    testWidgets('lanjut ke pembayaran ditolak jika stok sudah kurang', (
      tester,
    ) async {
      auth.register(
        name: 'B',
        email: 'b-stok@e.com',
        phone: '0812345678',
        password: 'Rahasia1!',
      );
      auth.login(
        email: 'b-stok@e.com',
        password: 'Rahasia1!',
        role: AccountRole.user,
      );
      addTearDown(() {
        auth.logout();
        auth.accounts.removeWhere((a) => !a.isAdmin);
      });
      auth.addAddress(
        label: 'Rumah',
        recipient: 'B',
        phone: '0812345678',
        street: 'Jl. Contoh 1',
        city: 'Bandung',
      );

      final product = store.products[0];
      product.stock = 5;
      for (var i = 0; i < 3; i++) {
        store.addToCart(product);
      }
      await pumpStack(tester, const CheckoutPage());

      product.stock = 2;
      await tester.tap(find.text('Lanjutkan Pembayaran'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentPage), findsNothing);
      expect(find.byType(CheckoutPage), findsNothing);
      expect(store.qtyInCart(product), 2);
      expect(find.textContaining('tinggal 2'), findsOneWidget);
    });
  });
}
