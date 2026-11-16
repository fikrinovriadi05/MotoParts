import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motopart/core/navigation.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/order_item.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:motopart/pages/admin/admin_orders_page.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/pages/user/orders_page.dart';
import 'package:motopart/pages/user/payment_page.dart';
import 'package:motopart/pages/user/payment_success_page.dart';
import 'package:motopart/pages/user/payment_waiting_page.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/order_timeline.dart';
import 'package:motopart/widgets/status_badge.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/fakes.dart';

late FakePaymentApi fake;

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
  userTabIndex.value = UserTab.home;
  fake = FakePaymentApi();
  paymentApi = fake;
}

void login() {
  auth.register(
    name: 'Siti Aminah',
    email: 'siti-pay@email.com',
    phone: '081234567890',
    password: 'rahasia1',
  );
  auth.login(
    email: 'siti-pay@email.com',
    password: 'rahasia1',
    role: AccountRole.user,
  );
}

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

/// Menunggu animasi halaman selesai. `pumpAndSettle` tidak dipakai di halaman
/// menunggu pembayaran karena ada timer pengecekan dan indikator yang berputar.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Mengakhiri tes: membuang halaman agar timer pengecekan otomatis berhenti.
Future<void> dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

/// Pesanan online yang menunggu pembayaran (Filter Oli Rp 25.000 + ongkir).
OrderItem awaitingOrder({
  Duration expiresIn = const Duration(minutes: 15),
  String type = 'qris',
  String? provider,
  String? qrString = 'QR-DATA',
  String? vaNumber,
  String? billerCode,
  String? billKey,
  DateTime Function()? clock,
}) {
  login();
  store.addToCart(store.products[1]);
  final code = store.newOrderCode();
  final info = PaymentInfo(
    paymentId: code,
    type: type,
    provider: provider,
    amount: 35000,
    qrString: qrString,
    vaNumber: vaNumber,
    billerCode: billerCode,
    billKey: billKey,
    expiresAt: (clock ?? DateTime.now)().add(expiresIn),
  );
  final label = switch (type) {
    'va' => 'Virtual Account - ${provider!.toUpperCase()}',
    'ewallet' => 'E-Wallet - GoPay',
    _ => 'QRIS',
  };
  expect(
    store.checkout(
      customer: 'Siti',
      shippingCost: 10000,
      address: 'Siti (0812)\nJl. A, Bandung',
      paymentMethod: label,
      payment: info,
      code: code,
    ),
    isTrue,
  );
  return store.orderByCode(code)!;
}

void main() {
  setUp(resetAll);
  tearDown(resetAll);

  group('Store: pesanan menunggu pembayaran', () {
    test(
      'checkout online: status menunggu, stok ditahan, keranjang kosong',
      () {
        login();
        final product = store.products[1];
        final before = product.stock;
        store.addToCart(product);
        store.addToCart(product);

        final code = store.newOrderCode();
        expect(code, startsWith('MP-'));
        final ok = store.checkout(
          customer: 'Siti',
          shippingCost: 10000,
          paymentMethod: 'QRIS',
          payment: PaymentInfo(paymentId: code, type: 'qris', amount: 60000),
          code: code,
        );

        expect(ok, isTrue);
        final order = store.orders.first;
        expect(order.code, code);
        expect(order.status, Store.awaitingPaymentStatus);
        expect(order.total, 60000);
        expect(order.payment!.paymentId, code);
        expect(product.stock, before - 2);
        expect(store.cart, isEmpty);
      },
    );

    test('checkout tanpa payment (COD) langsung Diproses', () {
      login();
      store.addToCart(store.products[1]);
      store.checkout(customer: 'Siti', shippingCost: 0, paymentMethod: 'COD');

      expect(store.orders.first.status, 'Diproses');
      expect(store.orders.first.payment, isNull);
    });

    test('markOrderPaid: menunggu -> Diproses, stok tidak berubah lagi', () {
      final order = awaitingOrder();
      final stock = store.products[1].stock;

      expect(store.markOrderPaid(order), isTrue);

      expect(order.status, 'Diproses');
      expect(store.products[1].stock, stock);
      expect(store.markOrderPaid(order), isFalse); // sudah bukan menunggu
    });

    test('cancelUnpaidOrder: Dibatalkan dan stok kembali', () {
      final before = Store().products[1].stock;
      final order = awaitingOrder();
      expect(store.products[1].stock, before - 1);

      expect(store.cancelUnpaidOrder(order), isTrue);

      expect(order.status, Store.cancelledStatus);
      expect(store.products[1].stock, before);
      expect(store.cancelUnpaidOrder(order), isFalse);
    });

    test(
      'pesanan yang sudah Diproses tidak bisa dibatalkan lewat cancelUnpaid',
      () {
        final order = awaitingOrder();
        store.markOrderPaid(order);

        expect(store.cancelUnpaidOrder(order), isFalse);
        expect(order.status, 'Diproses');
      },
    );

    test('penjualan hanya menghitung pesanan yang sudah dibayar', () {
      final base = store.totalSales;
      final baseUnits = store.totalUnitsSold;
      final order = awaitingOrder();

      expect(store.totalSales, base);
      expect(store.totalUnitsSold, baseUnits);
      expect(store.salesOrders, isNot(contains(order)));

      store.markOrderPaid(order);

      expect(store.totalSales, base + 35000);
      expect(store.totalUnitsSold, baseUnits + 1);
      expect(store.salesOrders, contains(order));
    });

    test('pendingPaymentOrders: hanya akun aktif dan yang punya tagihan', () {
      final mine = awaitingOrder();
      store.orders.add(
        OrderItem(
          code: 'MP-LAIN',
          customer: 'Lain',
          total: 1,
          status: Store.awaitingPaymentStatus,
          accountId: 'orang-lain',
          payment: const PaymentInfo(
            paymentId: 'MP-LAIN',
            type: 'qris',
            amount: 1,
          ),
        ),
      );
      store.orders.add(
        OrderItem(
          code: 'MP-TANPA',
          customer: 'Siti',
          total: 1,
          status: Store.awaitingPaymentStatus,
          accountId: store.currentAccountId,
        ),
      );

      expect(store.pendingPaymentOrders, [mine]);
    });

    test('status "Menunggu Pembayaran" ada di daftar status admin', () {
      expect(Store.orderStatuses.first, 'Menunggu Pembayaran');
      expect(Store.orderStatuses, contains('Diproses'));
    });

    test('pembatalan manual oleh admin juga mengembalikan stok', () {
      final before = Store().products[1].stock;
      final order = awaitingOrder();

      store.updateOrderStatus(order, Store.cancelledStatus);

      expect(store.products[1].stock, before);
    });

    test('orderByCode', () {
      final order = awaitingOrder();
      expect(store.orderByCode(order.code), same(order));
      expect(store.orderByCode('tidak-ada'), isNull);
    });
  });

  group('Store.refreshPendingPayments', () {
    test(
      'lunas -> Diproses; kedaluwarsa/gagal -> Dibatalkan; pending tetap',
      () async {
        final paid = awaitingOrder();
        store.addToCart(store.products[2]);
        final expiredCode = store.newOrderCode(
          DateTime.now().add(const Duration(seconds: 1)),
        );
        store.checkout(
          customer: 'Siti',
          shippingCost: 0,
          code: expiredCode,
          payment: PaymentInfo(
            paymentId: expiredCode,
            type: 'qris',
            amount: 32000,
          ),
        );
        store.addToCart(store.products[3]);
        final failedCode = store.newOrderCode(
          DateTime.now().add(const Duration(seconds: 2)),
        );
        store.checkout(
          customer: 'Siti',
          shippingCost: 0,
          code: failedCode,
          payment: PaymentInfo(
            paymentId: failedCode,
            type: 'qris',
            amount: 85000,
          ),
        );
        store.addToCart(store.products[4]);
        final pendingCode = store.newOrderCode(
          DateTime.now().add(const Duration(seconds: 3)),
        );
        store.checkout(
          customer: 'Siti',
          shippingCost: 0,
          code: pendingCode,
          payment: PaymentInfo(paymentId: pendingCode, type: 'qris', amount: 1),
        );

        fake.statuses[paid.code] = PaymentStatus.paid;
        fake.statuses[expiredCode] = PaymentStatus.expired;
        fake.statuses[failedCode] = PaymentStatus.failed;

        final changed = await store.refreshPendingPayments(fake);

        expect(changed, 3);
        expect(paid.status, 'Diproses');
        expect(store.orderByCode(expiredCode)!.status, Store.cancelledStatus);
        expect(store.orderByCode(failedCode)!.status, Store.cancelledStatus);
        expect(
          store.orderByCode(pendingCode)!.status,
          Store.awaitingPaymentStatus,
        );
      },
    );

    test('gangguan server diabaikan: status tidak berubah', () async {
      final order = awaitingOrder();
      fake.failure = const PaymentApiException('putus');

      expect(await store.refreshPendingPayments(fake), 0);

      expect(order.status, Store.awaitingPaymentStatus);
    });

    test('tanpa pesanan menunggu: server tidak dihubungi', () async {
      login();
      expect(await store.refreshPendingPayments(fake), 0);
      expect(fake.statusCalls, isEmpty);
    });
  });

  group('OrderItem + PaymentInfo', () {
    test('JSON bolak-balik, termasuk tagihan', () {
      final order = awaitingOrder(
        type: 'va',
        provider: 'bca',
        qrString: null,
        vaNumber: '8800123',
      );

      final copy = OrderItem.fromJson(
        jsonDecode(jsonEncode(order.toJson())) as Map<String, dynamic>,
      );

      expect(copy.status, Store.awaitingPaymentStatus);
      expect(copy.payment!.paymentId, order.code);
      expect(copy.payment!.vaNumber, '8800123');
      expect(copy.payment!.provider, 'bca');
      expect(copy.payment!.expiresAt, order.payment!.expiresAt!.toLocal());
      expect(copy.payment!.hasQr, isFalse);
    });

    test('pesanan lama tanpa tagihan tetap terbaca', () {
      final old = OrderItem.fromJson({
        'code': 'MP-1',
        'customer': 'Siti',
        'total': 1,
        'status': 'Selesai',
      });
      expect(old.payment, isNull);
    });

    test('isExpired dan hasQr', () {
      final now = DateTime(2026, 11, 16, 12);
      final info = PaymentInfo(
        paymentId: 'MP-1',
        type: 'qris',
        amount: 1,
        qrUrl: 'https://x/qr.png',
        expiresAt: now,
      );
      expect(info.hasQr, isTrue);
      expect(info.isExpired(now), isTrue);
      expect(info.isExpired(now.subtract(const Duration(seconds: 1))), isFalse);
      expect(
        const PaymentInfo(paymentId: 'a', type: 'va', amount: 1).isExpired(now),
        isFalse,
      );
    });

    test('PaymentStatus.parse', () {
      expect(PaymentStatus.parse('paid'), PaymentStatus.paid);
      expect(PaymentStatus.parse('expired'), PaymentStatus.expired);
      expect(PaymentStatus.parse('aneh'), PaymentStatus.pending);
      expect(PaymentStatus.parse(null), PaymentStatus.pending);
      expect(PaymentStatus.pending.isFinal, isFalse);
      expect(PaymentStatus.failed.isFinal, isTrue);
    });
  });

  group('HttpPaymentApi', () {
    Map<String, dynamic> body(http.Request r) =>
        jsonDecode(r.body) as Map<String, dynamic>;

    Map<String, dynamic> serverJson({String status = 'pending'}) => {
      'id': 'MP-1001',
      'type': 'qris',
      'provider': null,
      'amount': 55000,
      'status': status,
      'createdAt': '2026-11-16T12:00:00.000Z',
      'expiresAt': '2026-11-16T12:15:00.000Z',
      'qrString': '0002010212',
    };

    test('create: POST /payments dengan isi sesuai pilihan', () async {
      late http.Request sent;
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://server.test:8080/',
        client: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(serverJson()), 201);
        }),
      );

      final snapshot = await api.create(
        orderCode: 'MP-1001',
        choice: PaymentMethods.decode('Virtual Account|BNI')!,
        amount: 55000,
        customerName: 'Siti',
      );

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'http://server.test:8080/payments');
      expect(body(sent), {
        'id': 'MP-1001',
        'type': 'va',
        'provider': 'bni',
        'amount': 55000,
        'customerName': 'Siti',
      });
      expect(snapshot.status, PaymentStatus.pending);
      expect(snapshot.info.paymentId, 'MP-1001');
      expect(snapshot.info.qrString, '0002010212');
      expect(
        snapshot.info.expiresAt,
        DateTime.utc(2026, 11, 16, 12, 15).toLocal(),
      );
    });

    test('create QRIS: tanpa field provider', () async {
      late http.Request sent;
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(serverJson()), 201);
        }),
      );

      await api.create(
        orderCode: 'MP-1001',
        choice: PaymentMethods.defaultChoice,
        amount: 55000,
      );

      expect(body(sent).containsKey('provider'), isFalse);
      expect(body(sent)['type'], 'qris');
    });

    test('status: GET /payments/<id> dan status lunas', () async {
      late http.Request sent;
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(serverJson(status: 'paid')), 200);
        }),
      );

      final snapshot = await api.status('MP-1001');

      expect(sent.method, 'GET');
      expect(sent.url.path, '/payments/MP-1001');
      expect(snapshot.status, PaymentStatus.paid);
    });

    test('pesan kesalahan dari server diteruskan', () async {
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Jumlah pembayaran tidak valid.'}),
            400,
          ),
        ),
      );

      await expectLater(
        api.create(
          orderCode: 'MP-1',
          choice: PaymentMethods.defaultChoice,
          amount: 0,
        ),
        throwsA(
          isA<PaymentApiException>()
              .having(
                (e) => e.message,
                'message',
                'Jumlah pembayaran tidak valid.',
              )
              .having((e) => e.notFound, 'notFound', isFalse),
        ),
      );
    });

    test('404 menandai notFound', () async {
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Pembayaran tidak ditemukan.'}),
            404,
          ),
        ),
      );

      await expectLater(
        api.status('MP-1'),
        throwsA(
          isA<PaymentApiException>().having(
            (e) => e.notFound,
            'notFound',
            isTrue,
          ),
        ),
      );
    });

    test('server mati atau lambat: pesan ramah', () async {
      final down = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );
      await expectLater(
        down.status('MP-1'),
        throwsA(
          isA<PaymentApiException>().having(
            (e) => e.message,
            'message',
            contains('Tidak dapat terhubung ke server pembayaran'),
          ),
        ),
      );

      final slow = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        slow.status('MP-1'),
        throwsA(isA<PaymentApiException>()),
      );
    });

    test('respons bukan JSON atau rusak', () async {
      final html = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient((_) async => http.Response('<html>', 502)),
      );
      await expectLater(
        html.status('MP-1'),
        throwsA(
          isA<PaymentApiException>().having(
            (e) => e.message,
            'message',
            contains('502'),
          ),
        ),
      );

      final broken = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'foo': 1}), 200),
        ),
      );
      await expectLater(
        broken.status('MP-1'),
        throwsA(isA<PaymentApiException>()),
      );
    });

    test('COD tidak bisa dibuat lewat server', () {
      final api = HttpPaymentApi(
        baseUrlOverride: 'http://s',
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(
        () => api.create(
          orderCode: 'MP-1',
          choice: PaymentMethods.decode('COD')!,
          amount: 1000,
        ),
        throwsArgumentError,
      );
    });

    test(
      'alamat server bawaan: emulator Android 10.0.2.2, lainnya localhost',
      () {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(PaymentConfig.baseUrl, 'http://10.0.2.2:8080');
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(PaymentConfig.baseUrl, 'http://localhost:8080');
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        expect(PaymentConfig.baseUrl, 'http://localhost:8080');
      },
    );
  });

  group('PaymentPage: bayar online', () {
    Future<void> pumpPayment(WidgetTester tester, {String? favorite}) async {
      login();
      if (favorite != null) auth.setPreferredPayment(favorite);
      store.addToCart(store.products[1]); // Filter Oli Rp 25.000
      bigScreen(tester);
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

    testWidgets(
      'QRIS: tagihan dibuat di server, pesanan menunggu, halaman QR tampil',
      (tester) async {
        final before = Store().products[1].stock;
        await pumpPayment(tester);

        await tester.tap(find.text('Bayar Sekarang'));
        await settle(tester);

        expect(fake.created, hasLength(1));
        expect(fake.created.single.type, 'qris');
        expect(fake.created.single.amount, 35000);
        final order = store.orders.first;
        expect(order.status, Store.awaitingPaymentStatus);
        expect(order.code, fake.created.single.paymentId);
        expect(order.paymentMethod, 'QRIS');
        expect(order.address, contains('Jl. A, Bandung'));
        expect(store.products[1].stock, before - 1);
        expect(store.cart, isEmpty);

        expect(find.byType(PaymentWaitingPage), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        await dispose(tester);
      },
    );

    testWidgets('Virtual Account BCA: nomor VA tampil dan bisa disalin', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpPayment(tester);

      await tester.tap(find.text('Virtual Account'));
      await tester.pump();
      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);

      expect(fake.created.single.type, 'va');
      expect(fake.created.single.provider, 'bca');
      expect(store.orders.first.paymentMethod, 'Virtual Account - BCA');
      expect(find.text('Virtual Account BCA'), findsOneWidget);
      expect(find.text('88001234567890'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      await tester.tap(find.byTooltip('Salin Nomor Virtual Account'));
      await tester.pump();
      expect(copied, '88001234567890');
      expect(find.text('Nomor Virtual Account disalin.'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets(
      'Virtual Account Mandiri: kode perusahaan dan kode pembayaran',
      (tester) async {
        await pumpPayment(tester, favorite: 'Virtual Account|Mandiri');

        await tester.tap(find.text('Bayar Sekarang'));
        await settle(tester);

        expect(find.text('Kode Perusahaan'), findsOneWidget);
        expect(find.text('70012'), findsOneWidget);
        expect(find.text('Kode Pembayaran'), findsOneWidget);
        expect(find.text('990000000260'), findsOneWidget);
        await dispose(tester);
      },
    );

    testWidgets('GoPay: kode QR dan petunjuk aplikasi GoPay', (tester) async {
      await pumpPayment(tester, favorite: 'E-Wallet|GoPay');

      await tester.tap(find.text('Bayar Sekarang'));
      await settle(tester);

      expect(fake.created.single.type, 'ewallet');
      expect(fake.created.single.provider, 'gopay');
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('aplikasi GoPay'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets(
      'server mati: pesan, tanpa pesanan, keranjang utuh, bisa coba lagi',
      (tester) async {
        await pumpPayment(tester);
        fake.failure = const PaymentApiException(
          'Tidak dapat terhubung ke server pembayaran. Periksa koneksi internet '
          'dan pastikan server berjalan.',
        );
        final ordersBefore = store.orders.length;

        await tester.tap(find.text('Bayar Sekarang'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Tidak dapat terhubung ke server pembayaran'),
          findsOneWidget,
        );
        expect(store.orders.length, ordersBefore);
        expect(store.cart, hasLength(1));
        expect(find.byType(PaymentWaitingPage), findsNothing);
        expect(find.byType(PaymentPage), findsOneWidget);

        // Server pulih: tombol aktif lagi dan pembayaran berhasil dibuat.
        fake.failure = null;
        await tester.tap(find.text('Bayar Sekarang'));
        await settle(tester);
        expect(find.byType(PaymentWaitingPage), findsOneWidget);
        await dispose(tester);
      },
    );

    testWidgets('server menolak: pesan dari server ditampilkan', (
      tester,
    ) async {
      await pumpPayment(tester);
      fake.failure = const PaymentApiException(
        'Midtrans menolak pembayaran (402).',
      );

      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      expect(find.text('Midtrans menolak pembayaran (402).'), findsOneWidget);
      expect(store.cart, hasLength(1));
    });

    testWidgets('COD: tidak menghubungi server, langsung Diproses', (
      tester,
    ) async {
      await pumpPayment(tester);

      await tester.tap(find.text('COD'));
      await tester.pump();
      await tester.tap(find.text('Bayar Sekarang'));
      await tester.pumpAndSettle();

      expect(fake.created, isEmpty);
      expect(store.orders.first.status, 'Diproses');
      expect(store.orders.first.paymentMethod, 'COD');
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
    });

    testWidgets(
      'stok habis saat menunggu server: tidak ada pesanan, keranjang disesuaikan',
      (tester) async {
        login();
        store.addToCart(store.products[1]);
        store.products[1].stock = 5;
        // Pembeli lain menghabiskan stok setelah tagihan dibuat.
        paymentApi = _HookedApi(
          fake,
          onCreate: () => store.products[1].stock = 0,
        );
        bigScreen(tester);
        // Keranjang -> Checkout -> Pembayaran, seperti di aplikasi.
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentPage(
                                customerName: 'Siti',
                                shippingCost: 0,
                              ),
                            ),
                          ),
                          child: const Text('buka halaman'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('root'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('root'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('buka halaman'));
        await tester.pumpAndSettle();
        final ordersBefore = store.orders.length;

        await tester.tap(find.text('Bayar Sekarang'));
        await tester.pumpAndSettle();

        expect(store.orders.length, ordersBefore);
        expect(find.byType(PaymentWaitingPage), findsNothing);
        expect(find.byType(PaymentSuccessPage), findsNothing);
        expect(find.byType(PaymentPage), findsNothing);
        expect(find.textContaining('sudah habis'), findsOneWidget);
        expect(store.cart, isEmpty); // stok 0: item dikeluarkan dari keranjang
      },
    );
  });

  group('PaymentWaitingPage', () {
    testWidgets('menampilkan total, metode, status, dan hitung mundur', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 16, 12);
      final order = awaitingOrder(
        expiresIn: const Duration(minutes: 14, seconds: 32),
        clock: () => now,
      );
      bigScreen(tester);

      await tester.pumpWidget(
        app(PaymentWaitingPage(orderCode: order.code, clock: () => now)),
      );
      await tester.pump();

      expect(find.text(order.code), findsOneWidget);
      expect(find.text('Rp 35.000'), findsOneWidget);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Menunggu Pembayaran'), findsWidgets);
      expect(find.text('Bayar dalam 14:32'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('hitung mundur berjalan dan berhenti di 00:00', (tester) async {
      var now = DateTime(2026, 11, 16, 12);
      final order = awaitingOrder(
        expiresIn: const Duration(seconds: 3),
        clock: () => now,
      );
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          PaymentWaitingPage(
            orderCode: order.code,
            clock: () => now,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      expect(find.text('Bayar dalam 00:03'), findsOneWidget);

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Bayar dalam 00:01'), findsOneWidget);

      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Bayar dalam 00:00'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets(
      'dicek otomatis: setelah server menyatakan lunas pindah ke halaman sukses',
      (tester) async {
        final order = awaitingOrder();
        bigScreen(tester);
        await tester.pumpWidget(
          app(
            PaymentWaitingPage(
              orderCode: order.code,
              pollInterval: const Duration(seconds: 3),
            ),
          ),
        );
        await tester.pump(); // pengecekan pertama
        expect(find.byType(PaymentSuccessPage), findsNothing);
        expect(order.status, Store.awaitingPaymentStatus);

        fake.statuses[order.code] = PaymentStatus.paid;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        expect(order.status, 'Diproses');
        expect(find.byType(PaymentSuccessPage), findsOneWidget);
        expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
        expect(
          find.text('QRIS'),
          findsOneWidget,
        ); // metode tampil di halaman sukses
        await dispose(tester);
      },
    );

    testWidgets('pengecekan berulang selama masih pending', (tester) async {
      final order = awaitingOrder();
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          PaymentWaitingPage(
            orderCode: order.code,
            pollInterval: const Duration(seconds: 3),
          ),
        ),
      );
      await tester.pump();
      final first = fake.statusCalls.length;

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));

      expect(fake.statusCalls.length, greaterThanOrEqualTo(first + 2));
      expect(fake.statusCalls.every((id) => id == order.code), isTrue);
      expect(order.status, Store.awaitingPaymentStatus);
      await dispose(tester);
    });

    testWidgets(
      'kedaluwarsa: pesanan dibatalkan, stok kembali, pengecekan berhenti',
      (tester) async {
        final before = Store().products[1].stock;
        final order = awaitingOrder();
        expect(store.products[1].stock, before - 1);
        fake.statuses[order.code] = PaymentStatus.expired;
        bigScreen(tester);

        await tester.pumpWidget(app(PaymentWaitingPage(orderCode: order.code)));
        await tester.pump();
        await tester.pump();

        expect(order.status, Store.cancelledStatus);
        expect(store.products[1].stock, before);
        expect(find.textContaining('Waktu pembayaran habis'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
        expect(find.text('Kembali ke Beranda'), findsOneWidget);

        final calls = fake.statusCalls.length;
        await tester.pump(const Duration(seconds: 10));
        expect(fake.statusCalls.length, calls);
        await dispose(tester);
      },
    );

    testWidgets('server mati: peringatan tampil, lalu pulih sendiri', (
      tester,
    ) async {
      final order = awaitingOrder();
      fake.failure = const PaymentApiException(
        'Tidak dapat terhubung ke server pembayaran.',
      );
      bigScreen(tester);

      await tester.pumpWidget(
        app(
          PaymentWaitingPage(
            orderCode: order.code,
            pollInterval: const Duration(seconds: 2),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('Tidak dapat terhubung ke server pembayaran.'),
        findsOneWidget,
      );
      expect(find.textContaining('dicoba lagi otomatis'), findsOneWidget);
      expect(order.status, Store.awaitingPaymentStatus);

      fake.failure = null;
      fake.statuses[order.code] = PaymentStatus.paid;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(order.status, 'Diproses');
      expect(find.byType(PaymentSuccessPage), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('Cek Status Pembayaran manual: belum dibayar', (tester) async {
      final order = awaitingOrder();
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          PaymentWaitingPage(
            orderCode: order.code,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Cek Status Pembayaran'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Pembayaran belum diterima.'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('Bayar Nanti kembali; pesanan tetap menunggu', (tester) async {
      final order = awaitingOrder();
      bigScreen(tester);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentWaitingPage(
                    orderCode: order.code,
                    pollInterval: const Duration(hours: 1),
                  ),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await settle(tester);

      await tester.tap(find.text('Bayar Nanti'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentWaitingPage), findsNothing);
      expect(order.status, Store.awaitingPaymentStatus);
    });

    testWidgets(
      'pesanan sudah lunas sebelum halaman dibuka: langsung ke sukses',
      (tester) async {
        final order = awaitingOrder();
        store.markOrderPaid(order);
        bigScreen(tester);

        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentWaitingPage(orderCode: order.code),
                  ),
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('buka'));
        await tester.pumpAndSettle();

        expect(find.byType(PaymentSuccessPage), findsOneWidget);
        await dispose(tester);
      },
    );

    testWidgets('pesanan tidak ditemukan', (tester) async {
      bigScreen(tester);
      await tester.pumpWidget(app(const PaymentWaitingPage(orderCode: 'MP-X')));
      await tester.pump();

      expect(find.text('Pesanan tidak ditemukan.'), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('tagihan dengan gambar QR dari URL (tanpa qr_string)', (
      tester,
    ) async {
      final order = awaitingOrder(qrString: null);
      // Ganti tagihan: hanya qrUrl.
      final index = store.orders.indexOf(order);
      store.orders[index] = OrderItem(
        code: order.code,
        customer: order.customer,
        total: order.total,
        status: order.status,
        accountId: order.accountId,
        payment: PaymentInfo(
          paymentId: order.code,
          type: 'qris',
          amount: 35000,
          qrUrl: 'https://example.invalid/qr.png',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      );
      bigScreen(tester);

      await tester.pumpWidget(
        app(
          PaymentWaitingPage(
            orderCode: order.code,
            pollInterval: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      await dispose(tester);
    });
  });

  group('tidak ada overflow di layar kecil (320x568, teks 1.3x)', () {
    final variants = <String, OrderItem Function()>{
      'QRIS': () => awaitingOrder(),
      'Virtual Account': () => awaitingOrder(
        type: 'va',
        provider: 'bca',
        qrString: null,
        vaNumber: '88001234567890123',
      ),
      'Mandiri': () => awaitingOrder(
        type: 'va',
        provider: 'mandiri',
        qrString: null,
        billerCode: '70012',
        billKey: '990000000260123',
      ),
      'dibatalkan': () {
        final order = awaitingOrder();
        store.cancelUnpaidOrder(order);
        return order;
      },
    };

    for (final entry in variants.entries) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('menunggu pembayaran ${entry.key} (${mode.name})', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final order = entry.value();

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: PaymentWaitingPage(
                orderCode: order.code,
                pollInterval: const Duration(hours: 1),
              ),
            ),
          );
          await settle(tester);

          expect(tester.takeException(), isNull);
          await dispose(tester);
        });
      }
    }
  });

  group('Detail dan daftar pesanan menunggu pembayaran', () {
    testWidgets('detail: banner status dan tombol Lanjutkan Pembayaran', (
      tester,
    ) async {
      final order = awaitingOrder();
      bigScreen(tester);
      await tester.pumpWidget(app(OrderDetailPage(order: order)));

      expect(find.text('Menunggu Pembayaran'), findsOneWidget); // lencana
      expect(
        find.text('Menunggu pembayaran. Pesanan diproses setelah dibayar.'),
        findsOneWidget,
      );
      expect(find.text('Lanjutkan Pembayaran'), findsOneWidget);

      await tester.tap(find.text('Lanjutkan Pembayaran'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PaymentWaitingPage), findsOneWidget);
      await dispose(tester);
    });

    testWidgets('detail untuk admin: tanpa tombol pembayaran', (tester) async {
      final order = awaitingOrder();
      bigScreen(tester);
      await tester.pumpWidget(
        app(OrderDetailPage(order: order, isAdmin: true)),
      );

      expect(find.text('Lanjutkan Pembayaran'), findsNothing);
      expect(find.text('Ubah Status'), findsOneWidget);
    });

    testWidgets('detail pesanan yang sudah dibayar: tanpa tombol pembayaran', (
      tester,
    ) async {
      final order = awaitingOrder();
      store.markOrderPaid(order);
      bigScreen(tester);
      await tester.pumpWidget(app(OrderDetailPage(order: order)));

      expect(find.text('Lanjutkan Pembayaran'), findsNothing);
      expect(find.byType(OrderTimeline), findsOneWidget);
    });

    testWidgets('riwayat: status diperbarui otomatis saat halaman dibuka', (
      tester,
    ) async {
      final order = awaitingOrder();
      fake.statuses[order.code] = PaymentStatus.paid;
      bigScreen(tester);

      await tester.pumpWidget(app(const OrdersPage()));
      expect(find.text('Menunggu Pembayaran'), findsOneWidget);
      await tester.pump();
      await tester.pump();

      expect(order.status, 'Diproses');
      expect(find.text('Menunggu Pembayaran'), findsNothing);
      expect(find.text('Diproses'), findsOneWidget);
    });

    testWidgets('lencana status menunggu pembayaran', (tester) async {
      await tester.pumpWidget(
        app(const Scaffold(body: StatusBadge(Store.awaitingPaymentStatus))),
      );
      expect(find.text('Menunggu Pembayaran'), findsOneWidget);
      expect(
        orderStatusIcon(Store.awaitingPaymentStatus),
        Icons.schedule_rounded,
      );
    });

    testWidgets('admin: filter status Menunggu Pembayaran', (tester) async {
      awaitingOrder();
      auth.logout();
      bigScreen(tester);
      await tester.pumpWidget(app(const AdminOrdersPage()));

      expect(
        find.text('Menunggu Pembayaran (1)', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}

/// Pembungkus API yang menjalankan [onCreate] setelah tagihan dibuat.
class _HookedApi implements PaymentApi {
  final PaymentApi inner;
  final void Function() onCreate;

  _HookedApi(this.inner, {required this.onCreate});

  @override
  Future<PaymentSnapshot> create({
    required String orderCode,
    required PaymentChoice choice,
    required int amount,
    String customerName = '',
  }) async {
    final snapshot = await inner.create(
      orderCode: orderCode,
      choice: choice,
      amount: amount,
      customerName: customerName,
    );
    onCreate();
    return snapshot;
  }

  @override
  Future<PaymentSnapshot> status(String paymentId) => inner.status(paymentId);
}
