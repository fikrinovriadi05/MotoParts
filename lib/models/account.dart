enum AccountRole { user, admin }

class Account {
  final String id;
  final String name;
  final String email;
  final String phone;
  final AccountRole role;

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
  });

  bool get isAdmin => role == AccountRole.admin;

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
  };
}
