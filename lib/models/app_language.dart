enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'हिन्दी', 'Hindi'),
  marathi('mr', 'मराठी', 'Marathi'),
  bengali('bn', 'বাংলা', 'Bengali'),
  tamil('ta', 'தமிழ்', 'Tamil');

  final String code;
  final String nativeName;
  final String englishName;
  const AppLanguage(this.code, this.nativeName, this.englishName);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }

  /// BCP-47 language code used by Sarvam AI's STT / TTS / Translation APIs.
  String get sarvamCode {
    switch (this) {
      case AppLanguage.english:
        return 'en-IN';
      case AppLanguage.hindi:
        return 'hi-IN';
      case AppLanguage.marathi:
        return 'mr-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.tamil:
        return 'ta-IN';
    }
  }
}
