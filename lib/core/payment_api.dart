import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/safe_save.dart';
import 'package:motopart/models/payment_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kesalahan dari server pembayaran, dengan pesan yang bisa ditampilkan.
class PaymentApiException implements Exception {
  final String message;

  /// Server menjawab 404 (pembayaran tidak dikenal, mis. server direset).
  final bool notFound;

  const PaymentApiException(this.message, {this.notFound = false});

  @override
  String toString() => message;
}

/// Klien server pembayaran (`server/` di repositori ini).
abstract class PaymentApi {
  /// Membuat tagihan untuk pesanan [orderCode]. Memanggil ulang dengan data
  /// yang sama mengembalikan tagihan yang sama.
  Future<PaymentSnapshot> create({
    required String orderCode,
    required PaymentChoice choice,
    required int amount,
    String customerName = '',
  });

  /// Status terbaru; server memeriksanya ke penyedia pembayaran.
  Future<PaymentSnapshot> status(String paymentId);
}

class PaymentConfig {
  const PaymentConfig._();

  /// Alamat server. Atur saat build:
  /// `flutter run --dart-define=PAYMENT_API_URL=https://pay.contoh.com`.
  /// Tanpa itu: emulator Android memakai 10.0.2.2 (komputer pengembang),
  /// platform lain memakai localhost.
  static const _fromEnv = String.fromEnvironment('PAYMENT_API_URL');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }
}

class HttpPaymentApi implements PaymentApi {
  final http.Client _client;
  final Duration timeout;

  HttpPaymentApi({
    this.baseUrlOverride,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Alamat server; null memakai [PaymentConfig.baseUrl].
  final String? baseUrlOverride;

  String get baseUrl => (baseUrlOverride ?? PaymentConfig.baseUrl).replaceFirst(
    RegExp(r'/+$'),
    '',
  );

  static const _offline =
      'Tidak dapat terhubung ke server pembayaran. Periksa koneksi internet '
      'dan pastikan server berjalan.';

  Future<PaymentSnapshot> _request(
    Future<http.Response> Function(Uri base) call,
  ) async {
    final http.Response response;
    try {
      response = await call(Uri.parse(baseUrl)).timeout(timeout);
    } on Object {
      throw const PaymentApiException(_offline);
    }

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      json = null;
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        json != null) {
      try {
        return PaymentSnapshot(
          PaymentInfo.fromJson(json),
          PaymentStatus.parse(json['status']),
        );
      } on Object {
        throw const PaymentApiException(
          'Respons server pembayaran tidak valid.',
        );
      }
    }

    final message = json?['error'];
    throw PaymentApiException(
      message is String
          ? message
          : 'Server pembayaran bermasalah (${response.statusCode}).',
      notFound: response.statusCode == 404,
    );
  }

  @override
  Future<PaymentSnapshot> create({
    required String orderCode,
    required PaymentChoice choice,
    required int amount,
    String customerName = '',
  }) {
    final type = choice.apiType;
    if (type == null) {
      throw ArgumentError('${choice.label} tidak dibayar lewat server.');
    }
    return _request(
      (base) => _client.post(
        base.resolve('/payments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': orderCode,
          'type': type,
          if (choice.apiProvider != null) 'provider': choice.apiProvider,
          'amount': amount,
          'customerName': customerName,
        }),
      ),
    );
  }

  @override
  Future<PaymentSnapshot> status(String paymentId) => _request(
    (base) => _client.get(
      base.resolve('/payments/${Uri.encodeComponent(paymentId)}'),
    ),
  );
}

/// Pembayaran QRIS DEMO tanpa server: tagihan dibuat di perangkat dan dianggap
/// lunas hanya ketika [simulatePaid] dipanggil (tombol "Simulasikan
/// Pembayaran" di halaman menunggu pembayaran). Tidak ada uang yang
/// berpindah; kode QR-nya contoh dan tidak bisa dipakai membayar sungguhan.
///
/// Hanya QRIS yang didukung. Status disimpan di perangkat agar tahan
/// ditutupnya aplikasi.
class DemoPaymentApi implements PaymentApi {
  static const storageKey = 'motopart_demo_payments';

  /// Batas waktu bayar tagihan demo.
  static const validFor = Duration(minutes: 15);

  /// Awalan isi kode QR demo; dipakai untuk mengenali QR contoh.
  static const qrPrefix = 'MOTOPART-DEMO';

  final DateTime Function() clock;
  SharedPreferences? _prefs;

  /// id pembayaran -> (batas bayar, sudah dibayar).
  final Map<String, ({DateTime expiresAt, bool paid})> _payments = {};

  DemoPaymentApi({this.clock = DateTime.now});

  /// Memuat status tersimpan dan menyimpan setiap perubahan berikutnya.
  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in data.entries) {
        final item = e.value as Map<String, dynamic>;
        final expires = DateTime.tryParse(item['expiresAt'] as String? ?? '');
        if (expires == null) continue;
        _payments[e.key] = (
          expiresAt: expires,
          paid: item['paid'] as bool? ?? false,
        );
      }
    } on Object {
      // Data rusak: mulai dari kosong.
    }
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    unawaited(
      safeSetString(
        prefs,
        storageKey,
        jsonEncode({
          for (final e in _payments.entries)
            e.key: {
              'expiresAt': e.value.expiresAt.toIso8601String(),
              'paid': e.value.paid,
            },
        }),
      ),
    );
  }

  PaymentInfo _info(String id, int amount, DateTime expiresAt) => PaymentInfo(
    paymentId: id,
    type: 'qris',
    amount: amount,
    qrString: '$qrPrefix|$id|$amount',
    expiresAt: expiresAt,
  );

  @override
  Future<PaymentSnapshot> create({
    required String orderCode,
    required PaymentChoice choice,
    required int amount,
    String customerName = '',
  }) async {
    if (choice.apiType != 'qris') {
      throw const PaymentApiException(
        'Mode demo hanya menyimulasikan QRIS. Virtual Account dan e-wallet '
        'butuh server pembayaran.',
      );
    }
    // Memanggil ulang untuk pesanan yang sama memberi tagihan yang sama.
    final existing = _payments[orderCode];
    final expiresAt = existing?.expiresAt ?? clock().add(validFor);
    _payments[orderCode] = (
      expiresAt: expiresAt,
      paid: existing?.paid ?? false,
    );
    _save();
    return PaymentSnapshot(
      _info(orderCode, amount, expiresAt),
      existing?.paid ?? false ? PaymentStatus.paid : PaymentStatus.pending,
    );
  }

  @override
  Future<PaymentSnapshot> status(String paymentId) async {
    final payment = _payments[paymentId];
    // Tagihan tidak dikenal (mis. data demo terhapus atau pesanan dibuat di
    // perangkat lain): dianggap masih menunggu supaya tetap bisa disimulasikan.
    final status = payment == null
        ? PaymentStatus.pending
        : payment.paid
        ? PaymentStatus.paid
        : !clock().isBefore(payment.expiresAt)
        ? PaymentStatus.expired
        : PaymentStatus.pending;
    return PaymentSnapshot(
      PaymentInfo(
        paymentId: paymentId,
        type: 'qris',
        amount: 0,
        expiresAt: payment?.expiresAt,
      ),
      status,
    );
  }

  /// Menandai tagihan [paymentId] lunas (simulasi). Mengembalikan `false`
  /// bila tagihannya sudah kedaluwarsa.
  bool simulatePaid(String paymentId) {
    final payment = _payments[paymentId];
    if (payment != null &&
        !payment.paid &&
        !clock().isBefore(payment.expiresAt)) {
      return false;
    }
    _payments[paymentId] = (
      expiresAt: payment?.expiresAt ?? clock().add(validFor),
      paid: true,
    );
    _save();
    return true;
  }
}

/// Dipakai aplikasi; diganti di tes. Tanpa `PAYMENT_API_URL` memakai mode demo.
PaymentApi paymentApi = PaymentMethods.demoMode
    ? DemoPaymentApi()
    : HttpPaymentApi();
