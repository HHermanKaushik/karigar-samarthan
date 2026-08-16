import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/service_providers.dart';
import '../services/sync_logger.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  final SyncLogger _logger;

  ProductsNotifier(this._logger) : super([]) {
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

  /// Newest-created first. Firestore's own document order is not
  /// guaranteed, and older documents predate [Product.createdAt] entirely
  /// (sorted last, oldest-first among themselves) - this is intentionally
  /// resilient to both rather than trusting incoming list order.
  static List<Product> _newestFirst(List<Product> products) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return [...products]
      ..sort((a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch));
  }

  Future<void> _loadFromFirestore() async {
    if (!_isAuthenticated) return;
    try {
      final snap = await _col.get();
      state = _newestFirst(
          snap.docs.map(_fromDoc).where((p) => !p.archived).toList());
    } catch (_) {}
  }

  void add(Product p) {
    state = [p, ...state];
    if (_isAuthenticated) {
      // createdAt is set here, once, only on the write that creates the
      // document - never re-included in the shared _toMap() used by
      // update() too, or every edit would bump it back to "now".
      _col.doc(p.id).set({
        ..._toMap(p),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void update(Product p) {
    state = [
      for (final x in state)
        if (x.id == p.id) p else x
    ];
    if (_isAuthenticated) {
      // merge: true - a plain set() would silently wipe the createdAt
      // written by add() above, since it's deliberately absent from
      // _toMap()'s fields.
      _col.doc(p.id).set(_toMap(p), SetOptions(merge: true));
    }
  }

  Future<void> archive(String id) async {
    state = state.where((p) => p.id != id).toList();
    if (_isAuthenticated) {
      await _col.doc(id).update({'archived': true});
    }
  }

  /// Fetches archived products directly from Firestore. Not kept in [state]
  /// since every other reader of [state] assumes archived products are
  /// excluded (see [_loadFromFirestore] and [refresh]).
  Future<List<Product>> fetchArchived() async {
    if (!_isAuthenticated) return [];
    try {
      final snap = await _col.where('archived', isEqualTo: true).get();
      return snap.docs.map(_fromDoc).toList();
    } catch (e, st) {
      await _logger.logError(
        'fetch_archived_products',
        e,
        stackTrace: st,
        context: {'uid': _uid},
      );
      return [];
    }
  }

  Future<void> restore(Product p) async {
    final restored = p.copyWith(archived: false);
    if (_isAuthenticated) {
      await _col.doc(p.id).update({'archived': false});
    }
    state = [restored, ...state];
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
        state = _newestFirst(fresh
            .where((p) => p.wooId == null || activeWooIds.contains(p.wooId))
            .where((p) => !p.archived)
            .toList());
      } else {
        state = _newestFirst(fresh.where((p) => !p.archived).toList());
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
      localTitle: d['localTitle'] as String? ?? '',
      localCategory: d['localCategory'] as String? ?? '',
      localDescription: d['localDescription'] as String? ?? '',
      localLanguageCode: d['localLanguageCode'] as String?,
      price: (d['price'] as num?)?.toDouble() ?? 0,
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      imagePaths: List<String>.from(d['imagePaths'] ?? []),
      tags: List<String>.from(d['tags'] ?? []),
      wooId: d['wooId'] as int?,
      wooImageUrl: d['wooImageUrl'] as String?,
      wooImageUrls: List<String>.from(d['wooImageUrls'] ?? []),
      archived: d['archived'] as bool? ?? false,
      permalink: d['permalink'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> _toMap(Product p) => {
        'title': p.title,
        'category': p.category,
        'description': p.description,
        'localTitle': p.localTitle,
        'localCategory': p.localCategory,
        'localDescription': p.localDescription,
        if (p.localLanguageCode != null)
          'localLanguageCode': p.localLanguageCode,
        'price': p.price,
        'quantity': p.quantity,
        'imagePaths': p.imagePaths,
        'tags': p.tags,
        if (p.wooId != null) 'wooId': p.wooId,
        if (p.wooImageUrl != null) 'wooImageUrl': p.wooImageUrl,
        'wooImageUrls': p.wooImageUrls,
        'archived': p.archived,
        if (p.permalink != null) 'permalink': p.permalink,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
    (ref) => ProductsNotifier(ref.read(syncLoggerProvider)));
