import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../providers/language_provider.dart';
import '../../services/service_providers.dart';

class _ChatMessage {
  final String text;
  final bool fromAi;
  final DateTime at;

  _ChatMessage(this.text, this.fromAi) : at = DateTime.now();
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _State();
}

class _State extends ConsumerState<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      "Hi, Karigar! I'm your assistant. How can I help you?",
      true,
    ),
  ];

  bool _sending = false;
  bool _listening = false;

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();

    final stt = ref.read(speechToTextProvider);
    stt.stop();

    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _input.text).trim();

    if (content.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(content, false));
      _input.clear();
      _sending = true;
    });

    _scrollToBottom();

    final ai = ref.read(aiAssistantServiceProvider);
    final lang = ref.read(languageProvider).code;

    final reply = await ai.chat(
      message: content,
      languageCode: lang,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(reply, true));
      _sending = false;
    });

    _scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    final stt = ref.read(speechToTextProvider);

    if (_listening) {
      await stt.stop();
      setState(() => _listening = false);
      return;
    }

    final ok = await stt.initialize();

    if (!ok) return;

    setState(() => _listening = true);

    stt.listen(
      onResult: (r) {
        if (r.finalResult) {
          setState(() => _listening = false);
          _send(r.recognizedWords);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const _Typing();
                }

                final m = _messages[i];

                return Align(
                  alignment:
                      m.fromAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: m.fromAi ? AppColors.surface : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: m.fromAi ? AppColors.text : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.attach_file,
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  VoiceButton(
                    size: 48,
                    listening: _listening,
                    onTap: _toggleVoice,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: CircleAvatar(
                radius: 4,
                backgroundColor: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
