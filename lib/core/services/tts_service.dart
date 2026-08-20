import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/sarvam_service.dart';

/// Speaks text aloud, preferring Sarvam TTS (voice "kavya") and falling
/// back to the device's native TTS if Sarvam errors - callers don't need
/// to know which one spoke.
class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static final AudioPlayer _sarvamPlayer = AudioPlayer();
  static SarvamService? _sarvam;
  static SarvamService get _sarvamService => _sarvam ??= SarvamService();

  static const String _sarvamSpeaker = 'kavya';

  static const double defaultSpeechRate = 0.45;
  static const double slowSpeechRate = 0.3;
  static const double fastSpeechRate = 0.6;
  static const _speedKey = 'tts_speech_rate';

  /// Persisted per-device - lets a karigar slow down the voice once and
  /// have it stick.
  static Future<double> getSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_speedKey) ?? defaultSpeechRate;
  }

  static Future<void> setSpeechRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speedKey, rate);
  }

  /// Maps slow/normal/fast to Sarvam's `pace` param (0.5-2.0) - a
  /// different scale from flutter_tts's own rate units.
  static double _sarvamPace(double flutterRate) {
    if (flutterRate <= slowSpeechRate) return 0.75;
    if (flutterRate >= fastSpeechRate) return 1.3;
    return 1.0;
  }

  static Future<void> speak({
    required String text,
    required String languageCode,
    void Function()? onComplete,
  }) async {
    await stop();
    final rate = await getSpeechRate();

    if (await _speakViaSarvam(text, languageCode, rate, onComplete)) return;

    // Sarvam unavailable - fall back to native TTS.
    _tts.setCompletionHandler(onComplete ?? () {});
    // Otherwise speak()'s Future resolves on playback start, not finish.
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(languageCode);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(1.1);
    await _tts.speak(text);
  }

  /// True if Sarvam spoke the text ([onComplete] already called) - false
  /// means fall back.
  static Future<bool> _speakViaSarvam(
    String text,
    String languageCode,
    double rate,
    void Function()? onComplete,
  ) async {
    try {
      final audio = await _sarvamService.textToSpeech(
        text: text,
        languageCode: languageCode,
        speaker: _sarvamSpeaker,
        pace: _sarvamPace(rate),
      );
      if (audio == null || audio.isEmpty) return false;

      final completer = Completer<void>();
      late final StreamSubscription<void> sub;
      sub = _sarvamPlayer.onPlayerComplete.listen((_) {
        sub.cancel();
        if (!completer.isCompleted) completer.complete();
      });
      await _sarvamPlayer.play(BytesSource(audio));
      await completer.future;
      onComplete?.call();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    await _sarvamPlayer.stop();
    await _tts.stop();
  }
}
