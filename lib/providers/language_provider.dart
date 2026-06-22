import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.english) {
    _load();
  }

  static const _key = 'app_language_code';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppLanguage.fromCode(prefs.getString(_key));
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.code);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
    (ref) => LanguageNotifier());
