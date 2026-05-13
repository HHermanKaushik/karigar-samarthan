import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart';

class OrderDetailsScreen extends StatelessWidget {
  final CustomerOrder order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Order Details',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _SectionTitle('Shipping Address'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(order.shippingAddress),
                      const SizedBox(height: 4),
                      Text('Phone: ${order.customerPhone}'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final text =
                        '${order.customerName}\n${order.shippingAddress}\nPhone: ${order.customerPhone}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Items'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_outlined,
                    color: AppColors.primary),
              ),
              title: Text(order.productTitle),
              subtitle: Text('Quantity: ${order.quantity}'),
              trailing: Text('₹ ${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('Payment Total',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('₹ ${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'AI Assistant will ask for the tracking number shortly.')),
              );
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Mark as Shipped'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Once you mark an order as "shipped", our AI Assistant will ask for the Tracking Number. Payment is released once it is delivered to the customer.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6)),
    );
  }
}
