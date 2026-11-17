import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/product_image_storage.dart';
import 'package:motopart/core/safe_save.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/admin/admin_product_form_page.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/pages/user/about_page.dart';
import 'package:motopart/pages/user/address_form_page.dart';
import 'package:motopart/pages/user/addresses_page.dart';
import 'package:motopart/pages/user/cart_page.dart';
import 'package:motopart/pages/user/catalog_page.dart';
import 'package:motopart/pages/user/category_page.dart';
import 'package:motopart/pages/user/checkout_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/payment_methods_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/product_detail_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/pages/user/wishlist_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/selectable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final pngDataUrl = ProductImageStorageHelper.dataUrl(_png);

/// Jalan pintas agar tes memakai fungsi statis penyimpanan foto.
class ProductImageStorageHelper {
  static String dataUrl(List<int> bytes) =>
      DeviceProductImageStorage.dataUrlFromBytes(bytes, 'image/png');
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

/// Penyimpanan lokal yang selalu gagal menulis (mirip penyimpanan browser
/// yang penuh).
class FailingPrefs implements SharedPreferences {
  int writes = 0;

  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async {
    writes++;
    throw Exception('QuotaExceededError');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Penyimpanan foto yang selalu menolak karena foto terlalu besar.
class RejectingStorage implements ProductImageStorage {
  @override
  Future<String?> pickFromGallery() async =>
      throw const ProductImageException('Foto terlalu besar untuk versi web.');

  @override
  Future<void> delete(String? path) async {}
}

void main() {
  tearDown(() {
    PaymentMethods.onlineOverride = null;
    auth.logout();
    auth.accounts.removeWhere((a) => !a.isAdmin);
    store.setCurrentAccount(Store.guestId);
    store.cart.clear();
  });

  // ------------------------------------------------------- safeSetString
  group('safeSetString', () {
    test('berhasil: mengembalikan true dan menyimpan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await safeSetString(prefs, 'k', 'v'), isTrue);
      expect(prefs.getString('k'), 'v');
    });

    test('penyimpanan penuh: tidak melempar, mengembalikan false', () async {
      final prefs = FailingPrefs();

      expect(await safeSetString(prefs, 'k', 'v' * 100), isFalse);
      expect(prefs.writes, 1);
    });

    test('Store tetap bekerja saat penyimpanan gagal', () async {
      final prefs = FailingPrefs();
      final s = Store();
      await s.attach(prefs);

      s.setCurrentAccount('A');
      s.addToCart(s.products[0]);
      s.toggleWishlist(s.products[1]);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.writes, greaterThan(0));
      expect(s.qtyInCart(s.products[0]), 1);
      expect(s.isWishlisted(s.products[1]), isTrue);
    });

    test('AuthStore tetap bekerja saat penyimpanan gagal', () async {
      final prefs = FailingPrefs();
      final a = AuthStore(store: Store());
      await a.attach(prefs);

      expect(
        a.register(
          name: 'Siti',
          email: 'siti-web@email.com',
          phone: '081234567890',
          password: 'rahasia1',
        ),
        isNull,
      );
      expect(
        a.login(
          email: 'siti-web@email.com',
          password: 'rahasia1',
          role: AccountRole.user,
        ),
        isNull,
      );
      await Future<void>.delayed(Duration.zero);

      expect(a.isLoggedIn, isTrue);
      expect(prefs.writes, greaterThan(0));
    });
  });

  // ------------------------------------------------- foto sebagai data URL
  group('Foto produk sebagai data URL (web)', () {
    test('dataUrlFromBytes membentuk data URL yang bisa dibaca kembali', () {
      expect(pngDataUrl, startsWith('data:image/png;base64,'));
      expect(ProductPicture.isDataUrl(pngDataUrl), isTrue);
      expect(ProductPicture.bytesOf(pngDataUrl), _png);
    });

    test('isDataUrl menolak yang bukan data URL gambar', () {
      expect(ProductPicture.isDataUrl(null), isFalse);
      expect(ProductPicture.isDataUrl('/data/foto.png'), isFalse);
      expect(ProductPicture.isDataUrl('data:text/plain;base64,AAAA'), isFalse);
      expect(ProductPicture.isDataUrl('data:image/png,tanpa-base64'), isFalse);
    });

    test('data URL rusak: bytesOf null dan hasPhoto false', () {
      const rusak = 'data:image/png;base64,!!!bukan-base64!!!';
      expect(ProductPicture.bytesOf(rusak), isNull);
      expect(ProductPicture.hasPhoto(rusak), isFalse);
    });

    test('hasPhoto: data URL valid true, null/berkas hilang false', () {
      expect(ProductPicture.hasPhoto(pngDataUrl), isTrue);
      expect(ProductPicture.hasPhoto(null), isFalse);
      expect(ProductPicture.hasPhoto('/tidak/ada.png'), isFalse);
    });

    test('hasil dekode disimpan sementara (instance sama)', () {
      final a = ProductPicture.bytesOf(pngDataUrl);
      final b = ProductPicture.bytesOf(pngDataUrl);
      expect(identical(a, b), isTrue);
    });

    test('batas ukuran foto web 350 KB', () {
      expect(DeviceProductImageStorage.maxWebPhotoBytes, 350 * 1024);
    });

    test('ProductImageException menampilkan pesannya', () {
      expect(
        const ProductImageException('Terlalu besar').toString(),
        'Terlalu besar',
      );
    });

    testWidgets('ProductPicture menampilkan foto dari data URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Center(
            child: ProductPicture(
              imagePath: pngDataUrl,
              icon: Icons.build_rounded,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(find.byIcon(Icons.build_rounded), findsNothing);
    });

    testWidgets('data URL rusak: kembali ke ikon, tidak error', (tester) async {
      await tester.pumpWidget(
        app(
          const Center(
            child: ProductPicture(
              imagePath: 'data:image/png;base64,!!!',
              icon: Icons.build_rounded,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.build_rounded), findsOneWidget);
    });

    testWidgets('foto lewat data URL ikut tampil di kartu produk dan detail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final product = store.products[0];
      final old = product.imagePath;
      product.imagePath = pngDataUrl;
      addTearDown(() => product.imagePath = old);

      await tester.pumpWidget(app(ProductDetailPage(product: product)));

      final memory = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is MemoryImage);
      expect(memory, isNotEmpty);
    });

    testWidgets(
      'admin: foto ditolak (terlalu besar) menampilkan pesan, data tetap',
      (tester) async {
        tester.view.physicalSize = const Size(600, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final original = productImageStorage;
        productImageStorage = RejectingStorage();
        addTearDown(() => productImageStorage = original);
        final product = store.products[0];
        final before = product.imagePath;

        await tester.pumpWidget(app(const AdminProductsPage()));
        await tester.tap(find.byTooltip('Edit').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pilih Foto'));
        await tester.pumpAndSettle();

        expect(
          find.text('Foto terlalu besar untuk versi web.'),
          findsOneWidget,
        );
        expect(
          find.byType(AdminProductFormPage),
          findsOneWidget,
        ); // form tetap terbuka
        expect(product.imagePath, before);
      },
    );
  });

  // ------------------------------------------- pembayaran online di web
  group('Pembayaran online tidak tersedia (web tanpa server)', () {
    setUp(() => PaymentMethods.onlineOverride = false);

    test('hanya COD yang ditawarkan dan menjadi pilihan awal', () {
      expect(PaymentMethods.onlineAvailable, isFalse);
      expect(PaymentMethods.available.map((g) => g.name), ['COD']);
      expect(PaymentMethods.defaultChoice.label, 'COD');
    });

    test('pilihan online yang tersimpan diganti COD; COD tetap', () {
      final online = PaymentMethods.decode('E-Wallet|GoPay');
      expect(PaymentMethods.usable(online).label, 'COD');
      expect(PaymentMethods.usable(null).label, 'COD');
      expect(PaymentMethods.usable(PaymentMethods.decode('COD')).label, 'COD');
    });

    test('tersedia: semua metode dan QRIS menjadi awal', () {
      PaymentMethods.onlineOverride = true;
      expect(PaymentMethods.available.length, PaymentMethods.groups.length);
      expect(PaymentMethods.defaultChoice.label, 'QRIS');
      final gopay = PaymentMethods.decode('E-Wallet|GoPay');
      expect(PaymentMethods.usable(gopay), gopay);
    });

    testWidgets('halaman pembayaran: hanya COD dan ada catatannya', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      auth.register(
        name: 'Siti',
        email: 'siti-cod@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti-cod@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      auth.setPreferredPayment('E-Wallet|GoPay'); // favorit lama yang online
      store.addToCart(store.products[1]);

      await tester.pumpWidget(
        app(const PaymentPage(customerName: 'Siti', shippingCost: 0)),
      );

      final cards = tester
          .widgetList<SelectableCard>(find.byType(SelectableCard))
          .toList();
      expect(cards.map((c) => c.title), ['COD']);
      expect(cards.single.selected, isTrue);
      expect(find.textContaining('Di sini hanya COD'), findsOneWidget);
      expect(find.text('QRIS'), findsNothing);

      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();
      expect(store.orders.first.status, 'Diproses');
      expect(store.orders.first.paymentMethod, 'COD');
    });

    testWidgets('halaman metode pembayaran: hanya COD', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      auth.register(
        name: 'Siti',
        email: 'siti-cod2@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti-cod2@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );

      await tester.pumpWidget(app(const PaymentMethodsPage()));

      expect(find.text('COD'), findsOneWidget);
      expect(find.text('Virtual Account'), findsNothing);
      expect(find.text('E-Wallet'), findsNothing);
    });

    testWidgets('tersedia: tanpa catatan "hanya COD"', (tester) async {
      PaymentMethods.onlineOverride = true;
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.addToCart(store.products[1]);

      await tester.pumpWidget(
        app(const PaymentPage(customerName: 'Siti', shippingCost: 0)),
      );

      expect(find.textContaining('Di sini hanya COD'), findsNothing);
      expect(find.text('QRIS'), findsOneWidget);
    });
  });

  // ------------------------------------------------------ layar lebar
  group('Tidak ada overflow di layar lebar (desktop/tablet)', () {
    final pages = <String, Widget Function()>{
      'login': () => const LoginPage(),
      'daftar': () => const RegisterPage(),
      'beranda': () => const HomePage(),
      'cangkang pembeli': () => const UserShell(),
      'katalog': () => const CatalogPage(),
      'katalog + filter motor': () =>
          const CatalogPage(initialMotor: 'Honda Beat'),
      'kategori': () => const CategoryPage(),
      'keranjang': () => const CartPage(),
      'detail produk': () => ProductDetailPage(product: store.products[0]),
      'wishlist': () => const WishlistPage(),
      'checkout': () => const CheckoutPage(),
      'pembayaran': () =>
          const PaymentPage(customerName: 'Siti', shippingCost: 10000),
      'pesanan': () => const OrdersPage(),
      'akun': () => const ProfilePage(),
      'data akun': () => const EditProfilePage(),
      'alamat': () => const AddressesPage(),
      'form alamat': () => const AddressFormPage(),
      'metode pembayaran': () => const PaymentMethodsPage(),
      'tentang': () => const AboutPage(),
      'admin dashboard': () => const AdminDashboardPage(),
      'admin produk': () => const AdminProductsPage(),
      'admin pesanan': () => const AdminOrdersPage(),
      'admin pengguna': () => const AdminUsersPage(),
      'admin laporan': () => AdminReportsPage(now: DateTime(2026, 11, 16)),
    };

    for (final size in const [Size(1280, 800), Size(900, 700)]) {
      for (final entry in pages.entries) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          testWidgets(
            '${entry.key} (${mode.name}) di ${size.width.toInt()}x${size.height.toInt()}',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              auth.register(
                name: 'Siti Aminah',
                email: 'lebar@email.com',
                phone: '081234567890',
                password: 'rahasia1',
              );
              auth.login(
                email: 'lebar@email.com',
                password: 'rahasia1',
                role: AccountRole.user,
              );
              auth.updateProfile(
                name: 'Siti Aminah',
                phone: '081234567890',
                motorName: 'Honda Beat',
                motorType: 'Street',
                motorYear: '2020',
              );
              auth.addAddress(
                label: 'Rumah',
                recipient: 'Siti Aminah',
                phone: '081234567890',
                street: 'Jl. Mawar No. 12',
                city: 'Bandung',
              );
              store.addToCart(store.products[0]);
              store.addToCart(store.products[1]);
              store.checkout(
                customer: 'Siti',
                shippingCost: 10000,
                paymentMethod: 'COD',
              );
              store.addToCart(store.products[2]);

              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: mode,
                  home: entry.value(),
                ),
              );
              await tester.pump(const Duration(seconds: 1));
              await tester.pump(const Duration(seconds: 1));

              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  });
}
