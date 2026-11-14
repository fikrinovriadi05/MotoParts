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
}
