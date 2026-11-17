import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/categories.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/models/review.dart';
import 'package:motopart/pages/admin/admin_categories_page.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_product_form_page.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_settings_page.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/admin/sales_chart.dart';
import 'package:motopart/widgets/product_picture.dart';
import 'package:motopart/widgets/shimmer.dart';
import 'package:motopart/widgets/motopart_wordmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

void size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget home, {ThemeMode mode = ThemeMode.light, double scale = 1}) =>
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

void loginAdmin() {
  auth.logout();
  final error = auth.login(
    email: AuthStore.adminEmail,
    password: AuthStore.adminInitialPassword,
    role: AccountRole.admin,
  );
  expect(error, isNull);
}

OrderItem orderAt(
  String code,
  DateTime at, {
  String status = 'Diproses',
  int total = 50000,
}) => OrderItem(
  code: code,
  customer: 'Siti',
  total: total,
  status: status,
  createdAt: at,
  lines: const [
    OrderLine(productId: 1, name: 'Kampas Rem Depan', qty: 1, price: 40000),
  ],
);

void main() {
  final now = DateTime(2026, 11, 17, 13, 0); // Selasa siang

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final fresh = Store();
    store.products
      ..clear()
      ..addAll(fresh.products);
    store.orders
      ..clear()
      ..addAll(fresh.orders);
    store.categories
      ..clear()
      ..addAll(Store.defaultCategories());
    store.reviews.clear();
    loginAdmin();
  });

  tearDown(() {
    auth.logout();
    store.categories
      ..clear()
      ..addAll(Store.defaultCategories());
  });

  group('format', () {
    test('tanggal lengkap berbahasa Indonesia', () {
      expect(formatTanggalLengkap(now), 'Selasa, 17 November 2026');
      expect(
        formatTanggalLengkap(DateTime(2026, 1, 4)),
        'Minggu, 4 Januari 2026',
      );
    });

    test('salam menurut jam', () {
      expect(salamWaktu(DateTime(2026, 1, 1, 8)), 'Selamat pagi');
      expect(salamWaktu(DateTime(2026, 1, 1, 13)), 'Selamat siang');
      expect(salamWaktu(DateTime(2026, 1, 1, 16)), 'Selamat sore');
      expect(salamWaktu(DateTime(2026, 1, 1, 20)), 'Selamat malam');
      expect(salamWaktu(DateTime(2026, 1, 1, 2)), 'Selamat malam');
    });
  });

  group('kerangka admin', () {
    testWidgets('HP: bilah navigasi bawah dengan lima menu', (tester) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      for (final label in [
        'Dashboard',
        'Produk',
        'Pesanan',
        'Kategori',
        'Pengaturan',
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('layar lebar (> 900): sidebar dengan nama admin', (
      tester,
    ) async {
      size(tester, 1000, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Admin MotoPart'), findsOneWidget);
      // Belum cukup lebar untuk logo tulisan lengkap.
      expect(find.byType(MotoPartWordmark), findsNothing);
    });

    testWidgets('layar sangat lebar: sidebar diperluas dengan wordmark', (
      tester,
    ) async {
      size(tester, 1400, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.byType(MotoPartWordmark), findsOneWidget);
    });

    testWidgets('tepat 900 masih memakai bilah bawah', (tester) async {
      size(tester, 900, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('berpindah menu menampilkan halamannya', (tester) async {
      size(tester, 400, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();

      Future<void> open(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open('Produk');
      expect(find.text('Kelola Produk'), findsOneWidget);
      await open('Pesanan');
      expect(find.text('Kelola Pesanan'), findsOneWidget);
      await open('Kategori');
      expect(find.text('Kelola Kategori'), findsOneWidget);
      await open('Pengaturan');
      expect(find.text('Keluar'), findsOneWidget);
    });

    testWidgets('tanpa login admin: diarahkan ke halaman login', (
      tester,
    ) async {
      auth.logout();
      size(tester, 400, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('pembeli biasa pun tidak bisa membuka isi admin', (
      tester,
    ) async {
      auth.logout();
      auth.register(
        name: 'Siti',
        email: 'siti@e.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti@e.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
      size(tester, 400, 800);
      await tester.pumpWidget(app(const AdminShell()));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      auth.logout();
    });
  });

  group('dasbor', () {
    Future<void> open(WidgetTester tester, {double w = 400}) async {
      size(tester, w, 3200);
      await tester.pumpWidget(app(AdminDashboardPage(now: now)));
      await tester.pumpAndSettle();
    }

    testWidgets('sapaan menurut jam dan tanggal hari ini', (tester) async {
      await open(tester);
      expect(find.text('Selamat siang, Admin'), findsOneWidget);
      expect(find.text('Selasa, 17 November 2026'), findsOneWidget);
    });

    testWidgets('empat kartu statistik dengan angka nyata', (tester) async {
      store.orders
        ..clear()
        ..addAll([
          orderAt('A', now, total: 100000),
          orderAt('B', now, status: 'Dibatalkan', total: 999000),
          orderAt('C', now.subtract(const Duration(days: 2)), total: 50000),
        ]);
      await open(tester);

      expect(find.text('Total Produk'), findsOneWidget);
      expect(find.text('Pesanan Hari Ini'), findsOneWidget);
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Stok Menipis'), findsWidgets); // kartu + judul daftar
      expect(find.text('12'), findsOneWidget); // total produk
      expect(find.text('2'), findsWidgets); // pesanan hari ini (A dan B)
      expect(find.text(formatRupiah(150000)), findsOneWidget);
    });

    testWidgets('stok menipis: di bawah 5, yang paling sedikit di depan', (
      tester,
    ) async {
      store.products[0].stock = 5; // batas: tidak termasuk
      store.products[1].stock = 0;
      store.products[2].stock = 3;
      await open(tester);

      expect(Store.lowStockThreshold, 5);
      final names = store.lowStockProducts.map((p) => p.name).toList();
      expect(names.first, store.products[1].name); // stok 0
      expect(names, isNot(contains(store.products[0].name)));
      expect(find.text('Habis'), findsOneWidget);
      expect(find.text('Sisa 3'), findsOneWidget);
    });

    testWidgets('ketuk produk stok menipis membuka form edit', (tester) async {
      store.products[2].stock = 2;
      await open(tester);

      await tester.tap(find.text(store.products[2].name).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Produk'), findsOneWidget);
    });

    testWidgets('stok aman: keterangan ramah', (tester) async {
      for (final p in store.products) {
        p.stock = 50;
      }
      await open(tester);
      expect(find.textContaining('Semua stok aman'), findsOneWidget);
    });

    testWidgets('pesanan terbaru maksimal lima', (tester) async {
      store.orders
        ..clear()
        ..addAll([
          for (var i = 0; i < 8; i++)
            orderAt('MP-$i', now.subtract(Duration(hours: i))),
        ]);
      await open(tester);

      for (var i = 0; i < 5; i++) {
        expect(find.text('MP-$i'), findsOneWidget);
      }
      expect(find.text('MP-5'), findsNothing);
      expect(dashboardRecentOrders, 5);
    });

    testWidgets('grafik penjualan tampil bila ada penjualan 7 hari', (
      tester,
    ) async {
      store.orders
        ..clear()
        ..add(orderAt('MP-1', now.subtract(const Duration(days: 1))));
      await open(tester);
      expect(find.byType(SalesChart), findsOneWidget);
    });

    testWidgets('tanpa penjualan: keterangan, bukan grafik kosong', (
      tester,
    ) async {
      store.orders.clear();
      await open(tester);
      expect(find.byType(SalesChart), findsNothing);
      expect(
        find.text('Belum ada penjualan dalam 7 hari terakhir.'),
        findsOneWidget,
      );
      expect(find.text('Belum ada pesanan.'), findsOneWidget);
    });

    testWidgets('shimmer tampil sesaat saat dimuat', (tester) async {
      final before = UiConfig.simulateLoading;
      UiConfig.simulateLoading = true;
      addTearDown(() => UiConfig.simulateLoading = before);
      size(tester, 400, 3000);

      await tester.pumpWidget(app(AdminDashboardPage(now: now)));
      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.text('Total Produk'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(Shimmer), findsNothing);
      expect(find.text('Total Produk'), findsOneWidget);
    });

    testWidgets('layar lebar: empat kolom tanpa overflow', (tester) async {
      await open(tester, w: 1000);
      expect(statColumns(1000), 4);
      expect(tester.takeException(), isNull);
    });
  });

  group('produk', () {
    Future<void> open(WidgetTester tester) async {
      size(tester, 400, 2400);
      await tester.pumpWidget(app(const AdminProductsPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('tombol Tambah Produk mengambang dan membuka form', (
      tester,
    ) async {
      await open(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.text('Tambah Produk'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminProductFormPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Nama Produk'), findsOneWidget);
    });

    testWidgets('filter kategori menyaring daftar', (tester) async {
      await open(tester);
      final all = store.products.length;
      expect(find.text('$all produk'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Oli'));
      await tester.pumpAndSettle();
      final oli = store.products.where((p) => p.category == 'Oli').length;
      expect(find.text('$oli produk'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await tester.pumpAndSettle();
      expect(find.text('$all produk'), findsOneWidget);
    });

    testWidgets('filter tanpa hasil: keterangan dan Reset Filter', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Transmisi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);

      await tester.tap(find.text('Reset Filter'));
      await tester.pumpAndSettle();
      expect(find.text('${store.products.length} produk'), findsOneWidget);
    });

    testWidgets('stok bisa diatur cepat dengan tombol - dan +', (tester) async {
      await open(tester);
      final product = store.products.first;
      final stock = product.stock;

      await tester.tap(find.byTooltip('Tambah stok').first);
      await tester.pumpAndSettle();
      expect(product.stock, stock + 1);

      await tester.tap(find.byTooltip('Kurangi stok').first);
      await tester.tap(find.byTooltip('Kurangi stok').first);
      await tester.pumpAndSettle();
      expect(product.stock, stock - 1);
    });

    testWidgets('stok 0: tombol kurangi nonaktif (tidak jadi negatif)', (
      tester,
    ) async {
      store.products.first.stock = 0;
      await open(tester);
      final button = tester.widget<IconButton>(
        find
            .widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded)
            .first,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('daftar kosong: ajakan menambah produk pertama', (
      tester,
    ) async {
      store.products.clear();
      await open(tester);
      expect(find.text('Belum ada produk.'), findsOneWidget);
      expect(find.text('Tambah Produk Pertama'), findsOneWidget);
    });

    testWidgets('form: chip motor mengisi isian Tipe Motor', (tester) async {
      await open(tester);
      await tester.tap(find.text('Tambah Produk'));
      await tester.pumpAndSettle();

      TextField typeField() => tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Tipe Motor',
        ),
      );
      expect(typeField().controller!.text, 'Universal');

      await tester.tap(find.widgetWithText(FilterChip, 'Honda Beat'));
      await tester.pumpAndSettle();
      expect(typeField().controller!.text, 'Honda Beat');

      await tester.tap(find.widgetWithText(FilterChip, 'Yamaha Mio'));
      await tester.pumpAndSettle();
      expect(typeField().controller!.text, 'Honda Beat, Yamaha Mio');

      await tester.tap(find.widgetWithText(FilterChip, 'Honda Beat'));
      await tester.pumpAndSettle();
      expect(typeField().controller!.text, 'Yamaha Mio');

      await tester.tap(find.widgetWithText(FilterChip, 'Yamaha Mio'));
      await tester.pumpAndSettle();
      expect(typeField().controller!.text, 'Universal'); // tak pernah kosong

      // Universal menggantikan pilihan lain.
      await tester.tap(find.widgetWithText(FilterChip, 'Honda Beat'));
      await tester.tap(find.widgetWithText(FilterChip, 'Universal'));
      await tester.pumpAndSettle();
      expect(typeField().controller!.text, 'Universal');
    });

    testWidgets('form edit: chip mengikuti tipe yang sudah ada', (
      tester,
    ) async {
      store.products.first.type = 'Honda Beat, Honda Vario';
      await open(tester);
      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();

      FilterChip chip(String label) =>
          tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
      expect(chip('Honda Beat').selected, isTrue);
      expect(chip('Honda Vario').selected, isTrue);
      expect(chip('Yamaha Mio').selected, isFalse);
    });

    testWidgets('kategori di dropdown form mengikuti daftar kategori', (
      tester,
    ) async {
      store.addCategory('Aki', 'electric_bolt');
      await open(tester);
      await tester.tap(find.text('Tambah Produk'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Aki'), findsWidgets);
    });

    testWidgets('layar 320, teks besar: tanpa overflow', (tester) async {
      size(tester, 320, 568);
      await tester.pumpWidget(app(const AdminProductsPage(), scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('form produk (halaman)', () {
    Future<void> openForm(WidgetTester tester, {Product? product}) async {
      size(tester, 400, 1800);
      await tester.pumpWidget(app(AdminProductFormPage(product: product)));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );

    ProductPicture preview(WidgetTester tester) => tester
        .widget<ProductPicture>(find.byKey(const ValueKey('photo-preview')));

    testWidgets('tambah: simpan membuat produk dan menutup halaman', (
      tester,
    ) async {
      size(tester, 400, 1800);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    const AdminProductsPage().productDialog(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Nama Produk'), 'Rantai Motor');
      await tester.enterText(field('Harga'), '95000');
      await tester.enterText(field('Stok'), '7');
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminProductFormPage), findsNothing);
      expect(store.products.last.name, 'Rantai Motor');
      expect(store.products.last.price, 95000);
    });

    testWidgets('validasi: nama wajib diisi', (tester) async {
      await openForm(tester);
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama produk wajib diisi.'), findsOneWidget);
      expect(find.byType(AdminProductFormPage), findsOneWidget);
    });

    testWidgets('edit: Batal tidak mengubah produk', (tester) async {
      final product = store.products.first;
      final name = product.name;
      await openForm(tester, product: product);

      expect(find.text('Edit Produk'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
      await tester.enterText(field('Nama Produk'), 'Nama Lain');
      await tester.ensureVisible(find.text('Batal'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(product.name, name);
    });

    testWidgets('URL gambar: pratinjau dan tersimpan sebagai foto produk', (
      tester,
    ) async {
      final product = store.products.first;
      await openForm(tester, product: product);

      await tester.enterText(
        field('URL Gambar (opsional)'),
        'https://contoh.com/foto.jpg',
      );
      await tester.pump();
      expect(preview(tester).imagePath, 'https://contoh.com/foto.jpg');
      expect(find.text('Hapus Foto'), findsOneWidget);

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(product.imagePath, 'https://contoh.com/foto.jpg');
    });

    testWidgets('URL tidak valid: pesan galat dan tidak bisa disimpan', (
      tester,
    ) async {
      final product = store.products.first;
      await openForm(tester, product: product);

      await tester.enterText(field('URL Gambar (opsional)'), 'foto.jpg');
      await tester.pump();
      expect(
        find.text('Alamat gambar harus diawali http:// atau https://'),
        findsWidgets,
      );
      expect(preview(tester).imagePath, isNull);

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(product.imagePath, isNull);
      expect(find.byType(AdminProductFormPage), findsOneWidget);
    });

    testWidgets('produk berfoto URL: kolom terisi; Hapus Foto mengosongkan', (
      tester,
    ) async {
      final product = store.products.first
        ..imagePath = 'https://contoh.com/a.png';
      await openForm(tester, product: product);

      expect(
        tester
            .widget<TextField>(field('URL Gambar (opsional)'))
            .controller!
            .text,
        'https://contoh.com/a.png',
      );
      await tester.tap(find.text('Hapus Foto'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(field('URL Gambar (opsional)'))
            .controller!
            .text,
        isEmpty,
      );
      expect(preview(tester).imagePath, isNull);
    });

    testWidgets('layar 320, teks besar: tanpa overflow', (tester) async {
      size(tester, 320, 600);
      await tester.pumpWidget(app(const AdminProductFormPage(), scale: 1.4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('layar lebar: formulir dibatasi lebarnya', (tester) async {
      size(tester, 1400, 900);
      await tester.pumpWidget(app(const AdminProductFormPage()));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(640),
      );
    });
  });

  group('ProductPicture dan URL', () {
    test('mengenali alamat web', () {
      expect(ProductPicture.isNetworkUrl('https://a.com/x.png'), isTrue);
      expect(ProductPicture.isNetworkUrl('http://a.com/x.png'), isTrue);
      expect(ProductPicture.isNetworkUrl('  https://a.com/x.png  '), isTrue);
      expect(ProductPicture.isNetworkUrl('ftp://a.com/x.png'), isFalse);
      expect(ProductPicture.isNetworkUrl('https://'), isFalse);
      expect(ProductPicture.isNetworkUrl('foto.png'), isFalse);
      expect(ProductPicture.isNetworkUrl(null), isFalse);
      expect(ProductPicture.hasPhoto('https://a.com/x.png'), isTrue);
    });

    testWidgets('gambar web yang gagal dimuat kembali ke ikon', (tester) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: ProductPicture(
              imagePath: 'https://tidak-ada.example/x.png',
              icon: Icons.build_rounded,
              width: 80,
              height: 80,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.build_rounded), findsOneWidget);
    });
  });

  group('kategori (data)', () {
    test('tambah: pangkas, tolak kosong/ganda/terlalu panjang', () {
      expect(store.addCategory('  Aki  ', 'electric_bolt'), isNull);
      expect(store.categoryNames.last, 'Aki');
      expect(store.categories.last.iconKey, 'electric_bolt');
      expect(store.addCategory('', 'build'), 'Nama kategori wajib diisi.');
      expect(store.addCategory('   ', 'build'), 'Nama kategori wajib diisi.');
      expect(store.addCategory('aki', 'build'), 'Kategori "aki" sudah ada.');
      expect(
        store.addCategory('x' * 31, 'build'),
        'Nama kategori maksimal 30 karakter.',
      );
      expect(store.categories.length, productCategories.length + 1);
    });

    test('ikon tak dikenal menjadi ikon bawaan', () {
      store.addCategory('Aki', 'tidak-ada');
      expect(store.categories.last.iconKey, 'build');
    });

    test('ubah nama memindahkan produknya; boleh pakai namanya sendiri', () {
      final rem = store.categories.firstWhere((c) => c.name == 'Rem');
      final count = store.productCountIn('Rem');
      expect(count, greaterThan(0));

      expect(store.updateCategory(rem, name: 'Rem', iconKey: 'speed'), isNull);
      expect(
        store.categories.firstWhere((c) => c.name == 'Rem').iconKey,
        'speed',
      );

      final again = store.categories.firstWhere((c) => c.name == 'Rem');
      expect(
        store.updateCategory(again, name: 'Pengereman', iconKey: 'speed'),
        isNull,
      );
      expect(store.productCountIn('Rem'), 0);
      expect(store.productCountIn('Pengereman'), count);
      expect(store.categoryNames, contains('Pengereman'));
    });

    test('ubah ke nama kategori lain ditolak', () {
      final rem = store.categories.firstWhere((c) => c.name == 'Rem');
      expect(
        store.updateCategory(rem, name: 'oli', iconKey: 'build'),
        'Kategori "oli" sudah ada.',
      );
    });

    test('hapus: ditolak bila masih dipakai produk', () {
      final oli = store.categories.firstWhere((c) => c.name == 'Oli');
      final used = store.productCountIn('Oli');
      expect(
        store.deleteCategory(oli),
        'Kategori masih dipakai $used produk. Pindahkan atau hapus '
        'produknya dulu.',
      );
      expect(store.categoryNames, contains('Oli'));
    });

    test('hapus: kategori kosong terhapus', () {
      store.addCategory('Aki', 'build');
      final aki = store.categories.last;
      expect(store.deleteCategory(aki), isNull);
      expect(store.categoryNames, isNot(contains('Aki')));
      expect(store.deleteCategory(aki), 'Kategori tidak ditemukan.');
    });

    test('reset data contoh mengembalikan kategori bawaan', () {
      store.addCategory('Aki', 'build');
      store.resetSampleData();
      expect(store.categoryNames, productCategoryNames);
    });

    test('kategori ikut tersimpan dan dipulihkan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = Store();
      await s.attach(prefs);
      s.addCategory('Aki', 'electric_bolt');
      await Future<void>.delayed(Duration.zero);

      final restored = Store();
      await restored.attach(prefs);
      expect(restored.categoryNames, contains('Aki'));
      expect(
        restored.categories.firstWhere((c) => c.name == 'Aki').iconKey,
        'electric_bolt',
      );
    });

    test('JSON kategori: kunci ikon dikenal dan bulat', () {
      for (final c in productCategories) {
        final back = ProductCategory.fromJson(c.toJson());
        expect(back.name, c.name);
        expect(back.icon, c.icon);
      }
      expect(
        ProductCategory.fromJson({'name': 'X', 'icon': 'aneh'}).iconKey,
        'build',
      );
    });
  });

  group('halaman kategori', () {
    Future<void> open(WidgetTester tester) async {
      size(tester, 400, 1600);
      await tester.pumpWidget(app(const AdminCategoriesPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('daftar kategori dengan jumlah produk', (tester) async {
      await open(tester);
      expect(find.text('${store.categories.length} kategori'), findsOneWidget);
      for (final c in store.categories) {
        expect(find.text(c.name), findsOneWidget);
      }
      final oli = store.productCountIn('Oli');
      expect(find.text('$oli produk'), findsWidgets);
    });

    testWidgets('tambah kategori lewat dialog', (tester) async {
      await open(tester);
      await tester.tap(find.text('Tambah Kategori'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Aki dan Kabel');
      await tester.tap(
        find.byKey(const ValueKey('category-icon-electric_bolt')),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();

      final added = store.categories.last;
      expect(added.name, 'Aki dan Kabel');
      expect(added.iconKey, 'electric_bolt');
      expect(find.text('Aki dan Kabel'), findsOneWidget);
    });

    testWidgets('nama kosong atau ganda: pesan galat di dialog', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Tambah Kategori'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();
      expect(find.text('Nama kategori wajib diisi.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'mesin');
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah'));
      await tester.pumpAndSettle();
      expect(find.text('Kategori "mesin" sudah ada.'), findsOneWidget);
      expect(store.categories.length, productCategories.length);
    });

    testWidgets('ubah nama dan ikon; produk ikut berpindah', (tester) async {
      await open(tester);
      final count = store.productCountIn('Rem');
      await tester.tap(find.byTooltip('Ubah Rem'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Pengereman');
      await tester.tap(find.byKey(const ValueKey('category-icon-speed')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.text('Rem'), findsNothing);
      expect(find.text('Pengereman'), findsOneWidget);
      expect(store.productCountIn('Pengereman'), count);
    });

    testWidgets('hapus kategori terpakai: pesan, tanpa dialog', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Hapus Oli'));
      await tester.pumpAndSettle();

      expect(find.textContaining('masih dipakai'), findsOneWidget);
      expect(find.text('Hapus Kategori'), findsNothing);
      expect(store.categoryNames, contains('Oli'));
    });

    testWidgets('hapus kategori kosong lalu Urungkan', (tester) async {
      store.addCategory('Aki', 'build');
      await open(tester);

      await tester.tap(find.byTooltip('Hapus Aki'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Kategori'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(store.categoryNames, isNot(contains('Aki')));
      expect(find.text('Kategori dihapus'), findsOneWidget);

      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(store.categoryNames, contains('Aki'));
    });

    testWidgets('kosong: ilustrasi, teks, dan tombol tambah', (tester) async {
      store.categories.clear();
      await open(tester);
      expect(find.text('Belum ada kategori'), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah Kategori'));
      await tester.pumpAndSettle();
      expect(find.text('Nama Kategori'), findsOneWidget);
    });

    testWidgets('beranda pembeli memakai kategori dari data', (tester) async {
      store.addCategory('Aki', 'electric_bolt');
      expect(store.categoryNames, contains('Aki'));
      expect(store.categories.map((c) => c.icon), isNotEmpty);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'layar 320, teks 1.4x, ${dark ? 'gelap' : 'terang'}: tanpa overflow',
        (tester) async {
          size(tester, 320, 600);
          await tester.pumpWidget(
            app(
              const AdminCategoriesPage(),
              mode: dark ? ThemeMode.dark : ThemeMode.light,
              scale: 1.4,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Tambah Kategori'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('urutan kategori', () {
    test('moveCategory memakai posisi akhir dan menjaga isi', () {
      final names = store.categoryNames;
      store.moveCategory(0, 2);
      expect(store.categoryNames, [
        names[1],
        names[2],
        names[0],
        ...names.skip(3),
      ]);
      store.moveCategory(2, 0);
      expect(store.categoryNames, names);
    });

    test('indeks di luar batas diabaikan atau dipangkas', () {
      final names = store.categoryNames;
      store.moveCategory(-1, 0);
      store.moveCategory(99, 0);
      store.moveCategory(2, 2);
      expect(store.categoryNames, names);
      store.moveCategory(0, 99);
      expect(store.categoryNames.last, names.first);
    });

    testWidgets('seret pegangan memindahkan kategori', (tester) async {
      size(tester, 400, 1600);
      await tester.pumpWidget(app(const AdminCategoriesPage()));
      await tester.pumpAndSettle();
      final first = store.categoryNames.first;
      expect(find.text('Seret untuk mengurutkan'), findsOneWidget);

      final handle = find.byTooltip('Seret untuk mengurutkan $first');
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(store.categoryNames.first, isNot(first));
      expect(store.categoryNames.indexOf(first), greaterThan(0));
    });
  });

  group('pengaturan admin', () {
    Future<void> open(WidgetTester tester, {double scale = 1}) async {
      size(tester, 400, 1200);
      await tester.pumpWidget(app(const AdminSettingsPage(), scale: scale));
      await tester.pumpAndSettle();
    }

    testWidgets('menampilkan akun dan semua menu', (tester) async {
      await open(tester);
      expect(find.text('Admin MotoPart'), findsOneWidget);
      expect(find.text(AuthStore.adminEmail), findsOneWidget);
      for (final label in [
        'Pengaturan Tampilan',
        'Laporan Penjualan',
        'Pengguna',
        'Ganti Password',
        'Reset Data Contoh',
        'Keluar',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('keluar meminta konfirmasi; Batal tidak keluar', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.text('Keluar?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(auth.isLoggedIn, isTrue);
    });

    testWidgets('konfirmasi keluar: akun keluar dan masuk ke login', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(auth.isLoggedIn, isFalse);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('layar 320, teks besar: tanpa overflow', (tester) async {
      size(tester, 320, 700);
      await tester.pumpWidget(app(const AdminSettingsPage(), scale: 1.4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('produk dihapus lalu dikembalikan (data)', () {
    test('kembali ke posisi semula dengan ulasannya', () {
      final product = store.products[3];
      final index = 3;
      final before = store.products.length;
      store.reviews.add(
        Review(
          productId: product.id,
          accountId: 'u1',
          authorName: 'Siti',
          rating: 5,
          comment: 'Bagus',
          createdAt: DateTime(2026, 11, 1),
        ),
      );
      final removal = store.deleteProduct(product);
      expect(store.products.length, before - 1);
      expect(store.reviews.where((r) => r.productId == product.id), isEmpty);

      store.restoreProduct(removal);
      expect(store.products.length, before);
      expect(store.products[index].id, product.id);
      expect(
        store.reviews.where((r) => r.productId == product.id),
        hasLength(1),
      );

      store.restoreProduct(removal); // dua kali tidak menggandakan
      expect(store.products.length, before);
    });
  });
}
