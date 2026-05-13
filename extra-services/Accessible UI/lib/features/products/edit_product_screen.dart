import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  ConsumerState<EditProductScreen> createState() => _State();
}

class _State extends ConsumerState<EditProductScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.product.title);
  late final TextEditingController _category =
      TextEditingController(text: widget.product.category);
  late final TextEditingController _price =
      TextEditingController(text: widget.product.price.toStringAsFixed(0));
  late final TextEditingController _qty =
      TextEditingController(text: widget.product.quantity.toString());
  late final TextEditingController _desc =
      TextEditingController(text: widget.product.description);

  final List<File> _images = [];

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _price.dispose();
    _qty.dispose();
    _desc.dispose();
    super.dispose();
  }

  // =========================
  // SAVE
  // =========================
  void _save() {
    ref.read(productsProvider.notifier).update(widget.product.copyWith(
          title: _title.text,
          category: _category.text,
          description: _desc.text,
          price: double.tryParse(_price.text) ?? widget.product.price,
          quantity: int.tryParse(_qty.text) ?? widget.product.quantity,
        ));

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _images.isEmpty
              ? 'Product saved (no images)'
              : 'Product saved with ${_images.length} image(s)',
        ),
      ),
    );
  }

  // =========================
  // IMAGE PICKER
  // =========================
  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _images.add(File(picked.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // =========================
  // STT FUNCTION
  // =========================
  Future<void> _listen(TextEditingController controller) async {
    if (!_isListening) {
      bool available = await _speech.initialize();

      if (available) {
        setState(() => _isListening = true);

        _speech.listen(
          onResult: (result) {
            setState(() {
              controller.text = result.recognizedWords;
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit Product',
                  style: TextStyle(
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
          ),

          const SizedBox(height: 12),

          // =========================
          // IMAGE SECTION (MULTIPLE)
          // =========================
          Container(
            height: 160,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Expanded(
                  child: _images.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (_, i) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(_images[i]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.red,
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _addImage,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Image"),
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 18),

          _Field(
              label: 'Title', controller: _title, onMic: () => _listen(_title)),
          _Field(
              label: 'Category',
              controller: _category,
              onMic: () => _listen(_category)),

          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Price',
                  controller: _price,
                  number: true,
                  onMic: () => _listen(_price),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Quantity',
                  controller: _qty,
                  number: true,
                  onMic: () => _listen(_qty),
                ),
              ),
            ],
          ),

          _Field(
            label: 'Description',
            controller: _desc,
            lines: 5,
            onMic: () => _listen(_desc),
          ),

          const SizedBox(height: 8),

          ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// =========================
// FIELD WITH STT BUTTON
// =========================
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool number;
  final int lines;
  final VoidCallback onMic;

  const _Field({
    required this.label,
    required this.controller,
    required this.onMic,
    this.number = false,
    this.lines = 1,
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      number ? TextInputType.number : TextInputType.multiline,
                  maxLines: lines,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mic),
                onPressed: onMic,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
