import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Alamat API database (backend PHP + MySQL di folder `backend/`).
///
/// Atur saat build/jalankan, mis.
/// `flutter run --dart-define=API_URL=http://10.0.2.2/motopart-api`.
/// Tanpa nilai ini aplikasi berjalan sepenuhnya lokal (data di perangkat).
class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment('API_URL');

  static bool get enabled => baseUrl.trim().isNotEmpty;
}

/// Kesalahan saat memanggil API, dengan pesan yang bisa ditampilkan.
class RemoteException implements Exception {
  final String message;

  /// Kode HTTP; 0 berarti server tidak terjangkau.
  final int status;

  const RemoteException(this.message, {this.status = 0});

  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 409;

  @override
  String toString() => message;
}

/// Pintu ke server database. Diabstraksikan agar bisa diganti di tes.
abstract class RemoteGateway {
  /// Token sesi login (null = tamu).
  String? token;

  /// Memanggil API dan mengembalikan isi JSON-nya. [token] menggantikan token
  /// sesi untuk satu panggilan ini. Melempar [RemoteException] jika gagal.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  });
}

class HttpRemoteGateway extends RemoteGateway {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  HttpRemoteGateway(
    String baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';
    final bearer = token ?? this.token;
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const RemoteException(
        'Server tidak menjawab. Periksa koneksi lalu coba lagi.',
      );
    } on Exception {
      throw const RemoteException(
        'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
      );
    }

    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        // Bukan JSON (mis. halaman galat Apache): ditangani di bawah.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final message = json['error'];
    throw RemoteException(
      message is String && message.isNotEmpty
          ? message
          : 'Server bermasalah (${response.statusCode}).',
      status: response.statusCode,
    );
  }
}

/// Gateway yang dipakai aplikasi; null = mode lokal tanpa database.
RemoteGateway? remoteGateway = ApiConfig.enabled
    ? HttpRemoteGateway(ApiConfig.baseUrl)
    : null;
