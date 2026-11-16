import 'gateway.dart';
import 'models.dart';

/// Penyedia palsu untuk pengembangan tanpa akun Midtrans. Kode QR dan nomor VA
/// hanya tiruan (tidak bisa dibayar di aplikasi bank sungguhan).
///
/// Pembayaran dianggap lunas jika [markPaid] dipanggil (endpoint
/// `/payments/<id>/simulate-paid`) atau otomatis setelah [autoPayAfter].
class MockGateway implements PaymentGateway {
  final Duration? autoPayAfter;
  final DateTime Function() _now;
  final _created = <String, DateTime>{};
  final _paid = <String>{};

  MockGateway({this.autoPayAfter, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  String get name => 'mock';

  @override
  Future<GatewayCharge> charge(
    PaymentRequest request, {
    required int expiryMinutes,
  }) async {
    _created[request.id] = _now();
    final expires = _now().add(Duration(minutes: expiryMinutes));

    switch (request.type) {
      case PaymentType.qris:
      case PaymentType.ewallet:
        return GatewayCharge(
          qrString:
              '00020101021226MOCK-${request.id}-${request.amount}5303360'
              '5802ID5909MotoPart',
          expiresAt: expires,
        );
      case PaymentType.va:
        final digits = request.id.replaceAll(RegExp(r'\D'), '');
        final tail = digits.padLeft(10, '0');
        final number = '8800${tail.substring(tail.length - 10)}';
        if (request.provider == 'mandiri') {
          return GatewayCharge(
            billerCode: '70012',
            billKey: number,
            expiresAt: expires,
          );
        }
        return GatewayCharge(vaNumber: number, expiresAt: expires);
    }
  }

  @override
  Future<PaymentStatus> status(String id) async {
    if (_paid.contains(id)) return PaymentStatus.paid;
    final after = autoPayAfter;
    final created = _created[id];
    if (after != null &&
        created != null &&
        !_now().isBefore(created.add(after))) {
      _paid.add(id);
      return PaymentStatus.paid;
    }
    return PaymentStatus.pending;
  }

  /// Menandai pembayaran lunas (untuk simulasi).
  void markPaid(String id) => _paid.add(id);
}
