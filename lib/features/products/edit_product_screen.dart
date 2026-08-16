import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/product_translation_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/service_providers.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final Product product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductScreen> createState() => _State();
}

/// One of the product's pre-existing photos, shown and individually
/// removable alongside newly picked ones (see _State._existingImages).
class _ExistingImage {
  final String? localPath;
  final String? wooUrl;
  const _ExistingImage({this.localPath, this.wooUrl});
}

class _State extends ConsumerState<EditProductScreen> {
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _price =
      TextEditingController(text: widget.product.price.toStringAsFixed(0));
  late final TextEditingController _qty =
      TextEditingController(text: widget.product.quantity.toString());
  late final TextEditingController _desc;

  // Newly picked photos this session, additive alongside _existingImages -
  // adding a photo no longer replaces what was already there.
  final List<File> _images = [];

  // The product's pre-existing photos that are still being kept (removing
  // one via the X button splices it out of this list, same as _removeImage
  // does for _images).
  late final List<_ExistingImage> _existingImages;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _saving = false;
  bool _archiving = false;

  @override
  void initState() {
    super.initState();
    // Prefer the karigar's own words if this product was captured in the
    // app's current language - otherwise fall back to the English text
    // (e.g. a product added while the app was in a different language, or
    // an older product from before this was tracked at all).
    final langCode = ref.read(languageProvider).code;
    _title = TextEditingController(text: widget.product.displayTitle(langCode));
    _category =
        TextEditingController(text: widget.product.displayCategory(langCode));
    _desc = TextEditingController(
        text: widget.product.displayDescription(langCode));

    // Reconciles local file paths with WooCommerce URLs by position - both
    // lists are populated together, in the same order, at add/edit time.
    // wooImageUrl (singular) is the pre-multi-image fallback for products
    // saved before wooImageUrls existed.
    final urls = widget.product.wooImageUrls.isNotEmpty
        ? widget.product.wooImageUrls
        : (widget.product.wooImageUrl != null
            ? [widget.product.wooImageUrl!]
            : const <String>[]);
    final count = widget.product.imagePaths.length > urls.length
        ? widget.product.imagePaths.length
        : urls.length;
    _existingImages = [
      for (var i = 0; i < count; i++)
        _ExistingImage(
          localPath: i < widget.product.imagePaths.length
              ? widget.product.imagePaths[i]
              : null,
          wooUrl: i < urls.length ? urls[i] : null,
        ),
    ];

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _liveTranslateFieldsIfNeeded());
  }

  // The fast path above (displayTitle/displayCategory/displayDescription)
  // only shows the karigar's own words when this exact product was last
  // saved in the app's current language. Every other case - a product made
  // in a different language, or one from before local* was tracked at all -
  // needs an actual live translation of the canonical English text, same as
  // the Home screen tiles (see product_translation_provider.dart).
  Future<void> _liveTranslateFieldsIfNeeded() async {
    final lang = ref.read(languageProvider);
    if (lang.code == 'en') return;
    if (widget.product.localLanguageCode == lang.code) return;

    final cache = ref.read(productTranslationCacheProvider.notifier);

    Future<void> translateField(
      TextEditingController controller,
      String english,
      String field,
    ) async {
      if (english.trim().isEmpty) return;
      final key =
          ProductTranslationCache.cacheKey(widget.product.id, field, lang.code);
      final before = controller.text;
      await cache.ensureTranslated(
        cacheKey: key,
        text: english,
        targetSarvamCode: lang.sarvamCode,
      );
      if (!mounted) return;
      final translated = ref.read(productTranslationCacheProvider)[key];
      // Only overwrite if the karigar hasn't already started editing this
      // field while the translation was in flight.
      if (translated != null && controller.text == before) {
        controller.text = translated;
      }
    }

    await Future.wait([
      translateField(_title, widget.product.title, 'title'),
      translateField(_category, widget.product.category, 'category'),
      translateField(_desc, widget.product.description, 'description'),
    ]);
  }

  void _removeExistingImage(int index) =>
      setState(() => _existingImages.removeAt(index));

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _price.dispose();
    _qty.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    // Listings must always be stored/published in English, regardless of
    // which language the karigar used to edit them (voice/typed) — the
    // storefront and other karigars/shoppers all expect English text.
    final lang = ref.read(languageProvider);
    final sarvam = ref.read(sarvamServiceProvider);
    Future<String> toEnglish(String text) async {
      if (text.trim().isEmpty) return text;
      return await sarvam.translateText(
            text: text,
            targetLanguageCode: 'en-IN',
            sourceLanguageCode: lang.sarvamCode,
          ) ??
          text;
    }

    final updated = widget.product.copyWith(
      title: await toEnglish(_title.text.trim()),
      category: await toEnglish(_category.text.trim()),
      description: await toEnglish(_desc.text.trim()),
      // Keeps the karigar's own words viewable in-app when they're back on
      // this same language - see Product.displayTitle() and friends.
      localTitle: lang.code != 'en' ? _title.text.trim() : '',
      localCategory: lang.code != 'en' ? _category.text.trim() : '',
      localDescription: lang.code != 'en' ? _desc.text.trim() : '',
      localLanguageCode: lang.code != 'en' ? lang.code : null,
      price: double.tryParse(_price.text.trim()) ?? widget.product.price,
      quantity: int.tryParse(_qty.text.trim()) ?? widget.product.quantity,
      imagePaths: [
        for (final e in _existingImages)
          if (e.localPath != null) e.localPath!,
        ..._images.map((f) => f.path),
      ],
    );

    ref.read(productsProvider.notifier).update(updated);

    if (widget.product.wooId != null) {
      final woo = ref.read(wooServiceProvider);
      final result = await woo.updateProduct(
        wooId: widget.product.wooId!,
        title: updated.title,
        description: updated.description,
        price: _price.text.trim(),
        quantity: updated.quantity,
        category: updated.category,
        storeName: ref.read(userProvider).storeName,
        newImageFiles: _images,
        keepImageUrls: [
          for (final e in _existingImages)
            if (e.wooUrl != null) e.wooUrl!,
        ],
      );

      if (!mounted) return;
      setState(() => _saving = false);

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ??
              'Saved locally but could not update the live store. Please try again.'),
        ));
        return;
      }

      if (result.imageUrls.isNotEmpty || result.permalink != null) {
        ref.read(productsProvider.notifier).update(updated.copyWith(
              wooImageUrl: result.imageUrl,
              wooImageUrls:
                  result.imageUrls.isNotEmpty ? result.imageUrls : null,
              permalink: result.permalink,
            ));
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(trProvider)('productUpdatedOnStore')),
      ));
    } else {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_images.isEmpty
            ? 'Saved locally. This product has not been published to the store yet.'
            : 'Saved locally with ${_images.length} image(s). This product has not been published yet.'),
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final tr = ref.read(trProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('archiveProductTitle')),
        content: Text(tr('archiveProductConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('archiveAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = true);
    await ref.read(productsProvider.notifier).archive(widget.product.id);
    if (widget.product.wooId != null) {
      await ref.read(wooServiceProvider).setProductArchived(
            wooId: widget.product.wooId!,
            archived: true,
          );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  /// One tile in the combined photo gallery, for either an existing photo
  /// (local file first, falling back to the WooCommerce URL if the local
  /// file is gone, e.g. after a reinstall - same fallback chain used for
  /// thumbnails on the home screen) or a newly picked one. Multiple
  /// existing/new photos can coexist and are each individually removable -
  /// adding a photo no longer replaces what was already there.
  Widget _buildGalleryTile({
    required Widget image,
    required VoidCallback onRemove,
    Key? key,
  }) {
    return Stack(
      key: key,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 130,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: image,
        ),
        Positioned(
          top: 6,
          right: 18,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 13,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingImageTile(int index) {
    final e = _existingImages[index];
    Widget image;
    if (e.localPath != null) {
      image = Image.file(
        File(e.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => e.wooUrl != null
            ? Image.network(
                e.wooUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.image_outlined,
                      size: 42, color: AppColors.primary),
                ),
              )
            : const Center(
                child: Icon(Icons.image_outlined,
                    size: 42, color: AppColors.primary),
              ),
      );
    } else {
      image = Image.network(
        e.wooUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, size: 42, color: AppColors.primary),
        ),
      );
    }
    return _buildGalleryTile(
      key: ValueKey('existing_image_$index'),
      image: image,
      onRemove: () => _removeExistingImage(index),
    );
  }

  Future<void> _listen(TextEditingController controller) async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
            onResult: (r) =>
                setState(() => controller.text = r.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('editProduct'),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              if (widget.product.wooId == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('productNotPublished'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // IMAGE SECTION
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: (_existingImages.isEmpty && _images.isEmpty)
                          ? const Center(
                              child: Icon(Icons.add_a_photo_outlined,
                                  size: 54, color: AppColors.primary))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount:
                                  _existingImages.length + _images.length,
                              itemBuilder: (_, i) {
                                if (i < _existingImages.length) {
                                  return _buildExistingImageTile(i);
                                }
                                final newIndex = i - _existingImages.length;
                                return _buildGalleryTile(
                                  key: ValueKey('new_image_$newIndex'),
                                  image: Image.file(_images[newIndex],
                                      fit: BoxFit.cover),
                                  onRemove: () => _removeImage(newIndex),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addImage,
                        icon: const Icon(Icons.add),
                        label: Text(tr('addImage')),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _Field(
                  label: tr('title'),
                  controller: _title,
                  onMic: () => _listen(_title)),
              _Field(
                  label: tr('category'),
                  controller: _category,
                  onMic: () => _listen(_category)),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                        label: tr('price'),
                        controller: _price,
                        number: true,
                        onMic: () => _listen(_price)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                        label: tr('qty'),
                        controller: _qty,
                        number: true,
                        integerOnly: true,
                        onMic: () => _listen(_qty)),
                  ),
                ],
              ),
              _Field(
                  label: tr('description'),
                  controller: _desc,
                  lines: 5,
                  onMic: () => _listen(_desc)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: (_saving || _archiving) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr('saveProduct')),
              ),
              TextButton.icon(
                onPressed: (_saving || _archiving) ? null : _archive,
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: Text(tr('archiveProductTitle')),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final bool integerOnly;
  final int lines;
  final VoidCallback onMic;

  const _Field({
    required this.label,
    required this.controller,
    required this.onMic,
    this.number = false,
    this.integerOnly = false,
    this.lines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: !number
                      ? TextInputType.multiline
                      : integerOnly
                          ? TextInputType.number
                          : const TextInputType.numberWithOptions(
                              decimal: true),
                  // Quantity is a count of physical items - "2.5" isn't a
                  // valid quantity, so digits-only here (unlike Price,
                  // which legitimately needs a decimal point for paise).
                  inputFormatters: integerOnly
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  maxLines: lines,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.mic),
                  color: AppColors.primary,
                  onPressed: onMic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
