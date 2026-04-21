import 'package:flutter/material.dart';
import '../../components/voice_button.dart';

class NumericInput extends StatelessWidget {
  final String value;
  final String label;
  final String prefix;
  final String suffix;
  final bool isListening;
  final VoidCallback onListenTap;
  final Function(String) onChanged;

  const NumericInput({
    super.key,
    required this.value,
    required this.label,
    this.prefix = "",
    this.suffix = "",
    required this.isListening,
    required this.onListenTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        VoiceButton(onTap: onListenTap, isListening: isListening, label: label),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (prefix.isNotEmpty)
              Text(prefix, style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            IntrinsicWidth(
              child: TextField(
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
                onChanged: (val) => onChanged(val.replaceAll(RegExp(r'[^\d]'), '')),
                style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                decoration: InputDecoration(
                  hintText: "--",
                  hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.3)),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (suffix.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(suffix, style: theme.textTheme.headlineMedium),
            ]
          ],
        ),
      ],
    );
  }
}