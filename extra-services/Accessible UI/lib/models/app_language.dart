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
}
