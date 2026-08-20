import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_samarthan/core/utils/financial_year.dart';
import 'package:karigar_samarthan/models/order.dart';

CustomerOrder _order({required DateTime placedAt, double total = 100}) {
  return CustomerOrder(
    id: 'test-${placedAt.toIso8601String()}',
    productTitle: 'Test Product',
    quantity: 1,
    total: total,
    placedAt: placedAt,
    status: OrderStatus.placed,
    customerName: 'Test Customer',
    shippingAddress: 'Test Address',
    customerPhone: '9999999999',
  );
}

void main() {
  group('currentFyQuarter', () {
    test('a date in April falls in Q1 of that calendar year\'s FY', () {
      final range = currentFyQuarter(DateTime(2026, 4, 15));
      expect(range.label, 'Q1 FY26-27');
      expect(range.start, DateTime(2026, 4, 1));
      expect(range.endExclusive, DateTime(2026, 7, 1));
    });

    test('June 30 is still Q1, July 1 is Q2 - the Q1/Q2 boundary', () {
      final juneEnd = currentFyQuarter(DateTime(2026, 6, 30));
      final julyStart = currentFyQuarter(DateTime(2026, 7, 1));
      expect(juneEnd.label, 'Q1 FY26-27');
      expect(julyStart.label, 'Q2 FY26-27');
    });

    test('December falls in Q3', () {
      final range = currentFyQuarter(DateTime(2026, 12, 10));
      expect(range.label, 'Q3 FY26-27');
      expect(range.start, DateTime(2026, 10, 1));
      expect(range.endExclusive, DateTime(2027, 1, 1));
    });

    test(
        'January falls in Q4 of the FY that STARTED the previous calendar '
        'year - the trickiest case, since the FY label spans the Jan 1 '
        'calendar-year rollover', () {
      final range = currentFyQuarter(DateTime(2027, 1, 15));
      expect(range.label, 'Q4 FY26-27');
      expect(range.start, DateTime(2027, 1, 1));
      expect(range.endExclusive, DateTime(2027, 4, 1));
    });

    test('March 31 is the last day of Q4 - must not roll into next FY\'s Q1',
        () {
      final range = currentFyQuarter(DateTime(2027, 3, 31));
      expect(range.label, 'Q4 FY26-27');
    });

    test('April 1 exactly is the first day of the new FY\'s Q1, not the '
        'previous FY\'s Q4', () {
      final range = currentFyQuarter(DateTime(2027, 4, 1));
      expect(range.label, 'Q1 FY27-28');
      expect(range.start, DateTime(2027, 4, 1));
    });
  });

  group('currentFyYear', () {
    test('any date from April through the following March maps to one '
        'consistent FY range', () {
      final inApril = currentFyYear(DateTime(2026, 4, 1));
      final inDecember = currentFyYear(DateTime(2026, 12, 25));
      final inMarch = currentFyYear(DateTime(2027, 3, 31));

      for (final range in [inApril, inDecember, inMarch]) {
        expect(range.label, 'FY26-27');
        expect(range.start, DateTime(2026, 4, 1));
        expect(range.endExclusive, DateTime(2027, 4, 1));
      }
    });

    test('a date on the FY boundary (April 1) belongs to the new FY', () {
      final range = currentFyYear(DateTime(2027, 4, 1));
      expect(range.label, 'FY27-28');
    });
  });

  group('ordersInFyRange', () {
    final range = currentFyYear(DateTime(2026, 6, 1)); // FY26-27

    test('an order exactly at the range start is included (start is '
        'inclusive)', () {
      final orders = [_order(placedAt: range.start)];
      expect(ordersInFyRange(orders, range), hasLength(1));
    });

    test('an order exactly at endExclusive is excluded (end is exclusive)',
        () {
      final orders = [_order(placedAt: range.endExclusive)];
      expect(ordersInFyRange(orders, range), isEmpty);
    });

    test('an order one day before the range start is excluded', () {
      final orders = [
        _order(placedAt: range.start.subtract(const Duration(days: 1)))
      ];
      expect(ordersInFyRange(orders, range), isEmpty);
    });

    test('an order one second before endExclusive is included', () {
      final orders = [
        _order(placedAt: range.endExclusive.subtract(const Duration(seconds: 1)))
      ];
      expect(ordersInFyRange(orders, range), hasLength(1));
    });

    test('filters a mixed list down to only the in-range orders', () {
      final inRange1 = _order(placedAt: DateTime(2026, 5, 1));
      final inRange2 = _order(placedAt: DateTime(2027, 1, 1));
      final beforeRange = _order(placedAt: DateTime(2026, 3, 31));
      final afterRange = _order(placedAt: DateTime(2027, 4, 1));

      final result = ordersInFyRange(
        [inRange1, beforeRange, inRange2, afterRange],
        range,
      );

      expect(result, containsAll([inRange1, inRange2]));
      expect(result, isNot(contains(beforeRange)));
      expect(result, isNot(contains(afterRange)));
      expect(result, hasLength(2));
    });

    test('an empty order list returns an empty result', () {
      expect(ordersInFyRange([], range), isEmpty);
    });
  });
}
