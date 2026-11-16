import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akun [accountId] membeli [product] lalu pesanannya diubah ke [status].
void buy(
  Store s,
  String accountId,
  Product product, {
  String status = 'Selesai',
}) {
  s.setCurrentAccount(accountId);
  s.addToCart(product);
  s.checkout(customer: accountId, shippingCost: 0);
  s.updateOrderStatus(s.orders.first, status);
}

String? review(
  Store s,
  Product product, {
  int rating = 5,
  String comment = 'Bagus',
  String name = 'Siti',
  DateTime? now,
}) => s.submitReview(
  product,
  rating: rating,
  comment: comment,
  authorName: name,
  now: now,
);

void main() {
  group('Store: aturan ulasan', () {
    late Store s;
    late Product product;
    setUp(() {
      s = Store();
      product = s.products[0];
    });

    test('tamu tidak bisa mengulas', () {
      expect(s.canReview(product), isFalse);
      expect(
        review(s, product),
        'Ulasan hanya untuk pembeli yang pesanannya sudah selesai.',
      );
    });

    test('akun tanpa pesanan tidak bisa mengulas', () {
      s.setCurrentAccount('A');

      expect(s.canReview(product), isFalse);
    });

    test('pesanan belum selesai tidak cukup', () {
      for (final status in ['Diproses', 'Dikemas', 'Dikirim', 'Dibatalkan']) {
        final fresh = Store();
        buy(fresh, 'A', fresh.products[0], status: status);

        expect(fresh.canReview(fresh.products[0]), isFalse, reason: status);
      }
    });

    test('pesanan selesai berisi produk itu membolehkan ulasan', () {
      buy(s, 'A', product);

      expect(s.canReview(product), isTrue);
      expect(review(s, product), isNull);
    });

    test('hanya untuk produk yang dibeli, dan hanya akun pembelinya', () {
      buy(s, 'A', product);

      expect(s.canReview(s.products[1]), isFalse);
      s.setCurrentAccount('B');
      expect(s.canReview(product), isFalse);
    });

    test('pesanan batal setelah selesai mencabut hak ulasan', () {
      buy(s, 'A', product);
      s.updateOrderStatus(s.orders.first, 'Dibatalkan');

      expect(s.canReview(product), isFalse);
    });
  });

  group('Store: ulasan', () {
    late Store s;
    late Product product;
    setUp(() {
      s = Store();
      product = s.products[0];
      buy(s, 'A', product);
    });

    test('rating di luar 1-5 ditolak', () {
      expect(review(s, product, rating: 0), 'Pilih rating 1 sampai 5 bintang.');
      expect(review(s, product, rating: 6), 'Pilih rating 1 sampai 5 bintang.');
      expect(s.reviews, isEmpty);
    });

    test('komentar terlalu panjang ditolak, komentar kosong boleh', () {
      expect(
        review(s, product, comment: 'x' * 301),
        'Komentar maksimal 300 karakter.',
      );
      expect(review(s, product, comment: '   '), isNull);
      expect(s.reviews.single.comment, '');
    });

    test('satu ulasan per akun per produk: ulasan baru menggantikan', () {
      review(s, product, rating: 2, comment: 'Biasa');
      review(s, product, rating: 5, comment: 'Ternyata bagus');

      expect(s.reviews.length, 1);
      expect(s.myReviewFor(product)?.rating, 5);
      expect(s.myReviewFor(product)?.comment, 'Ternyata bagus');
    });

    test('rata-rata rating dan urutan terbaru di atas', () {
      review(s, product, rating: 5, name: 'Siti', now: DateTime(2026, 1, 1));
      buy(s, 'B', product);
      review(s, product, rating: 2, name: 'Budi', now: DateTime(2026, 2, 1));

      expect(s.averageRating(product), 3.5);
      expect(s.reviewsFor(product).map((r) => r.authorName), ['Budi', 'Siti']);
    });

    test('produk tanpa ulasan: rata-rata null', () {
      expect(s.averageRating(s.products[1]), isNull);
    });

    test('myReviewFor hanya mengembalikan ulasan akun aktif', () {
      review(s, product);

      s.setCurrentAccount('B');
      expect(s.myReviewFor(product), isNull);
      s.setCurrentAccount('A');
      expect(s.myReviewFor(product), isNotNull);
    });

    test('deleteReview menghapus dan memanggil listener', () {
      review(s, product);
      var notified = 0;
      s.addListener(() => notified++);

      s.deleteReview(s.reviews.single);

      expect(s.reviews, isEmpty);
      expect(notified, 1);
    });

    test('menghapus produk ikut menghapus ulasannya', () {
      review(s, product);

      s.deleteProduct(product);

      expect(s.reviews, isEmpty);
    });

    test('ulasan tersimpan dan dimuat kembali', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      buy(first, 'A', first.products[0]);
      review(
        first,
        first.products[0],
        rating: 4,
        comment: 'Mantap',
        now: DateTime(2026, 3, 4, 5, 6),
      );

      final reloaded = Store();
      await reloaded.attach(prefs);

      final r = reloaded.reviews.single;
      expect(r.rating, 4);
      expect(r.comment, 'Mantap');
      expect(r.authorName, 'Siti');
      expect(r.createdAt, DateTime(2026, 3, 4, 5, 6));
    });
  });

  group('tampilan ulasan', () {
    setUp(() {
      auth.logout();
      auth.accounts.removeWhere((a) => !a.isAdmin);
      final fresh = Store();
      store.products
        ..clear()
        ..addAll(fresh.products);
      store.orders
        ..clear()
        ..addAll(fresh.orders);
      store.reviews.clear();
    });

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpDetail(WidgetTester tester, Product product) async {
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(home: ProductDetailPage(product: product)),
      );
    }

    /// Siti mendaftar, login, dan punya pesanan selesai berisi [product].
    void sitiBought(Product product) {
      auth.register(
        name: 'Siti',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      store.addToCart(product);
      store.checkout(customer: 'Siti', shippingCost: 0);
      store.updateOrderStatus(store.orders.first, 'Selesai');
    }

    testWidgets('produk tanpa ulasan menampilkan keterangan', (tester) async {
      await pumpDetail(tester, store.products[0]);

      expect(find.text('Belum ada ulasan'), findsOneWidget);
      expect(find.text('Belum ada ulasan untuk produk ini.'), findsOneWidget);
      expect(find.text('Tulis Ulasan'), findsNothing);
    });

    testWidgets('pembeli tanpa pesanan selesai melihat keterangan syarat', (
      tester,
    ) async {
      auth.register(
        name: 'Siti',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      await pumpDetail(tester, store.products[0]);

      expect(
        find.text('Ulasan hanya untuk pembeli yang pesanannya sudah selesai.'),
        findsOneWidget,
      );
      expect(find.text('Tulis Ulasan'), findsNothing);
    });

    testWidgets('pembeli yang berhak menulis ulasan dan langsung tampil', (
      tester,
    ) async {
      final product = store.products[0];
      sitiBought(product);
      await pumpDetail(tester, product);

      await tester.tap(find.text('Tulis Ulasan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 bintang'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Pengereman jadi pakem');
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();

      expect(find.text('Pengereman jadi pakem'), findsOneWidget);
      expect(find.text('Siti (Anda)'), findsOneWidget);
      expect(find.text('4.0 (1)'), findsOneWidget);
      expect(find.text('Ubah Ulasan Saya'), findsOneWidget);
    });

    testWidgets('kirim tanpa rating menampilkan pesan kesalahan', (
      tester,
    ) async {
      final product = store.products[0];
      sitiBought(product);
      await pumpDetail(tester, product);

      await tester.tap(find.text('Tulis Ulasan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim'));
      await tester.pump();

      expect(find.text('Pilih rating 1 sampai 5 bintang.'), findsOneWidget);
      expect(store.reviews, isEmpty);
    });

    testWidgets('admin menghapus ulasan dari daftar produk', (tester) async {
      final product = store.products[0];
      sitiBought(product);
      store.submitReview(
        product,
        rating: 1,
        comment: 'Tidak pantas',
        authorName: 'Siti',
      );
      auth.logout();
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminProductsPage()));

      await tester.tap(find.byTooltip('Ulasan').first);
      await tester.pumpAndSettle();
      expect(find.text('Tidak pantas'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus ulasan'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak pantas'), findsNothing);
      expect(find.text('Belum ada ulasan.'), findsOneWidget);
      expect(store.reviews, isEmpty);
    });
  });
}
