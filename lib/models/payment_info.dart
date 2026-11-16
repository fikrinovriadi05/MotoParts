/// Status pembayaran di server.
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

/// Data tagihan online (QRIS, Virtual Account, GoPay) milik sebuah pesanan.
/// Disimpan bersama pesanan agar pembayaran bisa dilanjutkan setelah aplikasi
/// ditutup.
class PaymentInfo {
  /// Id pembayaran di server (sama dengan kode pesanan).
  final String paymentId;

  /// `qris`, `va`, atau `ewallet`.
  final String type;
  final String? provider;
  final int amount;

  /// Isi QR (dirender jadi kode QR) atau alamat gambar QR dari penyedia.
  final String? qrString;
  final String? qrUrl;

  /// Virtual Account: nomor VA, atau kode perusahaan + kode bayar (Mandiri).
  final String? vaNumber;
  final String? billerCode;
  final String? billKey;

  /// Batas waktu bayar.
  final DateTime? expiresAt;

  const PaymentInfo({
    required this.paymentId,
    required this.type,
    required this.amount,
    this.provider,
    this.qrString,
    this.qrUrl,
    this.vaNumber,
    this.billerCode,
    this.billKey,
    this.expiresAt,
  });

  bool get hasQr => (qrString ?? '').isNotEmpty || (qrUrl ?? '').isNotEmpty;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  /// Dari JSON server (`id`) maupun JSON penyimpanan lokal (`paymentId`).
  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paymentId: (json['paymentId'] ?? json['id']) as String,
      type: json['type'] as String,
      provider: json['provider'] as String?,
      amount: json['amount'] as int,
      qrString: json['qrString'] as String?,
      qrUrl: json['qrUrl'] as String?,
      vaNumber: json['vaNumber'] as String?,
      billerCode: json['billerCode'] as String?,
      billKey: json['billKey'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '')
          ?.toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'type': type,
    'provider': provider,
    'amount': amount,
    'qrString': qrString,
    'qrUrl': qrUrl,
    'vaNumber': vaNumber,
    'billerCode': billerCode,
    'billKey': billKey,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };
}

/// Tagihan beserta status terbarunya.
class PaymentSnapshot {
  final PaymentInfo info;
  final PaymentStatus status;

  const PaymentSnapshot(this.info, this.status);
}
