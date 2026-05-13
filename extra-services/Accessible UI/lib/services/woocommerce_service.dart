import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thin WooCommerce REST client. Real endpoints go here later. For the
/// prototype it stays unused but compilable.
class WooCommerceService {
  WooCommerceService() : _dio = Dio() {
    final base = dotenv.maybeGet('WOOCOMMERCE_BASE_URL') ?? '';
    if (base.isNotEmpty) {
      _dio.options.baseUrl = base;
    }
  }
  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    if (_dio.options.baseUrl.isEmpty) return [];
    final r = await _dio.get('/wp-json/wc/v3/products', queryParameters: {
      'consumer_key': dotenv.maybeGet('WOOCOMMERCE_CONSUMER_KEY') ?? '',
      'consumer_secret': dotenv.maybeGet('WOOCOMMERCE_CONSUMER_SECRET') ?? '',
    });
    return List<Map<String, dynamic>>.from(r.data as List);
  }
}
