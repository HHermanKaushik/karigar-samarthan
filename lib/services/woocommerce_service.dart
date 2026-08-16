import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'sync_logger.dart';

class PublishResult {
  final bool success;
  final String? message;
  final int? productId;

  /// First image URL - kept for callers that only ever cared about one.
  final String? imageUrl;

  /// Every image URL WooCommerce now has for this product, in order.
  final List<String> imageUrls;

  /// The public storefront URL WooCommerce assigned this product.
  final String? permalink;

  const PublishResult({
    required this.success,
    this.message,
    this.productId,
    this.imageUrl,
    this.imageUrls = const [],
    this.permalink,
  });
}

/// Aggregate price stats across all karigars' published listings in one
/// WooCommerce category - used for smart-pricing suggestions and as an
/// honest, in-marketplace substitute for cross-site competitor comparison.
class CategoryPriceStats {
  final int count;
  final double min;
  final double max;
  final double avg;

  const CategoryPriceStats({
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
  });
}

class WooCommerceService {
  final Dio _dio;
  final Dio _wpDio;
  final SyncLogger _logger;
  final String _wpUsername;
  final String _wpAppPassword;

  WooCommerceService({SyncLogger? logger})
      : _logger = logger ?? SyncLogger(),
        _wpUsername = dotenv.env['WP_USERNAME'] ?? '',
        _wpAppPassword = dotenv.env['WP_APP_PASSWORD'] ?? '',
        _dio = Dio(
          BaseOptions(
            baseUrl:
                '${(dotenv.env['WOOCOMMERCE_BASE_URL'] ?? '').trim()}/wp-json/wc/v3',
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            queryParameters: {
              'consumer_key': dotenv.env['WOOCOMMERCE_CONSUMER_KEY'] ?? '',
              'consumer_secret':
                  dotenv.env['WOOCOMMERCE_CONSUMER_SECRET'] ?? '',
            },
          ),
        ),
        _wpDio = Dio(
          BaseOptions(
            baseUrl:
                '${(dotenv.env['WOOCOMMERCE_BASE_URL'] ?? '').trim()}/wp-json/wp/v2',
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  String get _wpBasicAuthHeader {
    final token = base64Encode(utf8.encode('$_wpUsername:$_wpAppPassword'));
    return 'Basic $token';
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String _extensionFor(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  Future<int?> _uploadImageToWordPress(File imageFile) async {
    print('========== WP UPLOAD DEBUG ==========');
    print('username: $_wpUsername');
    print('password empty: ${_wpAppPassword.isEmpty}');
    print('base url: ${_wpDio.options.baseUrl}');
    print('file exists: ${await imageFile.exists()}');
    print('file size: ${await imageFile.length()}');
    print('======================================');
    if (_wpUsername.isEmpty || _wpAppPassword.isEmpty) {
      debugPrint(
          'wp_media_upload: WP_USERNAME="$_wpUsername" WP_APP_PASSWORD is ${_wpAppPassword.isEmpty ? "EMPTY" : "set"} — check .env');
      await _logger.logError(
        'wp_media_upload',
        'Missing WP_USERNAME / WP_APP_PASSWORD in .env',
      );
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final mimeType = _mimeTypeFor(imageFile.path);
      final ext = _extensionFor(mimeType);
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';

      debugPrint(
          'wp_media_upload: attempting POST to ${_wpDio.options.baseUrl}/media as user "$_wpUsername"');

      final response = await _wpDio.post(
        '/media',
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Authorization': _wpBasicAuthHeader,
            'Content-Type': mimeType,
            'Content-Disposition': 'attachment; filename="$fileName"',
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      debugPrint('wp_media_upload: success, mediaId=${response.data['id']}');
      return response.data['id'] as int?;
    } catch (e, st) {
      debugPrint('wp_media_upload ERROR: $e');
      await _logger.logError(
        'wp_media_upload',
        e,
        stackTrace: st,
        context: {'file': imageFile.path},
      );
      return null;
    }
  }

  Future<String?> _backupToFirebaseStorage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('products').child(fileName);

      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: _mimeTypeFor(imageFile.path)),
      );

      return await ref.getDownloadURL();
    } catch (e, st) {
      await _logger.logError(
        'firebase_storage_backup',
        e,
        stackTrace: st,
        context: {'file': imageFile.path},
      );
      return null;
    }
  }

  /// Resolves [name] to the ID of the matching term in the given WordPress
  /// [taxonomy] (its REST base, e.g. `product_brand` or `product_cat`),
  /// creating the term if none exists yet. The WooCommerce products endpoint
  /// only accepts `brands`/`categories` by `id` — their `name` sub-field is
  /// read-only, so posting `{'name': ...}` there is silently ignored. Returns
  /// null (and logs) if lookup/creation fails, so callers can skip that
  /// field rather than fail the whole publish/update.
  Future<int?> _resolveTermId(String taxonomy, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (_wpUsername.isEmpty || _wpAppPassword.isEmpty) return null;

    try {
      final search = await _wpDio.get<List<dynamic>>(
        '/$taxonomy',
        queryParameters: {'search': trimmed, 'per_page': 100},
        options: Options(headers: {'Authorization': _wpBasicAuthHeader}),
      );
      for (final entry in search.data ?? []) {
        final term = entry as Map<String, dynamic>;
        if ((term['name'] as String?)?.toLowerCase() == trimmed.toLowerCase()) {
          return term['id'] as int?;
        }
      }

      final created = await _wpDio.post(
        '/$taxonomy',
        data: {'name': trimmed},
        options: Options(headers: {'Authorization': _wpBasicAuthHeader}),
      );
      return created.data['id'] as int?;
    } catch (e, st) {
      await _logger.logError(
        'wc_resolve_term',
        e,
        stackTrace: st,
        context: {'taxonomy': taxonomy, 'name': trimmed},
      );
      return null;
    }
  }

  String _friendlyWooError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Could not publish product. Please try again.';
  }

  /// Uploads each file (same path as publishProduct(): WordPress media
  /// first, Firebase Storage as fallback) and returns one WooCommerce image
  /// entry per file that succeeded. A single failed upload is skipped
  /// (and logged) rather than aborting every other image in the batch.
  Future<List<Map<String, Object?>>> _uploadImagesForEntries(
      List<File> files) async {
    final entries = <Map<String, Object?>>[];
    for (final file in files) {
      int? mediaId;
      if (_wpUsername.isNotEmpty && _wpAppPassword.isNotEmpty) {
        mediaId = await _uploadImageToWordPress(file);
      }
      String? storageUrl;
      if (mediaId == null) {
        storageUrl = await _backupToFirebaseStorage(file)
            .timeout(const Duration(seconds: 15), onTimeout: () => null);
      }
      if (mediaId != null) {
        entries.add({'id': mediaId});
      } else if (storageUrl != null) {
        entries.add({'src': storageUrl});
      }
    }
    return entries;
  }

  Future<PublishResult> updateProduct({
    required int wooId,
    required String title,
    required String description,
    required String price,
    required int quantity,
    String category = '',
    String storeName = '',
    List<File>? newImageFiles,
    List<String>? keepImageUrls,
  }) async {
    try {
      // null (both params) = don't touch images at all - existing callers
      // that only update text/price keep this exact behavior. Passing
      // either param (even as an empty list) means "here is the full
      // desired image set" - kept existing images by URL plus newly picked
      // files uploaded fresh. Note: kept images are re-sideloaded by URL
      // (WooCommerce doesn't accept "keep this existing attachment by URL"
      // without its media id, which this app doesn't track) - functionally
      // correct but can leave old duplicate attachments in the WP media
      // library over repeated edits.
      List<Map<String, Object?>>? images;
      if (newImageFiles != null || keepImageUrls != null) {
        images = [
          for (final url in keepImageUrls ?? const <String>[]) {'src': url},
          ...await _uploadImagesForEntries(newImageFiles ?? const <File>[]),
        ];
      }

      final categoryTermId = await _resolveTermId('product_cat', category);
      final brandTermId = await _resolveTermId('product_brand', storeName);
      final response = await _dio.put('/products/$wooId', data: {
        'name': title,
        'regular_price': price,
        'description': description,
        'stock_quantity': quantity,
        'manage_stock': true,
        if (images != null) 'images': images,
        if (categoryTermId != null)
          'categories': [
            {'id': categoryTermId},
          ],
        if (brandTermId != null)
          'brands': [
            {'id': brandTermId},
          ],
      });

      final respImages = response.data['images'] as List?;
      final imageUrls = (respImages ?? [])
          .map((img) => (img as Map<String, dynamic>)['src'] as String?)
          .whereType<String>()
          .toList();

      return PublishResult(
        success: true,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        imageUrls: imageUrls,
        permalink: response.data['permalink'] as String?,
      );
    } catch (e, st) {
      await _logger.logError(
        'wc_update_product',
        e,
        stackTrace: st,
        context: {'wooId': wooId, 'title': title},
      );

      return PublishResult(
        success: false,
        message: e is DioException
            ? _friendlyWooError(e)
            : 'Could not update product. Please try again.',
      );
    }
  }

  /// Sets or clears the WooCommerce-side archived state: [archived] marks the
  /// product out of stock and hides it from catalog/search, [!archived]
  /// reverses both. [quantity] is the stock count to restore when
  /// un-archiving (ignored when archiving).
  ///
  /// All products here have `manage_stock` enabled, under which WooCommerce
  /// always re-derives `stock_status` from `stock_quantity` on save and
  /// ignores an explicit `stock_status` value sent alongside a non-zero/zero
  /// quantity mismatch — so the quantity must be driven to 0 (archive) or
  /// back to its original value (restore) in the same request for the
  /// status to actually stick. `stock_status`/`catalog_visibility` are
  /// otherwise standard WooCommerce product fields, so an admin can also
  /// toggle them back manually from the WordPress product edit screen.
  ///
  /// `catalog_visibility: hidden` alone only delists a product from
  /// catalog/search — its direct permalink still resolves and returns the
  /// page (confirmed via live testing). `status: private` is what actually
  /// blocks direct-URL access, so both must be set together for an archive
  /// to fully take a product off the storefront.
  Future<bool> setProductArchived({
    required int wooId,
    required bool archived,
    int quantity = 0,
  }) async {
    try {
      await _dio.put('/products/$wooId', data: {
        'stock_quantity': archived ? 0 : quantity,
        'stock_status': archived ? 'outofstock' : 'instock',
        'catalog_visibility': archived ? 'hidden' : 'visible',
        'status': archived ? 'private' : 'publish',
      });
      return true;
    } catch (e, st) {
      await _logger.logError(
        'wc_set_product_archived',
        e,
        stackTrace: st,
        context: {'wooId': wooId, 'archived': archived, 'quantity': quantity},
      );
      return false;
    }
  }

  /// Adds a customer-visible order note with the tracking number and updates
  /// the order status to 'completed' (shipped + delivered in WooCommerce).
  Future<bool> markOrderShipped({
    required int wooOrderId,
    required String trackingNumber,
    String carrier = 'India Post',
  }) async {
    try {
      // Add a note the customer receives by email
      await _dio.post('/orders/$wooOrderId/notes', data: {
        'note':
            'Your order has been shipped via $carrier. Tracking number: $trackingNumber',
        'customer_note': true,
      });
      // Update order status so WooCommerce shows it as completed
      await _dio.put('/orders/$wooOrderId', data: {
        'status': 'completed',
        'meta_data': [
          {'key': '_tracking_number', 'value': trackingNumber},
          {'key': '_tracking_carrier', 'value': carrier},
        ],
      });
      return true;
    } catch (e, st) {
      await _logger.logError(
        'wc_mark_shipped',
        e,
        stackTrace: st,
        context: {
          'wooOrderId': wooOrderId,
          'trackingNumber': trackingNumber,
        },
      );
      return false;
    }
  }

  /// Returns the WooCommerce IDs of all non-deleted products (any status).
  /// Returns an empty list on network error — callers treat this as "unknown"
  /// and must not delete local data in that case.
  Future<List<int>> fetchActiveProductIds() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/products',
        queryParameters: {'per_page': 100, 'status': 'any'},
      );
      return (response.data ?? [])
          .map((p) => p['id'] as int?)
          .whereType<int>()
          .toList();
    } catch (e, st) {
      await _logger.logError('wc_fetch_product_ids', e, stackTrace: st);
      return [];
    }
  }

  /// Aggregate price stats (count/min/max/avg) across every published
  /// product in [category], across ALL karigars - used for smart-pricing
  /// suggestions and in-marketplace comparison. Read-only: unlike
  /// [_resolveTermId], this never creates a category term, since a mistyped
  /// or one-off category name here shouldn't leave junk terms behind.
  /// Returns null if the category doesn't exist yet or has no listings.
  Future<CategoryPriceStats?> fetchCategoryPriceStats(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return null;
    try {
      final termId = await _lookupTermId('product_cat', trimmed);
      if (termId == null) return null;

      final response = await _dio.get<List<dynamic>>(
        '/products',
        queryParameters: {
          'category': termId,
          'per_page': 50,
          'status': 'publish',
        },
      );

      final prices = (response.data ?? [])
          .map((p) => double.tryParse(
              (p as Map<String, dynamic>)['regular_price'] as String? ?? ''))
          .whereType<double>()
          .where((p) => p > 0)
          .toList();
      if (prices.isEmpty) return null;

      final sum = prices.reduce((a, b) => a + b);
      return CategoryPriceStats(
        count: prices.length,
        min: prices.reduce((a, b) => a < b ? a : b),
        max: prices.reduce((a, b) => a > b ? a : b),
        avg: sum / prices.length,
      );
    } catch (e, st) {
      await _logger.logError('wc_fetch_category_price_stats', e,
          stackTrace: st, context: {'category': trimmed});
      return null;
    }
  }

  /// Search-only variant of [_resolveTermId] - returns the matching term id
  /// or null, never creates one.
  Future<int?> _lookupTermId(String taxonomy, String name) async {
    if (_wpUsername.isEmpty || _wpAppPassword.isEmpty) return null;
    try {
      final search = await _wpDio.get<List<dynamic>>(
        '/$taxonomy',
        queryParameters: {'search': name, 'per_page': 100},
        options: Options(headers: {'Authorization': _wpBasicAuthHeader}),
      );
      for (final entry in search.data ?? []) {
        final term = entry as Map<String, dynamic>;
        if ((term['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
          return term['id'] as int?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Updates karigar meta on every product in [wooIds] without touching any
  /// other metadata. WooCommerce REST API uses merge semantics for meta_data —
  /// only the keys included in the request are changed.
  ///
  /// Always writes _ks_upi_id. Writes _ks_karigar_uid when [karigarUid] is
  /// provided, which is required for the Cloud Function order-attribution logic.
  Future<bool> syncUpiId({
    required List<int> wooIds,
    required String upiId,
    String karigarUid = '',
  }) async {
    if (wooIds.isEmpty) return true;
    final meta = <Map<String, String>>[
      {'key': '_ks_upi_id', 'value': upiId},
      if (karigarUid.isNotEmpty)
        {'key': '_ks_karigar_uid', 'value': karigarUid},
    ];
    final results = await Future.wait(
      wooIds.map((id) async {
        try {
          await _dio.put('/products/$id', data: {'meta_data': meta});
          return true;
        } catch (e, st) {
          await _logger.logError(
            'wc_sync_upi_id',
            e,
            stackTrace: st,
            context: {'wooId': id, 'upiId': upiId},
          );
          return false;
        }
      }),
    );
    return results.every((r) => r);
  }

  /// Sets the storefront-visible image on this karigar's WooCommerce Brand
  /// term (native WooCommerce Brands, `/wc/v3/products/brands`) - the same
  /// term every one of their products is already tagged with via
  /// [_resolveTermId]. [imageUrl] is sideloaded by WooCommerce as a new
  /// media attachment (WooCommerce doesn't accept "use this existing
  /// attachment by URL" without its media id, which this app doesn't track
  /// for the profile photo). Returns false (logged) if the brand term
  /// doesn't exist yet - e.g. the karigar hasn't published a product under
  /// this store name yet, so there's no brand to attach an image to.
  Future<bool> syncBrandImage({
    required String storeName,
    required String imageUrl,
  }) async {
    final termId = await _resolveTermId('product_brand', storeName);
    if (termId == null) return false;
    try {
      await _dio.put('/products/brands/$termId', data: {
        'image': {'src': imageUrl},
      });
      return true;
    } catch (e, st) {
      await _logger.logError(
        'wc_sync_brand_image',
        e,
        stackTrace: st,
        context: {'storeName': storeName, 'termId': termId},
      );
      return false;
    }
  }

  /// Renames this karigar's WooCommerce Brand term in place (rather than
  /// creating a new one) when they change their Store Name in the app -
  /// [_resolveTermId] elsewhere only ever creates/reuses a term matching
  /// whatever store name is passed in at that moment, so without this,
  /// renaming in-app silently drifted from the storefront: every existing
  /// product stayed tagged to the old-named term forever (products
  /// reference a brand by ID, not by name, so renaming the term in place is
  /// exactly what makes every product using it pick up the new name too,
  /// with no need to re-save each product individually).
  ///
  /// Read-only lookup on [oldStoreName] (via [_lookupTermId], not
  /// [_resolveTermId]) - if the karigar never published anything under the
  /// old name, there's no term to rename, and that's fine: the next publish
  /// under the new name will create a correctly-named term from scratch via
  /// the normal [_resolveTermId] path. Returns false (logged) on failure.
  Future<bool> renameBrand({
    required String oldStoreName,
    required String newStoreName,
  }) async {
    if (oldStoreName.trim() == newStoreName.trim()) return true;
    final termId = await _lookupTermId('product_brand', oldStoreName);
    if (termId == null) return false;
    try {
      await _dio.put('/products/brands/$termId', data: {
        'name': newStoreName.trim(),
      });
      return true;
    } catch (e, st) {
      await _logger.logError(
        'wc_rename_brand',
        e,
        stackTrace: st,
        context: {
          'oldStoreName': oldStoreName,
          'newStoreName': newStoreName,
          'termId': termId,
        },
      );
      return false;
    }
  }

  Future<PublishResult> publishProduct({
    required String title,
    required String description,
    required String price,
    required List<File> imageFiles,
    String karigarUid = '',
    String karigarName = '',
    String upiId = '',
    String language = '',
    String category = '',
    String storeName = '',
  }) async {
    final imageEntries = await _uploadImagesForEntries(imageFiles);

    if (imageEntries.isEmpty) {
      await _logger.logError(
        'wc_publish_product',
        'Aborting: every image upload failed (WP media + Firebase Storage backup)',
        context: {'title': title, 'imageCount': imageFiles.length},
      );
      return const PublishResult(
        success: false,
        message:
            'Could not upload the product photo. Please check your connection and try again.',
      );
    }

    try {
      final categoryTermId = await _resolveTermId('product_cat', category);
      final brandTermId = await _resolveTermId('product_brand', storeName);

      final payload = {
        'name': title,
        'type': 'simple',
        'regular_price': price,
        'description': description,
        'status': 'publish',
        'images': imageEntries,
        if (categoryTermId != null)
          'categories': [
            {'id': categoryTermId},
          ],
        if (brandTermId != null)
          'brands': [
            {'id': brandTermId},
          ],
        'meta_data': [
          {'key': '_ks_karigar_uid', 'value': karigarUid},
          {'key': '_ks_karigar_name', 'value': karigarName},
          {'key': '_ks_upi_id', 'value': upiId},
          {'key': '_ks_language', 'value': language},
        ],
      };

      final response = await _dio.post('/products', data: payload);

      final images = response.data['images'] as List?;
      final imageUrls = (images ?? [])
          .map((img) => (img as Map<String, dynamic>)['src'] as String?)
          .whereType<String>()
          .toList();

      return PublishResult(
        success: true,
        productId: response.data['id'] as int?,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        imageUrls: imageUrls,
        permalink: response.data['permalink'] as String?,
      );
    } catch (e, st) {
      await _logger.logError(
        'wc_create_product',
        e,
        stackTrace: st,
        context: {'title': title, 'imageCount': imageFiles.length},
      );

      return PublishResult(
        success: false,
        message: e is DioException
            ? _friendlyWooError(e)
            : 'Could not publish product. Please try again.',
      );
    }
  }
}
