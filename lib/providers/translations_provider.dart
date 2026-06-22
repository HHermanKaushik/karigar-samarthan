import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/il8n/app_strings.dart';
import 'language_provider.dart';

/// Returns a translator function for the current app language.
///
/// Usage in any ConsumerWidget / ConsumerState:
///   final tr = ref.watch(trProvider);
///   Text(tr('myStore'))
///
/// Falls back to the English string if a key is missing for the active
/// language. The underlying [AppStrings] table is the source of truth for
/// static UI text. For dynamic content (AI replies, product descriptions,
/// user input) use SarvamService.translateText() instead.
final trProvider = Provider<String Function(String)>((ref) {
  final lang = ref.watch(languageProvider);
  return (String key) => AppStrings.t(key, lang.code);
});
