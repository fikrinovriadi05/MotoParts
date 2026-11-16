import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motopart_server/gateway.dart';
import 'package:motopart_server/handler.dart';
import 'package:motopart_server/midtrans_gateway.dart';
import 'package:motopart_server/mock_gateway.dart';
import 'package:motopart_server/models.dart';
import 'package:motopart_server/payment_repository.dart';
import 'package:motopart_server/payment_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Jam yang bisa dimajukan di tes.
class Clock {
  DateTime now = DateTime.utc(2026, 11, 16, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

Future<Response> send(
  Handler handler,
  String method,
  String path, [
  Object? body,
]) => Future.value(
  handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
    ),
  ),
);

Future<Map<String, dynamic>> bodyOf(Response r) async =>
    jsonDecode(await r.readAsString()) as Map<String, dynamic>;

Map<String, dynamic> qrisBody([String id = 'MP-1001', int amount = 55000]) => {
  'id': id,
  'type': 'qris',
  'amount': amount,
  'customerName': 'Siti',
};

void main() {
  group('mode simulasi (MockGateway)', () {
    late Clock clock;
    late MockGateway gateway;
    late PaymentService service;
    late Handler handler;

    setUp(() {
      clock = Clock();
      gateway = MockGateway(now: clock.call);
      service = PaymentService(
        gateway: gateway,
        repository: PaymentRepository(),
        now: clock.call,
      );
      handler = buildHandler(service);
    });

    test('health menyebut penyedia', () async {
      final r = await send(handler, 'GET', '/health');
      expect(r.statusCode, 200);
      expect(await bodyOf(r), {'status': 'ok', 'gateway': 'mock'});
    });

    test(
      'membuat pembayaran QRIS: pending dengan kode QR dan batas bayar',
      () async {
        final r = await send(handler, 'POST', '/payments', qrisBody());
        expect(r.statusCode, 201);

        final json = await bodyOf(r);
        expect(json['id'], 'MP-1001');
        expect(json['type'], 'qris');
        expect(json['status'], 'pending');
        expect(json['amount'], 55000);
        expect(json['qrString'], isNotEmpty);
        expect(
          DateTime.parse(json['expiresAt'] as String),
          clock.now.add(const Duration(minutes: 15)),
        );
      },
    );

    test(
      'Virtual Account: nomor VA; Mandiri: kode perusahaan dan kode bayar',
      () async {
        final bca = await bodyOf(
          await send(handler, 'POST', '/payments', {
            'id': 'MP-1002',
            'type': 'va',
            'provider': 'bca',
            'amount': 20000,
          }),
        );
        expect(bca['vaNumber'], startsWith('8800'));
        expect(bca['billKey'], isNull);
        expect(
          DateTime.parse(bca['expiresAt'] as String),
          clock.now.add(const Duration(minutes: 60)),
        );

        final mandiri = await bodyOf(
          await send(handler, 'POST', '/payments', {
            'id': 'MP-1003',
            'type': 'va',
            'provider': 'mandiri',
            'amount': 20000,
          }),
        );
        expect(mandiri['billerCode'], '70012');
        expect(mandiri['billKey'], isNotEmpty);
        expect(mandiri['vaNumber'], isNull);
      },
    );

    test('status berubah lunas setelah disimulasikan', () async {
      await send(handler, 'POST', '/payments', qrisBody());
      expect(
        (await bodyOf(
          await send(handler, 'GET', '/payments/MP-1001'),
        ))['status'],
        'pending',
      );

      final paid = await send(
        handler,
        'POST',
        '/payments/MP-1001/simulate-paid',
      );
      expect((await bodyOf(paid))['status'], 'paid');

      final after = await bodyOf(
        await send(handler, 'GET', '/payments/MP-1001'),
      );
      expect(after['status'], 'paid');
      expect(after['paidAt'], isNotNull);
    });

    test('lunas otomatis setelah beberapa detik (autoPayAfter)', () async {
      final auto = MockGateway(
        autoPayAfter: const Duration(seconds: 5),
        now: clock.call,
      );
      final h = buildHandler(
        PaymentService(
          gateway: auto,
          repository: PaymentRepository(),
          now: clock.call,
        ),
      );
      await send(h, 'POST', '/payments', qrisBody());

      clock.advance(const Duration(seconds: 4));
      expect(
        (await bodyOf(await send(h, 'GET', '/payments/MP-1001')))['status'],
        'pending',
      );
      clock.advance(const Duration(seconds: 2));
      expect(
        (await bodyOf(await send(h, 'GET', '/payments/MP-1001')))['status'],
        'paid',
      );
    });

    test('kedaluwarsa setelah batas bayar terlewati', () async {
      await send(handler, 'POST', '/payments', qrisBody());

      clock.advance(const Duration(minutes: 16));
      final r = await bodyOf(await send(handler, 'GET', '/payments/MP-1001'));
      expect(r['status'], 'expired');

      // Status akhir tidak berubah lagi.
      gateway.markPaid('MP-1001');
      expect(
        (await bodyOf(
          await send(handler, 'GET', '/payments/MP-1001'),
        ))['status'],
        'expired',
      );
    });

    test(
      'membuat ulang dengan data sama mengembalikan pembayaran yang sama',
      () async {
        final first = await bodyOf(
          await send(handler, 'POST', '/payments', qrisBody()),
        );
        final again = await send(handler, 'POST', '/payments', qrisBody());

        expect(again.statusCode, 201);
        expect((await bodyOf(again))['qrString'], first['qrString']);
      },
    );

    test('kode pesanan sama dengan jumlah berbeda ditolak (409)', () async {
      await send(handler, 'POST', '/payments', qrisBody());
      final r = await send(
        handler,
        'POST',
        '/payments',
        qrisBody('MP-1001', 99000),
      );

      expect(r.statusCode, 409);
    });

    test('validasi permintaan', () async {
      Future<void> bad(Object body, String message) async {
        final r = await send(handler, 'POST', '/payments', body);
        expect(r.statusCode, 400, reason: '$body');
        expect((await bodyOf(r))['error'], message);
      }

      await bad({...qrisBody(), 'id': 'a b'}, 'Kode pesanan tidak valid.');
      await bad({
        ...qrisBody(),
        'type': 'kartu',
      }, 'Jenis pembayaran tidak dikenal.');
      await bad({...qrisBody(), 'amount': 0}, 'Jumlah pembayaran tidak valid.');
      await bad({
        ...qrisBody(),
        'amount': '5000',
      }, 'Jumlah pembayaran tidak valid.');
      await bad({
        ...qrisBody(),
        'amount': 200000000,
      }, 'Jumlah pembayaran tidak valid.');
      await bad({
        ...qrisBody(),
        'type': 'va',
      }, 'Bank Virtual Account tidak didukung.');
      await bad({
        ...qrisBody(),
        'type': 'va',
        'provider': 'permata',
      }, 'Bank Virtual Account tidak didukung.');
      await bad({
        ...qrisBody(),
        'type': 'ewallet',
        'provider': 'ovo',
      }, 'Dompet digital tidak didukung.');
      await bad([1, 2], 'Isi permintaan tidak valid.');
    });

    test('isi bukan JSON ditolak', () async {
      final r = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/payments'),
          body: 'bukan json',
        ),
      );
      expect(r.statusCode, 400);
    });

    test('pembayaran tidak dikenal: 404', () async {
      expect((await send(handler, 'GET', '/payments/MP-0000')).statusCode, 404);
      expect(
        (await send(
          handler,
          'POST',
          '/payments/MP-0000/simulate-paid',
        )).statusCode,
        404,
      );
    });

    test('webhook mati di mode simulasi', () async {
      final r = await send(handler, 'POST', '/midtrans/notification', {
        'order_id': 'x',
      });
      expect(r.statusCode, 404);
    });
  });

  group('penyimpanan ke berkas', () {
    test('pembayaran bertahan setelah server dihidupkan ulang', () async {
      final dir = await Directory.systemTemp.createTemp('motopart_server_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/data/payments.json');

      final clock = Clock();
      final first = PaymentService(
        gateway: MockGateway(now: clock.call),
        repository: PaymentRepository(file: file),
        now: clock.call,
      );
      await first.create(
        PaymentRequest(id: 'MP-2001', type: PaymentType.qris, amount: 15000),
      );

      final second = PaymentService(
        gateway: MockGateway(now: clock.call),
        repository: PaymentRepository(file: file),
        now: clock.call,
      );
      final restored = second.find('MP-2001');
      expect(restored, isNotNull);
      expect(restored!.amount, 15000);
      expect(restored.qrString, isNotEmpty);
    });

    test('berkas rusak diabaikan', () {
      final dir = Directory.systemTemp.createTempSync('motopart_server_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/payments.json')
        ..writeAsStringSync('{rusak');

      expect(PaymentRepository(file: file).all, isEmpty);
    });
  });

  group('MidtransGateway', () {
    const key = 'SB-Mid-server-TESTKEY';

    MidtransGateway gateway(MockClient client, {bool production = false}) =>
        MidtransGateway(serverKey: key, production: production, client: client);

    test('nama dan alamat sandbox/produksi', () {
      expect(
        gateway(MockClient((_) async => http.Response('{}', 200))).name,
        'midtrans-sandbox',
      );
      expect(
        gateway(
          MockClient((_) async => http.Response('{}', 200)),
          production: true,
        ).name,
        'midtrans',
      );
    });

    test('QRIS: permintaan charge sesuai dokumentasi', () async {
      late http.Request sent;
      final g = gateway(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'status_code': '201',
              'status_message': 'QRIS transaction is created',
              'order_id': 'MP-1001',
              'qr_string': '000201010212...',
              'expiry_time': '2026-11-16 20:30:00',
              'actions': [
                {
                  'name': 'generate-qr-code',
                  'method': 'GET',
                  'url': 'https://api.sandbox.midtrans.com/v2/qris/abc/qr-code',
                },
              ],
            }),
            201,
          );
        }),
      );

      final charge = await g.charge(
        PaymentRequest(
          id: 'MP-1001',
          type: PaymentType.qris,
          amount: 55000,
          customerName: 'Siti',
        ),
        expiryMinutes: 15,
      );

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.sandbox.midtrans.com/v2/charge');
      expect(
        sent.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('$key:'))}',
      );
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['payment_type'], 'qris');
      expect(body['qris'], {'acquirer': 'gopay'});
      expect(body['transaction_details'], {
        'order_id': 'MP-1001',
        'gross_amount': 55000,
      });
      expect(body['custom_expiry'], {'expiry_duration': 15, 'unit': 'minute'});
      expect((body['item_details'] as List).single['price'], 55000);
      expect(body['customer_details'], {'first_name': 'Siti'});

      expect(charge.qrString, '000201010212...');
      expect(
        charge.qrUrl,
        'https://api.sandbox.midtrans.com/v2/qris/abc/qr-code',
      );
      // 20:30 WIB = 13:30 UTC
      expect(charge.expiresAt, DateTime.utc(2026, 11, 16, 13, 30));
    });

    test('QRIS tanpa qr_string: tetap ada alamat gambar QR', () async {
      final g = gateway(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status_code': '201',
              'actions': [
                {'name': 'generate-qr-code-v2', 'url': 'https://x/v4'},
                {'name': 'generate-qr-code', 'url': 'https://x/v2'},
              ],
            }),
            201,
          ),
        ),
      );
      final charge = await g.charge(
        PaymentRequest(id: 'MP-1', type: PaymentType.qris, amount: 1000),
        expiryMinutes: 15,
      );
      expect(charge.qrString, isNull);
      expect(charge.qrUrl, 'https://x/v2');
      expect(charge.expiresAt, isNull);
    });

    test('Virtual Account BCA/BNI/BRI: bank_transfer dan nomor VA', () async {
      late Map<String, dynamic> body;
      final g = gateway(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status_code': '201',
              'va_numbers': [
                {'bank': 'bni', 'va_number': '8123456789'},
              ],
            }),
            201,
          );
        }),
      );

      final charge = await g.charge(
        PaymentRequest(
          id: 'MP-5',
          type: PaymentType.va,
          provider: 'bni',
          amount: 25000,
        ),
        expiryMinutes: 60,
      );

      expect(body['payment_type'], 'bank_transfer');
      expect(body['bank_transfer'], {'bank': 'bni'});
      expect(charge.vaNumber, '8123456789');
    });

    test('Mandiri: echannel dengan kode perusahaan dan kode bayar', () async {
      late Map<String, dynamic> body;
      final g = gateway(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status_code': '201',
              'biller_code': '70012',
              'bill_key': '990000000260',
            }),
            201,
          );
        }),
      );

      final charge = await g.charge(
        PaymentRequest(
          id: 'MP-6',
          type: PaymentType.va,
          provider: 'mandiri',
          amount: 25000,
        ),
        expiryMinutes: 60,
      );

      expect(body['payment_type'], 'echannel');
      expect((body['echannel'] as Map)['bill_info1'], 'MotoPart');
      expect(charge.billerCode, '70012');
      expect(charge.billKey, '990000000260');
    });

    test('GoPay: payment_type gopay', () async {
      late Map<String, dynamic> body;
      final g = gateway(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'status_code': '201'}), 201);
        }),
      );

      await g.charge(
        PaymentRequest(
          id: 'MP-7',
          type: PaymentType.ewallet,
          provider: 'gopay',
          amount: 25000,
        ),
        expiryMinutes: 15,
      );

      expect(body['payment_type'], 'gopay');
      expect(body.containsKey('customer_details'), isFalse);
    });

    test('penolakan Midtrans menjadi GatewayException', () async {
      final g = gateway(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status_code': '401',
              'status_message': 'Access denied',
            }),
            401,
          ),
        ),
      );

      expect(
        g.charge(
          PaymentRequest(id: 'MP-1', type: PaymentType.qris, amount: 1000),
          expiryMinutes: 15,
        ),
        throwsA(
          isA<GatewayException>().having(
            (e) => e.message,
            'message',
            contains('Access denied'),
          ),
        ),
      );
    });

    test(
      'jaringan putus atau respons bukan JSON menjadi GatewayException',
      () async {
        final down = gateway(
          MockClient((_) async => throw http.ClientException('putus')),
        );
        expect(down.status('MP-1'), throwsA(isA<GatewayException>()));

        final html = gateway(
          MockClient((_) async => http.Response('<html>', 502)),
        );
        expect(html.status('MP-1'), throwsA(isA<GatewayException>()));
      },
    );

    test('status memanggil GET /v2/<id>/status', () async {
      late http.Request sent;
      final g = gateway(
        MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'status_code': '200',
              'transaction_status': 'settlement',
            }),
            200,
          );
        }),
      );

      expect(await g.status('MP-1001'), PaymentStatus.paid);
      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.sandbox.midtrans.com/v2/MP-1001/status',
      );
    });

    test('status 404 dianggap masih menunggu', () async {
      final g = gateway(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status_code': '404',
              'status_message': "Transaction doesn't exist.",
            }),
            200,
          ),
        ),
      );
      expect(await g.status('MP-1'), PaymentStatus.pending);
    });

    test('pemetaan status Midtrans', () {
      PaymentStatus map(String s, [String? fraud]) =>
          MidtransGateway.mapStatus(s, fraud);

      expect(map('settlement'), PaymentStatus.paid);
      expect(map('capture', 'accept'), PaymentStatus.paid);
      expect(map('capture'), PaymentStatus.paid);
      expect(map('capture', 'challenge'), PaymentStatus.pending);
      expect(map('pending'), PaymentStatus.pending);
      expect(map('authorize'), PaymentStatus.pending);
      expect(map('expire'), PaymentStatus.expired);
      expect(map('deny'), PaymentStatus.failed);
      expect(map('cancel'), PaymentStatus.failed);
      expect(map('failure'), PaymentStatus.failed);
      expect(map('status-baru'), PaymentStatus.pending);
      expect(MidtransGateway.mapStatus(null, null), PaymentStatus.pending);
    });
  });

  group('webhook Midtrans', () {
    const key = 'SB-Mid-server-TESTKEY';
    late Clock clock;
    late PaymentService service;
    late Handler handler;

    Map<String, dynamic> notification({
      String status = 'settlement',
      String code = '200',
      String amount = '55000.00',
      String? signature,
      String orderId = 'MP-1001',
    }) => {
      'order_id': orderId,
      'status_code': code,
      'gross_amount': amount,
      'transaction_status': status,
      'fraud_status': 'accept',
      'signature_key':
          signature ??
          PaymentService.signature(
            orderId: orderId,
            statusCode: code,
            grossAmount: amount,
            serverKey: key,
          ),
    };

    setUp(() async {
      clock = Clock();
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'status_code': '201', 'qr_string': 'QR'}),
          201,
        ),
      );
      service = PaymentService(
        gateway: MidtransGateway(serverKey: key, client: client),
        repository: PaymentRepository(),
        webhookKey: key,
        now: clock.call,
      );
      handler = buildHandler(service);
      await send(handler, 'POST', '/payments', qrisBody());
    });

    test('tanda tangan sama dengan SHA-512 dari order_id+status_code+gross_amount+kunci', () {
      expect(
        PaymentService.signature(
          orderId: 'order03',
          statusCode: '200',
          grossAmount: '275000.00',
          serverKey: 'KEY',
        ),
        'd916ce2d58c030a4f55197e59ec99098ff95fecd99570104f08473c737d09dbf'
        '35b865f1321ed6b875b3222d84f5dffc382b11a1894f0f2dbef4b3f358a7290b',
      );
      expect(
        PaymentService.signature(
          orderId: 'a',
          statusCode: 'b',
          grossAmount: 'c',
          serverKey: 'd',
        ).length,
        128,
      );
    });

    test('notifikasi settlement menandai pembayaran lunas', () async {
      final r = await send(
        handler,
        'POST',
        '/midtrans/notification',
        notification(),
      );
      expect(r.statusCode, 200);
      expect(service.find('MP-1001')!.status, PaymentStatus.paid);
      expect(service.find('MP-1001')!.paidAt, isNotNull);
    });

    test('notifikasi expire menandai kedaluwarsa', () async {
      await send(
        handler,
        'POST',
        '/midtrans/notification',
        notification(status: 'expire', code: '202'),
      );
      expect(service.find('MP-1001')!.status, PaymentStatus.expired);
    });

    test('tanda tangan salah ditolak (403) dan status tidak berubah', () async {
      final r = await send(
        handler,
        'POST',
        '/midtrans/notification',
        notification(signature: 'palsu'),
      );
      expect(r.statusCode, 403);
      expect(service.find('MP-1001')!.status, PaymentStatus.pending);
    });

    test('jumlah yang diubah membuat tanda tangan tidak cocok', () async {
      final tampered = notification()..['gross_amount'] = '1.00';
      final r = await send(handler, 'POST', '/midtrans/notification', tampered);
      expect(r.statusCode, 403);
    });

    test('pesanan tidak dikenal: 404', () async {
      final r = await send(
        handler,
        'POST',
        '/midtrans/notification',
        notification(orderId: 'MP-9999'),
      );
      expect(r.statusCode, 404);
    });

    test('status akhir tidak ditimpa notifikasi berikutnya', () async {
      await send(handler, 'POST', '/midtrans/notification', notification());
      await send(
        handler,
        'POST',
        '/midtrans/notification',
        notification(status: 'expire', code: '202'),
      );
      expect(service.find('MP-1001')!.status, PaymentStatus.paid);
    });

    test('GET status memeriksa ke Midtrans dan memperbarui', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'status_code': '201', 'qr_string': 'QR'}),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'status_code': '200',
            'transaction_status': 'settlement',
          }),
          200,
        );
      });
      final s = PaymentService(
        gateway: MidtransGateway(serverKey: key, client: client),
        repository: PaymentRepository(),
        now: clock.call,
      );
      final h = buildHandler(s);
      await send(h, 'POST', '/payments', qrisBody('MP-3001'));

      final r = await bodyOf(await send(h, 'GET', '/payments/MP-3001'));
      expect(r['status'], 'paid');
    });

    test(
      'gangguan Midtrans saat cek status: tetap pending, bukan error',
      () async {
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({'status_code': '201', 'qr_string': 'QR'}),
              201,
            );
          }
          throw http.ClientException('putus');
        });
        final s = PaymentService(
          gateway: MidtransGateway(serverKey: key, client: client),
          repository: PaymentRepository(),
          now: clock.call,
        );
        final h = buildHandler(s);
        await send(h, 'POST', '/payments', qrisBody('MP-3002'));

        final r = await send(h, 'GET', '/payments/MP-3002');
        expect(r.statusCode, 200);
        expect((await bodyOf(r))['status'], 'pending');
      },
    );

    test('Midtrans menolak charge: 502 dengan pesan', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status_code': '402',
            'status_message': 'Payment channel is not activated',
          }),
          200,
        ),
      );
      final h = buildHandler(
        PaymentService(
          gateway: MidtransGateway(serverKey: key, client: client),
          repository: PaymentRepository(),
          now: clock.call,
        ),
      );

      final r = await send(h, 'POST', '/payments', qrisBody('MP-4001'));
      expect(r.statusCode, 502);
      expect((await bodyOf(r))['error'], contains('not activated'));
    });
  });
}
