/// Satu notifikasi di dalam aplikasi (mis. status pesanan berubah).
class AppNotification {
  final String id;

  /// Akun penerima.
  final String accountId;
  final String title;
  final String body;
  final DateTime createdAt;

  /// Kode pesanan terkait (ketuk membuka detail pesanan), jika ada.
  final String? orderCode;

  /// Status pesanan saat notifikasi dibuat; dipakai untuk ikon dan warna.
  final String? status;
  bool read;

  AppNotification({
    required this.id,
    required this.accountId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderCode,
    this.status,
    this.read = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      orderCode: json['orderCode'] as String?,
      status: json['status'] as String?,
      read: (json['read'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'orderCode': orderCode,
    'status': status,
    'read': read,
  };
}
