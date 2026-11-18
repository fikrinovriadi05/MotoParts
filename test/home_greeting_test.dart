import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/user/home_page.dart';
import 'package:motopart/store/auth_store.dart';

void main() {
  group('Account.firstName', () {
    Account named(String name) => Account(
      id: 'x',
      name: name,
      email: 'x@y.com',
      phone: '0812345678',
      role: AccountRole.user,
      passwordHash: 'h',
      salt: 's',
    );

    test('mengambil kata pertama nama', () {
      expect(named('Siti Aminah').firstName, 'Siti');
      expect(named('  Budi   Santoso ').firstName, 'Budi');
      expect(named('Dewi').firstName, 'Dewi');
    });
  });

  group('sapaan di beranda', () {
    setUp(() {
      auth.logout();
      auth.accounts.removeWhere((a) => !a.isAdmin);
    });

    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
    }

    void signUpAndLogin(String name, String email) {
      auth.register(
        name: name,
        email: email,
        phone: '081234567890',
        password: 'Rahasia1!',
      );
      auth.login(email: email, password: 'Rahasia1!', role: AccountRole.user);
    }

    testWidgets('memakai nama saat daftar, bukan nama tetap', (tester) async {
      signUpAndLogin('Siti Aminah', 'siti@email.com');
      await pumpHome(tester);

      expect(find.text('Halo, Siti 👋'), findsOneWidget);
      expect(find.textContaining('Budi'), findsNothing);
    });

    testWidgets('berganti saat akun lain login', (tester) async {
      signUpAndLogin('Siti Aminah', 'siti@email.com');
      await pumpHome(tester);
      expect(find.text('Halo, Siti 👋'), findsOneWidget);

      auth.logout();
      auth.register(
        name: 'Dewi Lestari',
        email: 'dewi@email.com',
        phone: '081234567891',
        password: 'Rahasia1!',
      );
      auth.login(
        email: 'dewi@email.com',
        password: 'Rahasia1!',
        role: AccountRole.user,
      );
      await tester.pump();

      expect(find.text('Halo, Dewi 👋'), findsOneWidget);
    });

    testWidgets('ikut berubah saat nama diedit', (tester) async {
      signUpAndLogin('Siti Aminah', 'siti@email.com');
      await pumpHome(tester);

      auth.updateProfile(name: 'Sari Ayu', phone: '081234567890');
      await tester.pump();

      expect(find.text('Halo, Sari 👋'), findsOneWidget);
    });

    testWidgets('tanpa login: sapaan netral', (tester) async {
      await pumpHome(tester);

      expect(find.text('Halo 👋'), findsOneWidget);
    });
  });
}
