import 'package:motopart/core/location_service.dart';
import 'package:motopart/core/payment_api.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/payment_info.dart';

/// Server pembayaran palsu: tagihan dibuat di memori, status diatur tes.
class FakePaymentApi implements PaymentApi {
  /// Status per id pembayaran; bawaan `pending`.
  final statuses = <String, PaymentStatus>{};
  final created = <PaymentInfo>[];
  final statusCalls = <String>[];

  /// Jika diisi, semua panggilan melempar ini (mis. server mati).
  PaymentApiException? failure;

  /// Batas bayar tagihan baru dari sekarang.
  Duration expiresIn = const Duration(minutes: 15);

  DateTime Function() now = DateTime.now;

  @override
  Future<PaymentSnapshot> create({
    required String orderCode,
    required PaymentChoice choice,
    required int amount,
    String customerName = '',
  }) async {
    if (failure != null) throw failure!;
    final type = choice.apiType!;
    final info = PaymentInfo(
      paymentId: orderCode,
      type: type,
      provider: choice.apiProvider,
      amount: amount,
      qrString: type == 'va' ? null : 'FAKE-QR-$orderCode',
      vaNumber: type == 'va' && choice.apiProvider != 'mandiri'
          ? '88001234567890'
          : null,
      billerCode: choice.apiProvider == 'mandiri' ? '70012' : null,
      billKey: choice.apiProvider == 'mandiri' ? '990000000260' : null,
      expiresAt: now().add(expiresIn),
    );
    created.add(info);
    return PaymentSnapshot(info, statuses[orderCode] ?? PaymentStatus.pending);
  }

  @override
  Future<PaymentSnapshot> status(String paymentId) async {
    statusCalls.add(paymentId);
    if (failure != null) throw failure!;
    final info = created.where((i) => i.paymentId == paymentId).firstOrNull;
    return PaymentSnapshot(
      info ?? PaymentInfo(paymentId: paymentId, type: 'qris', amount: 0),
      statuses[paymentId] ?? PaymentStatus.pending,
    );
  }
}

/// Lokasi palsu: hasil diatur tes.
class FakeLocationService implements LocationService {
  DeviceLocation? location = const DeviceLocation(-6.9175, 107.6191);
  LocationException? locationError;
  PlaceInfo? place = const PlaceInfo(
    street: 'Jl. Braga No. 10, Braga',
    city: 'Sumur Bandung, Bandung',
    postalCode: '40111',
  );
  int calls = 0;

  @override
  Future<DeviceLocation> currentLocation() async {
    calls++;
    if (locationError != null) throw locationError!;
    return location!;
  }

  @override
  Future<PlaceInfo?> reverseGeocode(double latitude, double longitude) async =>
      place;
}
