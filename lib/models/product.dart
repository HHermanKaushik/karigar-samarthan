class Product {
  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final int quantity;
  final List<String> imagePaths;
  final List<String> tags;

  /// The WooCommerce product ID returned after a successful publish.
  /// Null for seed/local-only products that haven't been synced yet.
  final int? wooId;

  /// The primary image URL on WooCommerce (used when the local file is gone).
  final String? wooImageUrl;

  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.quantity,
    this.imagePaths = const [],
    this.tags = const [],
    this.wooId,
    this.wooImageUrl,
  });

  Product copyWith({
    String? title,
    String? category,
    String? description,
    double? price,
    int? quantity,
    List<String>? imagePaths,
    List<String>? tags,
    int? wooId,
    String? wooImageUrl,
  }) {
    return Product(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imagePaths: imagePaths ?? this.imagePaths,
      tags: tags ?? this.tags,
      wooId: wooId ?? this.wooId,
      wooImageUrl: wooImageUrl ?? this.wooImageUrl,
    );
  }
}
