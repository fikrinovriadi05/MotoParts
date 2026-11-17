import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/safe_save.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/shipping_address.dart';
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

  // ------------------------------------------------------- kelola akun

  void _replace(Account updated) {
    final index = accounts.indexWhere((a) => a.id == updated.id);
    if (index < 0) return;
    accounts[index] = updated;
    if (_current?.id == updated.id) _current = updated;
  }

  /// Apakah akun admin masih memakai password awal bawaan.
  bool get adminUsesDefaultPassword => accounts.any(
    (a) => a.isAdmin && _passwordMatches(a, adminInitialPassword),
  );

  /// Mengubah password akun yang sedang login. Mengembalikan pesan
  /// kesalahan, atau `null` jika berhasil.
  String? changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    if (!_passwordMatches(account, oldPassword)) {
      return 'Password lama salah.';
    }
    if (newPassword.length < minPasswordLength) {
      return 'Password baru minimal $minPasswordLength karakter.';
    }
    if (newPassword == oldPassword) {
      return 'Password baru harus berbeda dari password lama.';
    }

    final salt = _newSalt();
    _replace(
      account.copyWith(
        salt: salt,
        passwordHash: hashPassword(newPassword, salt),
      ),
    );
    notifyListeners();
    return null;
  }

  /// Tahun motor tertua yang diterima.
  static const oldestMotorYear = 1970;

  /// Mengubah nama dan nomor telepon akun yang sedang login (email tetap).
  ///
  /// Data motor bersifat opsional: parameter `null` berarti tidak diubah,
  /// string kosong menghapus isinya. [motorYear] harus berupa angka tahun.
  String? updateProfile({
    required String name,
    required String phone,
    String? motorName,
    String? motorType,
    String? motorYear,
    DateTime? now,
  }) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    if (name.trim().isEmpty || phone.trim().isEmpty) {
      return 'Nama dan nomor telepon wajib diisi.';
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      return 'Nomor telepon tidak valid.';
    }

    final newMotorName = (motorName ?? account.motorName).trim();
    final newMotorType = (motorType ?? account.motorType).trim();
    int? newYear = account.motorYear;
    if (motorYear != null) {
      final raw = motorYear.trim();
      if (raw.isEmpty) {
        newYear = null;
      } else {
        newYear = int.tryParse(raw);
        final latest = (now ?? DateTime.now()).year + 1;
        if (newYear == null || newYear < oldestMotorYear || newYear > latest) {
          return 'Tahun motor harus antara $oldestMotorYear dan $latest.';
        }
      }
    }
    if (newMotorName.isEmpty && (newMotorType.isNotEmpty || newYear != null)) {
      return 'Isi nama motor terlebih dahulu.';
    }

    _replace(
      account.copyWith(
        name: name.trim(),
        phone: phone.trim(),
        motorName: newMotorName,
        motorType: newMotorType,
        motorYear: newYear,
        clearMotorYear: newYear == null,
      ),
    );
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------ alamat & bayar

  String _newAddressId() =>
      'adr${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1 << 20)}';

  /// Menambah alamat pengiriman. Alamat pertama otomatis menjadi alamat
  /// utama; [makeDefault] menjadikan alamat ini utama. Mengembalikan pesan
  /// kesalahan, atau `null` jika berhasil ([onSaved] menerima alamat barunya).
  String? addAddress({
    required String label,
    required String recipient,
    required String phone,
    required String street,
    required String city,
    String postalCode = '',
    String note = '',
    double? latitude,
    double? longitude,
    bool makeDefault = false,
    void Function(ShippingAddress saved)? onSaved,
  }) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    final error = ShippingAddress.validate(
      label: label,
      recipient: recipient,
      phone: phone,
      street: street,
      city: city,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
    );
    if (error != null) return error;

    final address = ShippingAddress(
      id: _newAddressId(),
      label: label.trim(),
      recipient: recipient.trim(),
      phone: phone.trim(),
      street: street.trim(),
      city: city.trim(),
      postalCode: postalCode.trim(),
      note: note.trim(),
      latitude: latitude,
      longitude: longitude,
    );
    final isFirst = account.addresses.isEmpty;
    _replace(
      account.copyWith(
        addresses: [...account.addresses, address],
        defaultAddressId: isFirst || makeDefault
            ? address.id
            : account.defaultAddressId,
      ),
    );
    notifyListeners();
    onSaved?.call(address);
    return null;
  }

  /// Mengubah alamat yang sudah ada (id tetap).
  String? updateAddress(
    String id, {
    required String label,
    required String recipient,
    required String phone,
    required String street,
    required String city,
    String postalCode = '',
    String note = '',
    double? latitude,
    double? longitude,
    bool makeDefault = false,
  }) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    final index = account.addresses.indexWhere((a) => a.id == id);
    if (index < 0) return 'Alamat tidak ditemukan.';
    final error = ShippingAddress.validate(
      label: label,
      recipient: recipient,
      phone: phone,
      street: street,
      city: city,
      postalCode: postalCode,
      latitude: latitude,
      longitude: longitude,
    );
    if (error != null) return error;

    final list = [...account.addresses];
    list[index] = list[index].copyWith(
      label: label,
      recipient: recipient,
      phone: phone,
      street: street,
      city: city,
      postalCode: postalCode,
      note: note,
      latitude: latitude,
      longitude: longitude,
      clearLocation: latitude == null && longitude == null,
    );
    _replace(
      account.copyWith(
        addresses: list,
        defaultAddressId: makeDefault ? id : account.defaultAddressId,
      ),
    );
    notifyListeners();
    return null;
  }

  /// Menghapus alamat. Jika yang dihapus adalah alamat utama, alamat pertama
  /// yang tersisa menjadi utama.
  String? deleteAddress(String id) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    if (!account.addresses.any((a) => a.id == id)) {
      return 'Alamat tidak ditemukan.';
    }
    final list = account.addresses.where((a) => a.id != id).toList();
    final wasDefault = account.defaultAddress?.id == id;
    _replace(
      account.copyWith(
        addresses: list,
        defaultAddressId: wasDefault && list.isNotEmpty
            ? list.first.id
            : account.defaultAddressId,
        clearDefaultAddress: list.isEmpty,
      ),
    );
    notifyListeners();
    return null;
  }

  String? setDefaultAddress(String id) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    if (!account.addresses.any((a) => a.id == id)) {
      return 'Alamat tidak ditemukan.';
    }
    _replace(account.copyWith(defaultAddressId: id));
    notifyListeners();
    return null;
  }

  /// Menyimpan metode pembayaran favorit ([encoded] dari
  /// `PaymentChoice.encoded`); `null` menghapusnya.
  String? setPreferredPayment(String? encoded) {
    final account = _current;
    if (account == null) return 'Anda belum masuk.';
    if (encoded != null && PaymentMethods.decode(encoded) == null) {
      return 'Metode pembayaran tidak dikenal.';
    }
    _replace(
      account.copyWith(
        preferredPayment: encoded,
        clearPreferredPayment: encoded == null,
      ),
    );
    notifyListeners();
    return null;
  }

  /// Akun pembeli (tanpa admin), untuk halaman kelola pengguna.
  List<Account> get userAccounts => accounts.where((a) => !a.isAdmin).toList();

  /// Password sementara acak (tanpa karakter yang mudah tertukar).
  String generateTemporaryPassword() {
    const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
    return List.generate(
      8,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  /// Admin mengatur ulang password pembeli (pengganti "lupa password" karena
  /// belum ada server/email). Hanya bisa dilakukan oleh admin yang login.
  String? resetPassword(Account target, String newPassword) {
    if (!isAdmin) return 'Hanya admin yang dapat mengatur ulang password.';
    if (target.isAdmin) return 'Password admin diubah lewat Ganti Password.';
    if (newPassword.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter.';
    }
    final index = accounts.indexWhere((a) => a.id == target.id);
    if (index < 0) return 'Akun tidak ditemukan.';

    final salt = _newSalt();
    _replace(
      accounts[index].copyWith(
        salt: salt,
        passwordHash: hashPassword(newPassword, salt),
      ),
    );
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
    unawaited(
      safeSetString(
        prefs,
        storageKey,
        jsonEncode({
          'accounts': accounts.map((a) => a.toJson()).toList(),
          'currentId': _current?.id,
        }),
      ),
    );
  }

  @override
  void notifyListeners() {
    _save();
    super.notifyListeners();
  }
}

final AuthStore auth = AuthStore(store: store);
