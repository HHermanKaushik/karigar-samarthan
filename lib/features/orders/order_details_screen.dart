import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart';
import '../../services/service_providers.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final CustomerOrder order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _shipping = false;

  Future<void> _markShipped() async {
    final trackingController = TextEditingController();
    final carrierController = TextEditingController(text: 'India Post');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Shipped'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trackingController,
              decoration: const InputDecoration(
                labelText: 'Tracking Number *',
                hintText: 'e.g. EA123456789IN',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: carrierController,
              decoration: const InputDecoration(
                labelText: 'Carrier',
                hintText: 'e.g. India Post, DTDC, BlueDart',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (trackingController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final tracking = trackingController.text.trim();
    final carrier = carrierController.text.trim().isEmpty
        ? 'India Post'
        : carrierController.text.trim();

    setState(() => _shipping = true);

    try {
      final wooId = int.tryParse(widget.order.id);
      bool wooOk = false;
      if (wooId != null) {
        wooOk = await ref.read(wooServiceProvider).markOrderShipped(
          wooOrderId: wooId,
          trackingNumber: tracking,
          carrier: carrier,
        );
      }

      // Update Firestore immediately so the orders list reflects the new status
      // without waiting for a WooCommerce webhook.
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final db = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'karigar',
        );
        await db
            .collection('users')
            .doc(uid)
            .collection('orders')
            .doc(widget.order.id)
            .update({
          'status': 'shipped',
          'wooStatus': 'completed',
          'trackingNumber': tracking,
          'carrier': carrier,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(wooOk
            ? 'Order marked as shipped. Customer notified via WooCommerce.'
            : 'Marked as shipped in app. WooCommerce update failed — check your connection.'),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _shipping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
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
                          style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
              color: AppColors.accent.withValues(alpha: 0.08),
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
          if (order.status != OrderStatus.shipped &&
              order.status != OrderStatus.delivered)
            ElevatedButton.icon(
              onPressed: _shipping ? null : _markShipped,
              icon: _shipping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.local_shipping_outlined),
              label: Text(_shipping ? 'Updating…' : 'Mark as Shipped'),
            ),
          if (order.status == OrderStatus.shipped ||
              order.status == OrderStatus.delivered)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    order.status == OrderStatus.delivered
                        ? 'Delivered'
                        : 'Shipped',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
