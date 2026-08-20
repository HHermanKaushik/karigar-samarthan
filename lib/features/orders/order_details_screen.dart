import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../models/order.dart';
import '../../providers/translations_provider.dart';
import '../../services/service_providers.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final CustomerOrder order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _shipping = false;

  // Draft persistence for the "Mark as Shipped" tracking/carrier fields,
  // keyed per order - switching away mid-entry (e.g. to WhatsApp) and back
  // was losing whatever had been typed, likely Android reclaiming the
  // backgrounded process. Saved on every keystroke, restored on open.
  String get _draftTrackingKey => 'shipping_draft_tracking_${widget.order.id}';
  String get _draftCarrierKey => 'shipping_draft_carrier_${widget.order.id}';

  Future<void> _clearShippingDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftTrackingKey);
    await prefs.remove(_draftCarrierKey);
  }

  Future<void> _markShipped() async {
    final tr = ref.read(trProvider);
    final prefs = await SharedPreferences.getInstance();
    final trackingController =
        TextEditingController(text: prefs.getString(_draftTrackingKey) ?? '');
    final carrierController = TextEditingController(
        text: prefs.getString(_draftCarrierKey) ?? 'India Post');
    trackingController.addListener(() {
      prefs.setString(_draftTrackingKey, trackingController.text);
    });
    carrierController.addListener(() {
      prefs.setString(_draftCarrierKey, carrierController.text);
    });

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('markAsShipped')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trackingController,
              decoration: InputDecoration(
                labelText: tr('trackingNumberLabel'),
                hintText: '${tr('egPrefix')} EA123456789IN',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: carrierController,
              decoration: InputDecoration(
                labelText: tr('carrierLabel'),
                hintText: '${tr('egPrefix')} India Post, DTDC, BlueDart',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (trackingController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: Text(tr('confirmBtn')),
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

      // Update Firestore immediately, don't wait on the webhook.
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

      await _clearShippingDraft();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            wooOk ? tr('orderShippedWooSuccess') : tr('orderShippedWooFailed')),
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _shipping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('errorPrefix')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final tr = ref.watch(trProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('orderDetailsTitle'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectionTitle(tr('shippingAddress')),
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
                      Text('${tr('phone')}: ${order.customerPhone}'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final text =
                        '${order.customerName}\n${order.shippingAddress}\n${tr('phone')}: ${order.customerPhone}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('addressCopied'))),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(tr('itemsSectionTitle')),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            // One row per line item.
            child: Column(
              children: [
                for (var i = 0; i < order.lineItems.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
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
                    title: Text(order.lineItems[i].title),
                    subtitle: Text(
                        '${tr('quantityLabel')}: ${order.lineItems[i].quantity}'),
                    trailing: Text(
                        '₹ ${order.lineItems[i].price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tr('paymentTotal'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('₹ ${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
                if (order.upiUtr.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(tr('upiReferenceUtr'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Text(order.upiUtr,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: order.upiUtr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('utrCopied'))),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined, size: 18),
                      ),
                    ],
                  ),
                ],
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
              label: Text(
                  _shipping ? tr('updatingEllipsis') : tr('markAsShipped')),
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
                        ? tr('deliveredLabel')
                        : tr('shippedLabel'),
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
