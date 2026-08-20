import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../services/service_providers.dart';

/// Live-translates a product's English text into the current app language
/// and caches the result per product/field/language for the session.
/// Separate from Product.localTitle/etc, which only covers viewing in the
/// exact language a product was created in - this covers every other
/// combination.
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
/// [currentLanguageCode]:
///   1. English as-is, if current language IS English.
///   2. The karigar's own words, if authored in the current language.
///   3. A cached live translation, if already fetched this session.
///   4. English, while a live translation kicks off in the background.
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

  // Just schedules the fetch - safe to call during build.
  ref.read(productTranslationCacheProvider.notifier).ensureTranslated(
        cacheKey: key,
        text: field.english,
        targetSarvamCode: currentSarvamCode,
      );
  return field.english;
}
