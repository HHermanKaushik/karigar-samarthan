import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';

class OrdersNotifier extends StateNotifier<List<CustomerOrder>> {
  OrdersNotifier() : super([]) {
    _init();
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      );

  static bool get _isAuthenticated {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _init() {
    if (!_isAuthenticated) return;
    _sub = _db
        .collection('users')
        .doc(_uid)
        .collection('orders')
        .orderBy('placedAt', descending: true)
        .snapshots()
        .listen(
      (snap) {
        state = snap.docs.map(_fromDoc).toList();
      },
      onError: (_) {},
    );
  }

  /// Forces a one-time re-fetch (e.g. pull-to-refresh).
  Future<void> refresh() async {
    if (!_isAuthenticated) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('orders')
          .orderBy('placedAt', descending: true)
          .get();
      state = snap.docs.map(_fromDoc).toList();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static CustomerOrder _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final productTitle = d['productTitle'] ?? '';
    final productImage = d['productImage'] as String?;
    final quantity = (d['quantity'] as num?)?.toInt() ?? 1;

    final rawLineItems = d['lineItems'] as List<dynamic>?;
    final lineItems = (rawLineItems != null && rawLineItems.isNotEmpty)
        ? rawLineItems.map((raw) {
            final li = raw as Map<String, dynamic>;
            return OrderLineItem(
              title: li['title'] as String? ?? '',
              image: li['image'] as String?,
              quantity: (li['quantity'] as num?)?.toInt() ?? 1,
              price: (li['price'] as num?)?.toDouble() ?? 0,
            );
          }).toList()
        // Orders synced before lineItems existed in Firestore - fall back
        // to a single-item list built from the legacy flat fields.
        : [
            OrderLineItem(
              title: productTitle,
              image: productImage,
              quantity: quantity,
              price: (d['total'] as num?)?.toDouble() ?? 0,
            ),
          ];

    return CustomerOrder(
      id: doc.id,
      lineItems: lineItems,
      productTitle: productTitle,
      productImage: productImage,
      quantity: quantity,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      placedAt: (d['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => OrderStatus.placed,
      ),
      customerName: d['customerName'] ?? '',
      shippingAddress: d['shippingAddress'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      upiUtr: d['upiUtr'] as String? ?? '',
      trackingNumber: d['trackingNumber'] as String? ?? '',
      carrier: d['carrier'] as String? ?? '',
    );
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<CustomerOrder>>(
        (ref) => OrdersNotifier());
