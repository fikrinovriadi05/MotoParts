import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/product_grid.dart';
import 'package:motopart/widgets/promo_banner.dart';
import 'package:motopart/widgets/shimmer.dart';

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: mode,
  home: home,
);

void size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void resetStore() {
  final fresh = Store();
  store.products
    ..clear()
    ..addAll(fresh.products);
  store.orders
    ..clear()
    ..addAll(fresh.orders);
  store.setCurrentAccount(Store.guestId);
  store.cart.clear();
  store.wishlistIds.clear();
  store.reviews.clear();
  userTabIndex.value = UserTab.home;
}

void main() {
  setUp(resetStore);

  group('format harga (intl)', () {
    test('Rp dengan spasi dan titik ribuan', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(999), 'Rp 999');
      expect(formatRupiah(125000), 'Rp 125.000');
      expect(formatRupiah(1250000), 'Rp 1.250.000');
    });
  });

  group('Store.productsBySales', () {
    test('tanpa penjualan: urutan daftar tetap', () {
      final s = Store()..orders.clear();

      expect(s.productsBySales().map((p) => p.id), s.products.map((p) => p.id));
    });

    test('produk paling banyak terjual di depan; batal tidak dihitung', () {
      final s = Store();
      s.setCurrentAccount('A');
      final seller = s.products[3];
      final cancelled = s.products[4];
      // Lebih banyak dari penjualan terbanyak di data contoh (3 unit).
      for (var i = 0; i < 4; i++) {
        s.addToCart(seller);
      }
      s.checkout(customer: 'A', shippingCost: 0);
      for (var i = 0; i < 5; i++) {
        s.addToCart(cancelled);
      }
      s.checkout(customer: 'A', shippingCost: 0);
      s.updateOrderStatus(s.orders.first, 'Dibatalkan');

      final order = s.productsBySales().map((p) => p.id).toList();

      expect(order.first, seller.id);
      expect(s.unitsSold[seller.id], 4);
      expect(s.unitsSold[cancelled.id], isNull);
    });
  });

  group('kategori', () {
    test('mencakup Mesin, Rem, Oli, Ban, Kelistrikan, Body', () {
      expect(
        productCategoryNames,
        containsAll(['Mesin', 'Rem', 'Oli', 'Ban', 'Kelistrikan', 'Body']),
      );
    });
  });

  group('beranda', () {
    testWidgets('menampilkan sapaan, banner, kategori, dan Produk Terlaris', (
      tester,
    ) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));

      expect(find.text('Produk Terlaris'), findsOneWidget);
      expect(find.byType(PromoBanner), findsOneWidget);
      for (final name in ['Mesin', 'Rem', 'Oli', 'Ban']) {
        expect(find.bySemanticsLabel('Kategori $name'), findsOneWidget);
      }
      expect(find.byType(ProductCard), findsWidgets);
    });

    testWidgets('banner bisa digeser dan indikator titik berpindah', (
      tester,
    ) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));

      double dotWidth(int i) =>
          tester.getSize(find.byKey(ValueKey('promo-dot-$i'))).width;
      expect(dotWidth(0), greaterThan(dotWidth(1)));

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(dotWidth(1), greaterThan(dotWidth(0)));
    });

    testWidgets('menekan kategori membuka katalog dengan kategori itu', (
      tester,
    ) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));

      await tester.tap(find.bySemanticsLabel('Kategori Rem'));
      await tester.pumpAndSettle();

      final catalog = tester.widget<CatalogPage>(find.byType(CatalogPage));
      expect(catalog.selectedCategory, 'Rem');
    });

    testWidgets('kategori tanpa produk membuka katalog kosong', (tester) async {
      size(tester, 400, 2400);
      store.products.removeWhere((p) => p.category == 'Ban');
      await tester.pumpWidget(app(const HomePage()));

      await tester.tap(find.bySemanticsLabel('Kategori Ban'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);
    });

    testWidgets('pencarian mengganti judul dan menyaring produk', (
      tester,
    ) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));

      await tester.enterText(find.byType(TextField), 'busi');
      await tester.pump();

      expect(find.text('Hasil Pencarian'), findsOneWidget);
      expect(find.text('Busi NGK'), findsOneWidget);
      expect(find.text('Gear Set'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);
    });

    testWidgets('Produk Terlaris mengurutkan menurut penjualan', (
      tester,
    ) async {
      size(tester, 400, 2400);
      store.setCurrentAccount('A');
      for (var i = 0; i < 4; i++) {
        store.addToCart(store.products[5]); // Gear Set, lebih laris dari contoh
      }
      store.checkout(customer: 'A', shippingCost: 0);
      store.setCurrentAccount(Store.guestId);
      await tester.pumpWidget(app(const HomePage()));

      final firstName = tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .first
          .product
          .name;

      expect(firstName, 'Gear Set');
    });

    testWidgets('mode gelap tidak error', (tester) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage(), mode: ThemeMode.dark));

      expect(find.text('Produk Terlaris'), findsOneWidget);
    });
  });

  group('kartu produk', () {
    Product product([int stock = 24]) {
      final p = store.products[0]; // Kampas Rem Depan, Rp 45.000
      p.stock = stock;
      return p;
    }

    Future<void> pumpCard(WidgetTester tester, Product p) async {
      size(tester, 400, 900);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: ProductCard.extent,
                child: ProductCard(product: p, onTap: () {}),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('menampilkan nama, merek motor, harga, dan stok', (
      tester,
    ) async {
      await pumpCard(tester, product());

      expect(find.text('Kampas Rem Depan'), findsOneWidget);
      expect(find.text('Honda Beat'), findsOneWidget);
      expect(find.text('Rp 45.000'), findsOneWidget);
      expect(find.text('Stok 24'), findsOneWidget);
    });

    testWidgets('stok di bawah 5 tampil merah "Stok tinggal N"', (
      tester,
    ) async {
      await pumpCard(tester, product(3));

      final label = tester.widget<Text>(find.text('Stok tinggal 3'));
      expect(label.style!.color, AppPalette.light.dangerText);
    });

    testWidgets('stok 5 belum dianggap menipis', (tester) async {
      await pumpCard(tester, product(5));

      final label = tester.widget<Text>(find.text('Stok 5'));
      expect(label.style!.color, AppPalette.light.textMuted);
    });

    testWidgets('tombol + menambah ke keranjang dengan SnackBar dan Lihat', (
      tester,
    ) async {
      final p = product();
      await pumpCard(tester, p);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(store.qtyInCart(p), 1);
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
      expect(find.text('Lihat'), findsOneWidget);
    });

    testWidgets('area sentuh tombol + minimal 48x48', (tester) async {
      await pumpCard(tester, product());

      final box = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(InkResponse),
        ),
      );

      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
    });

    testWidgets('stok habis: tombol + tidak menambah', (tester) async {
      final p = product(0);
      await pumpCard(tester, p);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(store.qtyInCart(p), 0);
      expect(find.text('Stok habis'), findsOneWidget);
    });

    testWidgets('kartu mengecil sedikit saat ditekan', (tester) async {
      await pumpCard(tester, product());
      // AnimatedScale terluar = efek tekan (yang di dalamnya: zoom gambar saat hover).
      final scale = find
          .descendant(
            of: find.byType(ProductCard),
            matching: find.byType(AnimatedScale),
          )
          .first;
      expect(tester.widget<AnimatedScale>(scale).scale, 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Kampas Rem Depan')),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.widget<AnimatedScale>(scale).scale, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
    });
  });

  group('grid responsif', () {
    test('2 kolom di HP, 3 di tablet kecil, 4 di layar lebar', () {
      expect(productGridColumns(320), 2);
      expect(productGridColumns(599), 2);
      expect(productGridColumns(600), 3);
      expect(productGridColumns(899), 3);
      expect(productGridColumns(900), 4);
      expect(productGridColumns(1400), 4);
    });

    for (final width in [320.0, 400.0, 700.0, 1100.0]) {
      testWidgets('tanpa overflow dan kolom sesuai di lebar $width', (
        tester,
      ) async {
        size(tester, width, 1400);
        await tester.pumpWidget(
          app(
            Scaffold(
              body: ProductGrid(
                products: store.products,
                padding: const EdgeInsets.all(AppSpacing.page),
              ),
            ),
          ),
        );

        final firstRowY = tester.getTopLeft(find.byType(ProductCard).first).dy;
        final inFirstRow = tester
            .widgetList<ProductCard>(find.byType(ProductCard))
            .toList()
            .asMap()
            .keys
            .where(
              (i) =>
                  tester.getTopLeft(find.byType(ProductCard).at(i)).dy ==
                  firstRowY,
            )
            .length;
        expect(inFirstRow, productGridColumns(width));
      });
    }

    testWidgets('layar kecil 320x568 dengan teks dibesarkan tetap aman', (
      tester,
    ) async {
      size(tester, 320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app(const HomePage()));
      await tester.pumpAndSettle();

      expect(find.text('Kategori'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('shimmer', () {
    setUp(() => UiConfig.simulateLoading = true);
    tearDown(() => UiConfig.simulateLoading = false);

    testWidgets('beranda menampilkan kerangka dulu, lalu produk', (
      tester,
    ) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));

      expect(find.byType(ProductCardSkeleton), findsWidgets);
      expect(find.byType(ProductCard), findsNothing);

      await tester.pump(
        UiConfig.loadingDuration + const Duration(milliseconds: 50),
      );

      expect(find.byType(ProductCardSkeleton), findsNothing);
      expect(find.byType(ProductCard), findsWidgets);
    });

    testWidgets('kilau bergerak (animasi berjalan)', (tester) async {
      size(tester, 400, 600);
      await tester.pumpWidget(
        app(const Scaffold(body: Shimmer(child: ShimmerBox(height: 40)))),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ShaderMask), findsWidgets);
    });
  });

  group('halaman detail', () {
    Future<void> pumpDetail(WidgetTester tester, Product p) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(ProductDetailPage(product: p)));
    }

    testWidgets('chip kompatibilitas dari tipe motor', (tester) async {
      final p = store.products[0];
      await pumpDetail(tester, p);

      expect(find.text('Cocok untuk motor'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Honda Beat'), findsOneWidget);
    });

    test('compatibleBikes memecah beberapa motor', () {
      final p = Product(
        id: 99,
        name: 'X',
        category: 'Mesin',
        type: 'Honda Beat, Vario / Scoopy',
        price: 1000,
        stock: 1,
        icon: Icons.build_rounded,
        description: '',
      );

      expect(compatibleBikes(p), ['Honda Beat', 'Vario', 'Scoopy']);
    });

    testWidgets('pemilih jumlah: - 1 + dengan batas stok', (tester) async {
      final p = store.products[0];
      p.stock = 3;
      await pumpDetail(tester, p);
      String qty() =>
          tester.widget<Text>(find.byKey(const ValueKey('qty-value'))).data!;

      expect(qty(), '1');
      await tester.tap(find.byTooltip('Tambah jumlah'));
      await tester.pump();
      await tester.tap(find.byTooltip('Tambah jumlah'));
      await tester.pump();
      expect(qty(), '3');

      // Sudah di batas stok: tombol + nonaktif.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_rounded),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Kurangi jumlah'));
      await tester.pump();
      expect(qty(), '2');
    });

    testWidgets('tombol bawah menambah sebanyak jumlah terpilih', (
      tester,
    ) async {
      final p = store.products[0];
      await pumpDetail(tester, p);

      await tester.tap(find.byTooltip('Tambah jumlah'));
      await tester.pump();
      await tester.tap(find.text('Tambah ke Keranjang'));
      await tester.pump();

      expect(store.qtyInCart(p), 2);
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('qty-value'))).data,
        '1',
        reason: 'jumlah kembali ke 1 setelah ditambahkan',
      );
    });

    testWidgets('tombol bawah menempel dan tidak ikut tergulir', (
      tester,
    ) async {
      final p = store.products[0];
      await pumpDetail(tester, p);
      final before = tester.getTopLeft(find.text('Tambah ke Keranjang')).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(tester.getTopLeft(find.text('Tambah ke Keranjang')).dy, before);
    });

    testWidgets('stok habis: tombol nonaktif', (tester) async {
      final p = store.products[0];
      p.stock = 0;
      await pumpDetail(tester, p);

      expect(find.text('Stok Habis'), findsWidgets);
      expect(find.text('Tambah ke Keranjang'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.add_rounded),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('semua unit sudah di keranjang: tombol maksimum', (
      tester,
    ) async {
      final p = store.products[0];
      p.stock = 2;
      store.addToCart(p);
      store.addToCart(p);
      await pumpDetail(tester, p);

      expect(find.text('Sudah Maksimum di Keranjang'), findsOneWidget);
    });

    testWidgets('Hero menghubungkan gambar kartu dan detail', (tester) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const HomePage()));
      final p = tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .first
          .product;

      await tester.tap(find.text(p.name).first);
      await tester.pump(const Duration(milliseconds: 100));

      // Selama transisi, tag Hero yang sama ada di kedua halaman.
      expect(
        find.byWidgetPredicate((w) => w is Hero && w.tag == productHeroTag(p)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailPage), findsOneWidget);
    });
  });
}
