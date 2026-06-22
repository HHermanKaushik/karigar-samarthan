import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_modal.dart';
import '../../models/order.dart';
import '../../providers/orders_provider.dart';
import '../../providers/translations_provider.dart';
import 'order_details_screen.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final tr = ref.watch(trProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('myOrders'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(tr('tapOrderDetails'),
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    tr('noOrdersYet'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('ordersWillAppear'),
                    style: const TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...orders.map((o) => _OrderCard(
                  order: o,
                  tr: tr,
                  onTap: () => showAppModal(context,
                      child: OrderDetailsScreen(order: o)),
                )),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CustomerOrder order;
  final String Function(String) tr;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.tr,
    required this.onTap,
  });

  Color _statusColor() {
    switch (order.status) {
      case OrderStatus.placed:
        return AppColors.secondary;
      case OrderStatus.paid:
        return AppColors.accent;
      case OrderStatus.shipped:
        return AppColors.primary;
      case OrderStatus.delivered:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, h:mm a');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Order # ${order.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor().withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr('status_${order.status.name}'),
                        style: TextStyle(
                            color: _statusColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(order.productTitle,
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 6),
                Text('${tr('ordered')}: ${df.format(order.placedAt)}',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
