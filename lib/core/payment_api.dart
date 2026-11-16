import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/models/payment_info.dart';

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

/// Dipakai aplikasi; diganti di tes.
PaymentApi paymentApi = HttpPaymentApi();
