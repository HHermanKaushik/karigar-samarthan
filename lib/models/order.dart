enum OrderStatus { placed, paid, shipped, delivered }

class CustomerOrder {
  final String id;
  final String productTitle;
  final String? productImage;
  final int quantity;
  final double total;
  final DateTime placedAt;
  final OrderStatus status;
  final String customerName;
  final String shippingAddress;
  final String customerPhone;

  const CustomerOrder({
    required this.id,
    required this.productTitle,
    required this.quantity,
    required this.total,
    required this.placedAt,
    required this.status,
    required this.customerName,
    required this.shippingAddress,
    required this.customerPhone,
    this.productImage,
  });
}
