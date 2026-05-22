import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'ai_assistant_service.dart';
import 'woocommerce_service.dart';

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return GeminiAiAssistantService();
});

final wooServiceProvider = Provider<WooCommerceService>((ref) {
  return WooCommerceService();
});

final speechToTextProvider = Provider<stt.SpeechToText>((ref) {
  return stt.SpeechToText();
});

final flutterTtsProvider = Provider<FlutterTts>((ref) {
  return FlutterTts();
});
