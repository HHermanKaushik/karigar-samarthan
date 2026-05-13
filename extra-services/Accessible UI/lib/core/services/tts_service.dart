import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    await _tts.stop();

    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}
