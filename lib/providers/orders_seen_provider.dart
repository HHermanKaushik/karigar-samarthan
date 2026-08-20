import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';
import 'orders_provider.dart';

/// Count of orders needing action (placed/paid, not shipped) - drives the
/// bottom-nav Orders badge. Status-based, not "seen at time T", so it
/// clears only once nothing's left to ship. No OS-level push notification
/// support here - that would need firebase_messaging + an FCM token per
/// karigar.
final newOrdersCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders
      .where(
          (o) => o.status == OrderStatus.placed || o.status == OrderStatus.paid)
      .length;
});
