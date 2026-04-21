import 'package:flutter/material.dart';
import '../../components/voice_button.dart';

class NameInput extends StatelessWidget {
  final String value;
  final String? suggestion;
  final bool isListening;
  final bool isAiThinking;
  final Function(String) onChanged;
  final VoidCallback onListenTap;
  final VoidCallback onAcceptSuggestion;
  final VoidCallback onRejectSuggestion;
  final Widget Function(String) aiThinkingWidget;
  final Widget Function({required String suggestion, required VoidCallback onAccept, required VoidCallback onReject}) suggestionWidget;

  const NameInput({
    super.key,
    required this.value,
    this.suggestion,
    required this.isListening,
    required this.isAiThinking,
    required this.onChanged,
    required this.onListenTap,
    required this.onAcceptSuggestion,
    required this.onRejectSuggestion,
    required this.aiThinkingWidget,
    required this.suggestionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          VoiceButton(onTap: onListenTap, isListening: isListening, label: "Tap to Speak Name"),
          const SizedBox(height: 20),
          TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Product Name"),
          ),
          if (suggestion != null && suggestion != value)
            suggestionWidget(suggestion: suggestion!, onAccept: onAcceptSuggestion, onReject: onRejectSuggestion),
          if (isAiThinking) aiThinkingWidget("crafting a name"),
        ],
      ),
    );
  }
}