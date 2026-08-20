import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_samarthan/core/utils/product_matching.dart';
import 'package:karigar_samarthan/models/product.dart';

Product _product({
  required String id,
  required String title,
  required String category,
  DateTime? createdAt,
}) {
  return Product(
    id: id,
    title: title,
    category: category,
    description: 'Test description',
    price: 100,
    quantity: 1,
    createdAt: createdAt,
  );
}

void main() {
  group('matchProduct', () {
    test('returns null when there are no products at all', () {
      expect(matchProduct('anything', []), isNull);
    });

    test('matches on title, case-insensitively', () {
      final bangles = _product(id: '1', title: 'Gold Bangles', category: 'Jewelry');
      final earrings = _product(id: '2', title: 'Silver Earrings', category: 'Jewelry');

      expect(matchProduct('BANGLES', [bangles, earrings]), same(bangles));
      expect(matchProduct('gold', [bangles, earrings]), same(bangles));
    });

    test('falls back to category when no title matches', () {
      // "pottery" matches no title, only a category.
      final vase = _product(id: '1', title: 'Blue Vase', category: 'Pottery');
      final scarf = _product(id: '2', title: 'Silk Scarf', category: 'Textiles');

      expect(matchProduct('pottery', [vase, scarf]), same(vase));
    });

    test('a title match always wins over a category match, even when a '
        'later product\'s category also matches', () {
      final categoryMatch =
          _product(id: '1', title: 'Blue Vase', category: 'Bangles Display');
      final titleMatch =
          _product(id: '2', title: 'Gold Bangles', category: 'Jewelry');

      // "bangles" matches both - title should win.
      expect(
        matchProduct('bangles', [categoryMatch, titleMatch]),
        same(titleMatch),
      );
    });

    test('an empty query falls back to the most recently created product',
        () {
      final older = _product(
        id: '1',
        title: 'Old Item',
        category: 'Misc',
        createdAt: DateTime(2026, 1, 1),
      );
      final newer = _product(
        id: '2',
        title: 'New Item',
        category: 'Misc',
        createdAt: DateTime(2026, 6, 1),
      );

      expect(matchProduct('', [older, newer]), same(newer));
      expect(matchProduct('   ', [older, newer]), same(newer));
    });

    test('a query matching nothing falls back to the newest product, not '
        'the first/last in list order', () {
      final newest = _product(
        id: '1',
        title: 'Newest',
        category: 'Misc',
        createdAt: DateTime(2026, 6, 1),
      );
      final middle = _product(
        id: '2',
        title: 'Middle',
        category: 'Misc',
        createdAt: DateTime(2026, 3, 1),
      );
      final oldest = _product(
        id: '3',
        title: 'Oldest',
        category: 'Misc',
        createdAt: DateTime(2026, 1, 1),
      );

      // Not in chronological order - result should come from createdAt.
      expect(
        matchProduct('no such product exists', [middle, newest, oldest]),
        same(newest),
      );
    });

    test('products with no createdAt (null) sort as the oldest, not '
        'crash or win by default', () {
      final noTimestamp = _product(id: '1', title: 'Legacy Item', category: 'Misc');
      final withTimestamp = _product(
        id: '2',
        title: 'New Item',
        category: 'Misc',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(
        matchProduct('', [noTimestamp, withTimestamp]),
        same(withTimestamp),
      );
    });

    test('when every product has a null createdAt, it still returns one '
        'of them rather than crashing', () {
      final a = _product(id: '1', title: 'A', category: 'Misc');
      final b = _product(id: '2', title: 'B', category: 'Misc');

      expect(matchProduct('', [a, b]), anyOf(same(a), same(b)));
    });
  });
}
