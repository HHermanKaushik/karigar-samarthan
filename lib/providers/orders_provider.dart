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
    return CustomerOrder(
      id: doc.id,
      productTitle: d['productTitle'] ?? '',
      productImage: d['productImage'] as String?,
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      placedAt: (d['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => OrderStatus.placed,
      ),
      customerName: d['customerName'] ?? '',
      shippingAddress: d['shippingAddress'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
    );
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<CustomerOrder>>(
        (ref) => OrdersNotifier());
