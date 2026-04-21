import 'package:flutter/material.dart';

class VoiceButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isListening;
  final String? label;
  final double size;

  const VoiceButton({
    super.key,
    required this.onTap,
    this.isListening = false,
    this.label,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color:
                      (isListening
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
