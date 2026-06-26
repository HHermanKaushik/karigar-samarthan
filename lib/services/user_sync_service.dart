import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../providers/user_provider.dart';
import 'sync_logger.dart';

/// Keeps a user's profile in sync across the three places it needs to
/// exist:
///
///  1. Firestore (`users/{uid}`) — the app's own source of truth, used by
///     the AI assistant and other screens to read account data.
///  2. WooCommerce (`/wc/v3/customers`) — so orders placed against this
///     artisan's store are linked to a real customer record.
///
/// NOTE on auth: this app does not yet have a real sign-in flow wired up
/// (the login screen's OTP step is a stub). To give Firestore a stable,
/// rule-friendly `uid` to write under, we fall back to Firebase Anonymous
/// Auth if no user is signed in yet. When real Phone Auth is added, the
/// anonymous account can be upgraded in place via
/// `FirebaseAuth.instance.currentUser.linkWithCredential(...)`, which keeps
/// the same `uid` — so no migration is needed for the data written here.
class UserSyncService {
  final SyncLogger _logger;
  late final Dio _dio;

  UserSyncService({SyncLogger? logger}) : _logger = logger ?? SyncLogger() {
    final baseUrl = (dotenv.env['WOOCOMMERCE_BASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) {
      debugPrint('UserSyncService: WOOCOMMERCE_BASE_URL not set — WooCommerce sync disabled');
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl.isNotEmpty ? '$baseUrl/wp-json/wc/v3' : 'https://localhost/wp-json/wc/v3',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        queryParameters: {
          'consumer_key': dotenv.env['WOOCOMMERCE_CONSUMER_KEY'] ?? '',
          'consumer_secret': dotenv.env['WOOCOMMERCE_CONSUMER_SECRET'] ?? '',
        },
      ),
    );
  }

  /// Syncs [profile] to Firestore and WooCommerce. Safe to call on every
  /// profile save (signup, profile edits, etc.) — it's idempotent and
  /// reuses the existing WooCommerce customer once one has been created.
  ///
  /// Never throws: all failures are recorded via [SyncLogger] so they show
  /// up in Crashlytics + the `sync_errors` Firestore collection without
  /// interrupting the user's flow. Returns `true` if the sync completed
  /// successfully, `false` otherwise (e.g. offline, server error).
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

      wooCustomerId ??= await _syncWooCustomer(profile, uid);

      await userDocRef.set({
        'fullName': profile.fullName,
        'storeName': profile.storeName,
        'phone': profile.phone,
        'role': profile.role,
        'paymentSetup': profile.paymentSetup,
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
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // TODO: replace with real Phone Auth once that flow lands (see class
      // doc above for why anonymous auth is a safe bridge).
      final cred = await FirebaseAuth.instance.signInAnonymously();
      user = cred.user;
    }
    return user!.uid;
  }

  /// Creates (or finds) a WooCommerce customer for this user and returns
  /// its ID, or `null` if the sync failed.
  Future<int?> _syncWooCustomer(UserProfile profile, String uid) async {
    // WooCommerce customers require a unique email + username, but the
    // current signup form only collects a phone number. Until a real
    // email is collected, derive a stable placeholder identity from the
    // phone number. Revisit once the signup form is finalized.
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
      // Stay idempotent: if a customer with this email already exists
      // (e.g. profile was synced before but the Firestore doc was missing
      // the wooCustomerId), reuse it instead of creating a duplicate.
      final existingSearch = await _dio.get(
        '/customers',
        queryParameters: {'email': email},
      );

      final existingList = existingSearch.data as List;
      if (existingList.isNotEmpty) {
        return existingList.first['id'] as int?;
      }

      final response = await _dio.post('/customers', data: {
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
}
