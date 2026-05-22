import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiProductSuggestion {
  final String title;
  final String category;
  final String description;
  final List<String> tags;

  const AiProductSuggestion({
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
  });
}

abstract class AiAssistantService {
  Future<String> chat({
    required String message,
    required String languageCode,
  });

  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  });
}

class GeminiAiAssistantService implements AiAssistantService {
  final Dio _dio = Dio();

  String get _apiKey => dotenv.env['GENAI_API_KEY'] ?? '';

  String get _url =>
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  @override
  Future<String> chat({
    required String message,
    required String languageCode,
  }) async {
    try {
      final prompt = '''
You are an AI assistant helping Indian artisans manage products and online selling.

Reply ONLY in language code: $languageCode

User:
$message
''';

      final response = await _dio.post(
        _url,
        data: {
          "contents": [
            {
              "parts": [
                {
                  "text": prompt,
                }
              ]
            }
          ]
        },
      );

      return response.data['candidates'][0]['content']['parts'][0]['text'];
    } catch (e) {
      print(e);
      return 'AI Service unavailable';
    }
  }

  @override
  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  }) async {
    try {
      final prompt = '''
You are helping an Indian artisan create an ecommerce product listing.

IMPORTANT:
Return ONLY valid JSON.
Do NOT include markdown.
Do NOT include explanation text.

JSON FORMAT:
{
  "title": "...",
  "category": "...",
  "description": "...",
  "tags": ["...", "..."]
}

Rules:
- title must be SHORT
- title must be only the product name
- do NOT say "here is"
- do NOT explain
- category should be ecommerce-friendly
- description should sound professional
- tags should be simple search keywords

Artisan description:
$voiceTranscript
''';

      final response = await _dio.post(
        _url,
        data: {
          "contents": [
            {
              "parts": [
                {
                  "text": prompt,
                }
              ]
            }
          ]
        },
      );

      final raw = response.data['candidates'][0]['content']['parts'][0]['text'];

      print(raw);

      final cleaned =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();

      final jsonData = jsonDecode(cleaned);

      return AiProductSuggestion(
        title: jsonData['title'] ?? 'Handmade Product',
        category: jsonData['category'] ?? 'Handicrafts',
        description: jsonData['description'] ?? voiceTranscript,
        tags: List<String>.from(jsonData['tags'] ?? []),
      );
    } catch (e) {
      print('========== AI ANALYZE ERROR ==========');
      print(e);
      print('======================================');

      return AiProductSuggestion(
        title: 'Handmade Product',
        category: 'Handicrafts',
        description: voiceTranscript,
        tags: ['artisan'],
      );
    }
  }
}
