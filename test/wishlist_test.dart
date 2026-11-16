import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/pages/user/wishlist_page.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Store wishlist', () {
    late Store s;
    setUp(() => s = Store());

    test('awalnya kosong', () {
      expect(s.wishlistIds, isEmpty);
      expect(s.wishlistProducts, isEmpty);
    });

    test('toggleWishlist menambah lalu menghapus', () {
      final product = s.products[0];

      expect(s.toggleWishlist(product), isTrue);
      expect(s.isWishlisted(product), isTrue);

      expect(s.toggleWishlist(product), isFalse);
      expect(s.isWishlisted(product), isFalse);
    });

    test('wishlistProducts menampilkan yang terakhir ditambah di atas', () {
      s.toggleWishlist(s.products[0]);
      s.toggleWishlist(s.products[2]);
      s.toggleWishlist(s.products[1]);

      expect(s.wishlistProducts.map((p) => p.id), [
        s.products[1].id,
        s.products[2].id,
        s.products[0].id,
      ]);
    });

    test('toggleWishlist memanggil listener', () {
      var notified = 0;
      s.addListener(() => notified++);

      s.toggleWishlist(s.products[0]);
      s.toggleWishlist(s.products[0]);

      expect(notified, 2);
    });

    test(
      'menghapus produk juga mengeluarkannya dari wishlist dan keranjang',
      () {
        final product = s.products[0];
        s.toggleWishlist(product);
        s.addToCart(product);

        s.deleteProduct(product);

        expect(s.wishlistIds, isEmpty);
        expect(s.cart, isEmpty);
      },
    );

    test('wishlist tersimpan dan dimuat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      first.toggleWishlist(first.products[0]);
      first.toggleWishlist(first.products[3]);

      final reloaded = Store();
      await reloaded.attach(prefs);

      expect(reloaded.wishlistIds, {
        first.products[0].id,
        first.products[3].id,
      });
    });

    test('data lama tanpa wishlist tetap terbaca', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      first.addToCart(first.products[0]); // menyimpan tanpa wishlist apa pun

      final reloaded = Store();
      await reloaded.attach(prefs);

      expect(reloaded.wishlistIds, isEmpty);
      expect(reloaded.cartCount, 1);
    });
  });

  group('tampilan wishlist', () {
    setUp(() {
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
      store.cart.clear();
      store.wishlistIds.clear();
    });

    testWidgets('halaman kosong menampilkan petunjuk', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WishlistPage()));

      expect(find.text('Wishlist masih kosong'), findsOneWidget);
    });

    testWidgets('tombol hati di detail produk menambah dan menghapus', (
      tester,
    ) async {
      final product = store.products[0];
      await tester.pumpWidget(
        MaterialApp(home: ProductDetailPage(product: product)),
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      expect(store.isWishlisted(product), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();
      expect(store.isWishlisted(product), isFalse);
    });

    testWidgets('halaman wishlist menampilkan produk favorit', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.toggleWishlist(store.products[2]); // Busi NGK
      await tester.pumpWidget(const MaterialApp(home: WishlistPage()));

      expect(find.text('Busi NGK'), findsOneWidget);
      expect(find.text('Gear Set'), findsNothing);

      // Hapus lewat hati pada kartu: produk hilang dari daftar.
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();

      expect(find.text('Busi NGK'), findsNothing);
      expect(find.text('Wishlist masih kosong'), findsOneWidget);
    });

    testWidgets('menu Wishlist di profil membuka halaman wishlist', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));

      await tester.tap(find.text('Wishlist'));
      await tester.pumpAndSettle();

      expect(find.byType(WishlistPage), findsOneWidget);
    });
  });
}
