import '../../models/order.dart';

/// One Indian Financial Year period (Apr 1 - Mar 31), or one quarter within
/// it (Q1 Apr-Jun ... Q4 Jan-Mar). GST/income tax filing runs on FY, not
/// calendar year.
class FyRange {
  final DateTime start;
  final DateTime endExclusive;
  final String label;
  const FyRange(
      {required this.start, required this.endExclusive, required this.label});
}

FyRange currentFyQuarter(DateTime now) {
  final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
  final monthsIntoFy = (now.month - 4) % 12;
  final quarterIndex = monthsIntoFy ~/ 3; // 0..3
  var startMonth = 4 + quarterIndex * 3;
  var startYear = fyStartYear;
  if (startMonth > 12) {
    startMonth -= 12;
    startYear += 1;
  }
  final start = DateTime(startYear, startMonth, 1);
  var endMonth = startMonth + 3;
  var endYear = startYear;
  if (endMonth > 12) {
    endMonth -= 12;
    endYear += 1;
  }
  final end = DateTime(endYear, endMonth, 1);
  final fyTag =
      '${fyStartYear.toString().substring(2)}-${(fyStartYear + 1).toString().substring(2)}';
  return FyRange(
      start: start, endExclusive: end, label: 'Q${quarterIndex + 1} FY$fyTag');
}

FyRange currentFyYear(DateTime now) {
  final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
  final start = DateTime(fyStartYear, 4, 1);
  final end = DateTime(fyStartYear + 1, 4, 1);
  final fyTag =
      '${fyStartYear.toString().substring(2)}-${(fyStartYear + 1).toString().substring(2)}';
  return FyRange(start: start, endExclusive: end, label: 'FY$fyTag');
}

/// Orders placed within [range] - start inclusive, end exclusive, matching
/// how [range] itself is defined.
List<CustomerOrder> ordersInFyRange(
        List<CustomerOrder> orders, FyRange range) =>
    orders
        .where((o) =>
            !o.placedAt.isBefore(range.start) &&
            o.placedAt.isBefore(range.endExclusive))
        .toList();
