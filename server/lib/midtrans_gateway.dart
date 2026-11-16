import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gateway.dart';
import 'models.dart';

/// Midtrans Core API v2 (https://docs.midtrans.com).
///
/// Penguraian respons dibuat toleran: beberapa bentuk respons (mis. VA,
/// echannel, GoPay) di dokumentasi Midtrans hanya diberi contoh sebagian.
class MidtransGateway implements PaymentGateway {
  static const sandboxUrl = 'https://api.sandbox.midtrans.com';
  static const productionUrl = 'https://api.midtrans.com';

  final String serverKey;
  final bool production;
  final http.Client _client;

  MidtransGateway({
    required this.serverKey,
    this.production = false,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  String get name => production ? 'midtrans' : 'midtrans-sandbox';

  String get _baseUrl => production ? productionUrl : sandboxUrl;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Basic ${base64Encode(utf8.encode('$serverKey:'))}',
  };

  /// Isi permintaan charge sesuai jenis pembayaran (dibuka untuk pengujian).
  Map<String, dynamic> chargeBody(
    PaymentRequest request, {
    required int expiryMinutes,
  }) {
    final body = <String, dynamic>{
      'transaction_details': {
        'order_id': request.id,
        'gross_amount': request.amount,
      },
      'item_details': [
        {
          'id': request.id,
          'price': request.amount,
          'quantity': 1,
          'name': 'Pesanan MotoPart',
        },
      ],
      if (request.customerName.isNotEmpty)
        'customer_details': {'first_name': request.customerName},
      'custom_expiry': {'expiry_duration': expiryMinutes, 'unit': 'minute'},
    };

    switch (request.type) {
      case PaymentType.qris:
        body['payment_type'] = 'qris';
        body['qris'] = {'acquirer': 'gopay'};
      case PaymentType.ewallet:
        body['payment_type'] = 'gopay';
        body['gopay'] = {'enable_callback': false};
      case PaymentType.va:
        if (request.provider == 'mandiri') {
          body['payment_type'] = 'echannel';
          body['echannel'] = {
            'bill_info1': 'MotoPart',
            'bill_info2': 'Pembayaran pesanan',
          };
        } else {
          body['payment_type'] = 'bank_transfer';
          body['bank_transfer'] = {'bank': request.provider};
        }
    }
    return body;
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() call,
  ) async {
    final http.Response response;
    try {
      response = await call().timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw GatewayException('Tidak dapat menghubungi Midtrans: $e');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      throw GatewayException(
        'Respons Midtrans tidak valid (${response.statusCode}).',
      );
    }
    return json;
  }

  @override
  Future<GatewayCharge> charge(
    PaymentRequest request, {
    required int expiryMinutes,
  }) async {
    final json = await _send(
      () => _client.post(
        Uri.parse('$_baseUrl/v2/charge'),
        headers: _headers,
        body: jsonEncode(chargeBody(request, expiryMinutes: expiryMinutes)),
      ),
    );

    final code = '${json['status_code']}';
    if (code != '200' && code != '201') {
      throw GatewayException(
        'Midtrans menolak pembayaran ($code): ${json['status_message']}',
      );
    }
    return parseCharge(json);
  }

  /// Membaca respons charge (dibuka untuk pengujian).
  static GatewayCharge parseCharge(Map<String, dynamic> json) {
    String? qrUrl;
    final actions = json['actions'];
    if (actions is List) {
      for (final a in actions) {
        if (a is Map && a['name'] == 'generate-qr-code') {
          qrUrl = a['url'] as String?;
        }
      }
    }

    String? vaNumber;
    final vaNumbers = json['va_numbers'];
    if (vaNumbers is List && vaNumbers.isNotEmpty && vaNumbers.first is Map) {
      vaNumber = (vaNumbers.first as Map)['va_number'] as String?;
    }
    vaNumber ??= json['permata_va_number'] as String?;

    return GatewayCharge(
      qrString: json['qr_string'] as String?,
      qrUrl: qrUrl,
      vaNumber: vaNumber,
      billerCode: json['biller_code'] as String?,
      billKey: json['bill_key'] as String?,
      expiresAt: parseMidtransTime(
        (json['expiry_time'] ?? json['expire_time']) as String?,
      ),
    );
  }

  /// Waktu Midtrans "yyyy-MM-dd HH:mm:ss" berzona GMT+7.
  static DateTime? parseMidtransTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse('${value.replaceFirst(' ', 'T')}+07:00');
  }

  @override
  Future<PaymentStatus> status(String id) async {
    final json = await _send(
      () => _client.get(
        Uri.parse('$_baseUrl/v2/${Uri.encodeComponent(id)}/status'),
        headers: _headers,
      ),
    );
    // 404: tagihan belum tercatat di Midtrans, anggap masih menunggu.
    if ('${json['status_code']}' == '404') return PaymentStatus.pending;
    return mapStatus(
      json['transaction_status'] as String?,
      json['fraud_status'] as String?,
    );
  }

  /// Memetakan status Midtrans ke status aplikasi.
  static PaymentStatus mapStatus(
    String? transactionStatus,
    String? fraudStatus,
  ) {
    switch (transactionStatus) {
      case 'settlement':
      case 'refund':
      case 'partial_refund':
        return PaymentStatus.paid;
      case 'capture':
        return fraudStatus == null || fraudStatus == 'accept'
            ? PaymentStatus.paid
            : PaymentStatus.pending;
      case 'expire':
        return PaymentStatus.expired;
      case 'deny':
      case 'cancel':
      case 'failure':
        return PaymentStatus.failed;
      default: // pending, authorize, dan status baru yang belum dikenal
        return PaymentStatus.pending;
    }
  }
}
