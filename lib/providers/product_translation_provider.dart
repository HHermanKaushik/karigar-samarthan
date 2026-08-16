import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/service_providers.dart';

/// Live-translates a product's English (canonical) text into whichever
/// language the karigar currently has the app set to, and caches the
/// result in memory so the same product/field/language combination is only
/// ever translated once per app session.
///
/// This is separate from Product.localTitle/etc: local* is a fast, free
/// "recall my own words" path that only works when viewing in the exact
/// language a product was created/edited in. This cache is the fallback
/// for every other case - viewing a Hindi-made product while in Marathi,
/// or an English-made product while in any non-English language - which is
/// what "show me everything in my current language, always" actually
/// requires.
class ProductTranslationCache extends StateNotifier<Map<String, String>> {
  final Ref _ref;
  final Set<String> _inFlight = {};

  ProductTranslationCache(this._ref) : super({});

  static String cacheKey(String productId, String field, String languageCode) =>
      '$productId:$field:$languageCode';

  Future<void> ensureTranslated({
    required String cacheKey,
    required String text,
    required String targetSarvamCode,
  }) async {
    if (text.trim().isEmpty) return;
    if (state.containsKey(cacheKey) || _inFlight.contains(cacheKey)) return;
    _inFlight.add(cacheKey);
    try {
      final sarvam = _ref.read(sarvamServiceProvider);
      final translated = await sarvam.translateText(
        text: text,
        targetLanguageCode: targetSarvamCode,
        sourceLanguageCode: 'en-IN',
      );
      if (translated != null && mounted) {
        state = {...state, cacheKey: translated};
      }
    } finally {
      _inFlight.remove(cacheKey);
    }
  }
}

final productTranslationCacheProvider =
    StateNotifierProvider<ProductTranslationCache, Map<String, String>>(
  (ref) => ProductTranslationCache(ref),
);

/// One field of one product, resolved to the best text available for
/// [currentLanguageCode] right now:
///   1. English text as-is, if the current language IS English.
///   2. The karigar's own words, if this exact product was created/edited
///      in the current language (product.localLanguageCode match) - free,
///      instant, no API call.
///   3. A cached live translation, if one has already been fetched this
///      session.
///   4. English text, while kicking off a live translation in the
///      background (fire-and-forget; the cache updating triggers a
///      rebuild via ref.watch once it resolves).
class ProductFieldText {
  final String english;
  final String local;
  final String field; // 'title' | 'category' | 'description'

  const ProductFieldText({
    required this.english,
    required this.local,
    required this.field,
  });
}

String watchTranslatedProductField(
  WidgetRef ref, {
  required Product product,
  required ProductFieldText field,
  required String currentLanguageCode,
  required String currentSarvamCode,
}) {
  if (currentLanguageCode == 'en') return field.english;
  if (product.localLanguageCode == currentLanguageCode &&
      field.local.isNotEmpty) {
    return field.local;
  }

  final key = ProductTranslationCache.cacheKey(
      product.id, field.field, currentLanguageCode);
  final cached = ref.watch(productTranslationCacheProvider)[key];
  if (cached != null) return cached;

  // Scheduling, not a synchronous state mutation - safe to call during
  // build (the cache's state= write only happens after the await inside
  // ensureTranslated, in a later microtask).
  ref.read(productTranslationCacheProvider.notifier).ensureTranslated(
        cacheKey: key,
        text: field.english,
        targetSarvamCode: currentSarvamCode,
      );
  return field.english;
}
