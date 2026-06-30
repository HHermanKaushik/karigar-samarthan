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
      state = snap.docs.map(_fromDoc).where((p) => !p.archived).toList();
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

  Future<void> archive(String id) async {
    state = state.where((p) => p.id != id).toList();
    if (_isAuthenticated) {
      await _col.doc(id).update({'archived': true});
    }
  }

  /// Reloads from Firestore and removes any product whose WooCommerce listing
  /// no longer exists. [activeWooIds] comes from WooCommerceService; if it is
  /// empty (network error) no deletions are performed so local data is safe.
  Future<void> refresh(List<int> activeWooIds) async {
    if (!_isAuthenticated) return;
    try {
      final snap = await _col.get();
      final fresh = snap.docs.map(_fromDoc).toList();

      if (activeWooIds.isNotEmpty) {
        for (final p in fresh) {
          if (p.wooId != null && !activeWooIds.contains(p.wooId)) {
            await _col.doc(p.id).delete();
          }
        }
        state = fresh
            .where((p) => p.wooId == null || activeWooIds.contains(p.wooId))
            .where((p) => !p.archived)
            .toList();
      } else {
        state = fresh.where((p) => !p.archived).toList();
      }
    } catch (_) {}
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
      wooImageUrl: d['wooImageUrl'] as String?,
      archived: d['archived'] as bool? ?? false,
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
        if (p.wooImageUrl != null) 'wooImageUrl': p.wooImageUrl,
        'archived': p.archived,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<Product>>(
        (ref) => ProductsNotifier());
