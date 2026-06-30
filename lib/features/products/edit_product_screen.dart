import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
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
  bool _saving = false;
  bool _archiving = false;

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

    final updated = widget.product.copyWith(
      title: _title.text.trim(),
      category: _category.text.trim(),
      description: _desc.text.trim(),
      price: double.tryParse(_price.text.trim()) ?? widget.product.price,
      quantity: int.tryParse(_qty.text.trim()) ?? widget.product.quantity,
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

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Product updated on the live store.'),
      ));
    } else {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Product'),
        content: const Text(
          'This product will be hidden from your list. It will remain on your WooCommerce store and can be restored from there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _archiving = true);
    await ref.read(productsProvider.notifier).archive(widget.product.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _images.add(File(picked.path)));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
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
                      child: _images.isEmpty
                          ? const Center(
                              child: Icon(Icons.add_a_photo_outlined,
                                  size: 54, color: AppColors.primary))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length,
                              itemBuilder: (_, i) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin:
                                          const EdgeInsets.only(right: 12),
                                      width: 130,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        image: DecorationImage(
                                          image: FileImage(_images[i]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 18,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(i),
                                        child: const CircleAvatar(
                                          radius: 13,
                                          backgroundColor: Colors.red,
                                          child: Icon(Icons.close,
                                              size: 15,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
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
                label: const Text('Archive Product'),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      number ? TextInputType.number : TextInputType.multiline,
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
