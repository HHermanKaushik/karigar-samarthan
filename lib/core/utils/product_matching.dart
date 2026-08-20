import '../../models/product.dart';

/// Resolves a spoken/typed product name or category - substring match on
/// title first (case-insensitive), then category. Falls back to the most
/// recently created product (by [Product.createdAt], not list order) when
/// the query is empty or matches nothing. Returns null only if [products]
/// is empty.
Product? matchProduct(String query, List<Product> products) {
  final trimmed = query.trim().toLowerCase();
  if (products.isEmpty) return null;

  if (trimmed.isNotEmpty) {
    for (final p in products) {
      if (p.title.toLowerCase().contains(trimmed)) return p;
    }
    for (final p in products) {
      if (p.category.toLowerCase().contains(trimmed)) return p;
    }
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return products.reduce(
      (a, b) => (a.createdAt ?? epoch).isAfter(b.createdAt ?? epoch) ? a : b);
}
