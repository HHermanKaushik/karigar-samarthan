import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier() : super(_seed);

  static final List<Product> _seed = [
    const Product(
      id: 'p1',
      title: 'Handwoven Pashmina Shawl',
      category: 'Apparel',
      description:
          'Handwoven Pashmina shawl made by Kashmiri artisans using traditional techniques. Soft, lightweight, suitable for winter.',
      price: 3500,
      quantity: 3,
    ),
    const Product(
      id: 'p2',
      title: 'Bokhara wool-silk rug',
      category: 'Home Decor',
      description: 'Hand-knotted Bokhara rug in wool and silk blend.',
      price: 12500,
      quantity: 1,
    ),
    const Product(
      id: 'p3',
      title: 'Jamawar Silk Saree',
      category: 'Apparel',
      description: 'Pure Jamawar silk saree with traditional motifs.',
      price: 8900,
      quantity: 2,
    ),
    const Product(
      id: 'p4',
      title: 'Kaani Silk Saree',
      category: 'Apparel',
      description: 'Kaani weave silk saree from Kashmir.',
      price: 9600,
      quantity: 2,
    ),
    const Product(
      id: 'p5',
      title: 'Raffal Paisley Stole',
      category: 'Apparel',
      description: 'Raffal wool stole with paisley embroidery.',
      price: 1800,
      quantity: 5,
    ),
  ];

  void add(Product p) => state = [p, ...state];

  void update(Product p) =>
      state = [for (final x in state) if (x.id == p.id) p else x];

  void remove(String id) => state = state.where((x) => x.id != id).toList();
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<Product>>(
        (ref) => ProductsNotifier());
