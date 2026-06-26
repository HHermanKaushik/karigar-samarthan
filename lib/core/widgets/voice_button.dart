import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Large, prominent voice button used across the app.
/// Pulses and shows a stop icon while [listening] is true.
class VoiceButton extends StatefulWidget {
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
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    if (widget.listening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VoiceButton old) {
    super.didUpdateWidget(old);
    if (widget.listening && !old.listening) {
      _pulse.repeat(reverse: true);
    } else if (!widget.listening && old.listening) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.listening ? 'Stop recording' : 'Start voice input',
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.listening ? AppColors.danger : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (widget.listening ? AppColors.danger : AppColors.primary)
                      .withValues(alpha: widget.listening ? 0.55 : 0.35),
                  blurRadius: widget.listening ? 28 : 18,
                  spreadRadius: widget.listening ? 6 : 2,
                ),
              ],
            ),
            child: Icon(
              widget.listening ? Icons.stop_rounded : Icons.mic,
              color: Colors.white,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
