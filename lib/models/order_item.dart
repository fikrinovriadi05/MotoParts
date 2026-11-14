class OrderItem {
  final String code;
  final String customer;
  final int total;
  String status;

  OrderItem({
    required this.code,
    required this.customer,
    required this.total,
    required this.status,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      code: json['code'] as String,
      customer: json['customer'] as String,
      total: json['total'] as int,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'customer': customer,
    'total': total,
    'status': status,
  };
}
