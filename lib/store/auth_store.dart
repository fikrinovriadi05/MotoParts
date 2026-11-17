import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:motopart/core/payment_methods.dart';
import 'package:motopart/core/remote_gateway.dart';
import 'package:motopart/core/safe_save.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/store/remote_sync.dart';
import 'package:motopart/store/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akun pengguna: pendaftaran, login, dan sesi.
///
/// Dua mode:
/// * **Database** (`API_URL` diatur): akun ada di MySQL lewat backend PHP;
///   password di-hash bcrypt di server dan aplikasi hanya menyimpan token sesi.
/// * **Lokal** (tanpa `API_URL`, juga dipakai di tes): akun di perangkat dengan
///   password SHA-256 + salt acak. Ini hanya mencegah password terbaca
///   langsung dari penyimpanan perangkat.
class AuthStore extends ChangeNotifier {
  static const storageKey = 'motopart_auth_v1';

  /// Token sesi untuk mode database.
  static const tokenKey = 'motopart_token_v1';
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

  /// Apakah data disimpan di database lewat server (bukan di perangkat).
  bool get isRemote => remoteGateway != null;

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

  // ------------------------------------------- mode database (server)

  /// Mendaftar. Di mode database akun dibuat di server; di mode lokal sama
  /// dengan [register]. Tidak otomatis login. Mengembalikan pesan kesalahan
  /// atau `null`.
  Future<String?> registerAsync({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final gateway = remoteGateway;
    if (gateway == null) {
      return register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
    }
    try {
      await gateway.send(
        'POST',
        '/auth/register',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        },
      );
      return null;
    } on RemoteException catch (e) {
      return e.message;
    }
  }

  /// Masuk. Di mode database lewat server (token disimpan); di mode lokal sama
  /// dengan [login].
  Future<String?> loginAsync({
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    final gateway = remoteGateway;
    if (gateway == null) {
      return login(email: email, password: password, role: role);
    }
    try {
      final json = await gateway.send(
        'POST',
        '/auth/login',
        body: {'email': email, 'password': password, 'role': role.name},
      );
      gateway.token = json['token'] as String;
      unawaited(_prefs?.setString(tokenKey, gateway.token!));
      _current = Account.fromJson(json['user'] as Map<String, dynamic>);
      _store?.setCurrentAccount(_current!.id);
      notifyListeners();
      // Data pribadi (pesanan, wishlist, daftar pengguna untuk admin).
      try {
        await RemoteSync.pull();
      } on RemoteException {
        // Login sudah berhasil; data menyusul pada sinkronisasi berikutnya.
      }
      return null;
    } on RemoteException catch (e) {
      return e.message;
    }
  }

  /// Menerapkan hasil `GET /sync` (mode database): akun yang sedang masuk dan,
  /// untuk admin, daftar pengguna.
  void applyRemoteSnapshot(Map<String, dynamic> json) {
    final me = json['me'];
    final previous = _current?.id;
    if (me == null && remoteGateway?.token != null) {
      // Server tidak mengenali token (kedaluwarsa/dicabut): jadi tamu.
      remoteGateway!.token = null;
      unawaited(_prefs?.remove(tokenKey));
    }
    _current = me is Map<String, dynamic> ? Account.fromJson(me) : null;
    accounts
      ..clear()
      ..addAll([
        ?_current,
        for (final u in (json['users'] as List?) ?? const [])
          Account.fromJson(u as Map<String, dynamic>),
      ]);
    if (previous != _current?.id) _store?.setCurrentAccount(_current?.id);
    notifyListeners();
  }

  /// Token ditolak server (kedaluwarsa/dicabut): kembali menjadi tamu.
  void sessionExpired() {
    remoteGateway?.token = null;
    unawaited(_prefs?.remove(tokenKey));
    if (_current == null) return;
    _current = null;
    accounts.clear();
    _store?.setCurrentAccount(null);
    notifyListeners();
  }

  // ------------------------------------------------------- kelola akun

  void _replace(Account updated) {
    final index = accounts.indexWhere((a) => a.id == updated.id);
    if (index < 0) return;
    accounts[index] = updated;
    if (_current?.id == updated.id) _current = updated;
  }

  /// Apakah akun admin masih memakai password awal bawaan.
  bool get adminUsesDefaultPassword => isRemote
      ? (_current?.isAdmin ?? false) && _current!.usesDefaultPassword
      : accounts.any(
          (a) => a.isAdmin && _passwordMatches(a, adminInitialPassword),
        );

  /// Ganti password. Di mode database lewat server; di mode lokal sama dengan
  /// [changePassword].
  Future<String?> changePasswordAsync({
    required String oldPassword,
    required String newPassword,
  }) async {
    final gateway = remoteGateway;
    if (gateway == null) {
      return changePassword(oldPassword: oldPassword, newPassword: newPassword);
    }
    try {
      await RemoteSync.run(
        (g) => g.send(
          'PUT',
          '/me/password',
          body: {'oldPassword': oldPassword, 'newPassword': newPassword},
        ),
      );
      return null;
    } on RemoteException catch (e) {
      return e.message;
    }
  }

  /// Admin mengatur ulang password pembeli. Di mode database lewat server; di
  /// mode lokal sama dengan [resetPassword].
  Future<String?> resetPasswordAsync(Account target, String newPassword) async {
    if (remoteGateway == null) return resetPassword(target, newPassword);
    try {
      await RemoteSync.run(
        (g) => g.send(
          'PUT',
          '/users/${Uri.encodeComponent(target.id)}/password',
          body: {'newPassword': newPassword},
        ),
      );
      return null;
    } on RemoteException catch (e) {
      return e.message;
    }
  }

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
    _push('PUT', '/me', {
      'name': name.trim(),
      'phone': phone.trim(),
      'motorName': newMotorName,
      'motorType': newMotorType,
      'motorYear': newYear,
    });
    return null;
  }

  /// Mengirim perubahan ke server (mode database); tidak melakukan apa pun di
  /// mode lokal.
  void _push(String method, String path, [Map<String, dynamic>? body]) {
    RemoteSync.push((g) => g.send(method, path, body: body));
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
    _push('POST', '/addresses', {
      ...address.toJson(),
      'makeDefault': makeDefault,
    });
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
    _push('PUT', '/addresses/${Uri.encodeComponent(id)}', {
      ...list[index].toJson(),
      'makeDefault': makeDefault,
    });
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
    _push('DELETE', '/addresses/${Uri.encodeComponent(id)}');
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
    _push('PUT', '/addresses/${Uri.encodeComponent(id)}/default');
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
    _push('PUT', '/me', {'preferredPayment': encoded});
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
    final gateway = remoteGateway;
    if (gateway != null) {
      final token = gateway.token;
      gateway.token = null;
      unawaited(_prefs?.remove(tokenKey));
      if (token != null) {
        // Cabut sesi di server; kegagalan jaringan tidak masalah.
        unawaited(
          gateway
              .send('POST', '/auth/logout', token: token)
              .then<void>((_) {})
              .catchError((Object _) {}),
        );
      }
      accounts.clear();
    }
    _current = null;
    _store?.setCurrentAccount(null);
    _store?.clearPrivateData();
    notifyListeners();
  }

  // ------------------------------------------------------- penyimpanan

  /// Menghubungkan ke penyimpanan lokal: memuat akun dan sesi yang tersimpan,
  /// lalu menyimpan otomatis setiap kali berubah.
  Future<void> attach(SharedPreferences prefs) async {
    _prefs = prefs;

    final gateway = remoteGateway;
    if (gateway != null) {
      // Mode database: akun ada di server. Sesi dipulihkan dari token oleh
      // RemoteSync.bootstrap() (dipanggil setelah store dan auth terpasang).
      accounts.clear();
      gateway.token = prefs.getString(tokenKey);
      super.notifyListeners();
      return;
    }

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
    if (prefs == null || isRemote) return;
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
