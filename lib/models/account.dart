import 'package:motopart/models/shipping_address.dart';

enum AccountRole { user, admin }

class Account {
  final String id;
  final String name;
  final String email;
  final String phone;
  final AccountRole role;

  /// Motor milik pembeli (opsional): nama/merek, tipe/varian, dan tahun.
  final String motorName;
  final String motorType;
  final int? motorYear;

  /// Alamat pengiriman tersimpan.
  final List<ShippingAddress> addresses;

  /// Id alamat utama; null jika belum ada alamat.
  final String? defaultAddressId;

  /// Metode pembayaran favorit (hasil `PaymentChoice.encoded`), opsional.
  final String? preferredPayment;

  /// Hash SHA-256 dari "salt:password". Password asli tidak pernah disimpan.
  final String passwordHash;
  final String salt;

  const Account({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.passwordHash,
    required this.salt,
    this.motorName = '',
    this.motorType = '',
    this.motorYear,
    this.addresses = const [],
    this.defaultAddressId,
    this.preferredPayment,
  });

  bool get isAdmin => role == AccountRole.admin;

  /// Kata pertama dari nama (untuk sapaan), mis. "Siti Aminah" -> "Siti".
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? name : parts.first;
  }

  bool get hasMotor => motorName.isNotEmpty;

  /// Ringkasan motor, mis. "Honda Beat Street · 2020"; kosong jika belum diisi.
  String get motorSummary {
    if (!hasMotor) return '';
    final model = [motorName, motorType].where((e) => e.isNotEmpty).join(' ');
    return motorYear == null ? model : '$model · $motorYear';
  }

  ShippingAddress? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.where((a) => a.id == defaultAddressId).firstOrNull ??
        addresses.first;
  }

  /// [clearMotorYear] menghapus tahun motor (null pada [motorYear] berarti
  /// "tidak diubah"); begitu juga [clearDefaultAddress] dan
  /// [clearPreferredPayment].
  Account copyWith({
    String? name,
    String? phone,
    String? passwordHash,
    String? salt,
    String? motorName,
    String? motorType,
    int? motorYear,
    bool clearMotorYear = false,
    List<ShippingAddress>? addresses,
    String? defaultAddressId,
    bool clearDefaultAddress = false,
    String? preferredPayment,
    bool clearPreferredPayment = false,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      motorName: motorName ?? this.motorName,
      motorType: motorType ?? this.motorType,
      motorYear: clearMotorYear ? null : motorYear ?? this.motorYear,
      addresses: addresses ?? this.addresses,
      defaultAddressId: clearDefaultAddress
          ? null
          : defaultAddressId ?? this.defaultAddressId,
      preferredPayment: clearPreferredPayment
          ? null
          : preferredPayment ?? this.preferredPayment,
    );
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: AccountRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => AccountRole.user,
      ),
      passwordHash: json['passwordHash'] as String,
      salt: json['salt'] as String,
      motorName: json['motorName'] as String? ?? '',
      motorType: json['motorType'] as String? ?? '',
      motorYear: json['motorYear'] as int?,
      addresses: ((json['addresses'] as List?) ?? const [])
          .map((e) => ShippingAddress.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultAddressId: json['defaultAddressId'] as String?,
      preferredPayment: json['preferredPayment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.name,
    'passwordHash': passwordHash,
    'salt': salt,
    'motorName': motorName,
    'motorType': motorType,
    'motorYear': motorYear,
    'addresses': addresses.map((a) => a.toJson()).toList(),
    'defaultAddressId': defaultAddressId,
    'preferredPayment': preferredPayment,
  };
}
