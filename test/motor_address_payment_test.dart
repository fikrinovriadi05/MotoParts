import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/pages/user/address_form_page.dart';
import 'package:motopart/pages/user/addresses_page.dart';
import 'package:motopart/pages/user/edit_profile_page.dart';
import 'package:motopart/pages/user/payment_methods_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/profile_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/selectable_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

AuthStore newAuth() => AuthStore(store: Store());

AuthStore loggedIn({String email = 'siti@email.com'}) {
  final a = newAuth();
  expect(
    a.register(
      name: 'Siti Aminah',
      email: email,
      phone: '081234567890',
      password: 'rahasia1',
    ),
    isNull,
  );
  expect(
    a.login(email: email, password: 'rahasia1', role: AccountRole.user),
    isNull,
  );
  return a;
}

String? addAddress(
  AuthStore a, {
  String label = 'Rumah',
  String street = 'Jl. Mawar No. 1',
  String city = 'Bandung',
  String postalCode = '',
  bool makeDefault = false,
}) => a.addAddress(
  label: label,
  recipient: 'Siti Aminah',
  phone: '081234567890',
  street: street,
  city: city,
  postalCode: postalCode,
  makeDefault: makeDefault,
);

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void resetGlobals() {
  auth.logout();
  auth.accounts.removeWhere((a) => !a.isAdmin);
  store.setCurrentAccount(Store.guestId);
  store.cart.clear();
}

void main() {
  group('data motor di akun', () {
    late AuthStore a;
    setUp(() => a = loggedIn());

    test('akun baru belum punya data motor', () {
      expect(a.currentAccount!.hasMotor, isFalse);
      expect(a.currentAccount!.motorSummary, '');
      expect(a.currentAccount!.motorYear, isNull);
    });

    test('nama, tipe, dan tahun motor tersimpan', () {
      expect(
        a.updateProfile(
          name: 'Siti Aminah',
          phone: '081234567890',
          motorName: ' Honda Beat ',
          motorType: 'Street',
          motorYear: '2020',
        ),
        isNull,
      );

      final acc = a.currentAccount!;
      expect(acc.motorName, 'Honda Beat');
      expect(acc.motorType, 'Street');
      expect(acc.motorYear, 2020);
      expect(acc.motorSummary, 'Honda Beat Street · 2020');
    });

    test('hanya nama motor: ringkasan tanpa tipe dan tahun', () {
      a.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Yamaha NMAX',
      );
      expect(a.currentAccount!.motorSummary, 'Yamaha NMAX');
    });

    test('tahun tidak valid ditolak dan data lama tidak berubah', () {
      a.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Honda Beat',
        motorYear: '2020',
      );
      final now = DateTime(2026, 11, 16);

      for (final bad in ['abc', '1950', '2099', '20.5']) {
        expect(
          a.updateProfile(
            name: 'Siti',
            phone: '081234567890',
            motorYear: bad,
            now: now,
          ),
          'Tahun motor harus antara 1970 dan 2027.',
          reason: bad,
        );
      }
      expect(a.currentAccount!.motorYear, 2020);
      // Tahun depan masih diterima (motor keluaran baru).
      expect(
        a.updateProfile(
          name: 'Siti',
          phone: '081234567890',
          motorYear: '2027',
          now: now,
        ),
        isNull,
      );
    });

    test('tipe atau tahun tanpa nama motor ditolak', () {
      expect(
        a.updateProfile(
          name: 'Siti',
          phone: '081234567890',
          motorType: 'Street',
        ),
        'Isi nama motor terlebih dahulu.',
      );
      expect(
        a.updateProfile(name: 'Siti', phone: '081234567890', motorYear: '2020'),
        'Isi nama motor terlebih dahulu.',
      );
      expect(a.currentAccount!.hasMotor, isFalse);
    });

    test('mengubah nama/telepon saja tidak menghapus data motor', () {
      a.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Honda Beat',
        motorType: 'Street',
        motorYear: '2020',
      );

      expect(a.updateProfile(name: 'Sari', phone: '089999999999'), isNull);

      expect(a.currentAccount!.name, 'Sari');
      expect(a.currentAccount!.motorSummary, 'Honda Beat Street · 2020');
    });

    test('string kosong menghapus data motor', () {
      a.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Honda Beat',
        motorType: 'Street',
        motorYear: '2020',
      );

      expect(
        a.updateProfile(
          name: 'Siti',
          phone: '081234567890',
          motorName: '',
          motorType: '',
          motorYear: '',
        ),
        isNull,
      );

      expect(a.currentAccount!.hasMotor, isFalse);
      expect(a.currentAccount!.motorYear, isNull);
    });
  });

  group('alamat pengiriman', () {
    late AuthStore a;
    setUp(() => a = loggedIn());

    test('alamat pertama otomatis menjadi utama', () {
      expect(addAddress(a), isNull);

      final acc = a.currentAccount!;
      expect(acc.addresses, hasLength(1));
      expect(acc.defaultAddress!.label, 'Rumah');
      expect(acc.defaultAddress!.fullText, 'Jl. Mawar No. 1, Bandung');
    });

    test('alamat berikutnya tidak mengganti utama kecuali diminta', () {
      addAddress(a);
      addAddress(a, label: 'Kantor', street: 'Jl. Melati 2');
      expect(a.currentAccount!.defaultAddress!.label, 'Rumah');

      addAddress(
        a,
        label: 'Bengkel',
        street: 'Jl. Kenanga 3',
        makeDefault: true,
      );
      expect(a.currentAccount!.defaultAddress!.label, 'Bengkel');
      expect(a.currentAccount!.addresses, hasLength(3));
    });

    test('onSaved menerima alamat yang baru disimpan', () {
      ShippingAddress? saved;
      a.addAddress(
        label: 'Rumah',
        recipient: 'Siti',
        phone: '081234567890',
        street: 'Jl. A',
        city: 'Bandung',
        onSaved: (s) => saved = s,
      );
      expect(saved, isNotNull);
      expect(a.currentAccount!.addresses.single.id, saved!.id);
    });

    test('data tidak lengkap atau tidak valid ditolak', () {
      expect(
        addAddress(a, street: ' '),
        'Lengkapi nama alamat, penerima, telepon, alamat, dan kota.',
      );
      expect(addAddress(a, city: ''), isNotNull);
      expect(
        a.addAddress(
          label: 'Rumah',
          recipient: 'Siti',
          phone: '123',
          street: 'Jl. A',
          city: 'Bandung',
        ),
        'Nomor telepon tidak valid.',
      );
      expect(addAddress(a, postalCode: '123'), 'Kode pos harus 5 angka.');
      expect(addAddress(a, postalCode: '40123'), isNull);
      expect(a.currentAccount!.addresses, hasLength(1));
      expect(a.currentAccount!.addresses.single.fullText, contains('40123'));
    });

    test('mengubah alamat mempertahankan id', () {
      addAddress(a);
      final id = a.currentAccount!.addresses.single.id;

      expect(
        a.updateAddress(
          id,
          label: 'Rumah Baru',
          recipient: 'Siti',
          phone: '081234567890',
          street: 'Jl. Baru 5',
          city: 'Jakarta',
          note: 'Pagar hijau',
        ),
        isNull,
      );

      final updated = a.currentAccount!.addresses.single;
      expect(updated.id, id);
      expect(updated.label, 'Rumah Baru');
      expect(updated.note, 'Pagar hijau');
      expect(updated.orderText, contains('Patokan: Pagar hijau'));
      expect(
        a.updateAddress(
          'tidak-ada',
          label: 'X',
          recipient: 'X',
          phone: '081234567890',
          street: 'X',
          city: 'X',
        ),
        'Alamat tidak ditemukan.',
      );
    });

    test('menghapus alamat utama memindahkan utama ke alamat lain', () {
      addAddress(a);
      addAddress(a, label: 'Kantor', street: 'Jl. Melati 2');
      final first = a.currentAccount!.addresses.first.id;

      expect(a.deleteAddress(first), isNull);

      expect(a.currentAccount!.addresses.single.label, 'Kantor');
      expect(a.currentAccount!.defaultAddress!.label, 'Kantor');

      a.deleteAddress(a.currentAccount!.addresses.single.id);
      expect(a.currentAccount!.addresses, isEmpty);
      expect(a.currentAccount!.defaultAddress, isNull);
      expect(a.deleteAddress('x'), 'Alamat tidak ditemukan.');
    });

    test('setDefaultAddress mengganti alamat utama', () {
      addAddress(a);
      addAddress(a, label: 'Kantor', street: 'Jl. Melati 2');
      final second = a.currentAccount!.addresses.last.id;

      expect(a.setDefaultAddress(second), isNull);
      expect(a.currentAccount!.defaultAddress!.label, 'Kantor');
    });

    test('alamat terpisah per akun', () {
      addAddress(a);
      a.logout();
      expect(
        a.register(
          name: 'Budi',
          email: 'budi@email.com',
          phone: '081200000000',
          password: 'rahasia1',
        ),
        isNull,
      );
      a.login(
        email: 'budi@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );

      expect(a.currentAccount!.addresses, isEmpty);
    });

    test('tanpa login: ditolak', () {
      a.logout();
      expect(addAddress(a), 'Anda belum masuk.');
      expect(a.setDefaultAddress('x'), 'Anda belum masuk.');
    });
  });

  group('metode pembayaran', () {
    test('daftar kelompok dan bank/dompet', () {
      expect(PaymentMethods.groups.map((g) => g.name), [
        'QRIS',
        'Virtual Account',
        'E-Wallet',
        'COD',
      ]);
      expect(PaymentMethods.groups[1].providers, [
        'BCA',
        'Mandiri',
        'BNI',
        'BRI',
      ]);
      expect(PaymentMethods.groups[2].providers, ['GoPay']);
      expect(PaymentMethods.groups.first.hasProviders, isFalse);
      expect(PaymentMethods.groups.last.hasProviders, isFalse);
      expect(PaymentMethods.defaultChoice.label, 'QRIS');
    });

    test('QRIS, VA, dan E-Wallet lewat server; COD tidak', () {
      final online = {
        for (final g in PaymentMethods.groups) g.name: g.isOnline,
      };
      expect(online, {
        'QRIS': true,
        'Virtual Account': true,
        'E-Wallet': true,
        'COD': false,
      });
      expect(PaymentMethods.defaultChoice.apiType, 'qris');
      expect(PaymentMethods.defaultChoice.apiProvider, isNull);
      final bca = PaymentMethods.decode('Virtual Account|BCA')!;
      expect(bca.apiType, 'va');
      expect(bca.apiProvider, 'bca');
      expect(PaymentMethods.decode('E-Wallet|GoPay')!.apiProvider, 'gopay');
      expect(PaymentMethods.decode('COD')!.apiType, isNull);
    });

    test('encode/decode bolak-balik dan menolak yang tidak dikenal', () {
      for (final group in PaymentMethods.groups) {
        final choice = PaymentMethods.firstOf(group);
        expect(PaymentMethods.decode(choice.encoded), choice);
      }
      expect(PaymentMethods.decode('COD')!.label, 'COD');
      expect(PaymentMethods.decode('QRIS')!.label, 'QRIS');
      expect(
        PaymentMethods.decode('E-Wallet|GoPay')!.label,
        'E-Wallet - GoPay',
      );
      expect(PaymentMethods.decode(null), isNull);
      expect(PaymentMethods.decode(''), isNull);
      expect(PaymentMethods.decode('Kartu Kredit'), isNull);
      expect(PaymentMethods.decode('E-Wallet|Tidak Ada'), isNull);
      expect(PaymentMethods.decode('E-Wallet'), isNull);
      // Metode lama yang sudah dihapus dari daftar.
      expect(PaymentMethods.decode('Transfer Bank|BCA'), isNull);
      expect(PaymentMethods.decode('E-Wallet|OVO'), isNull);
    });

    test('metode favorit disimpan, diganti, dan dihapus', () {
      final a = loggedIn();
      expect(a.currentAccount!.preferredPayment, isNull);

      expect(a.setPreferredPayment('E-Wallet|GoPay'), isNull);
      expect(a.currentAccount!.preferredPayment, 'E-Wallet|GoPay');

      expect(
        a.setPreferredPayment('Kartu Kredit'),
        'Metode pembayaran tidak dikenal.',
      );
      expect(a.currentAccount!.preferredPayment, 'E-Wallet|GoPay');

      expect(a.setPreferredPayment(null), isNull);
      expect(a.currentAccount!.preferredPayment, isNull);
    });

    test('checkout mencatat alamat dan metode pembayaran di pesanan', () {
      final s = Store();
      s.setCurrentAccount('A');
      s.addToCart(s.products[0]);

      expect(
        s.checkout(
          customer: 'Siti',
          shippingCost: 10000,
          address: 'Siti (0812)\nJl. A, Bandung',
          paymentMethod: 'E-Wallet - GoPay',
        ),
        isTrue,
      );

      final order = s.orders.first;
      expect(order.address, contains('Jl. A, Bandung'));
      expect(order.paymentMethod, 'E-Wallet - GoPay');

      final copy = OrderItem.fromJson(
        jsonDecode(jsonEncode(order.toJson())) as Map<String, dynamic>,
      );
      expect(copy.address, order.address);
      expect(copy.paymentMethod, 'E-Wallet - GoPay');
    });

    test('pesanan lama tanpa alamat/metode tetap terbaca', () {
      final old = OrderItem.fromJson({
        'code': 'MP-1',
        'customer': 'Siti',
        'total': 1000,
        'status': 'Selesai',
      });
      expect(old.address, isNull);
      expect(old.paymentMethod, isNull);
    });
  });

  group('penyimpanan', () {
    test(
      'motor, alamat, dan metode favorit bertahan setelah dimuat ulang',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final first = AuthStore(store: Store());
        await first.attach(prefs);
        first.register(
          name: 'Siti',
          email: 'siti@email.com',
          phone: '081234567890',
          password: 'rahasia1',
        );
        first.login(
          email: 'siti@email.com',
          password: 'rahasia1',
          role: AccountRole.user,
        );
        first.updateProfile(
          name: 'Siti',
          phone: '081234567890',
          motorName: 'Honda Beat',
          motorType: 'Street',
          motorYear: '2020',
        );
        addAddress(first, postalCode: '40123');
        first.setPreferredPayment('Virtual Account|BNI');

        final reloaded = AuthStore(store: Store());
        await reloaded.attach(prefs);

        final acc = reloaded.currentAccount!;
        expect(acc.motorSummary, 'Honda Beat Street · 2020');
        expect(acc.addresses.single.postalCode, '40123');
        expect(acc.defaultAddress!.label, 'Rumah');
        expect(acc.preferredPayment, 'Virtual Account|BNI');
      },
    );

    test('akun lama tanpa kolom baru tetap terbaca', () {
      final account = Account.fromJson({
        'id': 'x',
        'name': 'Lama',
        'email': 'lama@email.com',
        'phone': '081234567890',
        'role': 'user',
        'passwordHash': 'h',
        'salt': 's',
      });

      expect(account.hasMotor, isFalse);
      expect(account.addresses, isEmpty);
      expect(account.defaultAddress, isNull);
      expect(account.preferredPayment, isNull);
    });
  });

  group('halaman', () {
    setUp(resetGlobals);
    tearDown(resetGlobals);

    void login() {
      auth.register(
        name: 'Siti Aminah',
        email: 'siti-ui@email.com',
        phone: '081234567890',
        password: 'rahasia1',
      );
      auth.login(
        email: 'siti-ui@email.com',
        password: 'rahasia1',
        role: AccountRole.user,
      );
    }

    testWidgets('Data Akun: mengisi dan menyimpan data motor', (tester) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const EditProfilePage()));

      expect(find.text('Nama Motor'), findsOneWidget);
      expect(find.text('Tipe Motor'), findsOneWidget);
      expect(find.text('Tahun'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(3), 'Honda Beat');
      await tester.enterText(find.byType(TextField).at(4), 'Street');
      await tester.enterText(find.byType(TextField).at(5), '2020');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(auth.currentAccount!.motorSummary, 'Honda Beat Street · 2020');
    });

    testWidgets(
      'Data Akun: tahun salah menampilkan pesan dan tetap di halaman',
      (tester) async {
        login();
        bigScreen(tester);
        await tester.pumpWidget(app(const EditProfilePage()));

        await tester.enterText(find.byType(TextField).at(3), 'Honda Beat');
        await tester.enterText(find.byType(TextField).at(5), '1900');
        await tester.tap(find.text('Simpan'));
        await tester.pump();

        expect(find.textContaining('Tahun motor harus antara'), findsOneWidget);
        expect(find.byType(EditProfilePage), findsOneWidget);
        expect(auth.currentAccount!.hasMotor, isFalse);
      },
    );

    testWidgets('Data Akun: data motor lama terisi di form', (tester) async {
      login();
      auth.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Yamaha NMAX',
        motorType: '155 ABS',
        motorYear: '2022',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(const EditProfilePage()));

      expect(find.text('Yamaha NMAX'), findsOneWidget);
      expect(find.text('155 ABS'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
    });

    testWidgets('Profil: motor tampil di kartu akun dan menu terhubung', (
      tester,
    ) async {
      login();
      auth.updateProfile(
        name: 'Siti',
        phone: '081234567890',
        motorName: 'Honda Beat',
        motorYear: '2020',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(const ProfilePage()));

      expect(find.text('Honda Beat · 2020'), findsOneWidget);

      await tester.tap(find.text('Alamat Pengiriman'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressesPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(AddressesPage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Metode Pembayaran'));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentMethodsPage), findsOneWidget);
    });

    testWidgets('Alamat: kosong, tambah, ubah, jadikan utama, dan hapus', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressesPage()));

      expect(find.text('Belum ada alamat tersimpan'), findsOneWidget);

      // Tambah alamat pertama lewat form.
      await tester.tap(find.text('Tambah Alamat Baru'));
      await tester.pumpAndSettle();
      expect(find.byType(AddressFormPage), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(3), 'Jl. Mawar No. 1');
      await tester.enterText(find.byType(TextField).at(4), 'Bandung');
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada alamat tersimpan'), findsNothing);
      expect(find.text('Rumah'), findsOneWidget);
      expect(find.text('Utama'), findsOneWidget);
      expect(find.text('Jl. Mawar No. 1, Bandung'), findsOneWidget);
      expect(find.text('Siti Aminah · 081234567890'), findsOneWidget);

      // Alamat kedua: belum utama, bisa dijadikan utama.
      addAddress(auth, label: 'Kantor', street: 'Jl. Melati 2');
      await tester.pump();
      expect(find.text('Jadikan Utama'), findsOneWidget);
      await tester.tap(find.text('Jadikan Utama'));
      await tester.pump();
      expect(auth.currentAccount!.defaultAddress!.label, 'Kantor');

      // Ubah alamat Kantor.
      await tester.tap(find.text('Ubah').last);
      await tester.pumpAndSettle();
      expect(find.text('Ubah Alamat'), findsOneWidget);
      expect(find.text('Jl. Melati 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(3), 'Jl. Melati 22');
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pumpAndSettle();
      expect(find.text('Jl. Melati 22, Bandung'), findsOneWidget);

      // Hapus dengan konfirmasi.
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      expect(find.text('Hapus alamat?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(auth.currentAccount!.addresses, hasLength(2));

      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hapus'),
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.currentAccount!.addresses, hasLength(1));
      expect(auth.currentAccount!.defaultAddress!.label, 'Rumah');
    });

    testWidgets('Form alamat: data tidak lengkap menampilkan pesan', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));

      // Nama penerima dan telepon terisi dari akun; alamat/kota kosong.
      expect(find.text('Siti Aminah'), findsOneWidget);
      await tester.tap(find.text('Simpan Alamat'));
      await tester.pump();

      expect(
        find.text('Lengkapi nama alamat, penerima, telepon, alamat, dan kota.'),
        findsOneWidget,
      );
      expect(auth.currentAccount!.addresses, isEmpty);
    });

    testWidgets('Form alamat: pilihan cepat mengisi nama alamat', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const AddressFormPage()));

      await tester.tap(find.widgetWithText(ActionChip, 'Bengkel'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Bengkel'), findsOneWidget);
    });

    testWidgets('Metode Pembayaran: memilih dan menyimpan favorit', (
      tester,
    ) async {
      login();
      bigScreen(tester);
      await tester.pumpWidget(app(const PaymentMethodsPage()));

      await tester.tap(find.text('E-Wallet'));
      await tester.pump();
      expect(find.text('Pilih Dompet Digital'), findsOneWidget);
      await tester.tap(find.text('GoPay'));
      await tester.pump();
      await tester.tap(find.text('Simpan sebagai Favorit'));
      await tester.pumpAndSettle();

      expect(auth.currentAccount!.preferredPayment, 'E-Wallet|GoPay');
    });

    testWidgets('Metode Pembayaran: favorit lama terpilih dan bisa dihapus', (
      tester,
    ) async {
      login();
      auth.setPreferredPayment('Virtual Account|BNI');
      bigScreen(tester);
      await tester.pumpWidget(app(const PaymentMethodsPage()));

      final bni = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'BNI'),
      );
      expect(bni.selected, isTrue);

      await tester.tap(find.text('Hapus metode favorit'));
      await tester.pumpAndSettle();
      expect(auth.currentAccount!.preferredPayment, isNull);
    });

    testWidgets('Pembayaran: pilihan bank/dompet muncul di bawah kartunya', (
      tester,
    ) async {
      login();
      store.addToCart(store.products[1]);
      bigScreen(tester);
      await tester.pumpWidget(
        app(const PaymentPage(customerName: 'Siti', shippingCost: 10000)),
      );

      // Awal: QRIS (tanpa pilihan bank).
      expect(find.byType(ChoiceChip), findsNothing);

      await tester.tap(find.text('Virtual Account'));
      await tester.pump();
      expect(find.text('Pilih Bank'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'BCA'))
            .selected,
        isTrue,
      );

      await tester.tap(find.text('E-Wallet'));
      await tester.pump();
      expect(find.text('BCA'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'GoPay'), findsOneWidget);
    });

    testWidgets(
      'Pembayaran: COD tanpa pilihan bank dan metode favorit dipakai',
      (tester) async {
        login();
        auth.setPreferredPayment('COD');
        store.addToCart(store.products[1]);
        bigScreen(tester);
        await tester.pumpWidget(
          app(const PaymentPage(customerName: 'Siti', shippingCost: 0)),
        );

        final selected = tester
            .widgetList<SelectableCard>(find.byType(SelectableCard))
            .singleWhere((c) => c.selected);
        expect(selected.title, 'COD');
        expect(find.byType(ChoiceChip), findsNothing);

        await tester.tap(find.text('Bayar Sekarang'));
        await tester.pumpAndSettle();
        expect(store.orders.first.paymentMethod, 'COD');
      },
    );

    testWidgets('Halaman sukses menampilkan metode pembayaran', (tester) async {
      login();
      store.addToCart(store.products[1]);
      store.checkout(
        customer: 'Siti',
        shippingCost: 0,
        paymentMethod: 'Virtual Account - BNI',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(const PaymentSuccessPage()));

      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.text('Virtual Account - BNI'), findsOneWidget);
    });

    testWidgets('Detail pesanan: menampilkan alamat dan metode pembayaran', (
      tester,
    ) async {
      final order = OrderItem(
        code: 'MP-X',
        customer: 'Siti',
        total: 35000,
        status: 'Diproses',
        address: 'Siti (0812)\nJl. A, Bandung',
        paymentMethod: 'Virtual Account - BCA',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(OrderDetailPage(order: order)));

      expect(find.text('Alamat Pengiriman'), findsOneWidget);
      expect(find.textContaining('Jl. A, Bandung'), findsOneWidget);
      expect(find.text('Metode Pembayaran'), findsOneWidget);
      expect(find.text('Virtual Account - BCA'), findsOneWidget);
    });

    testWidgets('Detail pesanan lama: tanpa blok alamat/pembayaran', (
      tester,
    ) async {
      final order = OrderItem(
        code: 'MP-OLD',
        customer: 'Siti',
        total: 35000,
        status: 'Selesai',
      );
      bigScreen(tester);
      await tester.pumpWidget(app(OrderDetailPage(order: order)));

      expect(find.text('Alamat Pengiriman'), findsNothing);
      expect(find.text('Metode Pembayaran'), findsNothing);
    });
  });
}
