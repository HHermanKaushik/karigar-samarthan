class Product {
  final String id;

  /// English text - always required, since this is what's published to the
  /// WooCommerce storefront regardless of the karigar's app language.
  final String title;
  final String category;
  final String description;

  /// The karigar's own text in [localLanguageCode], captured alongside the
  /// English translation at add/edit time. Screens showing a product to the
  /// karigar (not the storefront) should prefer this over the English
  /// fields whenever [localLanguageCode] matches the app's current
  /// language - otherwise the karigar sees English regardless of what
  /// language they wrote (and are currently viewing) the app in, which is
  /// the product data never having been kept in their language at all, not
  /// a missing translation to render.
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

  /// The primary (first) image URL on WooCommerce - used as the thumbnail
  /// fallback when the local file at imagePaths.first is gone. Always
  /// wooImageUrls.first when wooImageUrls is non-empty; kept as its own
  /// field since it's what most read sites (list thumbnails) actually need.
  final String? wooImageUrl;

  /// Every image URL on WooCommerce, in order - a product can have more
  /// than one. Empty for products published before this was tracked, or
  /// products that only ever had wooImageUrl set.
  final List<String> wooImageUrls;

  /// Soft-deleted in the app. Archived products are hidden from the product
  /// list but remain on WooCommerce so no store data is lost.
  final bool archived;

  /// The public storefront URL for this product, as returned by WooCommerce
  /// at publish/update time. Null for products published before this was
  /// tracked, or local-only products never synced to Woo.
  final String? permalink;

  /// When this product was first created (server timestamp, set once at
  /// creation and never touched again - see products_provider.dart's add()/
  /// update()). Null for products created before this was tracked. This is
  /// the only reliable way to know which product is "newest" - list order
  /// from Firestore is not guaranteed and must not be relied on for that.
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
