/// Satu baris barang dalam pesanan (disalin saat checkout, jadi tidak ikut
/// berubah jika produknya kemudian diedit atau dihapus).
class OrderLine {
  final int productId;
  final String name;
  final int qty;
  final int price;

  const OrderLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      productId: json['productId'] as int,
      name: json['name'] as String,
      qty: json['qty'] as int,
      price: json['price'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'price': price,
  };
}

class OrderItem {
  final String code;
  final String customer;
  final int total;
  String status;

  /// Barang yang dipesan. Kosong untuk pesanan lama/contoh yang tidak
  /// mencatat barangnya.
  final List<OrderLine> lines;

  /// Waktu pesanan dibuat. Null untuk pesanan lama/contoh yang tidak
  /// mencatat waktunya.
  final DateTime? createdAt;

  /// Id akun pemilik pesanan. Null untuk pesanan contoh/lama yang tidak punya
  /// pemilik (hanya terlihat oleh admin).
  final String? accountId;

  /// Alamat pengiriman (nama, telepon, alamat) dan metode pembayaran yang
  /// dipilih. Null untuk pesanan lama/contoh yang tidak mencatatnya.
  final String? address;
  final String? paymentMethod;

  OrderItem({
    required this.code,
    required this.customer,
    required this.total,
    required this.status,
    this.lines = const [],
    this.createdAt,
    this.accountId,
    this.address,
    this.paymentMethod,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      code: json['code'] as String,
      customer: json['customer'] as String,
      total: json['total'] as int,
      status: json['status'] as String,
      lines: ((json['lines'] as List?) ?? const [])
          .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      accountId: json['accountId'] as String?,
      address: json['address'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'customer': customer,
    'total': total,
    'status': status,
    'lines': lines.map((e) => e.toJson()).toList(),
    'createdAt': createdAt?.toIso8601String(),
    'accountId': accountId,
    'address': address,
    'paymentMethod': paymentMethod,
  };
}
