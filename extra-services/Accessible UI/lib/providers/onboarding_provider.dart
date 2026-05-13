import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _load();
  }
  static const _key = 'onboarding_complete';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) => OnboardingNotifier());
