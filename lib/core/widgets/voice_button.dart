import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Large, prominent voice button used across the app.
class VoiceButton extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final bool listening;
  const VoiceButton({
    super.key,
    this.onTap,
    this.size = 64,
    this.listening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voice input',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: listening ? AppColors.danger : AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (listening ? AppColors.danger : AppColors.primary)
                    .withOpacity(0.35),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            listening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
