class Product {
  final String id;

  /// English text - always required, published to the storefront
  /// regardless of app language.
  final String title;
  final String category;
  final String description;

  /// The karigar's own text in [localLanguageCode]. Screens should prefer
  /// this over the English fields when [localLanguageCode] matches the
  /// current app language.
  final String localTitle;
  final String localCategory;
  final String localDescription;
  final String? localLanguageCode;

  final double price;
  final int quantity;
  final List<String> imagePaths;
  final List<String> tags;

  /// The WooCommerce product ID returned after a successful publish.
  /// Null for seed/local-only products that haven't been synced yet.
  final int? wooId;

  /// Primary (first) image URL on WooCommerce - thumbnail fallback when
  /// the local file is gone. Always wooImageUrls.first when non-empty.
  final String? wooImageUrl;

  /// Every image URL on WooCommerce, in order. Empty for products
  /// published before this was tracked.
  final List<String> wooImageUrls;

  /// Soft-deleted in the app; stays on WooCommerce so no store data is lost.
  final bool archived;

  /// Public storefront URL, as returned by WooCommerce at publish time.
  /// Null for products published before this was tracked.
  final String? permalink;

  /// Server timestamp, set once at creation - see products_provider.dart's
  /// add()/update(). The only reliable way to know "newest"; Firestore
  /// list order isn't guaranteed.
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.price,
    required this.quantity,
    this.localTitle = '',
    this.localCategory = '',
    this.localDescription = '',
    this.localLanguageCode,
    this.imagePaths = const [],
    this.tags = const [],
    this.wooId,
    this.wooImageUrl,
    this.wooImageUrls = const [],
    this.archived = false,
    this.permalink,
    this.createdAt,
  });

  /// Title to show the karigar in the app right now: their own text if it
  /// was captured in [currentLanguageCode], else the English fallback.
  String displayTitle(String currentLanguageCode) =>
      (localLanguageCode == currentLanguageCode && localTitle.isNotEmpty)
          ? localTitle
          : title;

  String displayCategory(String currentLanguageCode) =>
      (localLanguageCode == currentLanguageCode && localCategory.isNotEmpty)
          ? localCategory
          : category;

  String displayDescription(String currentLanguageCode) =>
      (localLanguageCode == currentLanguageCode && localDescription.isNotEmpty)
          ? localDescription
          : description;

  Product copyWith({
    String? title,
    String? category,
    String? description,
    String? localTitle,
    String? localCategory,
    String? localDescription,
    String? localLanguageCode,
    double? price,
    int? quantity,
    List<String>? imagePaths,
    List<String>? tags,
    int? wooId,
    String? wooImageUrl,
    List<String>? wooImageUrls,
    bool? archived,
    String? permalink,
  }) {
    return Product(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      localTitle: localTitle ?? this.localTitle,
      localCategory: localCategory ?? this.localCategory,
      localDescription: localDescription ?? this.localDescription,
      localLanguageCode: localLanguageCode ?? this.localLanguageCode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imagePaths: imagePaths ?? this.imagePaths,
      tags: tags ?? this.tags,
      wooId: wooId ?? this.wooId,
      wooImageUrl: wooImageUrl ?? this.wooImageUrl,
      wooImageUrls: wooImageUrls ?? this.wooImageUrls,
      archived: archived ?? this.archived,
      permalink: permalink ?? this.permalink,
    );
  }
}
