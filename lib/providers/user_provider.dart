import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/service_providers.dart';
import '../services/user_sync_service.dart';

class UserProfile {
  final String fullName;
  final String storeName;
  final String phone;
  final String role;
  final bool paymentSetup;
  final String upiId;

  const UserProfile({
    required this.fullName,
    required this.storeName,
    required this.phone,
    this.role = 'Master Artisan',
    this.paymentSetup = false,
    this.upiId = '',
  });

  UserProfile copyWith({
    String? fullName,
    String? storeName,
    String? phone,
    String? role,
    bool? paymentSetup,
    String? upiId,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        storeName: storeName ?? this.storeName,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        paymentSetup: paymentSetup ?? this.paymentSetup,
        upiId: upiId ?? this.upiId,
      );
}

class UserNotifier extends StateNotifier<UserProfile> {
  final UserSyncService _syncService;

  UserNotifier(this._syncService)
      : super(const UserProfile(
          fullName: '',
          storeName: '',
          phone: '',
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (name != null) {
      state = state.copyWith(
        fullName: name,
        storeName: prefs.getString('user_store') ?? state.storeName,
        phone: prefs.getString('user_phone') ?? state.phone,
        paymentSetup: prefs.getBool('user_payment') ?? state.paymentSetup,
        upiId: prefs.getString('user_upi_id') ?? state.upiId,
      );
      return;
    }

    // Returning user on a new device: load from Firestore if phone-authenticated.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      );
      final doc = await db.collection('users').doc(user.uid).get();
      if (!doc.exists) return;
      final d = doc.data()!;
      final profile = UserProfile(
        fullName: d['fullName'] ?? '',
        storeName: d['storeName'] ?? '',
        phone: d['phone'] ?? '',
        role: d['role'] ?? 'Master Artisan',
        paymentSetup: d['paymentSetup'] as bool? ?? false,
        upiId: d['upiId'] as String? ?? '',
      );
      state = profile;
      await prefs.setString('user_name', profile.fullName);
      await prefs.setString('user_store', profile.storeName);
      await prefs.setString('user_phone', profile.phone);
      await prefs.setBool('user_payment', profile.paymentSetup);
      await prefs.setString('user_upi_id', profile.upiId);
    } catch (_) {}
  }

  Future<void> saveLocal(UserProfile p) async {
    state = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', p.fullName);
    await prefs.setString('user_store', p.storeName);
    await prefs.setString('user_phone', p.phone);
    await prefs.setBool('user_payment', p.paymentSetup);
    await prefs.setString('user_upi_id', p.upiId);
  }

  Future<void> save(UserProfile p) async {
    await saveLocal(p);
    unawaited(_syncService.syncUserProfile(p));
  }

  Future<void> clear() async {
    state = const UserProfile(fullName: '', storeName: '', phone: '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_store');
    await prefs.remove('user_phone');
    await prefs.remove('user_payment');
    await prefs.remove('user_upi_id');
  }
}

final userProvider = StateNotifierProvider<UserNotifier, UserProfile>(
  (ref) => UserNotifier(ref.read(userSyncServiceProvider)),
);
