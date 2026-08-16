import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';

enum _ReportPeriod { quarter, year }

/// One Indian Financial Year period (Apr 1 - Mar 31), or one quarter within
/// it (Q1 Apr-Jun ... Q4 Jan-Mar) - GST returns and income tax filing in
/// India both run on the FY calendar, not the Jan-Dec one, so that's what
/// "quarter"/"year" mean here rather than calendar quarters.
class _FyRange {
  final DateTime start;
  final DateTime endExclusive;
  final String label;
  const _FyRange(
      {required this.start, required this.endExclusive, required this.label});
}

_FyRange _currentFyQuarter(DateTime now) {
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
  return _FyRange(
      start: start, endExclusive: end, label: 'Q${quarterIndex + 1} FY$fyTag');
}

_FyRange _currentFyYear(DateTime now) {
  final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
  final start = DateTime(fyStartYear, 4, 1);
  final end = DateTime(fyStartYear + 1, 4, 1);
  final fyTag =
      '${fyStartYear.toString().substring(2)}-${(fyStartYear + 1).toString().substring(2)}';
  return _FyRange(start: start, endExclusive: end, label: 'FY$fyTag');
}

class TaxReportScreen extends ConsumerStatefulWidget {
  const TaxReportScreen({super.key});

  @override
  ConsumerState<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends ConsumerState<TaxReportScreen> {
  _ReportPeriod _period = _ReportPeriod.quarter;
  bool _generating = false;

  _FyRange get _range {
    final now = DateTime.now();
    return _period == _ReportPeriod.quarter
        ? _currentFyQuarter(now)
        : _currentFyYear(now);
  }

  List<CustomerOrder> _ordersInRange(List<CustomerOrder> all, _FyRange r) => all
      .where((o) =>
          !o.placedAt.isBefore(r.start) && o.placedAt.isBefore(r.endExclusive))
      .toList();

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _buildReportText(_FyRange r, List<CustomerOrder> orders) {
    final user = ref.read(userProvider);
    final total = orders.fold<double>(0, (sum, o) => sum + o.total);
    final buffer = StringBuffer();
    buffer.writeln('KARIGAR SAMARTHAN - SALES REPORT');
    buffer.writeln('Generated: ${_fmtDate(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('Seller Details');
    buffer.writeln('Name: ${user.fullName}');
    buffer.writeln('Store Name: ${user.storeName}');
    buffer.writeln('Phone: ${user.phone}');
    if (user.upiId.isNotEmpty) buffer.writeln('UPI ID: ${user.upiId}');
    buffer.writeln();
    buffer.writeln(
        'Reporting Period: ${r.label} (${_fmtDate(r.start)} - ${_fmtDate(r.endExclusive.subtract(const Duration(days: 1)))})');
    buffer.writeln();
    buffer.writeln('Summary');
    buffer.writeln('Total Orders: ${orders.length}');
    buffer.writeln('Total Sales: Rs ${total.toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Order Details');
    buffer.writeln('-' * 60);
    for (final o in orders) {
      buffer.writeln(
          '${_fmtDate(o.placedAt)}  Order #${o.id}  ${o.customerName}  '
          'Rs ${o.total.toStringAsFixed(2)}  [${o.status.name}]');
    }
    if (orders.isEmpty) buffer.writeln('(no orders in this period)');
    buffer.writeln('-' * 60);
    buffer.writeln();
    buffer.writeln(
        'This report reflects gross sales recorded in the Karigar Samarthan '
        'app for the selected period. It is not a tax calculation or filing '
        'document - please consult a tax professional or chartered '
        'accountant to determine your actual tax liability.');
    return buffer.toString();
  }

  Future<void> _downloadReport(_FyRange r, List<CustomerOrder> orders) async {
    setState(() => _generating = true);
    try {
      final text = _buildReportText(r, orders);
      final dir = await getTemporaryDirectory();
      final safeLabel = r.label.replaceAll(' ', '_');
      final file = File('${dir.path}/karigar_sales_report_$safeLabel.txt');
      await file.writeAsString(text);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'Karigar Samarthan Sales Report - ${r.label}',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${ref.read(trProvider)('taxReportError')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final allOrders = ref.watch(ordersProvider);
    final range = _range;
    final orders = _ordersInRange(allOrders, range);
    final total = orders.fold<double>(0, (sum, o) => sum + o.total);
    final user = ref.watch(userProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('taxReportTitle'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('taxReportSubtitle'),
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PeriodChip(
                  label: tr('thisQuarter'),
                  selected: _period == _ReportPeriod.quarter,
                  onTap: () => setState(() => _period = _ReportPeriod.quarter),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PeriodChip(
                  label: tr('thisYear'),
                  selected: _period == _ReportPeriod.year,
                  onTap: () => setState(() => _period = _ReportPeriod.year),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(range.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          '${_fmtDate(range.start)} - ${_fmtDate(range.endExclusive.subtract(const Duration(days: 1)))}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        const Divider(height: 24),
                        _SummaryRow(
                            label: tr('storeName'), value: user.storeName),
                        _SummaryRow(
                            label: tr('totalOrders'),
                            value: '${orders.length}'),
                        _SummaryRow(
                            label: tr('totalSales'),
                            value: '₹ ${total.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('taxReportDisclaimer'),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed:
                  _generating ? null : () => _downloadReport(range, orders),
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: Text(tr('downloadTaxReport')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
