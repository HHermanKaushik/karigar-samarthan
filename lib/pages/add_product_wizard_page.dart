import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart' as tts;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../nav.dart';
import '../providers/app_state.dart';
import '../components/audio_prompt.dart';
import '../models/product.dart';

// Steps & Service
import 'ai_service.dart';
import 'add_product_steps/PhotoInput.dart';
import 'add_product_steps/NameInput.dart';
import 'add_product_steps/CategoryInput.dart';
import 'add_product_steps/DescInput.dart';
import 'add_product_steps/NumericInput.dart';

class AddProductWizardPage extends StatefulWidget {
  const AddProductWizardPage({super.key});

  @override
  State<AddProductWizardPage> createState() => _AddProductWizardPageState();
}

class _AddProductWizardPageState extends State<AddProductWizardPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final PageController _pageController = PageController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final tts.FlutterTts _tts = tts.FlutterTts();
  
  int _currentStep = 0;
  bool _isListening = false;
  String _activeField = "";
  
  // Form Data
  File? _imageFile;
  String _name = "", _category = "", _description = "", _price = "", _quantity = "";
  String? _aiSuggestedName, _aiSuggestedDescription, _aiSuggestedCategory;
  bool _isAiDone = false;
  Future<AiProductResult?>? _aiTask;

  @override
  void initState() {
    super.initState();
    _speech.initialize();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      final draftProduct = Product(
        id: DateTime.now().toString(),
        name: _name,
        category: _category,
        description: _description,
        price: double.tryParse(_price) ?? 0.0,
        quantity: int.tryParse(_quantity) ?? 0,
        imageFile: _imageFile,
      );
      context.go(AppRoutes.productReview, extra: draftProduct);
    }
  }

  void _listen(String fieldName) async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() { _isListening = true; _activeField = fieldName; });
        _speech.listen(
          localeId: appState.locale,
          onResult: (val) {
            setState(() {
              String text = val.recognizedWords;
              if (fieldName == "name") _name = text;
              if (fieldName == "description") _description = text;
              if (fieldName == "price") _price = text.replaceAll(RegExp(r'[^0-9]'), '');
              if (fieldName == "quantity") _quantity = text.replaceAll(RegExp(r'[^0-9]'), '');
            });
            if (val.finalResult) setState(() => _isListening = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 6'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded), // rounded looks a bit friendlier
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep("Add Product Photo", "Take a photo of your product", _stepPhoto()),
                _buildStep("Product Name", "Say the product name", _stepName()),
                _buildStep("Category", "Choose a category", _stepCategory()),
                _buildStep("Description", "Describe the product details", _stepDescription()),
                _buildStep("Set Price", "Say the price in rupees", _stepPrice()),
                _buildStep("Quantity", "How many items do you have?", _stepQuantity()),
              ],
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  // --- Step Builders ---

  Widget _stepPhoto() => PhotoInput(
    imageFile: _imageFile,
    onImagePicked: (file) {
      setState(() { 
        _imageFile = file; 
        _isAiDone = false; 
        _aiTask = AiService.processAndAnalyzeImage(file); 
      });
      _aiTask!.then((res) {
        if (res != null && mounted) {
          setState(() { 
            _aiSuggestedName = res.title; 
            _aiSuggestedDescription = res.description; 
            _aiSuggestedCategory = res.category; 
            _isAiDone = true; 
          });
        }
      });
      _nextStep();
    },
  );

  Widget _stepName() => NameInput(
    value: _name,
    suggestion: _aiSuggestedName,
    isListening: _isListening && _activeField == "name",
    isAiThinking: !_isAiDone && _aiTask != null,
    onChanged: (val) => setState(() => _name = val),
    onListenTap: () => _listen("name"),
    onAcceptSuggestion: () => setState(() { _name = _aiSuggestedName!; _aiSuggestedName = null; }),
    onRejectSuggestion: () => setState(() => _aiSuggestedName = null),
    aiThinkingWidget: _buildAiThinking,
    suggestionWidget: _buildAiSuggestion,
  );

  Widget _stepCategory() => CategoryInput(
    selectedCategory: _category,
    onCategorySelected: (cat) => setState(() => _category = cat),
  );

  Widget _stepDescription() => DescInput(
    value: _description,
    suggestion: _aiSuggestedDescription,
    isListening: _isListening && _activeField == "description",
    isAiThinking: !_isAiDone && _aiTask != null,
    onChanged: (val) => setState(() => _description = val),
    onListenTap: () => _listen("description"),
    onAcceptSuggestion: () => setState(() { _description = _aiSuggestedDescription!; _aiSuggestedDescription = null; }),
    onRejectSuggestion: () => setState(() => _aiSuggestedDescription = null),
    aiThinkingWidget: _buildAiThinking,
    suggestionWidget: _buildAiSuggestion,
  );

  Widget _stepPrice() => NumericInput(
    value: _price,
    label: "Tap to Say Price",
    prefix: "₹",
    isListening: _isListening && _activeField == "price",
    onListenTap: () => _listen("price"),
    onChanged: (val) => setState(() => _price = val),
  );

  Widget _stepQuantity() => NumericInput(
    value: _quantity,
    label: "Tap to Say Quantity",
    suffix: "units",
    isListening: _isListening && _activeField == "quantity",
    onListenTap: () => _listen("quantity"),
    onChanged: (val) => setState(() => _quantity = val),
  );

  // --- UI Helpers (Reusable) ---

  Widget _buildStep(String title, String audio, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AudioPrompt(text: audio, onPlay: () => _tts.speak(audio)),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentStep < 5 ? TextButton(onPressed: _nextStep, child: const Text('Skip')) : const SizedBox(width: 60),
          FloatingActionButton.extended(
            onPressed: _nextStep,
            label: Text(_currentStep == 5 ? 'Finish' : 'Next'),
            icon: Icon(_currentStep == 5 ? Icons.check : Icons.arrow_forward),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildAiThinking(String label) {
    return FadeTransition(
      opacity: _pulseController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 16),
          const SizedBox(width: 8),
          Text("AI is $label...", style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildAiSuggestion({required String suggestion, required VoidCallback onAccept, required VoidCallback onReject}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI Suggestion", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(suggestion),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onReject, child: const Text("Discard")),
              ElevatedButton(onPressed: onAccept, child: const Text("Accept")),
            ],
          )
        ],
      ),
    );
  }
}