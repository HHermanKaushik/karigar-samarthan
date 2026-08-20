enum OrderStatus { placed, paid, shipped, delivered }

/// One product line within an order. functions/index.js writes all of an
/// order's line items to Firestore's `lineItems` array.
class OrderLineItem {
  final String title;
  final String? image;
  final int quantity;
  final double price;

  const OrderLineItem({
    required this.title,
    required this.quantity,
    required this.price,
    this.image,
  });
}

class CustomerOrder {
  final String id;

  /// All product lines in this order. Always non-empty - falls back to
  /// the legacy single-product fields below for older synced orders.
  final List<OrderLineItem> lineItems;

  /// Legacy single-product fields, kept for orders synced before lineItems
  /// existed and for any code still reading the order's primary product.
  final String productTitle;
  final String? productImage;
  final int quantity;

  final double total;
  final DateTime placedAt;
  final OrderStatus status;
  final String customerName;
  final String shippingAddress;
  final String customerPhone;

  /// UPI transaction/reference ID (UTR) the customer submitted at checkout
  /// via the "Pay via UPI" gateway. Empty if the order wasn't paid via UPI
  /// or no reference was captured.
  final String upiUtr;

  /// Set when this order has been marked shipped (manually or via the AI
  /// assistant) - empty until then.
  final String trackingNumber;
  final String carrier;

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
    this.lineItems = const [],
    this.productImage,
    this.upiUtr = '',
    this.trackingNumber = '',
    this.carrier = '',
  });
}
