import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/legal_links.dart';
import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/service_providers.dart';

class AddProductFlow extends ConsumerStatefulWidget {
  const AddProductFlow({super.key});

  @override
  ConsumerState<AddProductFlow> createState() => _AddProductFlowState();
}

class _AddProductFlowState extends ConsumerState<AddProductFlow> {
  int _step = 0;

  final List<String> _imagePaths = [];
  String _voiceTranscript = '';
  bool _listening = false;
  bool _processing = false;
  bool _sttReady = false;
  AiProductSuggestion? _suggestion;

  final _title = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initStt();
  }

  Future<void> _initStt() async {
    final stt = ref.read(speechToTextProvider);
    final ok = await stt.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (ok && mounted) setState(() => _sttReady = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  // ── IMAGE PICKER ──────────────────────────────────────────────────────

  Future<void> _takePhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: source, imageQuality: 80);
      if (x == null) return;

      // Copy to the app's documents directory so the path survives app restarts.
      final dir = await getApplicationDocumentsDirectory();
      final ext = x.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final dest =
          '${dir.path}/product_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(x.path).copy(dest);

      if (mounted) setState(() => _imagePaths.add(dest));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_photo_error_message'),
          content: Text(ref.read(trProvider)('imagePickerError'))));
    }
  }

  void _removeImage(int index) => setState(() => _imagePaths.removeAt(index));

  // ── VOICE ─────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    final stt = ref.read(speechToTextProvider);

    if (_listening) {
      await stt.stop();
      setState(() => _listening = false);
      return;
    }

    if (!_sttReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_mic_unavailable_message'),
          content: Text(ref.read(trProvider)('micUnavailable'))));
      return;
    }

    setState(() => _listening = true);
    stt.listen(
        onResult: (r) => setState(() => _voiceTranscript = r.recognizedWords));
  }

  Future<void> _listenToNumber(TextEditingController controller,
      {bool allowDecimal = true}) async {
    // Don't interrupt the product description recording.
    if (_listening) return;

    final tr = ref.read(trProvider);
    final stt = ref.read(speechToTextProvider);

    if (stt.isListening) {
      await stt.stop();
      // Small pause to let the engine fully reset before re-using it.
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!_sttReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const Key('add_product_mic_unavailable_number_message'),
        content: Text(tr('micUnavailable')),
      ));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('listening')),
      duration: const Duration(seconds: 5),
    ));

    final started = await stt.listen(
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        if (r.finalResult) {
          final pattern = allowDecimal ? r'[^0-9.]' : r'[^0-9]';
          setState(() => controller.text =
              r.recognizedWords.replaceAll(RegExp(pattern), ''));
        }
      },
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const Key('add_product_mic_unavailable_number_message'),
        content: Text(tr('micUnavailable')),
      ));
    }
  }

  // ── AI ────────────────────────────────────────────────────────────────

  Future<void> _runAi() async {
    setState(() => _processing = true);
    try {
      final ai = ref.read(aiAssistantServiceProvider);
      final lang = ref.read(languageProvider).code;
      final s = await ai.analyzeProduct(
        imagePaths: _imagePaths,
        voiceTranscript: _voiceTranscript,
        languageCode: lang,
      );

      if (s.flagged) {
        await _logFlaggedListing(reason: s.flagReason);
        if (!mounted) return;
        setState(() => _processing = false);
        await _showFlaggedDialog(s.flagReason);
        if (!mounted) return;
        setState(() {
          _step = 0;
          _imagePaths.clear();
        });
        return;
      }

      _title.text = _cleanAiTitle(s.title);
      _category.text = s.category;
      _description.text = s.description;
      setState(() {
        _suggestion = s;
        _processing = false;
        _step = 3;
      });
    } catch (e) {
      setState(() => _processing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_ai_error_message'),
          content: Text('${ref.read(trProvider)('aiFailedPrefix')}: $e')));
      setState(() => _step = 1);
    }
  }

  /// Blocks until the karigar explicitly acknowledges why their photo was
  /// rejected - replaces an earlier SnackBar, which auto-dismissed in a few
  /// seconds (too fast to read) and had no audio at all, shutting out
  /// illiterate users entirely. This dialog can't be swiped/tapped away or
  /// dismissed with the back button, speaks itself aloud on open (via the
  /// same TTS pipeline as the rest of the app - Sarvam voice with a native
  /// fallback), and offers the full written policy as a web link for anyone
  /// who wants more detail than the in-app summary.
  Future<void> _showFlaggedDialog(String reason) async {
    final tr = ref.read(trProvider);
    final langCode = ref.read(languageProvider).sarvamCode;
    final title = tr('imageFlaggedError');
    final summary = tr('bannedItemsSummary');
    final spoken =
        reason.isNotEmpty ? '$title. $reason. $summary' : '$title. $summary';

    unawaited(TTSService.speak(text: spoken, languageCode: langCode));

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reason.isNotEmpty) ...[
                Text(reason,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
              ],
              Text(summary),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(termsAndConditionsUrl),
                  mode: LaunchMode.externalApplication),
              child: Text(tr('readFullPolicyBtn')),
            ),
            ElevatedButton(
              key: const Key('add_product_flagged_acknowledge_button'),
              onPressed: () {
                TTSService.stop();
                Navigator.of(dialogContext).pop();
              },
              child: Text(tr('iUnderstandBtn')),
            ),
          ],
        ),
      ),
    );
  }

  /// Records a blocked (illegal-item-flagged) publish attempt for manual
  /// follow-up - there's no admin review UI yet, so this is purely an audit
  /// trail. Never throws: a logging failure must not block the karigar from
  /// seeing the "publish blocked" message or trying again with new photos.
  Future<void> _logFlaggedListing({required String reason}) async {
    try {
      final user = ref.read(userProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      );
      final docRef = db.collection('flagged_listings').doc();

      final storagePaths = <String>[];
      for (var i = 0; i < _imagePaths.length; i++) {
        try {
          final file = File(_imagePaths[i]);
          if (!await file.exists()) continue;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('flagged_listings')
              .child(docRef.id)
              .child('image_$i.jpg');
          await storageRef.putFile(file);
          storagePaths.add(await storageRef.getDownloadURL());
        } catch (_) {}
      }

      await docRef.set({
        'uid': uid,
        'storeName': user.storeName,
        'phone': user.phone,
        'reason': reason,
        'voiceTranscript': _voiceTranscript,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrls': storagePaths,
      });
    } catch (_) {}
  }

  String _cleanAiTitle(String raw) {
    String t = raw.trim();
    const badPrefixes = [
      'here is',
      "here's",
      'here are',
      'analysis',
      'product analysis',
      'the analysis',
      'ai analysis',
      'here is the analysis',
      'here is the analysis of the artisan product',
    ];
    for (final p in badPrefixes) {
      if (t.toLowerCase().startsWith(p)) t = 'Handmade Artisan Product';
    }
    t = t.replaceAll('"', '');
    if (t.length > 80) t = t.substring(0, 80);
    if (t.isEmpty) t = 'Handmade Artisan Product';
    return t;
  }

  // ── PUBLISH ───────────────────────────────────────────────────────────

  Future<void> _publish() async {
    if (_processing) return;

    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_title_required_message'),
          content: Text(ref.read(trProvider)('titleRequired'))));
      return;
    }
    if (_price.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_price_required_message'),
          content: Text(ref.read(trProvider)('priceRequired'))));
      return;
    }
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_image_required_message'),
          content: Text(ref.read(trProvider)('imageRequired'))));
      return;
    }

    setState(() => _processing = true);

    final price = double.tryParse(_price.text.trim()) ?? 0;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;

    // Listings must always be stored/published in English, regardless of
    // which language the karigar used to create them via voice/AI — the
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

    // Each translation is independent (different source text, no shared
    // state in SarvamService), so they can run concurrently instead of
    // waiting on each other one at a time.
    final publishStopwatch = Stopwatch()..start();
    final translationStopwatch = Stopwatch()..start();

    final localTitle = _title.text.trim();
    final localCategory = _category.text.trim();
    final localDescription = _description.text.trim();

    final tagSources = _suggestion?.tags ?? const <String>[];
    final translated = await Future.wait([
      toEnglish(localTitle),
      toEnglish(localCategory),
      toEnglish(localDescription),
      ...tagSources.map(toEnglish),
    ]);

    translationStopwatch.stop();

    final title = translated[0];
    final category = translated[1];
    final description = translated[2];
    final tags = translated.sublist(3);

    final product = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      description: description,
      // Keeps the karigar's own words viewable in-app when they're back on
      // this same language - see Product.displayTitle() and friends. Only
      // worth keeping when it actually differs from the English translation
      // (i.e. the karigar wasn't already working in English).
      localTitle: lang.code != 'en' ? localTitle : '',
      localCategory: lang.code != 'en' ? localCategory : '',
      localDescription: lang.code != 'en' ? localDescription : '',
      localLanguageCode: lang.code != 'en' ? lang.code : null,
      price: price,
      quantity: qty,
      imagePaths: _imagePaths,
      tags: tags,
    );

    try {
      ref.read(productsProvider.notifier).add(product);
      final woo = ref.read(wooServiceProvider);
      final user = ref.read(userProvider);

      final wooStopwatch = Stopwatch()..start();
      final result = await woo.publishProduct(
        title: product.title,
        description: product.description,
        price: _price.text.trim(),
        imageFiles: _imagePaths.map((p) => File(p)).toList(),
        karigarUid: FirebaseAuth.instance.currentUser?.uid ?? '',
        karigarName: user.fullName,
        upiId: user.upiId,
        language: ref.read(languageProvider).code,
        category: product.category,
        storeName: user.storeName,
      );
      wooStopwatch.stop();
      publishStopwatch.stop();

      // ignore: avoid_print
      print('--- PUBLISH TIMING BREAKDOWN ---');
      // ignore: avoid_print
      print(
          'translation_call_count: ${3 + tagSources.length} (title+category+description+${tagSources.length} tags)');
      // ignore: avoid_print
      print(
          'translation_phase_ms: ${translationStopwatch.elapsedMilliseconds}');
      // ignore: avoid_print
      print('woocommerce_publish_ms: ${wooStopwatch.elapsedMilliseconds}');
      // ignore: avoid_print
      print('total_publish_ms: ${publishStopwatch.elapsedMilliseconds}');

      if (!mounted) return;

      if (result.success) {
        if (result.productId != null) {
          ref.read(productsProvider.notifier).update(product.copyWith(
                wooId: result.productId,
                wooImageUrl: result.imageUrl,
                wooImageUrls: result.imageUrls,
                permalink: result.permalink,
              ));
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            key: const Key('add_product_publish_success_message'),
            content: Text(ref.read(trProvider)('productPublishedSuccess'))));
        Navigator.of(context).pop();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_publish_failure_message'),
          content: Text(result.message ??
              ref.read(trProvider)('wooPublishFailedDefault'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const Key('add_product_publish_error_message'),
          content: Text('${ref.read(trProvider)('publishFailedPrefix')}: $e')));
    }

    if (mounted) setState(() => _processing = false);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: switch (_step) {
            0 => _stepPhoto(),
            1 => _stepVoice(),
            2 => _stepProcessing(),
            _ => _stepReview(),
          },
        ),
      ),
    );
  }

  // ── STEP 1: PHOTO ─────────────────────────────────────────────────────

  Widget _stepPhoto() {
    final tr = ref.watch(trProvider);
    return Column(
      children: [
        _Header(title: tr('addPhotos')),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: _imagePaths.isEmpty
                  ? GestureDetector(
                      key: const Key('add_product_photo_camera_area'),
                      onTap: () => _takePhoto(source: ImageSource.camera),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_outlined,
                              size: 80, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(tr('tapToAddPhotos'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imagePaths.length,
                            itemBuilder: (_, i) {
                              return Stack(
                                children: [
                                  Container(
                                    width: 220,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(File(_imagePaths[i]),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 18,
                                    child: GestureDetector(
                                      key: ValueKey(
                                          'add_product_photo_remove_$i'),
                                      onTap: () => _removeImage(i),
                                      child: const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.red,
                                        child: Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('add_product_photo_addmore_button'),
                          onPressed: () =>
                              _takePhoto(source: ImageSource.gallery),
                          icon: const Icon(Icons.add),
                          label: Text(tr('addMorePhotos')),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('add_product_gallery_button'),
                  onPressed: () => _takePhoto(source: ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tr('gallery')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('add_product_photo_next_button'),
                  // Photo is mandatory here - moderation in _runAi() only
                  // runs once per flow, so a later-added photo would skip
                  // it entirely.
                  onPressed: () {
                    if (_imagePaths.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          key: const Key('add_product_image_required_message'),
                          content: Text(tr('imageRequired'))));
                      return;
                    }
                    setState(() => _step = 1);
                  },
                  child: Text(tr('next')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 2: VOICE ─────────────────────────────────────────────────────

  Widget _stepVoice() {
    final tr = ref.watch(trProvider);
    return Column(
      children: [
        _Header(title: tr('describeProduct')),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _voiceTranscript.isEmpty
                        ? tr('describeProductHint')
                        : _voiceTranscript,
                    style: TextStyle(
                      color: _voiceTranscript.isEmpty
                          ? AppColors.textMuted
                          : AppColors.text,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _LabelField(
                    label: tr('price'),
                    controller: _price,
                    number: true,
                    onMic: () => _listenToNumber(_price),
                    fieldKey: const Key('add_product_price_field'),
                    micKey: const Key('add_product_price_mic_button')),
                _LabelField(
                    label: tr('quantityAvailable'),
                    controller: _qty,
                    number: true,
                    integerOnly: true,
                    onMic: () => _listenToNumber(_qty, allowDecimal: false),
                    fieldKey: const Key('add_product_qty_field'),
                    micKey: const Key('add_product_qty_mic_button')),
                const SizedBox(height: 24),
                Center(
                    child: VoiceButton(
                        key: const Key('add_product_voice_button'),
                        listening: _listening,
                        onTap: _toggleVoice)),
                const SizedBox(height: 10),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    // Sequential, not overlapping: the old label fully fades
                    // out before the new one fades in. AnimatedSwitcher's
                    // default crossfade shows both stacked at once, which
                    // reads as garbled/overlapping text right as recording
                    // starts or stops - exactly the "unclear" moment being
                    // fixed here.
                    switchInCurve: const Interval(0.5, 1.0),
                    switchOutCurve: const Interval(0.0, 0.5),
                    child: Text(
                      _listening
                          ? tr('recordingTapToStop')
                          : tr('tapMicToDescribe'),
                      key: ValueKey(_listening),
                      style: TextStyle(
                        color:
                            _listening ? AppColors.danger : AppColors.textMuted,
                        fontWeight:
                            _listening ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('add_product_voice_back_button'),
                  onPressed: () => setState(() => _step = 0),
                  child: Text(tr('back')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  key: const Key('add_product_voice_next_button'),
                  onPressed: () {
                    setState(() => _step = 2);
                    _runAi();
                  },
                  child: Text(tr('next')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STEP 3: PROCESSING ────────────────────────────────────────────────

  Widget _stepProcessing() {
    final tr = ref.watch(trProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              key: Key('add_product_processing_spinner'),
              color: AppColors.primary),
          const SizedBox(height: 20),
          Text(tr('aiProcessing'),
              style: const TextStyle(fontSize: 16, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── STEP 4: REVIEW ────────────────────────────────────────────────────

  Widget _stepReview() {
    final tr = ref.watch(trProvider);
    return Column(
      children: [
        _Header(title: tr('finalReview')),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Read-only here, deliberately: a photo is required and
                // vetted by AI moderation back on the photo step (Next is
                // disabled there until one exists), so there's no valid way
                // to reach this screen without an already-screened photo,
                // and no reason to let a new, unscreened one in this late.
                if (_imagePaths.isNotEmpty)
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imagePaths.length,
                      itemBuilder: (_, i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(File(_imagePaths[i]),
                                width: 220, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                _LabelField(
                    label: tr('title'),
                    controller: _title,
                    fieldKey: const Key('add_product_title_field')),
                _LabelField(
                    label: tr('category'),
                    controller: _category,
                    fieldKey: const Key('add_product_category_field')),
                _LabelField(
                    label: tr('price'),
                    controller: _price,
                    number: true,
                    onMic: () => _listenToNumber(_price),
                    fieldKey: const Key('add_product_price_field'),
                    micKey: const Key('add_product_price_mic_button')),
                _LabelField(
                    label: tr('qty'),
                    controller: _qty,
                    number: true,
                    integerOnly: true,
                    onMic: () => _listenToNumber(_qty, allowDecimal: false),
                    fieldKey: const Key('add_product_qty_field'),
                    micKey: const Key('add_product_qty_mic_button')),
                _LabelField(
                    label: tr('description'),
                    controller: _description,
                    maxLines: 5,
                    fieldKey: const Key('add_product_description_field')),
              ],
            ),
          ),
        ),
        if (_processing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr('publishingListing'),
              key: const Key('add_product_publish_status_text'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('add_product_publish_button'),
              onPressed: _processing ? null : _publish,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _processing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            key: Key('add_product_publish_spinner'),
                            strokeWidth: 2,
                            color: Colors.white))
                    : Text(tr('publishProduct')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        IconButton(
          key: const Key('add_product_close_button'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

// ── FIELD ─────────────────────────────────────────────────────────────────

class _LabelField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final bool integerOnly;
  final int maxLines;
  final VoidCallback? onMic;
  final Key? fieldKey;
  final Key? micKey;

  const _LabelField({
    required this.label,
    required this.controller,
    this.number = false,
    this.integerOnly = false,
    this.maxLines = 1,
    this.onMic,
    this.fieldKey,
    this.micKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  maxLines: maxLines,
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
                ),
              ),
              if (onMic != null)
                IconButton(
                    key: micKey, onPressed: onMic, icon: const Icon(Icons.mic)),
            ],
          ),
        ],
      ),
    );
  }
}
