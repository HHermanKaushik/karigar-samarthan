import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WooCommerceService {
  late final Dio _dio;

  WooCommerceService() {
    final baseUrl = dotenv.env['WOOCOMMERCE_BASE_URL'] ?? '';
    final consumerKey = dotenv.env['WOOCOMMERCE_CONSUMER_KEY'] ?? '';
    final consumerSecret = dotenv.env['WOOCOMMERCE_CONSUMER_SECRET'] ?? '';

    _dio = Dio(
      BaseOptions(
        baseUrl: '$baseUrl/wp-json/wc/v3',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        queryParameters: {
          'consumer_key': consumerKey,
          'consumer_secret': consumerSecret,
        },
      ),
    );
  }

  Future<bool> publishProduct({
    required String title,
    required String description,
    required String price,
    required File imageFile,
  }) async {
    try {
      //
      // STEP 1 — Upload image to Firebase Storage
      //
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref =
          FirebaseStorage.instance.ref().child('products').child(fileName);

      await ref.putFile(imageFile);

      final imageUrl = await ref.getDownloadURL();

      print('========== FIREBASE IMAGE URL ==========');
      print(imageUrl);

      //
      // STEP 2 — Create WooCommerce product
      //
      final payload = {
        'name': title,
        'type': 'simple',
        'regular_price': price,
        'description': description,
        'status': 'publish',
        'images': [
          {
            'src': imageUrl,
          }
        ],
      };

      print('========== PRODUCT PAYLOAD ==========');
      print(payload);

      final response = await _dio.post(
        '/products',
        data: payload,
      );

      print('========== WOO SUCCESS ==========');
      print(response.data);

      return true;
    } catch (e) {
      print('========== WOO ERROR ==========');
      print(e);

      if (e is DioException) {
        print(e.response?.data);
      }

      print('================================');

      return false;
    }
  }
}
