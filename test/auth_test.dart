import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthStore newAuth([Store? store]) => AuthStore(store: store ?? Store());

String? registerSiti(AuthStore a, {String email = 'siti@email.com'}) =>
    a.register(
      name: 'Siti',
      email: email,
      phone: '081234567890',
      password: 'Rahasia1!',
    );

String? loginUser(AuthStore a, String email, String password) =>
    a.login(email: email, password: password, role: AccountRole.user);

void main() {
  group('hash password', () {
    test('sama untuk salt yang sama, beda untuk salt berbeda', () {
      expect(
        AuthStore.hashPassword('abc123', 's1'),
        AuthStore.hashPassword('abc123', 's1'),
      );
      expect(
        AuthStore.hashPassword('abc123', 's1'),
        isNot(AuthStore.hashPassword('abc123', 's2')),
      );
    });

    test('password asli tidak tersimpan di akun', () {
      final a = newAuth();
      registerSiti(a);
      final account = a.accounts.firstWhere((x) => x.email == 'siti@email.com');

      expect(account.passwordHash, isNot('Rahasia1!'));
      expect(account.passwordHash.contains('Rahasia1!'), isFalse);
      expect(account.toJson().toString().contains('Rahasia1!'), isFalse);
      expect(account.salt, isNotEmpty);
    });
  });

  group('register', () {
    late AuthStore a;
    setUp(() => a = newAuth());

    test('admin bawaan sudah ada', () {
      expect(a.accounts.where((x) => x.isAdmin).length, 1);
      expect(a.accounts.first.email, AuthStore.adminEmail);
    });

    test('berhasil membuat akun pembeli tanpa otomatis login', () {
      expect(registerSiti(a), isNull);

      expect(a.accounts.length, 2);
      expect(a.accounts.last.role, AccountRole.user);
      expect(a.isLoggedIn, isFalse);
    });

    test('email ganda ditolak tanpa membedakan huruf besar/kecil', () {
      registerSiti(a);

      expect(
        registerSiti(a, email: 'SITI@Email.com'),
        'Email sudah terdaftar.',
      );
      expect(a.accounts.length, 2);
    });

    test('email tidak valid ditolak', () {
      for (final bad in ['siti', 'siti@', 'siti@email', '@email.com']) {
        expect(
          registerSiti(a, email: bad),
          'Format email tidak valid.',
          reason: bad,
        );
      }
    });

    test('password terlalu pendek ditolak', () {
      expect(
        a.register(
          name: 'Siti',
          email: 'siti@email.com',
          phone: '081234567890',
          password: '12345',
        ),
        'Password minimal 6 karakter.',
      );
    });

    test('nomor telepon tidak valid ditolak', () {
      expect(
        a.register(
          name: 'Siti',
          email: 'siti@email.com',
          phone: '123',
          password: 'Rahasia1!',
        ),
        'Nomor telepon tidak valid.',
      );
    });

    test('kolom kosong ditolak', () {
      expect(
        a.register(name: ' ', email: '', phone: '', password: ''),
        'Lengkapi semua data terlebih dahulu.',
      );
    });
  });

  group('login', () {
    late Store store;
    late AuthStore a;
    setUp(() {
      store = Store();
      a = AuthStore(store: store);
      registerSiti(a);
    });

    test(
      'berhasil dengan email (tanpa membedakan huruf) dan password benar',
      () {
        expect(loginUser(a, ' SITI@email.com ', 'Rahasia1!'), isNull);

        expect(a.currentAccount?.name, 'Siti');
        expect(store.currentAccountId, a.currentAccount!.id);
      },
    );

    test('password salah dan email tak dikenal memberi pesan yang sama', () {
      const message = 'Email atau password salah.';

      expect(loginUser(a, 'siti@email.com', 'salah'), message);
      expect(loginUser(a, 'tidak@ada.com', 'Rahasia1!'), message);
      expect(a.isLoggedIn, isFalse);
    });

    test('kolom kosong ditolak', () {
      expect(loginUser(a, '', ''), 'Email dan password wajib diisi.');
    });

    test('pembeli tidak bisa masuk lewat tab admin', () {
      final error = a.login(
        email: 'siti@email.com',
        password: 'Rahasia1!',
        role: AccountRole.admin,
      );

      expect(error, 'Akun ini bukan akun admin.');
      expect(a.isLoggedIn, isFalse);
    });

    test('admin masuk lewat tab admin, bukan tab pengguna', () {
      expect(
        loginUser(a, AuthStore.adminEmail, AuthStore.adminInitialPassword),
        'Akun admin masuk lewat tab Admin.',
      );
      expect(a.isLoggedIn, isFalse);

      final error = a.login(
        email: AuthStore.adminEmail,
        password: AuthStore.adminInitialPassword,
        role: AccountRole.admin,
      );

      expect(error, isNull);
      expect(a.isAdmin, isTrue);
    });

    test('logout mengakhiri sesi dan mengembalikan store ke tamu', () {
      loginUser(a, 'siti@email.com', 'Rahasia1!');

      a.logout();

      expect(a.isLoggedIn, isFalse);
      expect(store.currentAccountId, Store.guestId);
    });
  });

  group('penyimpanan akun', () {
    Future<(AuthStore, SharedPreferences)> attached() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = newAuth();
      await a.attach(prefs);
      return (a, prefs);
    }

    test('akun dan sesi tersimpan lalu dipulihkan', () async {
      final (a, prefs) = await attached();
      registerSiti(a);
      loginUser(a, 'siti@email.com', 'Rahasia1!');

      final store = Store();
      final reloaded = AuthStore(store: store);
      await reloaded.attach(prefs);

      expect(reloaded.accounts.length, 2);
      expect(reloaded.currentAccount?.email, 'siti@email.com');
      expect(store.currentAccountId, reloaded.currentAccount!.id);
      // Password yang sama masih bisa dipakai login setelah dimuat ulang.
      reloaded.logout();
      expect(loginUser(reloaded, 'siti@email.com', 'Rahasia1!'), isNull);
    });

    test('logout tersimpan: sesi tidak dipulihkan', () async {
      final (a, prefs) = await attached();
      registerSiti(a);
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      a.logout();

      final reloaded = newAuth();
      await reloaded.attach(prefs);

      expect(reloaded.isLoggedIn, isFalse);
      expect(reloaded.accounts.length, 2);
    });

    test('data rusak diabaikan dan admin bawaan tetap ada', () async {
      SharedPreferences.setMockInitialValues({
        AuthStore.storageKey: 'bukan json',
      });
      final a = newAuth();

      await a.attach(await SharedPreferences.getInstance());

      expect(a.isLoggedIn, isFalse);
      expect(a.accounts.any((x) => x.isAdmin), isTrue);
    });
  });

  group('data per akun', () {
    late Store store;
    late AuthStore a;
    setUp(() {
      store = Store();
      a = AuthStore(store: store);
      registerSiti(a);
      registerSiti(a, email: 'budi@email.com');
    });

    test('keranjang tidak bocor antar akun', () {
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      store.addToCart(store.products[0]);
      expect(store.cartCount, 1);

      a.logout();
      expect(store.cartCount, 0, reason: 'tamu tidak mewarisi keranjang');

      loginUser(a, 'budi@email.com', 'Rahasia1!');
      expect(store.cartCount, 0);
      store.addToCart(store.products[1]);
      store.addToCart(store.products[1]);

      a.logout();
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      expect(store.cartCount, 1);
      expect(store.cart.single.product.id, store.products[0].id);
    });

    test('wishlist tidak bocor antar akun', () {
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      store.toggleWishlist(store.products[0]);

      a.logout();
      loginUser(a, 'budi@email.com', 'Rahasia1!');

      expect(store.isWishlisted(store.products[0]), isFalse);
    });

    test('riwayat pesanan hanya milik akun sendiri; admin melihat semua', () {
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      store.addToCart(store.products[0]);
      store.checkout(customer: 'Siti', shippingCost: 0);

      expect(store.ordersForCurrentAccount.length, 1);
      expect(store.ordersForCurrentAccount.single.customer, 'Siti');

      a.logout();
      loginUser(a, 'budi@email.com', 'Rahasia1!');
      expect(store.ordersForCurrentAccount, isEmpty);

      // Admin memakai store.orders: pesanan Siti dan pesanan contoh.
      expect(store.orders.length, 3);
      expect(
        store.orders.where((o) => o.accountId == null).length,
        2,
        reason: 'pesanan contoh tidak punya pemilik',
      );
    });

    test('menghapus produk mengosongkannya dari keranjang semua akun', () {
      final product = store.products[0];
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      store.addToCart(product);
      a.logout();
      loginUser(a, 'budi@email.com', 'Rahasia1!');
      store.addToCart(product);
      store.toggleWishlist(product);

      store.deleteProduct(product);
      a.logout();
      loginUser(a, 'siti@email.com', 'Rahasia1!');

      expect(store.cart, isEmpty);
    });

    test('mengurangi stok memangkas keranjang akun lain', () {
      final product = store.products[0];
      loginUser(a, 'siti@email.com', 'Rahasia1!');
      for (var i = 0; i < 5; i++) {
        store.addToCart(product);
      }
      a.logout();

      store.updateProduct(product, stock: 2);
      loginUser(a, 'siti@email.com', 'Rahasia1!');

      expect(store.qtyInCart(product), 2);
    });

    test(
      'keranjang, wishlist, dan pemilik pesanan tersimpan per akun',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final s1 = Store();
        await s1.attach(prefs);
        final a1 = AuthStore(store: s1);
        await a1.attach(prefs);
        registerSiti(a1);
        loginUser(a1, 'siti@email.com', 'Rahasia1!');
        s1.addToCart(s1.products[0]);
        s1.toggleWishlist(s1.products[2]);
        s1.addToCart(s1.products[1]);
        s1.checkout(customer: 'Siti', shippingCost: 0);
        s1.addToCart(s1.products[3]);

        final s2 = Store();
        await s2.attach(prefs);
        final a2 = AuthStore(store: s2);
        await a2.attach(prefs); // memulihkan sesi Siti

        expect(s2.currentAccountId, a1.currentAccount!.id);
        expect(s2.cart.single.product.id, s2.products[3].id);
        expect(s2.isWishlisted(s2.products[2]), isTrue);
        expect(s2.ordersForCurrentAccount.length, 1);
      },
    );
  });

  group('layar login & daftar', () {
    setUp(() {
      auth.logout();
      auth.accounts.removeWhere((x) => !x.isAdmin);
      store.currentAccountId = Store.guestId;
    });

    Future<void> pumpLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    }

    testWidgets('login gagal menampilkan pesan dan tetap di layar login', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextField).at(0), 'x@y.com');
      await tester.enterText(find.byType(TextField).at(1), 'salah123');
      await tester.tap(find.text('Masuk').last);
      await tester.pump();

      expect(find.text('Email atau password salah.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('login pembeli membuka beranda pembeli', (tester) async {
      registerSiti(auth);
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextField).at(0), 'siti@email.com');
      await tester.enterText(find.byType(TextField).at(1), 'Rahasia1!');
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();

      expect(find.byType(UserShell), findsOneWidget);
      expect(auth.currentAccount?.name, 'Siti');
    });

    testWidgets('admin masuk lewat form yang sama dan membuka dashboard', (
      tester,
    ) async {
      await pumpLogin(tester);

      expect(find.text('Admin'), findsNothing, reason: 'tidak ada tab peran');
      await tester.enterText(
        find.byType(TextField).at(0),
        AuthStore.adminEmail,
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        AuthStore.adminInitialPassword,
      );
      await tester.tap(find.text('Masuk').last);
      await tester.pumpAndSettle();

      expect(find.byType(AdminShell), findsOneWidget);
      expect(auth.isAdmin, isTrue);
    });

    testWidgets('daftar dengan email ganda menampilkan pesan', (tester) async {
      registerSiti(auth);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

      await tester.enterText(find.byType(TextField).at(0), 'Siti Lain');
      await tester.enterText(find.byType(TextField).at(1), 'siti@email.com');
      await tester.enterText(find.byType(TextField).at(2), '081234567890');
      await tester.enterText(find.byType(TextField).at(3), 'Rahasia1!');
      await tester.enterText(find.byType(TextField).at(4), 'Rahasia1!');
      await tester.tap(find.text('Daftar').last);
      await tester.pump();

      expect(find.text('Email sudah terdaftar.'), findsOneWidget);
      expect(auth.accounts.length, 2);
    });
  });
}
