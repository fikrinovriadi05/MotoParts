import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'mock_gateway.dart';
import 'models.dart';
import 'payment_service.dart';

Response _json(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'Content-Type': 'application/json; charset=utf-8'},
);

Response _error(int status, String message) =>
    _json(status, {'error': message});

/// Rute HTTP server pembayaran.
///
/// - `GET  /health`
/// - `POST /payments` membuat pembayaran
/// - `GET  /payments/<id>` status (memeriksa ke penyedia secara otomatis)
/// - `POST /payments/<id>/simulate-paid` hanya mode simulasi (mock)
/// - `POST /midtrans/notification` webhook Midtrans
Handler buildHandler(PaymentService service) {
  final router = Router();

  router.get('/health', (Request request) {
    return _json(200, {'status': 'ok', 'gateway': service.gateway.name});
  });

  router.post('/payments', (Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException {
      return _error(400, 'Isi permintaan bukan JSON.');
    }

    final parsed = PaymentRequest.fromJson(body);
    final req = parsed.request;
    if (req == null) return _error(400, parsed.error!);

    try {
      final payment = await service.create(req);
      return _json(201, payment.toJson());
    } on ServiceException catch (e) {
      return _error(e.statusCode, e.message);
    }
  });

  router.get('/payments/<id>', (Request request, String id) async {
    final payment = service.find(id);
    if (payment == null) return _error(404, 'Pembayaran tidak ditemukan.');
    return _json(200, (await service.refresh(payment)).toJson());
  });

  router.post('/payments/<id>/simulate-paid', (
    Request request,
    String id,
  ) async {
    final gateway = service.gateway;
    if (gateway is! MockGateway) {
      return _error(404, 'Hanya tersedia di mode simulasi.');
    }
    final payment = service.find(id);
    if (payment == null) return _error(404, 'Pembayaran tidak ditemukan.');
    gateway.markPaid(id);
    return _json(200, (await service.refresh(payment)).toJson());
  });

  router.post('/midtrans/notification', (Request request) async {
    final Object? body;
    try {
      body = jsonDecode(await request.readAsString());
    } on FormatException {
      return _error(400, 'Isi permintaan bukan JSON.');
    }
    if (body is! Map<String, dynamic>) return _error(400, 'Isi tidak valid.');

    try {
      service.handleNotification(body);
      return _json(200, {'ok': true});
    } on ServiceException catch (e) {
      return _error(e.statusCode, e.message);
    }
  });

  return const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
}
