import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/cart_feedback.dart';
import 'package:motopart/widgets/product_card.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void main() {
  setUp(() {
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
  });

  group('Notifikasi tertutup sendiri (tidak menutupi tombol di bawahnya)', () {
    testWidgets('"Ditambahkan ke keranjang" hilang setelah beberapa detik', (
      tester,
    ) async {
      final product = store.products[0];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: ProductCard.extent,
                child: ProductCard(product: product, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);

      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.persist, isFalse);
      expect(snack.duration, snackDuration);

      await tester.pump(snackDuration);
      await tester.pumpAndSettle();
      expect(find.text('Ditambahkan ke keranjang'), findsNothing);
    });

    testWidgets('tombol Lihat tetap ada selama notifikasi tampil', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    addToCartWithFeedback(context, store.products[0]),
                child: const Text('tambah'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('tambah'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Lihat'), findsOneWidget);
      await tester.pump(snackDuration);
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
    });

    testWidgets(
      '"dihapus dari keranjang" hilang sendiri; Batal sebelum itu mengembalikan',
      (tester) async {
        tester.view.physicalSize = const Size(800, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = store.products[0];
        store.addToCart(p);
        await tester.pumpWidget(app(const CartPage()));

        await tester.tap(find.byTooltip('Hapus ${p.name}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snack.persist, isFalse);
        expect(find.text('${p.name} dihapus dari keranjang'), findsOneWidget);

        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text('${p.name} dihapus dari keranjang'), findsNothing);
        expect(store.qtyInCart(p), 0);
      },
    );
  });
}
