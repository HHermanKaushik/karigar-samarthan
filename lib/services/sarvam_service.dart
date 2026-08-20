import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'sync_logger.dart';

/// Result of a Sarvam speech-to-text request.
class SttResult {
  final String transcript;
  final String? languageCode;

  const SttResult({required this.transcript, this.languageCode});
}

/// Thin wrapper around Sarvam AI's STT/TTS REST APIs (https://api.sarvam.ai).
///
/// - STT: POST /speech-to-text (multipart, model `saaras:v3`)
/// - TTS: POST /text-to-speech (JSON, model `bulbul:v3`) - base64 WAV
///
/// Auth: `api-subscription-key` header, read from SARVAM_API_KEY in .env.
class SarvamService {
  final Dio _dio;
  final SyncLogger _logger;

  SarvamService({SyncLogger? logger})
      : _logger = logger ?? SyncLogger(),
        _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.sarvam.ai',
            connectTimeout: const Duration(seconds: 30),
            // TTS/STT responses (esp. audio) can take a little longer.
            receiveTimeout: const Duration(seconds: 60),
          ),
        );

  String get _apiKey => dotenv.env['SARVAM_API_KEY'] ?? '';

  /// Transcribes [audioFile] into text. [languageCode] is a Sarvam BCP-47
  /// code (see [AppLanguage.sarvamCode]). Returns `null` on failure.
  Future<SttResult?> speechToText({
    required File audioFile,
    required String languageCode,
  }) async {
    if (_apiKey.isEmpty) {
      await _logger.logError(
        'sarvam_stt',
        'Missing SARVAM_API_KEY in .env',
      );
      return null;
    }

    try {
      final formData = FormData.fromMap({
        'model': 'saaras:v3',
        'mode': 'transcribe',
        'language_code': languageCode,
        'file': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'speech.wav',
        ),
      });

      final response = await _dio.post(
        '/speech-to-text',
        data: formData,
        options: Options(headers: {'api-subscription-key': _apiKey}),
      );

      final transcript = (response.data['transcript'] as String?)?.trim();

      if (transcript == null || transcript.isEmpty) {
        return null;
      }

      return SttResult(
        transcript: transcript,
        languageCode: response.data['language_code'] as String?,
      );
    } catch (e, st) {
      await _logger.logError(
        'sarvam_stt',
        e,
        stackTrace: st,
        context: {'languageCode': languageCode},
      );
      return null;
    }
  }

  /// Translates [text] from [sourceLanguageCode] to [targetLanguageCode],
  /// or `null` on failure. For dynamic content only - static UI strings
  /// use [AppStrings.t] via trProvider.
  Future<String?> translateText({
    required String text,
    required String targetLanguageCode,
    String sourceLanguageCode = 'en-IN',
  }) async {
    if (_apiKey.isEmpty || text.trim().isEmpty) return null;
    if (sourceLanguageCode == targetLanguageCode) return text;

    try {
      final response = await _dio.post(
        '/translate',
        data: {
          'input': text.trim(),
          'source_language_code': sourceLanguageCode,
          'target_language_code': targetLanguageCode,
          'speaker_gender': 'Female',
          'mode': 'classic-colloquial',
        },
        options: Options(headers: {'api-subscription-key': _apiKey}),
      );

      return response.data['translated_text'] as String?;
    } catch (e, st) {
      await _logger.logError(
        'sarvam_translate',
        e,
        stackTrace: st,
        context: {
          'source': sourceLanguageCode,
          'target': targetLanguageCode,
        },
      );
      return null;
    }
  }

  /// Converts [text] to WAV audio bytes, or `null` on failure.
  /// [languageCode] is a Sarvam BCP-47 code. [pace] is bulbul:v3's speed,
  /// 0.5-2.0, 1.0 = normal.
  Future<Uint8List?> textToSpeech({
    required String text,
    required String languageCode,
    String speaker = 'kavya',
    double pace = 1.0,
  }) async {
    if (_apiKey.isEmpty) {
      await _logger.logError(
        'sarvam_tts',
        'Missing SARVAM_API_KEY in .env',
      );
      return null;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    try {
      // bulbul:v3 supports a maximum of 2500 characters per request.
      final clipped =
          trimmed.length > 2500 ? trimmed.substring(0, 2500) : trimmed;

      final response = await _dio.post(
        '/text-to-speech',
        data: {
          'text': clipped,
          'target_language_code': languageCode,
          'speaker': speaker,
          'model': 'bulbul:v3',
          'pace': pace,
        },
        options: Options(headers: {'api-subscription-key': _apiKey}),
      );

      // Sarvam sometimes sends text/plain instead of JSON - decode manually.
      final raw = response.data;
      final Map<String, dynamic>? body = raw is Map
          ? raw.cast()
          : (raw is String ? (jsonDecode(raw) as Map?)?.cast() : null);

      final audios = body?['audios'] as List?;
      if (audios == null || audios.isEmpty) {
        debugPrint('SarvamTTS: response missing "audios" field — body=$body');
        return null;
      }

      return base64Decode(audios.first as String);
    } catch (e, st) {
      await _logger.logError(
        'sarvam_tts',
        e,
        stackTrace: st,
        context: {'languageCode': languageCode},
      );
      return null;
    }
  }
}
