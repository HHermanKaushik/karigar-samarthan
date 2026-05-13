import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/products_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/service_providers.dart';

/// AI-assisted Add Product workflow:
/// 1. take/add photos
/// 2. speak about product
/// 3. AI suggests fields
/// 4. user reviews + edits
/// 5. publish
class AddProductFlow extends ConsumerStatefulWidget {
  const AddProductFlow({super.key});

  @override
  ConsumerState<AddProductFlow> createState() => _AddProductFlowState();
}

class _AddProductFlowState extends ConsumerState<AddProductFlow> {
  int _step = 0;

  // MULTIPLE IMAGES
  final List<String> _imagePaths = [];

  String _voiceTranscript = '';
  bool _listening = false;
  bool _processing = false;

  AiProductSuggestion? _suggestion;

  // EDITABLE CONTROLLERS
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

  // =========================
  // IMAGE PICKER
  // =========================
  Future<void> _takePhoto({required ImageSource source}) async {
    try {
      final picker = ImagePicker();

      final x = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (x != null) {
        setState(() {
          _imagePaths.add(x.path);
        });
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open image picker'),
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
  }

  // =========================
  // VOICE INPUT
  // =========================
  Future<void> _toggleVoice() async {
    final stt = ref.read(speechToTextProvider);

    if (_listening) {
      await stt.stop();
      setState(() => _listening = false);
      return;
    }

    final ok = await stt.initialize();

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone unavailable'),
        ),
      );
      return;
    }

    setState(() => _listening = true);

    stt.listen(onResult: (r) {
      setState(() {
        _voiceTranscript = r.recognizedWords;
      });
    });
  }

  Future<void> _listenToNumber(TextEditingController controller) async {
    final stt = ref.read(speechToTextProvider);

    final ok = await stt.initialize();

    if (!ok) return;

    stt.listen(onResult: (r) {
      setState(() {
        controller.text = r.recognizedWords.replaceAll(RegExp(r'[^0-9]'), '');
      });
    });
  }

  // =========================
  // AI
  // =========================
  Future<void> _runAi() async {
    setState(() => _processing = true);

    final ai = ref.read(aiAssistantServiceProvider);
    final lang = ref.read(languageProvider).code;

    final s = await ai.analyzeProduct(
      imagePaths: _imagePaths,
      voiceTranscript: _voiceTranscript,
      languageCode: lang,
    );

    // PREFILL EDITABLE FIELDS
    _title.text = s.title;
    _category.text = s.category;
    _description.text = s.description;

    setState(() {
      _suggestion = s;
      _processing = false;
      _step = 3;
    });
  }

  // =========================
  // PUBLISH
  // =========================
  void _publish() {
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

    ref.read(productsProvider.notifier).add(product);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_title.text} added to your store'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: switch (_step) {
        0 => _stepPhoto(),
        1 => _stepVoice(),
        2 => _stepProcessing(),
        _ => _stepReview(),
      },
    );
  }

  // =========================
  // STEP 1
  // =========================
  Widget _stepPhoto() {
    return Column(
      children: [
        const _Header(title: 'Add Product Photos'),
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
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              child: _imagePaths.isEmpty
                  ? GestureDetector(
                      onTap: () => _takePhoto(source: ImageSource.camera),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 80,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tap to Add Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                                        fit: BoxFit.cover,
                                      ),
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
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
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
                          label: const Text('Add More Photos'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _takePhoto(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 1),
                child: Text(
                  _imagePaths.isEmpty ? 'Skip' : 'Next',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // =========================
  // STEP 2
  // =========================
  Widget _stepVoice() {
    return Column(
      children: [
        const _Header(
          title: 'Tell us about your product',
        ),
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
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Text(
                    _voiceTranscript.isEmpty
                        ? 'Press the microphone and describe your product in your own words.'
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
                  label: 'Price (₹)',
                  controller: _price,
                  number: true,
                  onMic: () => _listenToNumber(_price),
                ),
                _LabelField(
                  label: 'Quantity Available',
                  controller: _qty,
                  number: true,
                  onMic: () => _listenToNumber(_qty),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: VoiceButton(
            listening: _listening,
            onTap: _toggleVoice,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _step = 2);
                  _runAi();
                },
                child: const Text('Next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // =========================
  // STEP 3
  // =========================
  Widget _stepProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          SizedBox(height: 20),
          Text(
            'AI is preparing your listing...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 4
  // =========================
  Widget _stepReview() {
    return Column(
      children: [
        const _Header(title: 'Final Review'),
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
                            child: Image.file(
                              File(_imagePaths[i]),
                              width: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                _LabelField(
                  label: 'Title',
                  controller: _title,
                ),
                _LabelField(
                  label: 'Category',
                  controller: _category,
                ),
                _LabelField(
                  label: 'Price',
                  controller: _price,
                  number: true,
                  onMic: () => _listenToNumber(_price),
                ),
                _LabelField(
                  label: 'Quantity',
                  controller: _qty,
                  number: true,
                  onMic: () => _listenToNumber(_qty),
                ),
                _LabelField(
                  label: 'Description',
                  controller: _description,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _publish,
          child: const Text('Finish'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// =========================
// HEADER
// =========================
class _Header extends StatelessWidget {
  final String title;

  const _Header({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

// =========================
// FIELD
// =========================
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
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType:
                      number ? TextInputType.number : TextInputType.multiline,
                ),
              ),
              if (onMic != null)
                IconButton(
                  onPressed: onMic,
                  icon: const Icon(Icons.mic),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
