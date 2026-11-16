import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'gateway.dart';
import 'midtrans_gateway.dart';
import 'models.dart';
import 'payment_repository.dart';

class ServiceException implements Exception {
  final int statusCode;
  final String message;
  const ServiceException(this.statusCode, this.message);

  @override
  String toString() => 'ServiceException($statusCode): $message';
}

/// Logika pembayaran: membuat tagihan, memeriksa status otomatis, dan
/// menerima notifikasi (webhook) dari Midtrans.
class PaymentService {
  final PaymentGateway gateway;
  final PaymentRepository repository;

  /// Batas bayar QRIS/GoPay dan Virtual Account (menit).
  final int qrExpiryMinutes;
  final int vaExpiryMinutes;

  /// Kunci server Midtrans untuk memverifikasi webhook; null = webhook mati.
  final String? webhookKey;
  final DateTime Function() _now;

  PaymentService({
    required this.gateway,
    required this.repository,
    this.qrExpiryMinutes = 15,
    this.vaExpiryMinutes = 60,
    this.webhookKey,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  int _expiryFor(PaymentType type) =>
      type == PaymentType.va ? vaExpiryMinutes : qrExpiryMinutes;

  /// Membuat pembayaran. Memanggil ulang dengan data yang sama (mis. karena
  /// koneksi terputus) mengembalikan pembayaran yang sudah ada.
  Future<Payment> create(PaymentRequest request) async {
    final existing = repository.find(request.id);
    if (existing != null) {
      final same =
          existing.type == request.type &&
          existing.amount == request.amount &&
          existing.provider == request.provider;
      if (!same) {
        throw const ServiceException(
          409,
          'Kode pesanan ini sudah dipakai untuk pembayaran lain.',
        );
      }
      return refresh(existing);
    }

    final minutes = _expiryFor(request.type);
    final GatewayCharge charge;
    try {
      charge = await gateway.charge(request, expiryMinutes: minutes);
    } on GatewayException catch (e) {
      throw ServiceException(502, e.message);
    }

    final now = _now();
    final payment = Payment(
      id: request.id,
      type: request.type,
      provider: request.provider,
      amount: request.amount,
      createdAt: now,
      expiresAt: charge.expiresAt ?? now.add(Duration(minutes: minutes)),
      qrString: charge.qrString,
      qrUrl: charge.qrUrl,
      vaNumber: charge.vaNumber,
      billerCode: charge.billerCode,
      billKey: charge.billKey,
    );
    repository.save(payment);
    return payment;
  }

  Payment? find(String id) => repository.find(id);

  /// Memeriksa status terbaru ke penyedia (jika masih menunggu) dan
  /// menyimpannya. Gangguan penyedia tidak mengubah status.
  Future<Payment> refresh(Payment payment) async {
    if (payment.status.isFinal) return payment;

    PaymentStatus? latest;
    try {
      latest = await gateway.status(payment.id);
    } on GatewayException {
      latest = null;
    }

    if (latest != null && latest != PaymentStatus.pending) {
      _finish(payment, latest);
    } else if (!_now().isBefore(payment.expiresAt)) {
      _finish(payment, PaymentStatus.expired);
    }
    return payment;
  }

  void _finish(Payment payment, PaymentStatus status) {
    payment.status = status;
    if (status == PaymentStatus.paid) payment.paidAt = _now();
    repository.save(payment);
  }

  /// Memproses notifikasi HTTP dari Midtrans. Melempar [ServiceException]
  /// jika tanda tangan salah atau pesanan tidak dikenal.
  Payment handleNotification(Map<String, dynamic> json) {
    final key = webhookKey;
    if (key == null) {
      throw const ServiceException(404, 'Webhook tidak aktif.');
    }

    final orderId = '${json['order_id']}';
    final expected = signature(
      orderId: orderId,
      statusCode: '${json['status_code']}',
      grossAmount: '${json['gross_amount']}',
      serverKey: key,
    );
    if ('${json['signature_key']}'.toLowerCase() != expected) {
      throw const ServiceException(403, 'Tanda tangan tidak valid.');
    }

    final payment = repository.find(orderId);
    if (payment == null) {
      throw const ServiceException(404, 'Pesanan tidak dikenal.');
    }
    if (!payment.status.isFinal) {
      final status = MidtransGateway.mapStatus(
        json['transaction_status'] as String?,
        json['fraud_status'] as String?,
      );
      if (status != PaymentStatus.pending) _finish(payment, status);
    }
    return payment;
  }

  /// signature_key Midtrans = SHA512(order_id + status_code + gross_amount +
  /// server key), heksadesimal huruf kecil.
  static String signature({
    required String orderId,
    required String statusCode,
    required String grossAmount,
    required String serverKey,
  }) => sha512
      .convert(utf8.encode('$orderId$statusCode$grossAmount$serverKey'))
      .toString();
}
