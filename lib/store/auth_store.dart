import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akun pengguna lokal (tanpa server): pendaftaran, login, dan sesi.
///
/// Password disimpan sebagai hash SHA-256 + salt acak. Ini hanya mencegah
/// password terbaca langsung dari penyimpanan perangkat; keamanan yang
/// sebenarnya memerlukan server.
class AuthStore extends ChangeNotifier {
  static const storageKey = 'motopart_auth_v1';
  static const minPasswordLength = 6;

  /// Akun admin bawaan, dibuat otomatis jika belum ada.
  static const adminEmail = 'admin@motopart.id';
  static const adminInitialPassword = 'admin123';

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final Store? _store;
  final Random _random;
  SharedPreferences? _prefs;

  final List<Account> accounts = [];
  Account? _current;

  AuthStore({this._store, Random? random})
    : _random = random ?? Random.secure() {
    _ensureAdmin();
  }

  Account? get currentAccount => _current;
  bool get isLoggedIn => _current != null;
  bool get isAdmin => _current?.isAdmin ?? false;

  // ---------------------------------------------------------------- hash

  String _newSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  bool _passwordMatches(Account account, String password) {
    final candidate = hashPassword(password, account.salt);
    final expected = account.passwordHash;
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  String _newId() =>
      'acc${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1 << 20)}';

  Account? _findByEmail(String email) {
    final key = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email.toLowerCase() == key) return account;
    }
    return null;
  }

  void _ensureAdmin() {
    if (accounts.any((a) => a.isAdmin)) return;
    final salt = _newSalt();
    accounts.add(
      Account(
        id: 'admin',
        name: 'Admin MotoPart',
        email: adminEmail,
        phone: '-',
        role: AccountRole.admin,
        passwordHash: hashPassword(adminInitialPassword, salt),
        salt: salt,
      ),
    );
  }

  // ------------------------------------------------------------- aksi

  /// Mendaftarkan akun pembeli baru. Mengembalikan pesan kesalahan, atau
  /// `null` jika berhasil. Tidak otomatis login.
  String? register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        phone.trim().isEmpty ||
        password.isEmpty) {
      return 'Lengkapi semua data terlebih dahulu.';
    }
    if (!_emailPattern.hasMatch(email.trim())) {
      return 'Format email tidak valid.';
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      return 'Nomor telepon tidak valid.';
    }
    if (password.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter.';
    }
    if (_findByEmail(email) != null) {
      return 'Email sudah terdaftar.';
    }

    final salt = _newSalt();
    accounts.add(
      Account(
        id: _newId(),
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        role: AccountRole.user,
        passwordHash: hashPassword(password, salt),
        salt: salt,
      ),
    );
    notifyListeners();
    return null;
  }

  /// Masuk ke akun. [role] adalah tab yang dipilih di layar login. Mengembalikan
  /// pesan kesalahan, atau `null` jika berhasil.
  String? login({
    required String email,
    required String password,
    required AccountRole role,
  }) {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Email dan password wajib diisi.';
    }
    final account = _findByEmail(email);
    if (account == null || !_passwordMatches(account, password)) {
      return 'Email atau password salah.';
    }
    if (account.role != role) {
      return account.isAdmin
          ? 'Akun admin masuk lewat tab Admin.'
          : 'Akun ini bukan akun admin.';
    }

    _current = account;
    _store?.setCurrentAccount(account.id);
    notifyListeners();
    return null;
  }

  void logout() {
    _current = null;
    _store?.setCurrentAccount(null);
    notifyListeners();
  }

  // ------------------------------------------------------- penyimpanan

  /// Menghubungkan ke penyimpanan lokal: memuat akun dan sesi yang tersimpan,
  /// lalu menyimpan otomatis setiap kali berubah.
  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final loaded = (data['accounts'] as List)
            .map((e) => Account.fromJson(e as Map<String, dynamic>))
            .toList();
        accounts
          ..clear()
          ..addAll(loaded);
        _ensureAdmin();

        final currentId = data['currentId'] as String?;
        _current = currentId == null
            ? null
            : accounts.where((a) => a.id == currentId).firstOrNull;
      } catch (_) {
        // Data rusak: abaikan dan pakai akun bawaan.
      }
    }
    _store?.setCurrentAccount(_current?.id);
    super.notifyListeners();
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(
      storageKey,
      jsonEncode({
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'currentId': _current?.id,
      }),
    );
  }

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }
}

final AuthStore auth = AuthStore(store: store);
