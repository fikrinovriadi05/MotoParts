import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/google_sign_in_service.dart';
import 'package:motopart/pages/admin/admin_shell.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/user/user_shell.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';

/// Layanan Google palsu: mengembalikan profil yang ditentukan tes.
class FakeGoogleSignIn implements GoogleSignInService {
  @override
  bool isConfigured;
  GoogleProfile? next;
  Object? failure;
  int calls = 0;
  final _events = StreamController<GoogleProfile>.broadcast();

  FakeGoogleSignIn({this.isConfigured = true, this.next});

  @override
  Future<Widget?> webButton() async => null;

  @override
  Stream<GoogleProfile> get profiles => _events.stream;

  @override
  Future<GoogleProfile?> signIn() async {
    calls++;
    if (failure != null) throw failure!;
    return next;
  }
}

AuthStore newAuth() => AuthStore(store: Store());

void main() {
  group('Masuk satu pintu (tanpa memilih peran)', () {
    test('pembeli dan admin masuk dengan form yang sama', () {
      final a = newAuth();
      a.register(
        name: 'Siti',
        email: 'siti@email.com',
        phone: '081234567890',
        password: 'Rahasia1!',
      );

      expect(a.login(email: 'siti@email.com', password: 'Rahasia1!'), isNull);
      expect(a.isLoggedIn, isTrue);
      expect(a.isAdmin, isFalse);

      expect(
        a.login(
          email: AuthStore.adminEmail,
          password: AuthStore.adminInitialPassword,
        ),
        isNull,
      );
      expect(a.isAdmin, isTrue);
    });

    test('password salah tetap ditolak', () {
      final a = newAuth();
      expect(
        a.login(email: AuthStore.adminEmail, password: 'salah-salah'),
        'Email atau password salah.',
      );
      expect(a.isLoggedIn, isFalse);
    });
  });

  group('Masuk dengan Google (AuthStore)', () {
    const siti = GoogleProfile(email: 'siti@gmail.com', name: 'Siti Aminah');

    test('email baru dibuatkan akun pembeli lalu masuk', () {
      final a = newAuth();
      final before = a.accounts.length;

      expect(a.loginWithGoogle(siti), isNull);

      expect(a.accounts.length, before + 1);
      expect(a.isLoggedIn, isTrue);
      expect(a.isAdmin, isFalse);
      expect(a.currentAccount!.email, 'siti@gmail.com');
      expect(a.currentAccount!.name, 'Siti Aminah');
    });

    test('masuk kedua kali memakai akun yang sama (tidak ganda)', () {
      final a = newAuth();
      a.loginWithGoogle(siti);
      final id = a.currentAccount!.id;
      a.logout();

      expect(a.loginWithGoogle(siti), isNull);
      expect(a.currentAccount!.id, id);
      expect(a.accounts.where((x) => x.email == 'siti@gmail.com').length, 1);
    });

    test('email yang sudah terdaftar masuk ke akun itu', () {
      final a = newAuth();
      a.register(
        name: 'Siti',
        email: 'Siti@Gmail.com',
        phone: '081234567890',
        password: 'Rahasia1!',
      );
      final id = a.accounts.last.id;

      expect(a.loginWithGoogle(siti), isNull);
      expect(a.currentAccount!.id, id);
    });

    test('akun admin tidak bisa masuk lewat Google', () {
      final a = newAuth();
      final error = a.loginWithGoogle(
        const GoogleProfile(email: AuthStore.adminEmail, name: 'Siapa pun'),
      );

      expect(error, contains('Akun admin'));
      expect(a.isLoggedIn, isFalse);
    });

    test('email tidak valid ditolak', () {
      final a = newAuth();
      expect(
        a.loginWithGoogle(const GoogleProfile(email: 'bukan-email', name: 'X')),
        isNotNull,
      );
      expect(a.isLoggedIn, isFalse);
    });

    test('akun Google tidak bisa dimasuki dengan password tebakan', () {
      final a = newAuth();
      a.loginWithGoogle(siti);
      a.logout();

      expect(
        a.login(email: 'siti@gmail.com', password: 'admin123'),
        'Email atau password salah.',
      );
      expect(a.login(email: 'siti@gmail.com', password: ''), isNotNull);
    });
  });

  group('Halaman login', () {
    late GoogleSignInService original;

    setUp(() {
      original = googleSignInService;
      auth.logout();
      auth.accounts.removeWhere((x) => !x.isAdmin);
    });

    tearDown(() {
      googleSignInService = original;
      auth.logout();
      auth.accounts.removeWhere((x) => !x.isAdmin);
    });

    Future<void> pumpLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      await tester.pump();
    }

    testWidgets('tombol Google membuka beranda pembeli', (tester) async {
      final fake = FakeGoogleSignIn(
        next: const GoogleProfile(email: 'budi@gmail.com', name: 'Budi'),
      );
      googleSignInService = fake;
      await pumpLogin(tester);

      await tester.tap(find.text('Lanjutkan dengan Google'));
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      expect(find.byType(UserShell), findsOneWidget);
      expect(auth.currentAccount?.email, 'budi@gmail.com');
    });

    testWidgets('dibatalkan: tetap di layar login', (tester) async {
      googleSignInService = FakeGoogleSignIn(next: null);
      await pumpLogin(tester);

      await tester.tap(find.text('Lanjutkan dengan Google'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(auth.isLoggedIn, isFalse);
    });

    testWidgets('gagal: pesan kesalahan tampil', (tester) async {
      googleSignInService = FakeGoogleSignIn()
        ..failure = const GoogleSignInFailure(
          'Konfigurasi Google belum benar.',
        );
      await pumpLogin(tester);

      await tester.tap(find.text('Lanjutkan dengan Google'));
      await tester.pumpAndSettle();

      expect(find.text('Konfigurasi Google belum benar.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets(
      'belum dikonfigurasi: memberi petunjuk, tidak memanggil Google',
      (tester) async {
        final fake = FakeGoogleSignIn(isConfigured: false);
        googleSignInService = fake;
        await pumpLogin(tester);

        await tester.tap(find.text('Lanjutkan dengan Google'));
        await tester.pump();

        expect(fake.calls, 0);
        expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);
      },
    );

    testWidgets('admin masuk lewat form email dan password', (tester) async {
      googleSignInService = FakeGoogleSignIn();
      await pumpLogin(tester);

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
    });
  });
}
