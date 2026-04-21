import 'package:flutter/material.dart';
import '../../components/voice_button.dart';

class DescInput extends StatelessWidget {
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

  const DescInput({
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
          VoiceButton(
            onTap: onListenTap, 
            isListening: isListening, 
            label: "Tap to Describe"
          ),
          const SizedBox(height: 24),
          TextField(
            maxLines: 4,
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Product Description",
              hintText: "Enter or speak details...",
              alignLabelWithHint: true,
            ),
          ),
          if (suggestion != null && suggestion != value)
            suggestionWidget(
              suggestion: suggestion!, 
              onAccept: onAcceptSuggestion, 
              onReject: onRejectSuggestion
            ),
          if (isAiThinking) aiThinkingWidget("generating a description"),
        ],
      ),
    );
  }
}