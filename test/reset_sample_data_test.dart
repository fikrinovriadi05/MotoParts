import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/models/review.dart';
import 'package:motopart/pages/admin/admin_settings_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage implements ProductImageStorage {
  final List<String?> deleted = [];

  @override
  Future<String?> pickFromGallery() async => null;

  @override
  Future<void> delete(String? path) async => deleted.add(path);
}

/// Mengacak data: tambah/hapus produk, ubah stok, pesanan, keranjang, dll.
void messUp(Store s) {
  s.deleteProduct(s.products.first);
  s.addProduct(
    Product(
      id: 999,
      name: 'Produk Baru',
      category: 'Mesin',
      type: 'Universal',
      price: 1000,
      stock: 3,
      icon: Icons.build_rounded,
      description: 'x',
      imagePath: '/data/product_images/baru.png',
    ),
  );
  s.products[1].stock = 1;
  s.products[2].imagePath = '/data/product_images/busi.png';

  s.setCurrentAccount('A');
  s.addToCart(s.products[3]);
  s.toggleWishlist(s.products[3]);
  s.checkout(customer: 'A', shippingCost: 0);
  s.addToCart(s.products[4]);
  s.setCurrentAccount('B');
  s.addToCart(s.products[4]);
  s.toggleWishlist(s.products[4]);
}

void main() {
  group('Store.resetSampleData', () {
    late Store s;
    setUp(() => s = Store());

    test('jumlah contoh sesuai konstanta', () {
      expect(Store.defaultProducts().length, Store.sampleProductCount);
      expect(Store.defaultOrders().length, Store.sampleOrderCount);
    });

    test('defaultProducts/defaultOrders membuat objek baru setiap kali', () {
      final a = Store.defaultProducts();
      final b = Store.defaultProducts();
      a.first.stock = 0;

      expect(b.first.stock, isNot(0));
      expect(identical(a.first, b.first), isFalse);
    });

    test('produk dan pesanan kembali ke data contoh', () {
      final defaults = Store.defaultProducts();
      messUp(s);
      expect(s.products.map((p) => p.id), isNot(defaults.map((p) => p.id)));

      s.resetSampleData();

      expect(s.products.map((p) => p.id), defaults.map((p) => p.id));
      expect(s.products.map((p) => p.name), defaults.map((p) => p.name));
      expect(s.products.map((p) => p.stock), defaults.map((p) => p.stock));
      expect(s.products.every((p) => p.imagePath == null), isTrue);
      expect(s.orders.map((o) => o.code), ['MP-250118-0001', 'MP-250118-0002']);
    });

    test('keranjang semua akun, wishlist, dan ulasan dikosongkan', () {
      messUp(s);
      s.setCurrentAccount('A');
      s.reviews.add(
        Review(
          productId: 1,
          accountId: 'A',
          authorName: 'A',
          rating: 5,
          comment: '',
          createdAt: DateTime(2026),
        ),
      );

      s.resetSampleData();

      for (final id in ['A', 'B', Store.guestId]) {
        s.setCurrentAccount(id);
        expect(s.cart, isEmpty, reason: 'keranjang $id');
        expect(s.wishlistIds, isEmpty, reason: 'wishlist $id');
      }
      expect(s.reviews, isEmpty);
    });

    test('mengembalikan jalur foto yang dihapus', () {
      messUp(s);

      final photos = s.resetSampleData();

      expect(
        photos,
        unorderedEquals([
          '/data/product_images/baru.png',
          '/data/product_images/busi.png',
        ]),
      );
    });

    test('akun aktif tidak berubah dan listener dipanggil sekali', () {
      s.setCurrentAccount('A');
      var notified = 0;
      s.addListener(() => notified++);

      s.resetSampleData();

      expect(s.currentAccountId, 'A');
      expect(notified, 1);
    });

    test('dipanggil pada data bawaan: tidak ada perubahan berarti', () {
      final before = s.products.map((p) => p.id).toList();

      expect(s.resetSampleData(), isEmpty);

      expect(s.products.map((p) => p.id), before);
    });

    test('hasil reset tersimpan permanen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Store();
      await first.attach(prefs);
      messUp(first);
      first.resetSampleData();

      final reloaded = Store();
      await reloaded.attach(prefs);

      expect(reloaded.products.length, Store.sampleProductCount);
      expect(reloaded.orders.length, Store.sampleOrderCount);
      reloaded.setCurrentAccount('A');
      expect(reloaded.cart, isEmpty);
    });

    test('data lama (6 produk) dipulihkan ke 12 produk contoh', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final old = Store();
      await old.attach(prefs);
      old.products.removeRange(6, old.products.length);
      old.updateProduct(old.products.first, stock: 7); // memicu simpan
      expect(old.products.length, 6);

      final loaded = Store();
      await loaded.attach(prefs);
      expect(loaded.products.length, 6);

      loaded.resetSampleData();

      expect(loaded.products.length, 12);
      expect(loaded.searchProducts(category: 'Ban').length, 2);
    });
  });

  group('tombol di pengaturan admin', () {
    late _FakeStorage fake;
    late ProductImageStorage original;

    setUp(() {
      original = productImageStorage;
      fake = _FakeStorage();
      productImageStorage = fake;
      store.products
        ..clear()
        ..addAll(Store.defaultProducts());
      store.orders
        ..clear()
        ..addAll(Store.defaultOrders());
      store.reviews.clear();
      auth.logout();
      auth.accounts.removeWhere((a) => !a.isAdmin);
      store.setCurrentAccount(Store.guestId);
    });

    tearDown(() => productImageStorage = original);

    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const AdminSettingsPage()),
      );
    }

    testWidgets('Pengaturan menampilkan tombol Reset Data Contoh', (
      tester,
    ) async {
      await pumpSettings(tester);

      expect(find.text('Reset Data Contoh'), findsOneWidget);
    });

    testWidgets(
      'dialog konfirmasi menjelaskan akibatnya; Batal tidak mengubah',
      (tester) async {
        store.products.first.stock = 1;
        store.products[1].imagePath = '/data/product_images/x.png';
        await pumpSettings(tester);

        await tester.tap(find.text('Reset Data Contoh'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Data Contoh?'), findsOneWidget);
        expect(find.textContaining('12 produk dan 2 pesanan'), findsOneWidget);
        expect(find.textContaining('tidak bisa dibatalkan'), findsOneWidget);

        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(store.products.first.stock, 1);
        expect(store.products[1].imagePath, isNotNull);
        expect(fake.deleted, isEmpty);
      },
    );

    testWidgets('Reset mengembalikan data, menghapus foto, dan memberi tahu', (
      tester,
    ) async {
      store.deleteProduct(store.products.first);
      store.products[2].imagePath = '/data/product_images/x.png';
      store.orders.clear();
      await pumpSettings(tester);

      await tester.tap(find.text('Reset Data Contoh'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(store.products.length, Store.sampleProductCount);
      expect(store.orders.length, Store.sampleOrderCount);
      expect(fake.deleted, ['/data/product_images/x.png']);
      expect(find.text('Data contoh dikembalikan.'), findsOneWidget);
    });

    testWidgets('akun pengguna tidak ikut terhapus', (tester) async {
      auth.register(
        name: 'Siti',
        email: 's@e.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 's@e.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      store.addToCart(store.products.first);
      await pumpSettings(tester);

      await tester.tap(find.text('Reset Data Contoh'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(auth.userAccounts.length, 1);
      expect(auth.currentAccount?.name, 'Siti');
      expect(store.cart, isEmpty, reason: 'keranjang ikut dikosongkan');
    });
  });
}
