import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier() : super([]) {
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

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('products');

  Future<void> _loadFromFirestore() async {
    if (!_isAuthenticated) return;
    try {
      final snap = await _col.get();
      state = snap.docs.map(_fromDoc).toList();
    } catch (_) {}
  }

  void add(Product p) {
    state = [p, ...state];
    if (_isAuthenticated) _col.doc(p.id).set(_toMap(p));
  }

  void update(Product p) {
    state = [for (final x in state) if (x.id == p.id) p else x];
    if (_isAuthenticated) _col.doc(p.id).set(_toMap(p));
  }

  void remove(String id) {
    state = state.where((x) => x.id != id).toList();
    if (_isAuthenticated) _col.doc(id).delete();
  }

  static Product _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Product(
      id: doc.id,
      title: d['title'] ?? '',
      category: d['category'] ?? '',
      description: d['description'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      imagePaths: List<String>.from(d['imagePaths'] ?? []),
      tags: List<String>.from(d['tags'] ?? []),
      wooId: d['wooId'] as int?,
    );
  }

  static Map<String, dynamic> _toMap(Product p) => {
        'title': p.title,
        'category': p.category,
        'description': p.description,
        'price': p.price,
        'quantity': p.quantity,
        'imagePaths': p.imagePaths,
        'tags': p.tags,
        if (p.wooId != null) 'wooId': p.wooId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<Product>>(
        (ref) => ProductsNotifier());
