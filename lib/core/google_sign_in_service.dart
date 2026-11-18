import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:motopart/core/google_web_button_stub.dart'
    if (dart.library.js_interop) 'package:motopart/core/google_web_button_web.dart';

/// Pengaturan masuk dengan Google, lewat `--dart-define`:
///
///   flutter run --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
///
/// [clientId]: ID klien OAuth (tipe Web untuk web, tipe iOS untuk iOS).
/// [serverClientId]: ID klien tipe Web, wajib di Android agar ID token
/// diterbitkan untuk server. Lihat README untuk langkah di Google Cloud.
class GoogleConfig {
  const GoogleConfig._();

  static const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get configured =>
      clientId.trim().isNotEmpty || serverClientId.trim().isNotEmpty;
}

/// Data akun Google yang sudah terverifikasi oleh Google.
class GoogleProfile {
  final String email;
  final String name;

  /// ID token OpenID Connect; dikirim ke server di mode database agar server
  /// memverifikasinya sendiri.
  final String? idToken;

  const GoogleProfile({required this.email, required this.name, this.idToken});
}

/// Pembungkus masuk-dengan-Google. Diabstraksikan agar bisa diganti di tes.
abstract class GoogleSignInService {
  /// Apakah ID klien Google sudah diatur.
  bool get isConfigured;

  /// Web: tombol resmi Google (hasil masuk lewat [profiles]). Platform lain:
  /// null, pakai tombol sendiri yang memanggil [signIn].
  Future<Widget?> webButton();

  /// Mobile/desktop: tampilkan pemilih akun Google. Null jika dibatalkan.
  /// Melempar [GoogleSignInFailure] jika gagal.
  Future<GoogleProfile?> signIn();

  /// Hasil masuk yang datang lewat tombol web.
  Stream<GoogleProfile> get profiles;
}

class GoogleSignInFailure implements Exception {
  final String message;

  const GoogleSignInFailure(this.message);

  @override
  String toString() => message;
}

class RealGoogleSignInService implements GoogleSignInService {
  Future<void>? _init;
  final _profiles = StreamController<GoogleProfile>.broadcast();
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;

  @override
  bool get isConfigured => GoogleConfig.configured;

  Future<void> _ensureInit() => _init ??= () async {
    await GoogleSignIn.instance.initialize(
      clientId: GoogleConfig.clientId.isEmpty ? null : GoogleConfig.clientId,
      serverClientId: GoogleConfig.serverClientId.isEmpty
          ? null
          : GoogleConfig.serverClientId,
    );
    _events = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _profiles.add(_toProfile(event.user));
      }
    });
  }();

  static GoogleProfile _toProfile(GoogleSignInAccount account) {
    final name = account.displayName?.trim();
    return GoogleProfile(
      email: account.email,
      name: (name == null || name.isEmpty)
          ? account.email.split('@').first
          : name,
      idToken: account.authentication.idToken,
    );
  }

  @override
  Future<Widget?> webButton() async {
    if (!isConfigured) return null;
    await _ensureInit();
    return buildGoogleWebButton();
  }

  @override
  Stream<GoogleProfile> get profiles => _profiles.stream;

  @override
  Future<GoogleProfile?> signIn() async {
    if (!isConfigured) {
      throw const GoogleSignInFailure('Masuk dengan Google belum diatur.');
    }
    await _ensureInit();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleSignInFailure(
        'Masuk dengan Google tidak didukung di platform ini.',
      );
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return _toProfile(account);
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
        case GoogleSignInExceptionCode.uiUnavailable:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const GoogleSignInFailure(
            'Konfigurasi Google belum benar. Periksa ID klien OAuth.',
          );
        default:
          throw GoogleSignInFailure(
            'Gagal masuk dengan Google${e.description == null ? '' : ': ${e.description}'}.',
          );
      }
    }
  }

  void dispose() {
    _events?.cancel();
    _profiles.close();
  }
}

/// Layanan yang dipakai aplikasi; diganti dengan palsu di tes.
GoogleSignInService googleSignInService = RealGoogleSignInService();
