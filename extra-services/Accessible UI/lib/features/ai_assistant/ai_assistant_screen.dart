import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/voice_button.dart';
import '../../models/app_language.dart';
import '../../providers/language_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/translations_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/service_providers.dart';

class _ChatMessage {
  final String text;
  final bool fromAi;
  final DateTime at;
  _ChatMessage(this.text, this.fromAi) : at = DateTime.now();
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  /// Called after the AI modal closes when the model invokes navigate_to.
  /// If null, navigation tool calls are handled as text only.
  final void Function(NavigateTarget)? onNavigateTo;

  const AiAssistantScreen({super.key, this.onNavigateTo});

  @override
  ConsumerState<AiAssistantScreen> createState() => _State();
}

class _State extends ConsumerState<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = FlutterSoundRecorder();
  final _player = AudioPlayer();

  bool _recorderReady = false;
  String? _recordingPath;

  late List<_ChatMessage> _messages;
  AgentSession? _session;

  bool _sending = false;
  bool _listening = false;
  bool _transcribing = false;

  @override
  void initState() {
    super.initState();
    final tr = ref.read(trProvider);
    _messages = [_ChatMessage(tr('aiGreeting'), true)];
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    await _recorder.openRecorder();
    if (mounted) setState(() => _recorderReady = true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  // Session is created lazily on first send so Firestore-backed providers
  // (products, orders) have time to finish loading.
  AgentSession _getSession() {
    if (_session != null) return _session!;
    final ai = ref.read(aiAssistantServiceProvider);
    final woo = ref.read(wooServiceProvider);
    final lang = ref.read(languageProvider);
    _session = ai.createSession(
      accountContext: _buildAccountContext(),
      languageCode: lang.code,
      woo: woo,
    );
    return _session!;
  }

  String _buildAccountContext() {
    final user = ref.read(userProvider);
    final products = ref.read(productsProvider);
    final orders = ref.read(ordersProvider);

    final productLines = products.isEmpty
        ? '- (none yet)'
        : products
            .map((p) =>
                '- "${p.title}" (${p.category}): price ₹${p.price.toStringAsFixed(0)}, qty ${p.quantity}${p.wooId != null ? ', wooId ${p.wooId}' : ''}')
            .join('\n');

    final orderLines = orders.isEmpty
        ? '- (none yet)'
        : orders
            .map((o) =>
                '- Order #${o.id}: "${o.productTitle}" ×${o.quantity}, ₹${o.total.toStringAsFixed(0)}, status: ${o.status.name}, customer: ${o.customerName}')
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

    setState(() {
      _messages.add(_ChatMessage(content, false));
      _input.clear();
      _sending = true;
    });
    _scrollToBottom();

    final lang = ref.read(languageProvider);
    final response = await _getSession().send(content);

    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(response.text, true));
      _sending = false;
    });
    _scrollToBottom();

    // Speak the response first, then navigate if needed.
    await _speak(response.text, lang);

    if (!mounted) return;

    if (response.navigateTo != null && widget.onNavigateTo != null) {
      final target = response.navigateTo!;
      final callback = widget.onNavigateTo!;
      Navigator.of(context).pop();
      // Let the pop animation finish before opening the next modal.
      WidgetsBinding.instance.addPostFrameCallback((_) => callback(target));
    }
  }

  Future<void> _speak(String text, AppLanguage lang) async {
    final sarvam = ref.read(sarvamServiceProvider);
    final audioBytes = await sarvam.textToSpeech(
      text: text,
      languageCode: lang.sarvamCode,
    );
    if (audioBytes == null || !mounted) return;
    try {
      await _player.stop();
      await _player.play(BytesSource(audioBytes));
    } catch (_) {}
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _stopListeningAndTranscribe();
      return;
    }

    if (!_recorderReady) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is needed for voice input'),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sorry, I didn't catch that. Please try again."),
      ));
      return;
    }

    await _send(result.transcript);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
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
                    fontSize: 20, fontWeight: FontWeight.w700),
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
                if (i == _messages.length) return const _Typing();
                final m = _messages[i];
                return Align(
                  alignment: m.fromAi
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: m.fromAi
                          ? AppColors.surface
                          : AppColors.primary,
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
          if (_transcribing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(tr('listening'),
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration:
                          InputDecoration(hintText: tr('typeMessage')),
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
              child:
                  CircleAvatar(radius: 4, backgroundColor: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
