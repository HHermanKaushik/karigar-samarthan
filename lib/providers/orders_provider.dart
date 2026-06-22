import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order.dart';

class OrdersNotifier extends StateNotifier<List<CustomerOrder>> {
  OrdersNotifier() : super([]) {
    _loadFromFirestore();
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      );

  static bool get _isAuthenticated {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _loadFromFirestore() async {
    if (!_isAuthenticated) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(_uid)
          .collection('orders')
          .get();
      state = snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    } catch (_) {}
  }

  static CustomerOrder _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CustomerOrder(
      id: doc.id,
      productTitle: d['productTitle'] ?? '',
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      placedAt:
          (d['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => OrderStatus.placed,
      ),
      customerName: d['customerName'] ?? '',
      shippingAddress: d['shippingAddress'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      productImage: d['productImage'] as String?,
    );
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, List<CustomerOrder>>(
        (ref) => OrdersNotifier());
