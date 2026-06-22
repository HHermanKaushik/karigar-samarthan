import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'ai_assistant_service.dart';
import 'sarvam_service.dart';
import 'sync_logger.dart';
import 'user_sync_service.dart';
import 'woocommerce_service.dart';

final aiAssistantServiceProvider = Provider<AiAssistantService>((ref) {
  return GeminiAiAssistantService();
});

final syncLoggerProvider = Provider<SyncLogger>((ref) {
  return SyncLogger();
});

final wooServiceProvider = Provider<WooCommerceService>((ref) {
  return WooCommerceService(logger: ref.read(syncLoggerProvider));
});

final userSyncServiceProvider = Provider<UserSyncService>((ref) {
  return UserSyncService(logger: ref.read(syncLoggerProvider));
});

final sarvamServiceProvider = Provider<SarvamService>((ref) {
  return SarvamService(logger: ref.read(syncLoggerProvider));
});

final speechToTextProvider = Provider<stt.SpeechToText>((ref) {
  return stt.SpeechToText();
});

final flutterTtsProvider = Provider<FlutterTts>((ref) {
  return FlutterTts();
});
