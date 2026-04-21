import 'dart:io';

class Product {
  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final int quantity;
  final File? imageFile;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.quantity,
    this.imageFile,
  });

  // Converting to JSON for backend
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': 'simple',
      'regular_price': price.toString(),
      'description': description,
      'categories': [{'name': category}],
      'stock_quantity': quantity,
      'manage_stock': true,
    };
  }
}