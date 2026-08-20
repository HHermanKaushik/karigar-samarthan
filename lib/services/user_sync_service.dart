import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/user_provider.dart';
import 'sync_logger.dart';

/// Keeps a user's profile in sync in two places: Firestore (`users/{uid}`,
/// the app's source of truth) and WooCommerce (`/wc/v3/customers`, so
/// orders link to a real customer record).
class UserSyncService {
  final SyncLogger _logger;
  late final Dio _dio;

  UserSyncService({SyncLogger? logger}) : _logger = logger ?? SyncLogger() {
    final baseUrl = (dotenv.env['WOOCOMMERCE_BASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) {
      debugPrint(
          'UserSyncService: WOOCOMMERCE_BASE_URL not set — WooCommerce sync disabled');
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.isNotEmpty
            ? '$baseUrl/wp-json/wc/v3/'
            : 'https://localhost/wp-json/wc/v3/',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        queryParameters: {
          'consumer_key': dotenv.env['WOOCOMMERCE_CONSUMER_KEY'] ?? '',
          'consumer_secret': dotenv.env['WOOCOMMERCE_CONSUMER_SECRET'] ?? '',
        },
      ),
    );
  }

  /// Syncs [profile] to Firestore and WooCommerce. Idempotent, safe to
  /// call on every profile save. Never throws - failures go through
  /// [SyncLogger]. Returns `true` on success.
  Future<bool> syncUserProfile(UserProfile profile) async {
    String uid;
    try {
      uid = await _ensureAuthUid();
    } catch (e, st) {
      await _logger.logError('user_auth_bootstrap', e, stackTrace: st);
      return false;
    }

    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'karigar',
    );
    final userDocRef = db.collection('users').doc(uid);

    try {
      final existing = await userDocRef.get();
      int? wooCustomerId = existing.data()?['wooCustomerId'] as int?;

      // Create the WooCommerce customer once, keep it updated on every save.
      if (wooCustomerId == null) {
        wooCustomerId = await _syncWooCustomer(profile, uid);
      } else {
        await _updateWooCustomer(wooCustomerId, profile);
      }

      await userDocRef.set({
        'fullName': profile.fullName,
        'storeName': profile.storeName,
        'phone': profile.phone,
        'role': profile.role,
        'paymentSetup': profile.paymentSetup,
        'upiId': profile.upiId,
        'photoUrl': profile.photoUrl,
        if (wooCustomerId != null) 'wooCustomerId': wooCustomerId,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e, st) {
      await _logger.logError(
        'user_profile_sync',
        e,
        stackTrace: st,
        context: {'uid': uid},
      );
      return false;
    }
  }

  Future<String> _ensureAuthUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message:
            'No authenticated active user session found during synchronization.',
      );
    }
    return user.uid;
  }

  /// Creates or finds a WooCommerce customer for this user, returns its
  /// ID, or `null` on failure.
  Future<int?> _syncWooCustomer(UserProfile profile, String uid) async {
    // WooCommerce needs a unique email + username; signup only collects a
    // phone number, so derive a placeholder identity from it.
    final digits = profile.phone.replaceAll(RegExp(r'\D'), '');
    final username = 'ks_$digits';
    final email = '$username@users.karigarsamarthan.app';

    final nameParts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : profile.fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    try {
      // Reuse an existing customer with this email instead of duplicating.
      final existingSearch = await _dio.get(
        'customers',
        queryParameters: {'email': email},
      );

      final existingList = existingSearch.data as List;
      if (existingList.isNotEmpty) {
        return existingList.first['id'] as int?;
      }

      final response = await _dio.post('customers', data: {
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'phone': profile.phone,
          'company': profile.storeName,
        },
        'meta_data': [
          {'key': 'firebase_uid', 'value': uid},
        ],
      });

      return response.data['id'] as int?;
    } catch (e, st) {
      await _logger.logError(
        'woo_customer_sync',
        e,
        stackTrace: st,
        context: {'uid': uid, 'email': email},
      );
      return null;
    }
  }

  /// Pushes name/phone/store-name changes to an existing WooCommerce
  /// customer record.
  Future<void> _updateWooCustomer(
      int wooCustomerId, UserProfile profile) async {
    final nameParts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : profile.fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    try {
      await _dio.put('customers/$wooCustomerId', data: {
        'first_name': firstName,
        'last_name': lastName,
        'billing': {
          'first_name': firstName,
          'last_name': lastName,
          'phone': profile.phone,
          'company': profile.storeName,
        },
      });
    } catch (e, st) {
      await _logger.logError(
        'woo_customer_update',
        e,
        stackTrace: st,
        context: {'wooCustomerId': wooCustomerId},
      );
    }
  }
}
