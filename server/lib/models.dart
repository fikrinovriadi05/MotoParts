/// Jenis pembayaran yang didukung server.
enum PaymentType {
  qris,
  va,
  ewallet;

  static PaymentType? parse(Object? value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  expired;

  static PaymentStatus parse(Object? value) => values.firstWhere(
    (s) => s.name == value,
    orElse: () => PaymentStatus.pending,
  );

  bool get isFinal => this != PaymentStatus.pending;
}

/// Permintaan membuat pembayaran dari aplikasi.
class PaymentRequest {
  /// Kode pesanan dari aplikasi; dipakai sebagai id pembayaran (idempoten).
  final String id;
  final PaymentType type;

  /// Bank untuk Virtual Account (bca, bni, bri, mandiri) atau "gopay".
  final String? provider;
  final int amount;
  final String customerName;

  const PaymentRequest({
    required this.id,
    required this.type,
    required this.amount,
    this.provider,
    this.customerName = '',
  });

  static final _idPattern = RegExp(r'^[A-Za-z0-9_-]{3,50}$');
  static const vaBanks = ['bca', 'bni', 'bri', 'mandiri'];
  static const ewalletProviders = ['gopay'];
  static const maxAmount = 100000000;

  /// Mengurai dan memvalidasi JSON. Mengembalikan pesan kesalahan (indonesia)
  /// lewat [error] jika tidak valid.
  static ({PaymentRequest? request, String? error}) fromJson(Object? json) {
    if (json is! Map) {
      return (request: null, error: 'Isi permintaan tidak valid.');
    }

    final id = json['id'];
    if (id is! String || !_idPattern.hasMatch(id)) {
      return (request: null, error: 'Kode pesanan tidak valid.');
    }
    final type = PaymentType.parse(json['type']);
    if (type == null) {
      return (request: null, error: 'Jenis pembayaran tidak dikenal.');
    }
    final amount = json['amount'];
    if (amount is! int || amount < 1 || amount > maxAmount) {
      return (request: null, error: 'Jumlah pembayaran tidak valid.');
    }

    final providerRaw = json['provider'];
    final provider = providerRaw is String ? providerRaw.toLowerCase() : null;
    switch (type) {
      case PaymentType.va:
        if (!vaBanks.contains(provider)) {
          return (request: null, error: 'Bank Virtual Account tidak didukung.');
        }
      case PaymentType.ewallet:
        if (!ewalletProviders.contains(provider)) {
          return (request: null, error: 'Dompet digital tidak didukung.');
        }
      case PaymentType.qris:
        break;
    }

    final name = json['customerName'];
    return (
      request: PaymentRequest(
        id: id,
        type: type,
        amount: amount,
        provider: type == PaymentType.qris ? null : provider,
        customerName: name is String ? name.trim() : '',
      ),
      error: null,
    );
  }
}

/// Data pembayaran yang disimpan dan dikirim ke aplikasi.
class Payment {
  final String id;
  final PaymentType type;
  final String? provider;
  final int amount;
  PaymentStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime? paidAt;

  /// Isi QR (QRIS/GoPay) atau alamat gambar QR, bila ada.
  final String? qrString;
  final String? qrUrl;

  /// Virtual Account: nomor VA, atau kode perusahaan + kode bayar (Mandiri).
  final String? vaNumber;
  final String? billerCode;
  final String? billKey;

  Payment({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    this.provider,
    this.status = PaymentStatus.pending,
    this.paidAt,
    this.qrString,
    this.qrUrl,
    this.vaNumber,
    this.billerCode,
    this.billKey,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    type: PaymentType.parse(json['type'])!,
    provider: json['provider'] as String?,
    amount: json['amount'] as int,
    status: PaymentStatus.parse(json['status']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    paidAt: json['paidAt'] == null
        ? null
        : DateTime.parse(json['paidAt'] as String),
    qrString: json['qrString'] as String?,
    qrUrl: json['qrUrl'] as String?,
    vaNumber: json['vaNumber'] as String?,
    billerCode: json['billerCode'] as String?,
    billKey: json['billKey'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'provider': provider,
    'amount': amount,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'paidAt': paidAt?.toUtc().toIso8601String(),
    'qrString': qrString,
    'qrUrl': qrUrl,
    'vaNumber': vaNumber,
    'billerCode': billerCode,
    'billKey': billKey,
  };
}
