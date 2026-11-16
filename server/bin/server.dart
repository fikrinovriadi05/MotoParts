import 'dart:io';

import 'package:motopart_server/gateway.dart';
import 'package:motopart_server/handler.dart';
import 'package:motopart_server/midtrans_gateway.dart';
import 'package:motopart_server/mock_gateway.dart';
import 'package:motopart_server/payment_repository.dart';
import 'package:motopart_server/payment_service.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Server pembayaran MotoPart. Pengaturan lewat variabel lingkungan:
///
/// - `PORT` (bawaan 8080)
/// - `MIDTRANS_SERVER_KEY` kunci server Midtrans; kosong = mode simulasi
/// - `MIDTRANS_ENV` `production` untuk Midtrans sungguhan (bawaan sandbox)
/// - `MOCK_AUTO_PAY_SECONDS` mode simulasi: otomatis lunas setelah N detik
/// - `QR_EXPIRY_MINUTES` (15) dan `VA_EXPIRY_MINUTES` (60)
/// - `DATA_FILE` berkas data (bawaan data/payments.json)
Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final key = (env['MIDTRANS_SERVER_KEY'] ?? '').trim();

  final PaymentGateway gateway;
  if (key.isEmpty) {
    final seconds = int.tryParse(env['MOCK_AUTO_PAY_SECONDS'] ?? '');
    gateway = MockGateway(
      autoPayAfter: seconds == null || seconds <= 0
          ? null
          : Duration(seconds: seconds),
    );
  } else {
    gateway = MidtransGateway(
      serverKey: key,
      production: env['MIDTRANS_ENV'] == 'production',
    );
  }

  final service = PaymentService(
    gateway: gateway,
    repository: PaymentRepository(
      file: File(env['DATA_FILE'] ?? 'data/payments.json'),
    ),
    qrExpiryMinutes: int.tryParse(env['QR_EXPIRY_MINUTES'] ?? '') ?? 15,
    vaExpiryMinutes: int.tryParse(env['VA_EXPIRY_MINUTES'] ?? '') ?? 60,
    webhookKey: key.isEmpty ? null : key,
  );

  final server = await io.serve(
    buildHandler(service),
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln(
    'Server pembayaran MotoPart di http://localhost:${server.port}',
  );
  stdout.writeln('Penyedia: ${gateway.name}');
  if (gateway is MockGateway) {
    stdout.writeln(
      'Mode SIMULASI: tidak ada uang/akun sungguhan. Lunasi lewat '
      'POST /payments/<id>/simulate-paid atau set MOCK_AUTO_PAY_SECONDS.',
    );
  }
}
