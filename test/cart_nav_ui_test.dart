import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/theme/theme_controller.dart';
import 'package:motopart/widgets/cart_badge_icon.dart';
import 'package:motopart/widgets/product_card.dart';
import 'package:motopart/widgets/product_grid.dart';

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  home: home,
);

void size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.orders
      ..clear()
      ..addAll(fresh.orders);
    auth.logout();
    auth.accounts.removeWhere((a) => !a.isAdmin);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
    store.wishlistIds.clear();
    userTabIndex.value = UserTab.home;
    themeController.setMode(ThemeMode.system);
  });

  group('keranjang', () {
    testWidgets('kosong: ilustrasi, teks ramah, dan tombol Mulai Belanja', (
      tester,
    ) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const CartPage()));

      expect(find.text('Keranjang masih kosong'), findsOneWidget);
      expect(find.text('Mulai Belanja'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    });

    testWidgets('Mulai Belanja berpindah ke tab Beranda', (tester) async {
      size(tester, 400, 800);
      userTabIndex.value = UserTab.cart;
      await tester.pumpWidget(app(const CartPage()));

      await tester.tap(find.text('Mulai Belanja'));
      await tester.pump();

      expect(userTabIndex.value, UserTab.home);
    });

    testWidgets('menampilkan item, harga, dan ringkasan total', (tester) async {
      size(tester, 400, 800);
      store.addToCart(store.products[0]); // Rp 45.000
      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]); // Rp 25.000
      await tester.pumpWidget(app(const CartPage()));

      expect(find.text('Kampas Rem Depan'), findsOneWidget);
      expect(find.text(formatRupiah(45000)), findsOneWidget);
      expect(find.text('Subtotal (3 barang)'), findsOneWidget);
      expect(find.text(formatRupiah(115000)), findsOneWidget);
      expect(find.text('Checkout (3)'), findsOneWidget);
    });

    testWidgets('tombol - dan + mengubah jumlah, - pada 1 menghapus', (
      tester,
    ) async {
      size(tester, 400, 800);
      final p = store.products[0];
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));

      await tester.tap(find.byTooltip('Tambah jumlah ${p.name}'));
      await tester.pump();
      expect(store.qtyInCart(p), 2);

      await tester.tap(find.byTooltip('Kurangi jumlah ${p.name}'));
      await tester.pump();
      await tester.tap(find.byTooltip('Kurangi jumlah ${p.name}'));
      await tester.pump();
      expect(store.cart, isEmpty);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);
    });

    testWidgets('ringkasan total ikut berubah saat jumlah diubah', (
      tester,
    ) async {
      size(tester, 400, 800);
      final p = store.products[0]; // Rp 45.000
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));
      expect(find.text('Subtotal (1 barang)'), findsOneWidget);
      expect(find.text(formatRupiah(45000)), findsWidgets);

      await tester.tap(find.byTooltip('Tambah jumlah ${p.name}'));
      await tester.pump();

      expect(find.text('Subtotal (2 barang)'), findsOneWidget);
      expect(find.text('Checkout (2)'), findsOneWidget);
      expect(find.text(formatRupiah(90000)), findsWidgets);

      // Item baru dari luar halaman (mis. tombol + di kartu) juga tercermin.
      store.addToCart(store.products[1]); // Rp 25.000
      await tester.pump();
      expect(find.text('Subtotal (3 barang)'), findsOneWidget);
      expect(find.text(formatRupiah(115000)), findsWidgets);
    });

    testWidgets('area sentuh tombol jumlah minimal 48x48', (tester) async {
      size(tester, 400, 800);
      final p = store.products[0];
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));

      final box = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(IconButton),
        ),
      );

      expect(box.width, greaterThanOrEqualTo(48));
      expect(box.height, greaterThanOrEqualTo(48));
    });

    testWidgets('geser ke kiri menghapus item, Batal mengembalikan', (
      tester,
    ) async {
      size(tester, 400, 800);
      final p = store.products[0];
      store.addToCart(p);
      store.addToCart(p);
      store.addToCart(store.products[1]);
      await tester.pumpWidget(app(const CartPage()));

      await tester.drag(
        find.byKey(ValueKey('cart-${p.id}')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      expect(store.qtyInCart(p), 0);
      expect(find.text('${p.name} dihapus dari keranjang'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(store.qtyInCart(p), 2, reason: 'jumlah semula dipulihkan');
    });

    testWidgets('tombol hapus juga menghapus', (tester) async {
      size(tester, 400, 800);
      final p = store.products[0];
      store.addToCart(p);
      await tester.pumpWidget(app(const CartPage()));

      await tester.tap(find.byTooltip('Hapus ${p.name}'));
      await tester.pumpAndSettle();

      expect(store.cart, isEmpty);
    });

    testWidgets('layar kecil 320x568: tidak ada overflow', (tester) async {
      size(tester, 320, 568);
      store.addToCart(store.products[0]);
      store.addToCart(store.products[5]);
      await tester.pumpWidget(app(const CartPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('navigasi bawah', () {
    Future<void> pumpShell(WidgetTester tester) async {
      size(tester, 400, 1800);
      await tester.pumpWidget(app(const UserShell()));
    }

    testWidgets('4 tab: Beranda, Kategori, Keranjang, Akun', (tester) async {
      await pumpShell(tester);

      final bar = find.byType(NavigationBar);
      for (final label in ['Beranda', 'Kategori', 'Keranjang', 'Akun']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: bar, matching: find.text('Pesanan')),
        findsNothing,
      );
    });

    testWidgets('badge keranjang menampilkan jumlah item', (tester) async {
      await pumpShell(tester);
      expect(find.byType(Badge), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);

      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]);
      await tester.pumpAndSettle();

      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsWidgets,
      );
    });

    testWidgets('badge beranimasi (membesar) saat item ditambahkan', (
      tester,
    ) async {
      await pumpShell(tester);
      double scale() => tester
          .widget<ScaleTransition>(
            find
                .descendant(
                  of: find.byType(CartBadgeIcon),
                  matching: find.byType(ScaleTransition),
                )
                .last,
          )
          .scale
          .value;
      expect(scale(), 1);

      store.addToCart(store.products[0]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(scale(), greaterThan(1));

      await tester.pumpAndSettle();
      expect(scale(), closeTo(1, 0.001));
    });

    testWidgets('menekan tab Keranjang membuka keranjang', (tester) async {
      await pumpShell(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Keranjang'),
        ),
      );
      await tester.pumpAndSettle();

      expect(userTabIndex.value, UserTab.cart);
      expect(find.text('Keranjang masih kosong'), findsOneWidget);
    });

    testWidgets('SnackBar "Lihat" membawa ke tab Keranjang', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump();
      expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500)); // animasi SnackBar
      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();

      expect(userTabIndex.value, UserTab.cart);
      expect(find.textContaining('Checkout ('), findsOneWidget);
    });
  });

  group('akun', () {
    Future<void> pumpProfile(WidgetTester tester) async {
      size(tester, 400, 1400);
      await tester.pumpWidget(app(const ProfilePage()));
    }

    testWidgets('menu Pesanan Saya membuka riwayat pesanan', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Pesanan Saya'));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
    });

    testWidgets('pilihan tampilan mengubah dan menyimpan mode tema', (
      tester,
    ) async {
      await pumpProfile(tester);
      expect(themeController.value, ThemeMode.system);

      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.dark);

      await tester.tap(find.text('Terang'));
      await tester.pumpAndSettle();
      expect(themeController.value, ThemeMode.light);
    });

    testWidgets('menampilkan nama akun yang login', (tester) async {
      auth.register(
        name: 'Siti Aminah',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      await pumpProfile(tester);

      expect(find.text('Siti Aminah'), findsOneWidget);
      expect(find.text('siti@email.com'), findsOneWidget);
    });
  });

  group('katalog: tarik untuk memuat ulang', () {
    setUp(() => UiConfig.simulateLoading = true);
    tearDown(() => UiConfig.simulateLoading = false);

    testWidgets('menarik ke bawah menampilkan kerangka lalu produk lagi', (
      tester,
    ) async {
      size(tester, 400, 900);
      await tester.pumpWidget(app(const CatalogPage()));
      expect(find.byType(ProductCardSkeleton), findsWidgets);
      await tester.pump(
        UiConfig.loadingDuration + const Duration(milliseconds: 50),
      );
      expect(find.byType(ProductCard), findsWidgets);

      await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      expect(find.byType(ProductCardSkeleton), findsWidgets);

      await tester.pump(
        UiConfig.loadingDuration + const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProductCardSkeleton), findsNothing);
      expect(find.byType(ProductCard), findsWidgets);
    });

    testWidgets('daftar kosong tetap bisa ditarik (tidak error)', (
      tester,
    ) async {
      size(tester, 400, 900);
      await tester.pumpWidget(app(const CatalogPage(selectedCategory: 'Ban')));
      await tester.pump(
        UiConfig.loadingDuration + const Duration(milliseconds: 50),
      );
      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);

      await tester.fling(
        find.text('Tidak ada produk yang cocok.'),
        const Offset(0, 400),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(
        UiConfig.loadingDuration + const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('transisi dan tema', () {
    test('transisi halaman halus (fade forwards) di semua platform', () {
      final builders = AppTheme.dark().pageTransitionsTheme.builders;

      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ]) {
        expect(builders[platform], isA<FadeForwardsPageTransitionsBuilder>());
      }
    });

    testWidgets('halaman utama pembeli aman di mode gelap, HP kecil', (
      tester,
    ) async {
      size(tester, 320, 568);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const UserShell(),
        ),
      );
      for (final tab in [
        UserTab.category,
        UserTab.cart,
        UserTab.account,
        UserTab.home,
      ]) {
        userTabIndex.value = tab;
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet: grid produk 3-4 kolom', (tester) async {
      size(tester, 1000, 1200);
      await tester.pumpWidget(
        app(Scaffold(body: ProductGrid(products: store.products))),
      );

      final firstRowY = tester.getTopLeft(find.byType(ProductCard).first).dy;
      var inRow = 0;
      for (var i = 0; i < store.products.length; i++) {
        if (tester.getTopLeft(find.byType(ProductCard).at(i)).dy == firstRowY) {
          inRow++;
        }
      }
      expect(inRow, 4);
    });
  });
}
