import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/product.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/admin/admin_products_page.dart';
import 'package:motopart/pages/admin/admin_reports_page.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/auth/onboarding_page.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/pages/user/checkout_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/checkout_steps.dart';
import 'package:motopart/widgets/order_timeline.dart';
import 'package:motopart/widgets/selectable_card.dart';
import 'package:motopart/widgets/status_badge.dart';

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

void resetAll() {
  final fresh = Store();
  store.products
    ..clear()
    ..addAll(fresh.products);
  store.orders
    ..clear()
    ..addAll(fresh.orders);
  store.reviews.clear();
  auth.logout();
  auth.accounts.removeWhere((a) => !a.isAdmin);
  store.setCurrentAccount(Store.guestId);
  store.cart.clear();
  store.wishlistIds.clear();
  userTabIndex.value = UserTab.home;
}

void registerAndLogin({String name = 'Siti Aminah', String email = 's@e.com'}) {
  auth.register(
    name: name,
    email: email,
    phone: '081234567890',
    password: 'rahasia1',
  );
  auth.login(email: email, password: 'rahasia1', role: AccountRole.user);
}

void main() {
  setUp(resetAll);

  group('agregat penjualan di Store', () {
    late Store s;
    setUp(() => s = Store());

    void buy(Product product, int qty, {DateTime? now, String? cancelTo}) {
      for (var i = 0; i < qty; i++) {
        s.addToCart(product);
      }
      s.checkout(customer: 'A', shippingCost: 0, now: now);
      if (cancelTo != null) s.updateOrderStatus(s.orders.first, cancelTo);
    }

    test('pesanan contoh dihitung, pesanan batal tidak', () {
      // Contoh: Rp 80.000 (Selesai) + Rp 125.000 (Dikirim).
      expect(s.totalSales, 205000);

      buy(s.products[0], 2, cancelTo: 'Dibatalkan'); // 2 x 45.000, batal
      expect(s.totalSales, 205000);

      buy(s.products[1], 1); // 25.000
      expect(s.totalSales, 230000);
      expect(s.salesOrders.length, 3);
    });

    test('totalUnitsSold menjumlahkan unit dari pesanan aktif', () {
      // Pesanan contoh: 2 + 3 unit.
      expect(s.totalUnitsSold, 5);

      buy(s.products[0], 3);
      buy(s.products[1], 2, cancelTo: 'Dibatalkan');

      expect(s.totalUnitsSold, 8);
    });

    test('salesLast7Days: 7 hari berurutan, total per hari', () {
      final now = DateTime(2026, 11, 16, 15);
      buy(s.products[0], 1, now: DateTime(2026, 11, 16, 9)); // hari ini 45.000
      buy(
        s.products[1],
        2,
        now: DateTime(2026, 11, 14, 10),
      ); // 2 hari lalu 50.000
      buy(
        s.products[2],
        1,
        now: DateTime(2026, 11, 14, 22),
      ); // 2 hari lalu 32.000
      buy(s.products[3], 1, now: DateTime(2026, 11, 1)); // di luar 7 hari

      final days = s.salesLast7Days(now);

      expect(days.length, 7);
      expect(days.first.day, DateTime(2026, 11, 10));
      expect(days.last.day, DateTime(2026, 11, 16));
      expect(days.last.total, 45000);
      expect(days[4].total, 82000);
      expect(days.fold<int>(0, (sum, d) => sum + d.total), 127000);
    });

    test('salesLast7Days melewati pergantian bulan dan tahun', () {
      buy(s.products[0], 1, now: DateTime(2026, 12, 31, 20));

      final days = s.salesLast7Days(DateTime(2027, 1, 2, 8));

      expect(days.first.day, DateTime(2026, 12, 27));
      expect(days[4].day, DateTime(2026, 12, 31));
      expect(days[4].total, 45000);
    });

    test('pesanan tanpa tanggal tidak masuk grafik harian', () {
      s.orders
        ..clear()
        ..add(
          OrderItem(
            code: 'MP-LAMA',
            customer: 'Lama',
            total: 99000,
            status: 'Selesai',
          ),
        );

      final days = s.salesLast7Days(DateTime(2026, 11, 16));

      expect(s.totalSales, 99000, reason: 'tetap dihitung di total');
      expect(days.every((d) => d.total == 0), isTrue);
    });

    test('pesanan contoh (Jan 2025) di luar 7 hari terakhir', () {
      final days = s.salesLast7Days(DateTime(2026, 11, 16));

      expect(days.every((d) => d.total == 0), isTrue);
    });

    test('pesanan batal tidak masuk grafik', () {
      buy(
        s.products[0],
        1,
        now: DateTime(2026, 11, 16, 9),
        cancelTo: 'Dibatalkan',
      );

      expect(s.salesLast7Days(DateTime(2026, 11, 16)).last.total, 0);
    });
  });

  group('alur checkout', () {
    Future<void> pumpCheckout(WidgetTester tester) async {
      size(tester, 400, 1400);
      registerAndLogin();
      store.addToCart(store.products[0]);
      store.addToCart(store.products[0]);
      store.addToCart(store.products[1]);
      await tester.pumpWidget(app(const CheckoutPage()));
    }

    testWidgets('langkah, alamat, kurir, dan ringkasan tampil', (tester) async {
      await pumpCheckout(tester);

      expect(find.byType(CheckoutSteps), findsOneWidget);
      expect(find.text('Alamat Pengiriman'), findsOneWidget);
      expect(find.text('JNE Regular'), findsOneWidget);
      expect(find.text('J&T Express'), findsOneWidget);
      expect(find.text('Ringkasan Pesanan'), findsOneWidget);
      expect(find.text('Kampas Rem Depan × 2'), findsOneWidget);
      expect(find.text('Lanjutkan Pembayaran'), findsOneWidget);
    });

    testWidgets('nama dan telepon terisi dari akun', (tester) async {
      await pumpCheckout(tester);

      expect(find.text('Siti Aminah'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
    });

    testWidgets('memilih kurir mengubah ongkir dan total', (tester) async {
      await pumpCheckout(tester);
      // 2 x 45.000 + 25.000 = 115.000
      expect(find.text(formatRupiah(125000)), findsWidgets); // + JNE 10.000

      await tester.tap(find.text('J&T Express'));
      await tester.pump();

      expect(find.text(formatRupiah(127000)), findsWidgets); // + J&T 12.000
      final selected = tester
          .widgetList<SelectableCard>(find.byType(SelectableCard))
          .where((c) => c.selected)
          .single;
      expect(selected.title, 'J&T Express');
    });

    testWidgets('alamat kosong ditolak dengan pesan', (tester) async {
      await pumpCheckout(tester);

      await tester.tap(find.text('Lanjutkan Pembayaran'));
      await tester.pump();

      expect(
        find.text('Lengkapi alamat pengiriman terlebih dahulu.'),
        findsOneWidget,
      );
      expect(find.byType(PaymentPage), findsNothing);
    });

    testWidgets('alamat terisi melanjutkan ke pembayaran', (tester) async {
      await pumpCheckout(tester);

      await tester.enterText(find.byType(TextField).at(2), 'Jl. Contoh No. 1');
      await tester.tap(find.text('Lanjutkan Pembayaran'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentPage), findsOneWidget);
    });

    test('CheckoutSteps punya 3 langkah', () {
      expect(CheckoutSteps.labels, ['Alamat', 'Pembayaran', 'Selesai']);
    });
  });

  group('pembayaran dan sukses', () {
    Future<void> pumpPayment(WidgetTester tester) async {
      size(tester, 400, 1600);
      registerAndLogin();
      store.addToCart(store.products[1]); // Filter Oli Honda Rp 25.000
      await tester.pumpWidget(
        app(const PaymentPage(customerName: 'Siti', shippingCost: 10000)),
      );
    }

    testWidgets('metode pembayaran dipilih lewat kartu', (tester) async {
      await pumpPayment(tester);
      SelectableCard selected() => tester
          .widgetList<SelectableCard>(find.byType(SelectableCard))
          .singleWhere((c) => c.selected);
      expect(selected().title, 'Transfer Bank');

      await tester.tap(find.text('COD'));
      await tester.pump();

      expect(selected().title, 'COD');
      expect(find.text('Bayar tunai saat barang tiba'), findsOneWidget);
    });

    testWidgets('total dan catatan simulasi tampil', (tester) async {
      await pumpPayment(tester);

      expect(find.text(formatRupiah(35000)), findsWidgets);
      expect(
        find.text('Ini hanya simulasi pembayaran, bukan transaksi nyata.'),
        findsOneWidget,
      );
    });

    testWidgets('bayar menampilkan halaman sukses dengan kode dan total', (
      tester,
    ) async {
      await pumpPayment(tester);

      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      final order = store.ordersForCurrentAccount.first;
      expect(find.text(order.code), findsOneWidget);
      expect(find.text(formatRupiah(35000)), findsOneWidget);
      expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
    });

    testWidgets('Lihat Pesanan membuka riwayat pesanan', (tester) async {
      await pumpPayment(tester);
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lihat Pesanan'));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersPage), findsOneWidget);
      expect(userTabIndex.value, UserTab.account);
    });

    testWidgets('Kembali ke Beranda mereset tab ke Beranda', (tester) async {
      await pumpPayment(tester);
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();
      userTabIndex.value = UserTab.cart;

      await tester.tap(find.text('Kembali ke Beranda'));
      await tester.pumpAndSettle();

      expect(userTabIndex.value, UserTab.home);
      expect(find.byType(PaymentSuccessPage), findsNothing);
    });
  });

  group('pesanan', () {
    OrderItem placed() {
      registerAndLogin();
      store.addToCart(store.products[2]);
      store.addToCart(store.products[1]);
      store.checkout(
        customer: 'Siti',
        shippingCost: 10000,
        now: DateTime(2026, 11, 14, 9, 5),
      );
      return store.orders.first;
    }

    test('itemsSummary: satu barang, beberapa barang, tanpa rincian', () {
      final order = placed();
      expect(OrdersPage.itemsSummary(order), 'Busi NGK dan 1 lainnya');

      final single = OrderItem(
        code: 'x',
        customer: 'A',
        total: 1,
        status: 'Diproses',
        lines: const [OrderLine(productId: 1, name: 'Satu', qty: 1, price: 1)],
      );
      expect(OrdersPage.itemsSummary(single), 'Satu');

      final none = OrderItem(
        code: 'y',
        customer: 'Budi',
        total: 1,
        status: 'Diproses',
      );
      expect(OrdersPage.itemsSummary(none), 'Budi');
    });

    testWidgets('kartu menampilkan kode, ringkasan, tanggal, total, status', (
      tester,
    ) async {
      size(tester, 400, 900);
      final order = placed();
      await tester.pumpWidget(app(const OrdersPage()));

      expect(find.text(order.code), findsOneWidget);
      expect(find.text('Busi NGK dan 1 lainnya'), findsOneWidget);
      expect(find.text('14 Nov 2026, 09:05'), findsOneWidget);
      expect(find.text(formatRupiah(order.total)), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('kosong: ilustrasi dan Mulai Belanja ke Beranda', (
      tester,
    ) async {
      size(tester, 400, 900);
      registerAndLogin();
      userTabIndex.value = UserTab.account;
      await tester.pumpWidget(app(const OrdersPage()));

      expect(find.text('Belum ada pesanan.'), findsOneWidget);
      await tester.tap(find.text('Mulai Belanja'));
      await tester.pump();

      expect(userTabIndex.value, UserTab.home);
    });

    testWidgets('lini masa menandai langkah yang sudah dilewati', (
      tester,
    ) async {
      size(tester, 400, 400);
      await tester.pumpWidget(
        app(const Scaffold(body: OrderTimeline(status: 'Dikirim'))),
      );

      for (final label in OrderTimeline.steps) {
        expect(find.text(label), findsOneWidget);
      }
      // Diproses & Dikemas selesai (centang), Dikirim aktif.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('pesanan batal menampilkan banner, bukan lini masa', (
      tester,
    ) async {
      size(tester, 400, 400);
      await tester.pumpWidget(
        app(const Scaffold(body: OrderTimeline(status: 'Dibatalkan'))),
      );

      expect(find.text('Pesanan ini dibatalkan.'), findsOneWidget);
      expect(find.text('Dikemas'), findsNothing);
    });

    testWidgets('detail pesanan memuat lini masa dan ikon barang', (
      tester,
    ) async {
      size(tester, 400, 1200);
      final order = placed();
      await tester.pumpWidget(app(OrderDetailPage(order: order)));

      expect(find.byType(OrderTimeline), findsOneWidget);
      expect(find.byIcon(store.products[2].icon), findsOneWidget);
    });

    test('warna status membedakan semua status', () {
      for (final status in [...Store.orderStatuses, 'Lainnya']) {
        expect(orderStatusIcon(status), isA<IconData>());
      }
      expect(orderStatusIcon('Selesai'), Icons.check_circle_rounded);
      expect(orderStatusIcon('Dibatalkan'), Icons.cancel_rounded);
    });
  });

  group('login, daftar, onboarding', () {
    testWidgets('tab Admin terbaca di mode terang maupun gelap', (
      tester,
    ) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        size(tester, 400, 1000);
        await tester.pumpWidget(app(const LoginPage(), mode: mode));
        await tester.tap(find.text('Admin').first);
        await tester.pump();

        final text = tester.widget<Text>(find.text('Admin').first);
        // Teks tab terpilih harus kontras terhadap latar oranye.
        expect(text.style!.color, AppColors.onPrimary);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('daftar punya tombol kembali ke login', (tester) async {
      size(tester, 400, 1000);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterPage()),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsNothing);
    });

    testWidgets('onboarding 3 halaman: Lanjut, Lewati, dan Mulai Sekarang', (
      tester,
    ) async {
      size(tester, 400, 900);
      await tester.pumpWidget(app(const OnboardingPage()));
      expect(find.text('Lengkap & Berkualitas'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Cocok untuk Motormu'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Belanja Praktis'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);

      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Lewati langsung ke login', (tester) async {
      size(tester, 400, 900);
      await tester.pumpWidget(app(const OnboardingPage()));

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('menggeser onboarding memindahkan indikator', (tester) async {
      size(tester, 400, 900);
      await tester.pumpWidget(app(const OnboardingPage()));
      double dot(int i) =>
          tester.getSize(find.byKey(ValueKey('onboarding-dot-$i'))).width;
      expect(dot(0), greaterThan(dot(1)));

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(dot(1), greaterThan(dot(0)));
    });
  });

  group('admin', () {
    testWidgets('dashboard: jumlah pelanggan nyata, bukan angka tetap', (
      tester,
    ) async {
      size(tester, 400, 1400);
      for (final e in ['a@e.com', 'b@e.com', 'c@e.com']) {
        registerAndLogin(name: 'Pelanggan', email: e);
        auth.logout();
      }
      await tester.pumpWidget(app(const AdminDashboardPage()));

      expect(find.text('Pelanggan'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('dashboard: pesanan terbaru membuka detail admin', (
      tester,
    ) async {
      size(tester, 400, 1400);
      await tester.pumpWidget(app(const AdminDashboardPage()));

      await tester.tap(find.text('MP-250118-0001'));
      await tester.pumpAndSettle();

      final page = tester.widget<OrderDetailPage>(find.byType(OrderDetailPage));
      expect(page.isAdmin, isTrue);
    });

    test('kolom kartu statistik: 2 di HP, 4 di layar lebar', () {
      expect(statColumns(400), 2);
      expect(statColumns(900), 4);
    });

    testWidgets('daftar produk bisa dicari', (tester) async {
      size(tester, 400, 1400);
      await tester.pumpWidget(app(const AdminProductsPage()));
      expect(find.text('${store.products.length} produk'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'busi');
      await tester.pump();

      expect(find.text('1 produk'), findsOneWidget);
      expect(find.text('Busi NGK'), findsOneWidget);
      expect(find.text('Gear Set'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump();
      expect(find.text('Tidak ada produk yang cocok.'), findsOneWidget);
    });

    testWidgets('stok menipis di daftar produk berwarna merah', (tester) async {
      size(tester, 400, 1400);
      store.products[0].stock = 3;
      await tester.pumpWidget(app(const AdminProductsPage()));

      final label = tester.widget<Text>(find.text('Rp 45.000 • Stok 3'));

      expect(label.style!.color, AppPalette.light.dangerText);
    });

    testWidgets('laporan memakai data penjualan nyata', (tester) async {
      size(tester, 400, 1400);
      final now = DateTime(2026, 11, 16, 12);
      store.setCurrentAccount('A');
      store.addToCart(store.products[0]);
      store.addToCart(store.products[0]);
      store.checkout(
        customer: 'A',
        shippingCost: 0,
        now: DateTime(2026, 11, 16, 9),
      );
      await tester.pumpWidget(app(AdminReportsPage(now: now)));
      await tester.pumpAndSettle();

      // 205.000 (contoh) + 90.000.
      expect(find.text(formatRupiah(295000)), findsOneWidget);
      expect(find.textContaining('Dari 3 pesanan'), findsOneWidget);
      expect(find.text('Barang Terjual'), findsOneWidget);
      expect(find.text('Penjualan 7 Hari Terakhir'), findsOneWidget);
      expect(find.textContaining('Rp 24.560.000'), findsNothing);
      expect(
        find.text('Belum ada penjualan dalam 7 hari terakhir.'),
        findsNothing,
      );
    });

    testWidgets('laporan tanpa penjualan 7 hari: keterangan kosong', (
      tester,
    ) async {
      size(tester, 400, 1400);
      await tester.pumpWidget(
        app(AdminReportsPage(now: DateTime(2026, 11, 16))),
      );

      expect(
        find.text('Belum ada penjualan dalam 7 hari terakhir.'),
        findsOneWidget,
      );
    });
  });

  group('tidak ada overflow di layar kecil, terang & gelap', () {
    final pages = <String, Widget Function()>{
      'login': () => const LoginPage(),
      'daftar': () => const RegisterPage(),
      'onboarding': () => const OnboardingPage(),
      'checkout': () => const CheckoutPage(),
      'pembayaran': () =>
          const PaymentPage(customerName: 'Siti', shippingCost: 12000),
      'sukses': () => const PaymentSuccessPage(),
      'riwayat pesanan': () => const OrdersPage(),
      'edit profil': () => const EditProfilePage(),
      'ganti password': () => const ChangePasswordPage(),
      'admin dashboard': () => const AdminDashboardPage(),
      'admin produk': () => const AdminProductsPage(),
      'admin pesanan': () => const AdminOrdersPage(),
      'admin pengguna': () => const AdminUsersPage(),
      'admin laporan': () => AdminReportsPage(now: DateTime(2026, 11, 16)),
    };

    for (final entry in pages.entries) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('${entry.key} (${mode.name}) di 320x568, teks 1.3x', (
          tester,
        ) async {
          size(tester, 320, 568);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          registerAndLogin(
            name: 'Siti Aminah Panjang Sekali',
            email: 'x@e.com',
          );
          store.addToCart(store.products[0]);
          store.addToCart(store.products[5]);
          store.checkout(customer: 'Siti', shippingCost: 10000);
          store.addToCart(store.products[3]);

          await tester.pumpWidget(app(entry.value(), mode: mode));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
