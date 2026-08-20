import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/tts_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../models/app_language.dart';
import '../../providers/chat_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/service_providers.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  /// Called after the AI modal closes when the model invokes navigate_to or
  /// open_edit_product. [editProductId] is set (the Firestore product doc
  /// id) when [target] is [NavigateTarget.editProduct].
  /// If null, navigation tool calls are handled as text only.
  final void Function(NavigateTarget target, {String? editProductId})?
      onNavigateTo;

  const AiAssistantScreen({super.key, this.onNavigateTo});

  @override
  ConsumerState<AiAssistantScreen> createState() => _State();
}

class _State extends ConsumerState<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = FlutterSoundRecorder();

  bool _recorderReady = false;
  String? _recordingPath;

  bool _sending = false;
  bool _listening = false;
  bool _transcribing = false;
  double _speechRate = TTSService.defaultSpeechRate;

  @override
  void initState() {
    super.initState();
    TTSService.getSpeechRate().then((rate) {
      if (mounted) setState(() => _speechRate = rate);
    });
    // Chat transcript/session live in providers (chat_provider.dart), not
    // this State, so they survive this screen popping and reopening. Only
    // seed the greeting when the app-wide transcript is empty. Deferred
    // via addPostFrameCallback - a provider write inside initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(chatMessagesProvider).isEmpty) {
        final tr = ref.read(trProvider);
        ref
            .read(chatMessagesProvider.notifier)
            .add(ChatMessage(tr('aiGreeting'), true));
      }
    });
    // Mic permission is requested on-demand in _toggleVoice(), not here,
    // so typing a text message never triggers a permission prompt.
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    TTSService.stop();
    super.dispose();
  }

  // Created lazily on first send so Firestore-backed providers have time
  // to load. Cached in chatSessionProvider, not local State, but rebuilt
  // if the app language changed since creation - the system prompt
  // hardcodes the reply language.
  AgentSession _getSession() {
    final lang = ref.read(languageProvider);
    final existing = ref.read(chatSessionProvider);
    if (existing != null && existing.languageCode == lang.code) {
      return existing.session;
    }
    final ai = ref.read(aiAssistantServiceProvider);
    final woo = ref.read(wooServiceProvider);
    // App-wide ProviderContainer, not this screen's own `ref` - the
    // session outlives this screen, and a screen-scoped `ref` would throw
    // once this screen is disposed.
    final container = ProviderScope.containerOf(context, listen: false);
    final session = ai.createSession(
      accountContext: _buildAccountContext(),
      languageCode: lang.code,
      woo: woo,
      getProducts: () => container.read(productsProvider),
      getOrders: () => container.read(ordersProvider),
    );
    ref.read(chatSessionProvider.notifier).set(session, lang.code);
    return session;
  }

  String _buildAccountContext() {
    final user = ref.read(userProvider);
    final products = ref.read(productsProvider);
    final orders = ref.read(ordersProvider);

    final productLines = products.isEmpty
        ? '- (none yet)'
        : products
            .map(
              (p) =>
                  '- "${p.title}" (${p.category}): price ₹${p.price.toStringAsFixed(0)}, qty ${p.quantity}${p.wooId != null ? ', wooId ${p.wooId}' : ''}',
            )
            .join('\n');

    final orderLines = orders.isEmpty
        ? '- (none yet)'
        : orders
            .map(
              (o) =>
                  '- Order #${o.id}: "${o.productTitle}" ×${o.quantity}, ₹${o.total.toStringAsFixed(0)}, status: ${o.status.name}, customer: ${o.customerName}',
            )
            .join('\n');

    return '''
Seller name: ${user.fullName}
Store name: ${user.storeName}
Phone: ${user.phone}
Role: ${user.role}
Payment setup: ${user.paymentSetup ? 'complete' : 'not set'}

Products:
$productLines

Orders:
$orderLines
''';
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

    ref.read(chatMessagesProvider.notifier).add(ChatMessage(content, false));
    setState(() {
      _input.clear();
      _sending = true;
    });
    _scrollToBottom();

    final lang = ref.read(languageProvider);
    final tr = ref.read(trProvider);
    final response = await _getSession().send(content);

    if (!mounted) return;

    final responseText = response.isError ? tr('aiError') : response.text;
    ref
        .read(chatMessagesProvider.notifier)
        .add(ChatMessage(responseText, true));
    setState(() {
      _sending = false;
    });
    _scrollToBottom();

    if (response.isError) return;

    // Speak the response first, then navigate if needed.
    await _speak(response.text, lang);

    if (!mounted) return;

    if (response.navigateTo != null && widget.onNavigateTo != null) {
      final target = response.navigateTo!;
      final editProductId = response.editProductId;
      final callback = widget.onNavigateTo!;
      Navigator.of(context).pop();
      // Let the pop animation finish first.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => callback(target, editProductId: editProductId));
    }
  }

  Future<void> _speak(String text, AppLanguage lang) async {
    try {
      await TTSService.speak(text: text, languageCode: lang.sarvamCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('ai_assistant_audio_error_message'),
            content: Text('${ref.read(trProvider)('audioErrorPrefix')}: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _stopListeningAndTranscribe();
      return;
    }

    final tr = ref.read(trProvider);

    if (!_recorderReady) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            key: const Key('ai_assistant_mic_permission_denied_message'),
            content: Text(tr('micPermissionDenied')),
          ));
        }
        return;
      }
      await _recorder.openRecorder();
      if (mounted) setState(() => _recorderReady = true);
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/ks_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: _recordingPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    if (mounted) setState(() => _listening = true);
  }

  Future<void> _stopListeningAndTranscribe() async {
    final path = await _recorder.stopRecorder();

    if (mounted) {
      setState(() {
        _listening = false;
        _transcribing = path != null;
      });
    }

    if (path == null) return;

    final lang = ref.read(languageProvider);
    final sarvam = ref.read(sarvamServiceProvider);

    final result = await sarvam.speechToText(
      audioFile: File(path),
      languageCode: lang.sarvamCode,
    );

    if (!mounted) return;
    if (mounted) setState(() => _transcribing = false);

    if (result == null || result.transcript.isEmpty) {
      final tr = ref.read(trProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const Key('ai_assistant_voice_not_captured_message'),
        content: Text(tr('voiceNotCaptured')),
      ));
      return;
    }

    await _send(result.transcript);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final messages = ref.watch(chatMessagesProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                tr('aiAssistant'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PopupMenuButton<double>(
                key: const Key('ai_assistant_speed_button'),
                tooltip: tr('speechSpeedTooltip'),
                icon: const Icon(Icons.speed),
                initialValue: _speechRate,
                onSelected: (rate) async {
                  await TTSService.setSpeechRate(rate);
                  if (mounted) setState(() => _speechRate = rate);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: TTSService.slowSpeechRate,
                    child: Text(tr('speedSlow')),
                  ),
                  PopupMenuItem(
                    value: TTSService.defaultSpeechRate,
                    child: Text(tr('speedNormal')),
                  ),
                  PopupMenuItem(
                    value: TTSService.fastSpeechRate,
                    child: Text(tr('speedFast')),
                  ),
                ],
              ),
              IconButton(
                key: const Key('ai_assistant_close_button'),
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
              itemCount: messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == messages.length) {
                  return const _Typing(
                      key: Key('ai_assistant_typing_indicator'));
                }
                final m = messages[i];
                return Align(
                  key: ValueKey('ai_assistant_response_text_$i'),
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
                    child: SelectableText(
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
          if (_transcribing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                tr('listening'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('ai_assistant_input_field'),
                      controller: _input,
                      decoration: InputDecoration(hintText: tr('typeMessage')),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send takes the trailing slot whenever there's typed
                  // text; mic only shows when the field is empty.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (_, value, __) {
                      if (value.text.trim().isNotEmpty) {
                        return IconButton(
                          key: const Key('ai_assistant_send_button'),
                          onPressed: () => _send(),
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                          ),
                        );
                      }
                      return VoiceButton(
                        key: const Key('ai_assistant_voice_button'),
                        size: 48,
                        listening: _listening,
                        onTap: _toggleVoice,
                      );
                    },
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
  const _Typing({super.key});

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
