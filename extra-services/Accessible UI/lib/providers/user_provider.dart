import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String fullName;
  final String storeName;
  final String phone;
  final String role;
  final bool paymentSetup;

  const UserProfile({
    required this.fullName,
    required this.storeName,
    required this.phone,
    this.role = 'Master Artisan',
    this.paymentSetup = false,
  });

  UserProfile copyWith({
    String? fullName,
    String? storeName,
    String? phone,
    String? role,
    bool? paymentSetup,
  }) =>
      UserProfile(
        fullName: fullName ?? this.fullName,
        storeName: storeName ?? this.storeName,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        paymentSetup: paymentSetup ?? this.paymentSetup,
      );
}

class UserNotifier extends StateNotifier<UserProfile> {
  UserNotifier()
      : super(const UserProfile(
          fullName: 'Shree Pingale',
          storeName: 'Pingale Handlooms',
          phone: '+91 90000 00000',
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
      );
    }
  }

  Future<void> save(UserProfile p) async {
    state = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', p.fullName);
    await prefs.setString('user_store', p.storeName);
    await prefs.setString('user_phone', p.phone);
    await prefs.setBool('user_payment', p.paymentSetup);
  }
}

final userProvider =
    StateNotifierProvider<UserNotifier, UserProfile>((ref) => UserNotifier());
