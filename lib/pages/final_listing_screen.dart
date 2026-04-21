import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/app_state.dart';
import '../models/product.dart';
import '../nav.dart';

class FinalReviewPage extends StatefulWidget {
  final Product draftProduct;

  const FinalReviewPage({super.key, required this.draftProduct});

  @override
  State<FinalReviewPage> createState() => _FinalReviewPageState();
}

class _FinalReviewPageState extends State<FinalReviewPage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _qtyController;
  late TextEditingController _catController;

  bool _isListening = false;
  String _activeField = "";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draftProduct.name);
    _descController = TextEditingController(text: widget.draftProduct.description);
    _priceController = TextEditingController(text: widget.draftProduct.price.toString());
    _qtyController = TextEditingController(text: widget.draftProduct.quantity.toString());
    _catController = TextEditingController(text: widget.draftProduct.category);

    _announce();
  }

  void _announce() {
    final isHi = Provider.of<AppState>(context, listen: false).selectedLang == 'Hindi';
    _tts.speak(isHi ? "सब ठीक है क्या? आप सुधार कर सकते हैं" : "Review your details. Tap the microphone to change anything.");
  }

  void _listen(TextEditingController controller, String fieldName) async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() { _isListening = true; _activeField = fieldName; });
        _speech.listen(onResult: (val) {
          setState(() { controller.text = val.recognizedWords; });
          if (val.finalResult) setState(() => _isListening = false);
        });
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);
    final bool isHi = appState.selectedLang == 'Hindi';

    return Scaffold(
      // Match the AppBar style from the Wizard
      appBar: AppBar(
        title: Text(isHi ? "विवरण की जांच करें" : "Final Review"),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Image Header - Using the 20dp radius from Wizard
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                // CHECK: If file exists, show it. Otherwise, show the fallback asset.
                image: DecorationImage(
                  image: widget.draftProduct.imageFile != null
                      ? FileImage(widget.draftProduct.imageFile!) as ImageProvider
                      : const AssetImage('assets/images/Handmade_pottery_brown_1769327617453.jpg'),
                  fit: BoxFit.cover,
                ),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              // OPTIONAL: Add a little "No Image" overlay text if it's the fallback
              child: widget.draftProduct.imageFile == null
                  ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withOpacity(0.2), // Dim the fallback slightly
                ),
                child: Center(
                  child: Text(
                    isHi ? "तस्वीर नहीं है" : "No Photo Added",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              )
                  : null,
            ),
            const SizedBox(height: 24),

            // AI/Summary Badge - Pulling that 'SecondaryContainer' logic from Project 2
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.secondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isHi ? "AI ने यह जानकारी तैयार की है" : "AI prepared these details for you.",
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. The Form Fields
            _buildEditTile(
              label: isHi ? "नाम" : "Product Name",
              controller: _nameController,
              icon: Icons.label_important_outline,
              fieldName: "name",
              theme: theme,
            ),

            // NEW: Category Field
            _buildEditTile(
              label: isHi ? "श्रेणी" : "Category",
              controller: _catController,
              icon: Icons.category_outlined,
              fieldName: "cat",
              theme: theme,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildEditTile(
                    label: isHi ? "कीमत (₹)" : "Price (₹)",
                    controller: _priceController,
                    icon: Icons.payments_outlined,
                    fieldName: "price",
                    theme: theme,
                    isNum: true,
                  ),
                ),
                const SizedBox(width: 16),
                // NEW: Quantity Field
                Expanded(
                  child: _buildEditTile(
                    label: isHi ? "मात्रा" : "Quantity",
                    controller: _qtyController,
                    icon: Icons.inventory_2_outlined,
                    fieldName: "qty",
                    theme: theme,
                    isNum: true,
                  ),
                ),
              ],
            ),

            _buildEditTile(
              label: isHi ? "विवरण" : "Description",
              controller: _descController,
              icon: Icons.notes,
              fieldName: "desc",
              theme: theme,
              lines: 3,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            final finalProduct = Product(
              id: widget.draftProduct.id,
              name: _nameController.text,
              category: _catController.text,
              description: _descController.text,
              price: double.tryParse(_priceController.text) ?? 0.0,
              quantity: int.tryParse(_qtyController.text) ?? 0,
              imageFile: widget.draftProduct.imageFile,
            );

            appState.addOrUpdateProduct(finalProduct);
            _tts.speak(isHi ? "जानकारी पक्की हो गई" : "Details confirmed!");
            context.go(AppRoutes.editProducts);
          },
          label: Text(isHi ? "अभी प्रकाशित करें" : "PUBLISH NOW"),
          icon: const Icon(Icons.check_circle),
          backgroundColor: theme.colorScheme.tertiary,
          foregroundColor: theme.colorScheme.onTertiary,
        ),
      ),
    );
  }

  Widget _buildEditTile({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String fieldName,
    required ThemeData theme,
    bool isNum = false,
    int lines = 1,
  }) {
    bool active = _isListening && _activeField == fieldName;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Using Surface Container Highest like File 1's inputs
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.1),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(label, style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  )),
                ],
              ),
              // Mic Button - Highlighted when active
              GestureDetector(
                onTap: () => _listen(controller, fieldName),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: active ? theme.colorScheme.error : theme.colorScheme.primaryContainer,
                  child: Icon(
                    active ? Icons.mic : Icons.mic_none,
                    size: 18,
                    color: active ? theme.colorScheme.onError : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: lines,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}