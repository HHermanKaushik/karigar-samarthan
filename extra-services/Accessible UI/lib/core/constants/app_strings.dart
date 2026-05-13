class AppStrings {
  // Used as a tiny in-app dictionary keyed by AppLanguage.code.
  // Keeps the project compilable without flutter_localizations setup; swap to
  // arb files later.
  static const Map<String, Map<String, String>> _t = {
    'chooseLanguage': {
      'en': 'Choose your language',
      'hi': 'अपनी भाषा चुनें',
      'mr': 'तुमची भाषा निवडा',
      'bn': 'আপনার ভাষা বেছে নিন',
      'ta': 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
    },
    'createAccount': {
      'en': 'Create your account',
      'hi': 'अपना खाता बनाएं',
      'mr': 'तुमचे खाते तयार करा',
      'bn': 'আপনার অ্যাকাউন্ট তৈরি করুন',
      'ta': 'உங்கள் கணக்கை உருவாக்கவும்',
    },
    'fullName': {'en': 'Full Name', 'hi': 'पूरा नाम'},
    'storeName': {'en': 'Store Name', 'hi': 'दुकान का नाम'},
    'phoneNumber': {'en': 'Phone Number', 'hi': 'फ़ोन नंबर'},
    'signUp': {'en': 'Sign Up', 'hi': 'साइन अप करें'},
    'login': {'en': 'Log in', 'hi': 'लॉग इन करें'},
    'getOtp': {'en': 'Get OTP', 'hi': 'OTP प्राप्त करें'},
    'home': {'en': 'My Store', 'hi': 'मेरी दुकान'},
    'addProduct': {'en': 'Add a New Product', 'hi': 'नया उत्पाद जोड़ें'},
    'orders': {'en': 'My Orders', 'hi': 'मेरे ऑर्डर'},
    'profile': {'en': 'My Account', 'hi': 'मेरा खाता'},
    'assistant': {'en': 'AI Assistant', 'hi': 'AI सहायक'},
  };

  static String t(String key, String langCode) {
    final entry = _t[key];
    if (entry == null) return key;
    return entry[langCode] ?? entry['en'] ?? key;
  }
}
