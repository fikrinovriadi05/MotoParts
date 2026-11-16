import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/pages/admin/admin_dashboard_page.dart';
import 'package:motopart/pages/admin/admin_users_page.dart';
import 'package:motopart/pages/auth/login_page.dart';
import 'package:motopart/pages/shared/change_password_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthStore newAuth() => AuthStore(store: Store());

String? register(AuthStore a, {String email = 'siti@email.com'}) => a.register(
  name: 'Siti',
  email: email,
  phone: '081234567890',
  password: 'rahasia1',
);

String? loginUser(AuthStore a, [String password = 'rahasia1']) => a.login(
  email: 'siti@email.com',
  password: password,
  role: AccountRole.user,
);

String? loginAdmin(AuthStore a, String password) => a.login(
  email: AuthStore.adminEmail,
  password: password,
  role: AccountRole.admin,
);

void main() {
  group('changePassword', () {
    late AuthStore a;
    setUp(() {
      a = newAuth();
      register(a);
      loginUser(a);
    });

    test('berhasil: password lama tidak berlaku, yang baru berlaku', () {
      expect(
        a.changePassword(oldPassword: 'rahasia1', newPassword: 'baru1234'),
        isNull,
      );

      a.logout();
      expect(loginUser(a, 'rahasia1'), 'Email atau password salah.');
      expect(loginUser(a, 'baru1234'), isNull);
    });

    test('password lama salah ditolak', () {
      expect(
        a.changePassword(oldPassword: 'salah', newPassword: 'baru1234'),
        'Password lama salah.',
      );
    });

    test('password baru terlalu pendek atau sama ditolak', () {
      expect(
        a.changePassword(oldPassword: 'rahasia1', newPassword: '123'),
        'Password baru minimal 6 karakter.',
      );
      expect(
        a.changePassword(oldPassword: 'rahasia1', newPassword: 'rahasia1'),
        'Password baru harus berbeda dari password lama.',
      );
    });

    test('tanpa login ditolak', () {
      a.logout();

      expect(
        a.changePassword(oldPassword: 'rahasia1', newPassword: 'baru1234'),
        'Anda belum masuk.',
      );
    });

    test('salt dan hash berganti', () {
      final before = a.currentAccount!;

      a.changePassword(oldPassword: 'rahasia1', newPassword: 'baru1234');

      expect(a.currentAccount!.salt, isNot(before.salt));
      expect(a.currentAccount!.passwordHash, isNot(before.passwordHash));
    });

    test('perubahan tersimpan permanen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = newAuth();
      await first.attach(prefs);
      register(first);
      loginUser(first);
      first.changePassword(oldPassword: 'rahasia1', newPassword: 'baru1234');

      final reloaded = newAuth();
      await reloaded.attach(prefs);
      reloaded.logout();

      expect(loginUser(reloaded, 'rahasia1'), isNotNull);
      expect(loginUser(reloaded, 'baru1234'), isNull);
    });
  });

  group('updateProfile', () {
    late AuthStore a;
    setUp(() {
      a = newAuth();
      register(a);
      loginUser(a);
    });

    test('mengubah nama dan telepon, email tetap', () {
      expect(
        a.updateProfile(name: ' Siti Aminah ', phone: '0899999999'),
        isNull,
      );

      expect(a.currentAccount!.name, 'Siti Aminah');
      expect(a.currentAccount!.phone, '0899999999');
      expect(a.currentAccount!.email, 'siti@email.com');
      expect(a.accounts.last.name, 'Siti Aminah');
    });

    test('validasi nama dan telepon', () {
      expect(
        a.updateProfile(name: ' ', phone: '0899999999'),
        'Nama dan nomor telepon wajib diisi.',
      );
      expect(
        a.updateProfile(name: 'Siti', phone: '123'),
        'Nomor telepon tidak valid.',
      );
      expect(a.currentAccount!.name, 'Siti');
    });

    test('password tidak berubah dan listener dipanggil', () {
      var notified = 0;
      a.addListener(() => notified++);

      a.updateProfile(name: 'Siti Baru', phone: '0899999999');
      a.logout();

      expect(notified, 2); // update + logout
      expect(loginUser(a), isNull);
    });
  });

  group('password admin bawaan', () {
    test('terdeteksi sampai diganti', () {
      final a = newAuth();
      expect(a.adminUsesDefaultPassword, isTrue);

      loginAdmin(a, AuthStore.adminInitialPassword);
      a.changePassword(
        oldPassword: AuthStore.adminInitialPassword,
        newPassword: 'passwordBaru1',
      );

      expect(a.adminUsesDefaultPassword, isFalse);
      a.logout();
      expect(loginAdmin(a, AuthStore.adminInitialPassword), isNotNull);
      expect(loginAdmin(a, 'passwordBaru1'), isNull);
    });
  });

  group('resetPassword (admin)', () {
    late AuthStore a;
    late Account siti;
    setUp(() {
      a = newAuth();
      register(a);
      siti = a.userAccounts.single;
    });

    test('userAccounts tidak memuat admin', () {
      expect(a.userAccounts.map((x) => x.email), ['siti@email.com']);
    });

    test('hanya admin yang login yang boleh', () {
      expect(
        a.resetPassword(siti, 'sementara1'),
        'Hanya admin yang dapat mengatur ulang password.',
      );

      loginUser(a);
      expect(
        a.resetPassword(siti, 'sementara1'),
        'Hanya admin yang dapat mengatur ulang password.',
      );
    });

    test('admin mengatur ulang: password lama mati, sementara berlaku', () {
      loginAdmin(a, AuthStore.adminInitialPassword);

      expect(a.resetPassword(siti, 'sementara1'), isNull);

      a.logout();
      expect(loginUser(a, 'rahasia1'), 'Email atau password salah.');
      expect(loginUser(a, 'sementara1'), isNull);
    });

    test('password sementara terlalu pendek ditolak', () {
      loginAdmin(a, AuthStore.adminInitialPassword);

      expect(a.resetPassword(siti, '123'), 'Password minimal 6 karakter.');
    });

    test('password admin tidak bisa direset lewat jalur ini', () {
      loginAdmin(a, AuthStore.adminInitialPassword);
      final admin = a.accounts.firstWhere((x) => x.isAdmin);

      expect(
        a.resetPassword(admin, 'sementara1'),
        'Password admin diubah lewat Ganti Password.',
      );
    });

    test('generateTemporaryPassword memenuhi syarat password', () {
      for (var i = 0; i < 20; i++) {
        final p = a.generateTemporaryPassword();
        expect(p.length, 8);
        expect(p, matches(RegExp(r'^[a-z0-9]+$')));
        expect(p.length >= AuthStore.minPasswordLength, isTrue);
      }
    });
  });

  group('layar', () {
    setUp(() {
      auth.logout();
      auth.accounts.removeWhere((x) => !x.isAdmin);
      // Kembalikan password admin bawaan jika tes lain mengubahnya.
      auth.accounts.removeWhere((x) => x.isAdmin);
      final fresh = AuthStore();
      auth.accounts.addAll(fresh.accounts);
    });

    void bigScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('ganti password: konfirmasi tidak sama ditolak', (
      tester,
    ) async {
      register(auth);
      loginUser(auth);
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordPage()));

      await tester.enterText(find.byType(TextField).at(0), 'rahasia1');
      await tester.enterText(find.byType(TextField).at(1), 'baru1234');
      await tester.enterText(find.byType(TextField).at(2), 'beda1234');
      await tester.tap(find.text('Simpan Password'));
      await tester.pump();

      expect(find.text('Konfirmasi password tidak sama.'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsOneWidget);
    });

    testWidgets('ganti password berhasil menutup halaman', (tester) async {
      register(auth);
      loginUser(auth);
      bigScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          // Scaffold di halaman asal: tempat SnackBar tampil setelah pop.
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'rahasia1');
      await tester.enterText(find.byType(TextField).at(1), 'baru1234');
      await tester.enterText(find.byType(TextField).at(2), 'baru1234');
      await tester.tap(find.text('Simpan Password'));
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordPage), findsNothing);
      expect(find.text('Password berhasil diubah.'), findsOneWidget);
      auth.logout();
      expect(loginUser(auth, 'baru1234'), isNull);
    });

    testWidgets('edit profil mengubah nama yang tampil di profil', (
      tester,
    ) async {
      register(auth);
      loginUser(auth);
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
      expect(find.text('Siti'), findsOneWidget);

      await tester.tap(find.text('Data Akun'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Siti Aminah');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfilePage), findsNothing);
      expect(find.text('Siti Aminah'), findsOneWidget);
    });

    testWidgets('admin mengatur ulang password pembeli dari daftar pengguna', (
      tester,
    ) async {
      register(auth);
      loginAdmin(auth, AuthStore.adminInitialPassword);
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminUsersPage()));
      expect(find.text('Siti'), findsOneWidget);

      await tester.tap(find.byTooltip('Reset password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sementara1');
      await tester.tap(find.text('Atur Ulang'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sementara1'), findsOneWidget);
      auth.logout();
      expect(loginUser(auth, 'sementara1'), isNull);
    });

    testWidgets('dashboard admin memperingatkan password bawaan', (
      tester,
    ) async {
      loginAdmin(auth, AuthStore.adminInitialPassword);
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));

      expect(
        find.textContaining('masih memakai password admin bawaan'),
        findsOneWidget,
      );

      auth.changePassword(
        oldPassword: AuthStore.adminInitialPassword,
        newPassword: 'passwordBaru1',
      );
      await tester.pump();

      expect(
        find.textContaining('masih memakai password admin bawaan'),
        findsNothing,
      );
    });

    testWidgets('lupa password menampilkan petunjuk menghubungi admin', (
      tester,
    ) async {
      bigScreen(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      await tester.tap(find.text('Lupa password?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hubungi admin toko'), findsOneWidget);
    });
  });
}
