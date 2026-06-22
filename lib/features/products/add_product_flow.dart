import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
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
  AiProductSuggestion? _suggestion;

  final _title = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController();

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
      if (x != null) setState(() => _imagePaths.add(x.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open image picker')));
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

    final ok = await stt.initialize();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone unavailable')));
      return;
    }

    setState(() => _listening = true);
    stt.listen(
        onResult: (r) =>
            setState(() => _voiceTranscript = r.recognizedWords));
  }

  Future<void> _listenToNumber(TextEditingController controller) async {
    final stt = ref.read(speechToTextProvider);
    final ok = await stt.initialize();
    if (!ok) return;
    stt.listen(
        onResult: (r) => setState(() => controller.text =
            r.recognizedWords.replaceAll(RegExp(r'[^0-9]'), '')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI failed: $e')));
      setState(() => _step = 1);
    }
  }

  String _cleanAiTitle(String raw) {
    String t = raw.trim();
    const badPrefixes = [
      'here is', "here's", 'here are', 'analysis', 'product analysis',
      'the analysis', 'ai analysis', 'here is the analysis',
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter product title')));
      return;
    }
    if (_price.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter price')));
      return;
    }
    if (_imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')));
      return;
    }

    final price = double.tryParse(_price.text.trim()) ?? 0;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    final product = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      category: _category.text.trim(),
      description: _description.text.trim(),
      price: price,
      quantity: qty,
      imagePaths: _imagePaths,
      tags: _suggestion?.tags ?? [],
    );

    setState(() => _processing = true);

    try {
      ref.read(productsProvider.notifier).add(product);
      final woo = ref.read(wooServiceProvider);
      final result = await woo.publishProduct(
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: _price.text.trim(),
        imageFile: File(_imagePaths.first),
      );

      if (!mounted) return;

      if (result.success) {
        if (result.productId != null) {
          ref
              .read(productsProvider.notifier)
              .update(product.copyWith(wooId: result.productId));
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Product published successfully')));
        Navigator.of(context).pop();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'WooCommerce publish failed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Publish failed: $e')));
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
                      onTap: () => _takePhoto(source: ImageSource.camera),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_camera_outlined,
                              size: 80, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(tr('tapToAddPhotos'),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
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
                                      child: Image.file(
                                          File(_imagePaths[i]),
                                          fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 18,
                                    child: GestureDetector(
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
                  onPressed: () => _takePhoto(source: ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tr('gallery')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _step = 1),
                  child: Text(
                      _imagePaths.isEmpty ? tr('skip') : tr('next')),
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
                    onMic: () => _listenToNumber(_price)),
                _LabelField(
                    label: tr('quantityAvailable'),
                    controller: _qty,
                    number: true,
                    onMic: () => _listenToNumber(_qty)),
              ],
            ),
          ),
        ),
        Center(child: VoiceButton(listening: _listening, onTap: _toggleVoice)),
        const SizedBox(height: 16),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: Text(tr('back')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
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
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(tr('aiProcessing'),
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textMuted)),
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
                _LabelField(label: tr('title'), controller: _title),
                _LabelField(label: tr('category'), controller: _category),
                _LabelField(
                    label: tr('price'),
                    controller: _price,
                    number: true,
                    onMic: () => _listenToNumber(_price)),
                _LabelField(
                    label: tr('qty'),
                    controller: _qty,
                    number: true,
                    onMic: () => _listenToNumber(_qty)),
                _LabelField(
                    label: tr('description'),
                    controller: _description,
                    maxLines: 5),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(0, 12, 0, 28),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processing ? null : _publish,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _processing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
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
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        IconButton(
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
  final int maxLines;
  final VoidCallback? onMic;

  const _LabelField({
    required this.label,
    required this.controller,
    this.number = false,
    this.maxLines = 1,
    this.onMic,
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
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: number
                      ? TextInputType.number
                      : TextInputType.multiline,
                ),
              ),
              if (onMic != null)
                IconButton(onPressed: onMic, icon: const Icon(Icons.mic)),
            ],
          ),
        ],
      ),
    );
  }
}
