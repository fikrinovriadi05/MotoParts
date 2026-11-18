import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/pages/auth/register_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';

AuthStore newAuth() => AuthStore(store: Store());

String? register(
  AuthStore a,
  String password, {
  String? confirm,
  String email = 'siti@email.com',
}) => a.register(
  name: 'Siti',
  email: email,
  phone: '081234567890',
  password: password,
  confirmPassword: confirm,
);

void main() {
  group('Aturan password akun baru', () {
    test('password yang memenuhi semua aturan diterima', () {
      expect(AuthStore.passwordStrengthError('Rahasia1!'), isNull);
      expect(register(newAuth(), 'Abc123#x'), isNull);
    });

    test('pesan menunjuk aturan yang dilanggar', () {
      expect(
        AuthStore.passwordStrengthError('Ab1!'),
        'Password minimal 6 karakter.',
      );
      expect(
        AuthStore.passwordStrengthError('rahasia1!'),
        'Password harus mengandung huruf kapital.',
      );
      expect(
        AuthStore.passwordStrengthError('Rahasia!!'),
        'Password harus mengandung angka.',
      );
      expect(
        AuthStore.passwordStrengthError('Rahasia11'),
        'Password harus mengandung simbol.',
      );
    });

    test('spasi bukan simbol', () {
      expect(
        AuthStore.passwordStrengthError('Rahasia 11'),
        'Password harus mengandung simbol.',
      );
    });

    test('register menolak password lemah tanpa membuat akun', () {
      final a = newAuth();
      final before = a.accounts.length;

      expect(
        register(a, 'rahasia1!'),
        'Password harus mengandung huruf kapital.',
      );
      expect(a.accounts.length, before);
    });

    test('konfirmasi harus sama', () {
      final a = newAuth();
      expect(
        register(a, 'Rahasia1!', confirm: 'Rahasia1?'),
        'Konfirmasi password tidak sama.',
      );
      expect(register(a, 'Rahasia1!', confirm: 'Rahasia1!'), isNull);
    });

    test('daftar rules dipakai UI: 4 aturan', () {
      expect(AuthStore.passwordRules.length, 4);
      expect(
        AuthStore.passwordRules.map((r) => r.test('Rahasia1!')),
        everyElement(isTrue),
      );
      expect(
        AuthStore.passwordRules.map((r) => r.test('')),
        everyElement(isFalse),
      );
    });
  });

  group('Layar Daftar', () {
    late AuthStore original;

    Future<void> pumpRegister(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
    }

    setUp(() {
      original = auth;
      auth.accounts.removeWhere((x) => !x.isAdmin);
    });

    tearDown(() {
      auth.accounts.removeWhere((x) => !x.isAdmin);
      expect(identical(original, auth), isTrue);
    });

    testWidgets('menuliskan aturan password dan punya kolom konfirmasi', (
      tester,
    ) async {
      await pumpRegister(tester);

      expect(find.text('Password harus memenuhi:'), findsOneWidget);
      expect(find.text('Minimal 6 karakter'), findsOneWidget);
      expect(find.text('Mengandung huruf kapital (A-Z)'), findsOneWidget);
      expect(find.text('Mengandung angka (0-9)'), findsOneWidget);
      expect(find.textContaining('Mengandung simbol'), findsOneWidget);
      expect(find.text('Konfirmasi Password'), findsOneWidget);
    });

    testWidgets('aturan berubah centang saat terpenuhi', (tester) async {
      await pumpRegister(tester);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.enterText(find.byType(TextField).at(3), 'Abc');
      await tester.pump();
      // Hanya "huruf kapital" yang terpenuhi.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(3), 'Abc123!');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
    });

    testWidgets('konfirmasi berbeda menampilkan kesalahan langsung', (
      tester,
    ) async {
      await pumpRegister(tester);

      await tester.enterText(find.byType(TextField).at(3), 'Abc123!');
      await tester.enterText(find.byType(TextField).at(4), 'Abc123');
      await tester.pump();
      expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(4), 'Abc123!');
      await tester.pump();
      expect(find.text('Konfirmasi password tidak sama.'), findsNothing);
    });

    testWidgets('daftar dengan password lemah ditolak', (tester) async {
      await pumpRegister(tester);
      final before = auth.accounts.length;

      await tester.enterText(find.byType(TextField).at(0), 'Budi');
      await tester.enterText(find.byType(TextField).at(1), 'budi@email.com');
      await tester.enterText(find.byType(TextField).at(2), '081234567890');
      await tester.enterText(find.byType(TextField).at(3), 'rahasia1');
      await tester.enterText(find.byType(TextField).at(4), 'rahasia1');
      await tester.tap(find.text('Daftar').last);
      await tester.pump();

      expect(
        find.text('Password harus mengandung huruf kapital.'),
        findsOneWidget,
      );
      expect(auth.accounts.length, before);
    });

    testWidgets('daftar dengan password kuat dan konfirmasi sama berhasil', (
      tester,
    ) async {
      await pumpRegister(tester);
      final before = auth.accounts.length;

      await tester.enterText(find.byType(TextField).at(0), 'Budi');
      await tester.enterText(find.byType(TextField).at(1), 'budi@email.com');
      await tester.enterText(find.byType(TextField).at(2), '081234567890');
      await tester.enterText(find.byType(TextField).at(3), 'Rahasia1!');
      await tester.enterText(find.byType(TextField).at(4), 'Rahasia1!');
      await tester.tap(find.text('Daftar').last);
      await tester.pump();

      expect(auth.accounts.length, before + 1);
    });
  });
}
