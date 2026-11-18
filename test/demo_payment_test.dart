import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/payment_waiting_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

final qris = PaymentMethods.firstOf(PaymentMethods.groups.first);

PaymentChoice choiceOf(String name, [String? provider]) {
  final group = PaymentMethods.groups.firstWhere((g) => g.name == name);
  return PaymentChoice(group, provider);
}

void reset() {
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
  userTabIndex.value = UserTab.home;
  PaymentMethods.demoOverride = true;
  PaymentMethods.onlineOverride = null;
}

void login() {
  auth.register(
    name: 'Siti Aminah',
    email: 'siti-demo@email.com',
    phone: '081234567890',
    password: 'Rahasia1!',
  );
  auth.login(
    email: 'siti-demo@email.com',
    password: 'Rahasia1!',
    role: AccountRole.user,
  );
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late DateTime now;
  late DemoPaymentApi demo;

  setUp(() {
    reset();
    now = DateTime(2026, 11, 17, 10);
    demo = DemoPaymentApi(clock: () => now);
    paymentApi = demo;
  });

  tearDown(() {
    PaymentMethods.demoOverride = false;
    PaymentMethods.onlineOverride = null;
    paymentApi = FakePaymentApi();
    reset();
    PaymentMethods.demoOverride = false;
  });

  group('metode yang ditawarkan', () {
    test('mode demo: QRIS dan COD saja', () {
      expect(PaymentMethods.demoMode, isTrue);
      expect(PaymentMethods.onlineAvailable, isFalse);
      expect(PaymentMethods.available.map((g) => g.name), ['QRIS', 'COD']);
      expect(PaymentMethods.defaultChoice.group.name, 'QRIS');
    });

    test('bukan mode demo: semua metode online (perilaku sebelumnya)', () {
      PaymentMethods.demoOverride = false;
      expect(PaymentMethods.onlineAvailable, isTrue);
      expect(PaymentMethods.available.length, PaymentMethods.groups.length);
    });

    test('pilihan favorit VA yang tersimpan diganti pilihan awal (QRIS)', () {
      final saved = choiceOf('Virtual Account', 'BCA');
      expect(PaymentMethods.usable(saved).group.name, 'QRIS');
      expect(PaymentMethods.usable(choiceOf('COD')).group.name, 'COD');
    });
  });

  group('DemoPaymentApi', () {
    test(
      'create: tagihan QRIS dengan kode QR contoh dan batas 15 menit',
      () async {
        final snap = await demo.create(
          orderCode: 'MP-1',
          choice: qris,
          amount: 35000,
        );
        expect(snap.status, PaymentStatus.pending);
        expect(snap.info.type, 'qris');
        expect(snap.info.paymentId, 'MP-1');
        expect(snap.info.amount, 35000);
        expect(snap.info.qrString, 'MOTOPART-DEMO|MP-1|35000');
        expect(snap.info.hasQr, isTrue);
        expect(snap.info.expiresAt, now.add(const Duration(minutes: 15)));
      },
    );

    test('create dua kali untuk pesanan sama: tagihan sama', () async {
      final a = await demo.create(
        orderCode: 'MP-1',
        choice: qris,
        amount: 1000,
      );
      now = now.add(const Duration(minutes: 5));
      final b = await demo.create(
        orderCode: 'MP-1',
        choice: qris,
        amount: 1000,
      );
      expect(b.info.expiresAt, a.info.expiresAt);
    });

    test('metode selain QRIS ditolak dengan pesan jelas', () async {
      for (final choice in [
        choiceOf('Virtual Account', 'BCA'),
        choiceOf('E-Wallet', 'GoPay'),
      ]) {
        await expectLater(
          demo.create(orderCode: 'MP-2', choice: choice, amount: 1),
          throwsA(
            isA<PaymentApiException>().having(
              (e) => e.message,
              'message',
              contains('hanya menyimulasikan QRIS'),
            ),
          ),
        );
      }
    });

    test('status: menunggu -> lunas setelah simulatePaid', () async {
      await demo.create(orderCode: 'MP-1', choice: qris, amount: 1000);
      expect((await demo.status('MP-1')).status, PaymentStatus.pending);

      expect(demo.simulatePaid('MP-1'), isTrue);
      expect((await demo.status('MP-1')).status, PaymentStatus.paid);
    });

    test(
      'status: kedaluwarsa setelah batas waktu; tak bisa dibayar lagi',
      () async {
        await demo.create(orderCode: 'MP-1', choice: qris, amount: 1000);
        now = now.add(const Duration(minutes: 15));
        expect((await demo.status('MP-1')).status, PaymentStatus.expired);
        expect(demo.simulatePaid('MP-1'), isFalse);
        expect((await demo.status('MP-1')).status, PaymentStatus.expired);
      },
    );

    test('yang sudah lunas tetap lunas walau batas waktu lewat', () async {
      await demo.create(orderCode: 'MP-1', choice: qris, amount: 1000);
      demo.simulatePaid('MP-1');
      now = now.add(const Duration(hours: 2));
      expect((await demo.status('MP-1')).status, PaymentStatus.paid);
    });

    test(
      'tagihan tak dikenal dianggap menunggu dan bisa disimulasikan',
      () async {
        expect((await demo.status('MP-ASING')).status, PaymentStatus.pending);
        expect(demo.simulatePaid('MP-ASING'), isTrue);
        expect((await demo.status('MP-ASING')).status, PaymentStatus.paid);
      },
    );

    test('status tersimpan dan pulih setelah aplikasi dibuka ulang', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = DemoPaymentApi(clock: () => now);
      await first.attach(prefs);
      await first.create(orderCode: 'MP-1', choice: qris, amount: 1000);
      await first.create(orderCode: 'MP-2', choice: qris, amount: 1000);
      first.simulatePaid('MP-2');
      await Future<void>.delayed(Duration.zero);

      final second = DemoPaymentApi(clock: () => now);
      await second.attach(prefs);
      expect((await second.status('MP-1')).status, PaymentStatus.pending);
      expect((await second.status('MP-2')).status, PaymentStatus.paid);
      now = now.add(const Duration(minutes: 16));
      expect((await second.status('MP-1')).status, PaymentStatus.expired);
    });

    test('data tersimpan rusak diabaikan', () async {
      SharedPreferences.setMockInitialValues({
        DemoPaymentApi.storageKey: 'bukan json',
      });
      final api = DemoPaymentApi(clock: () => now);
      await api.attach(await SharedPreferences.getInstance());
      expect((await api.status('MP-1')).status, PaymentStatus.pending);
    });
  });

  group('alur pembeli', () {
    Future<void> pumpPayment(WidgetTester tester) async {
      login();
      store.addToCart(store.products[1]); // Filter Oli Rp 25.000
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const PaymentPage(
            customerName: 'Siti',
            shippingCost: 10000,
            address: 'Siti (0812)\nJl. A, Bandung',
          ),
        ),
      );
    }

    testWidgets('halaman pembayaran: QRIS dan COD, dengan catatan mode demo', (
      tester,
    ) async {
      await pumpPayment(tester);
      expect(find.byKey(const ValueKey('demo-notice')), findsOneWidget);
      expect(find.textContaining('Mode demo'), findsOneWidget);
      expect(find.text('QRIS'), findsWidgets);
      expect(find.text('COD'), findsOneWidget);
      expect(find.text('Virtual Account'), findsNothing);
      expect(find.text('E-Wallet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bayar QRIS: pesanan menunggu, QR dan panel demo tampil', (
      tester,
    ) async {
      final stock = Store().products[1].stock;
      await pumpPayment(tester);

      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);

      final order = store.orders.first;
      expect(order.status, Store.awaitingPaymentStatus);
      expect(order.paymentMethod, 'QRIS');
      expect(order.payment!.qrString, startsWith('MOTOPART-DEMO|'));
      expect(store.products[1].stock, stock - 1);
      expect(find.byType(PaymentWaitingPage), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byKey(const ValueKey('demo-panel')), findsOneWidget);
      expect(find.text('Simulasikan Pembayaran Berhasil'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'Simulasikan Pembayaran Berhasil: pesanan diproses, halaman sukses',
      (tester) async {
        await pumpPayment(tester);
        await tester.tap(find.text('Bayar Sekarang'));
        await settle(tester);
        final order = store.orders.first;

        await tester.tap(find.text('Simulasikan Pembayaran Berhasil'));
        await settle(tester);

        expect(order.status, 'Diproses');
        expect(find.byType(PaymentSuccessPage), findsOneWidget);
        expect(find.byType(PaymentWaitingPage), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('tanpa menekan tombol: pesanan tetap menunggu', (tester) async {
      await pumpPayment(tester);
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);
      await tester.pump(
        const Duration(seconds: 7),
      ); // dua kali pengecekan otomatis

      expect(store.orders.first.status, Store.awaitingPaymentStatus);
      expect(find.byType(PaymentWaitingPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('waktu habis: pesanan dibatalkan dan stok kembali', (
      tester,
    ) async {
      final stock = Store().products[1].stock;
      await pumpPayment(tester);
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);
      expect(store.products[1].stock, stock - 1);

      now = now.add(const Duration(minutes: 16));
      await tester.tap(find.text('Cek Status Pembayaran'));
      await settle(tester);

      expect(store.orders.first.status, Store.cancelledStatus);
      expect(store.products[1].stock, stock);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('simulasi setelah waktu habis ditolak dengan pesan', (
      tester,
    ) async {
      await pumpPayment(tester);
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);

      now = now.add(const Duration(minutes: 16));
      await tester.tap(find.text('Simulasikan Pembayaran Berhasil'));
      await settle(tester);

      expect(find.text('Waktu pembayaran sudah habis.'), findsOneWidget);
      expect(store.orders.first.status, isNot('Diproses'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('COD tetap langsung diproses tanpa panel demo', (tester) async {
      await pumpPayment(tester);
      await tester.tap(find.text('COD'));
      await tester.pump();
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);

      expect(store.orders.first.status, 'Diproses');
      expect(find.byKey(const ValueKey('demo-panel')), findsNothing);
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('panel demo tidak tampil bila memakai server (bukan demo)', (
      tester,
    ) async {
      PaymentMethods.demoOverride = false;
      paymentApi = FakePaymentApi();
      await pumpPayment(tester);
      expect(find.byKey(const ValueKey('demo-notice')), findsNothing);
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);
      expect(find.byType(PaymentWaitingPage), findsOneWidget);
      expect(find.byKey(const ValueKey('demo-panel')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('layar 320, teks besar: tanpa overflow di halaman menunggu', (
      tester,
    ) async {
      login();
      store.addToCart(store.products[1]);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const PaymentPage(
            customerName: 'Siti',
            shippingCost: 10000,
            address: 'Siti (0812)\nJl. A, Bandung',
          ),
        ),
      );
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);
      expect(find.byType(PaymentWaitingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
