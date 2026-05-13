class Product {
  final String id;
  final String title;
  final String category;
  final String description;
  final double price;
  final int quantity;

  // MULTIPLE IMAGES
  final List<String> imagePaths;

  final List<String> tags;

  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.quantity,
    this.imagePaths = const [],
    this.tags = const [],
  });

  Product copyWith({
    String? title,
    String? category,
    String? description,
    double? price,
    int? quantity,
    List<String>? imagePaths,
    List<String>? tags,
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
    );
  }
}
