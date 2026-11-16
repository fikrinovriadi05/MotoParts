import 'models.dart';

/// Hasil membuat tagihan di penyedia pembayaran.
class GatewayCharge {
  final String? qrString;
  final String? qrUrl;
  final String? vaNumber;
  final String? billerCode;
  final String? billKey;

  /// Batas bayar menurut penyedia; null memakai batas bawaan server.
  final DateTime? expiresAt;

  const GatewayCharge({
    this.qrString,
    this.qrUrl,
    this.vaNumber,
    this.billerCode,
    this.billKey,
    this.expiresAt,
  });
}

class GatewayException implements Exception {
  final String message;
  const GatewayException(this.message);

  @override
  String toString() => 'GatewayException: $message';
}

/// Penyedia pembayaran (Midtrans, atau simulasi untuk pengembangan).
abstract class PaymentGateway {
  /// Nama untuk /health, mis. "midtrans-sandbox" atau "mock".
  String get name;

  /// Membuat tagihan. Melempar [GatewayException] jika ditolak/gagal.
  Future<GatewayCharge> charge(
    PaymentRequest request, {
    required int expiryMinutes,
  });

  /// Status terbaru dari penyedia. Melempar [GatewayException] jika gagal.
  Future<PaymentStatus> status(String id);
}
