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
  final String? imageUrl;

  const PublishResult({
    required this.success,
    this.message,
    this.productId,
    this.imageUrl,
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

  Future<PublishResult> updateProduct({
    required int wooId,
    required String title,
    required String description,
    required String price,
    required int quantity,
  }) async {
    try {
      await _dio.put('/products/$wooId', data: {
        'name': title,
        'regular_price': price,
        'description': description,
        'stock_quantity': quantity,
        'manage_stock': true,
      });

      return const PublishResult(success: true);
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
      if (karigarUid.isNotEmpty) {'key': '_ks_karigar_uid', 'value': karigarUid},
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

  Future<PublishResult> publishProduct({
    required String title,
    required String description,
    required String price,
    required File imageFile,
    String karigarUid = '',
    String karigarName = '',
    String upiId = '',
    String language = '',
  }) async {
    // Prefer WordPress media upload (gives a persistent mediaId).
    // Falls back to Firebase Storage URL when WP credentials are absent or upload fails.
    int? mediaId;
    if (_wpUsername.isNotEmpty && _wpAppPassword.isNotEmpty) {
      mediaId = await _uploadImageToWordPress(imageFile);
    }

    String? storageUrl;
    if (mediaId == null) {
      storageUrl = await _backupToFirebaseStorage(imageFile)
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
    }

    if (mediaId == null && storageUrl == null) {
      await _logger.logError(
        'wc_publish_product',
        'Aborting: both WP media upload and Firebase Storage backup failed',
        context: {'title': title},
      );
      return const PublishResult(
        success: false,
        message:
            'Could not upload the product photo. Please check your connection and try again.',
      );
    }

    try {
      // WooCommerce accepts either {id} (WP media library) or {src} (URL to sideload).
      final imageEntry =
          mediaId != null ? {'id': mediaId} : {'src': storageUrl};

      final payload = {
        'name': title,
        'type': 'simple',
        'regular_price': price,
        'description': description,
        'status': 'publish',
        'images': [imageEntry],
        'meta_data': [
          {'key': '_ks_karigar_uid', 'value': karigarUid},
          {'key': '_ks_karigar_name', 'value': karigarName},
          {'key': '_ks_upi_id', 'value': upiId},
          {'key': '_ks_language', 'value': language},
        ],
      };

      final response = await _dio.post('/products', data: payload);

      final images = response.data['images'] as List?;
      final imageUrl = (images != null && images.isNotEmpty)
          ? (images.first as Map<String, dynamic>)['src'] as String?
          : null;

      return PublishResult(
        success: true,
        productId: response.data['id'] as int?,
        imageUrl: imageUrl,
      );
    } catch (e, st) {
      await _logger.logError(
        'wc_create_product',
        e,
        stackTrace: st,
        context: {'title': title, 'mediaId': mediaId, 'storageUrl': storageUrl},
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
