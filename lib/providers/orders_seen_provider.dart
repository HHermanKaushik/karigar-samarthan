import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import 'orders_provider.dart';

/// Count of orders the karigar still needs to act on - placed or paid but
/// not yet shipped. Drives the "new order" badge on the bottom-nav Orders
/// icon. Deliberately status-based, not "seen at time T": a badge that
/// clears just because the Orders screen was opened (regardless of whether
/// anything was actually shipped) is exactly the bug this replaced - the
/// dot should only go away once there's nothing left needing to be shipped.
///
/// True OS-level push notifications (arriving while the app is closed) are
/// a separate, larger feature: they'd need firebase_messaging added to the
/// Flutter app, an FCM token stored per karigar, and functions/index.js's
/// wooOrderWebhook extended to send a push when it writes a brand-new order
/// doc - not attempted here.
final newOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders
      .where(
          (o) => o.status == OrderStatus.placed || o.status == OrderStatus.paid)
      .length;
});
