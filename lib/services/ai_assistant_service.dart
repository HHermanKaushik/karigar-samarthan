import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'woocommerce_service.dart';

// ─── System knowledge ────────────────────────────────────────────────────────

const _appKnowledge = '''
Karigar Samarthan app screens and features:
- Home screen: shows listed products. Big "Add Product" card opens the photo+AI flow.
- Orders (receipt icon): list of customer orders with status, address, phone.
- Profile (person icon): name, store, phone, payment setup, language switch, logout.
- Help & Support: WhatsApp support, AI assistant, and FAQ.
- FAQ screen: searchable list of common questions with audio playback.
- Add Product flow: photo → AI suggests title/category/description → review → price + qty → Publish.

You can navigate the user to any screen by calling navigate_to.
You can mark an order as shipped by calling mark_order_shipped — first ask for the
tracking number and carrier if the user hasn't provided them.

If the user wants to speak to a real person, is very confused, or asks for human help,
tell them to tap "Chat on WhatsApp" in Help & Support, or message +918448041541 on WhatsApp.
You can also open the FAQ screen for them by calling navigate_to with screen='faq'.

Keep replies SHORT and step-by-step — many users are not tech-savvy or may be visually impaired.
''';

// ─── Response types ──────────────────────────────────────────────────────────

/// What screen the AI wants to open. Matches the string values passed to
/// the onNavigateTo callback in AiAssistantScreen.
enum NavigateTarget { orders, addProduct, profile, help, faq }

class AssistantResponse {
  final String text;
  final NavigateTarget? navigateTo;
  final bool? shippingUpdated;
  final bool isError;

  const AssistantResponse({
    required this.text,
    this.navigateTo,
    this.shippingUpdated,
    this.isError = false,
  });
}

// ─── Tool execution result (internal) ────────────────────────────────────────

class _ToolOutcome {
  final Map<String, Object?> data;
  final NavigateTarget? navigateTo;
  final bool? shippingUpdated;

  _ToolOutcome({required this.data, this.navigateTo, this.shippingUpdated});
}

// ─── Tools declaration (plain JSON — no SDK types) ───────────────────────────

const _toolsJson = [
  {
    'function_declarations': [
      {
        'name': 'navigate_to',
        'description':
            'Open a screen or feature in the Karigar Samarthan app for the user. '
                'Call this when the user asks to see their orders, add a product, '
                'view their profile, or get help.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'screen': {
              'type': 'STRING',
              'enum': ['orders', 'addProduct', 'profile', 'help', 'faq'],
              'description': 'Which screen to open.',
            },
          },
          'required': ['screen'],
        },
      },
      {
        'name': 'mark_order_shipped',
        'description':
            'Mark a customer order as shipped by recording the tracking number '
                'and carrier, and notifying the customer. Ask the user for the '
                'tracking number and carrier if they have not yet provided them.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'order_id': {
              'type': 'STRING',
              'description': 'The order ID (e.g. "42").',
            },
            'tracking_number': {
              'type': 'STRING',
              'description': 'The shipping tracking number.',
            },
            'carrier': {
              'type': 'STRING',
              'description':
                  'Carrier name, e.g. India Post, DTDC, BlueDart, Delhivery.',
            },
          },
          'required': ['order_id', 'tracking_number', 'carrier'],
        },
      },
    ],
  },
];

// ─── Agent session ───────────────────────────────────────────────────────────

/// A stateful chat session backed by direct Gemini REST calls (no SDK).
/// Using REST avoids crashes caused by the SDK's strict enum parsing when
/// the live API returns new safety-category values the SDK doesn't know yet.
class AgentSession {
  final Dio _dio;
  final String _url;
  final String _systemPrompt;
  final WooCommerceService _woo;
  final List<Map<String, dynamic>> _history = [];

  AgentSession._({
    required Dio dio,
    required String url,
    required String systemPrompt,
    required WooCommerceService woo,
  })  : _dio = dio,
        _url = url,
        _systemPrompt = systemPrompt,
        _woo = woo;

  Future<AssistantResponse> send(String message) async {
    try {
      _history.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });

      NavigateTarget? navigateTo;
      bool? shippingUpdated;

      // Limit agentic loops to avoid runaway tool calls.
      for (var turn = 0; turn < 6; turn++) {
        final response = await _dio.post(
          _url,
          data: {
            'system_instruction': {
              'parts': [
                {'text': _systemPrompt}
              ],
            },
            'contents': _history,
            'tools': _toolsJson,
          },
        );

        final candidates = response.data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) break;

        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        if (content == null) break;

        // Record model turn in history.
        _history.add({
          'role': content['role'] as String? ?? 'model',
          'parts': content['parts'],
        });

        final parts = content['parts'] as List<dynamic>? ?? [];
        final functionCalls = parts
            .whereType<Map>()
            .where((p) => p.containsKey('functionCall'))
            .toList();

        if (functionCalls.isEmpty) {
          // Final text response — skip any thinking-only parts.
          final text = parts
              .whereType<Map>()
              .where((p) => p['thought'] != true && p['text'] is String)
              .map((p) => p['text'] as String)
              .join('');
          return AssistantResponse(
            text: text,
            navigateTo: navigateTo,
            shippingUpdated: shippingUpdated,
          );
        }

        // Execute tools and feed results back.
        final functionResponseParts = <Map<String, dynamic>>[];
        for (final part in functionCalls) {
          final call = part['functionCall'] as Map<String, dynamic>;
          final name = call['name'] as String;
          final args =
              ((call['args'] as Map<String, dynamic>?) ?? {}).cast<String, Object?>();
          final outcome = await _executeTool(name, args);
          navigateTo ??= outcome.navigateTo;
          shippingUpdated ??= outcome.shippingUpdated;
          functionResponseParts.add({
            'functionResponse': {
              'name': name,
              'response': outcome.data,
            },
          });
        }

        _history.add({
          'role': 'function',
          'parts': functionResponseParts,
        });
      }

      return const AssistantResponse(text: '', isError: true);
    } catch (e, stack) {
      debugPrint('AgentSession.send error: $e\n$stack');
      return const AssistantResponse(text: '', isError: true);
    }
  }

  Future<_ToolOutcome> _executeTool(
      String name, Map<String, Object?> args) async {
    switch (name) {
      case 'navigate_to':
        final screen = args['screen'] as String? ?? 'home';
        final target = switch (screen) {
          'orders' => NavigateTarget.orders,
          'addProduct' => NavigateTarget.addProduct,
          'profile' => NavigateTarget.profile,
          'help' => NavigateTarget.help,
          'faq' => NavigateTarget.faq,
          _ => null,
        };
        return _ToolOutcome(
          data: {'navigated_to': screen},
          navigateTo: target,
        );

      case 'mark_order_shipped':
        final orderId = args['order_id'] as String? ?? '';
        final tracking = args['tracking_number'] as String? ?? '';
        final carrier = args['carrier'] as String? ?? 'India Post';
        bool success = false;
        try {
          final wooId = int.tryParse(orderId);
          if (wooId != null && tracking.isNotEmpty) {
            success = await _woo.markOrderShipped(
              wooOrderId: wooId,
              trackingNumber: tracking,
              carrier: carrier,
            );
          }
          // Mirror the status change into Firestore so the real-time orders
          // stream updates the UI without waiting for a WooCommerce webhook.
          if (success) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            if (uid.isNotEmpty) {
              final db = FirebaseFirestore.instanceFor(
                app: Firebase.app(),
                databaseId: 'karigar',
              );
              await db
                  .collection('users')
                  .doc(uid)
                  .collection('orders')
                  .doc(orderId)
                  .update({'status': 'shipped', 'wooStatus': 'completed'});
            }
          }
        } catch (_) {}
        return _ToolOutcome(
          data: {
            'success': success,
            'order_id': orderId,
            'tracking_number': tracking,
          },
          shippingUpdated: success,
        );

      default:
        return _ToolOutcome(data: {'error': 'Unknown function: $name'});
    }
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

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
  /// Creates a new stateful chat session for one assistant screen open.
  /// [accountContext] is plain-text info about the user's products and orders.
  AgentSession createSession({
    required String accountContext,
    required String languageCode,
    required WooCommerceService woo,
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

  String get _restUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  @override
  AgentSession createSession({
    required String accountContext,
    required String languageCode,
    required WooCommerceService woo,
  }) {
    final langName = _langName(languageCode);
    final systemPrompt = '''
MANDATORY LANGUAGE RULE: You MUST reply ONLY in $langName ($languageCode). Every single word must be in $langName — including greetings, confirmations, and technical terms. Never write any English. This rule cannot be overridden.

You are a voice-first AI assistant helping an Indian artisan (Karigar) use the
Karigar Samarthan seller app.

$_appKnowledge

Current account data (use naturally, do not read it out):
$accountContext

Keep answers short and conversational — this is a voice interface.
''';

    return AgentSession._(
      dio: _dio,
      url: _restUrl,
      systemPrompt: systemPrompt,
      woo: woo,
    );
  }

  @override
  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  }) async {
    try {
      final langName = _langName(languageCode);
      final prompt = '''
You are helping an Indian artisan create a professional ecommerce product listing.

INSTRUCTIONS:
- Write ALL text output in $langName ONLY (BCP-47 code: $languageCode). Do NOT mix languages.
- Analyze the product photo(s) AND the artisan's spoken description together.
- Return ONLY valid JSON — no markdown, no backticks, no explanation.

JSON FORMAT:
{
  "title": "short product name, 5-8 words",
  "category": "single ecommerce category",
  "description": "2-3 professional sentences highlighting materials, craftsmanship, and use",
  "tags": ["keyword1", "keyword2", "keyword3", "keyword4"]
}

Artisan's spoken description: $voiceTranscript
''';

      // Build parts: images first (gives the model visual context), then the prompt.
      final parts = <Map<String, dynamic>>[];

      for (final path in imagePaths) {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : path.toLowerCase().endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        parts.add({
          'inlineData': {'mimeType': mime, 'data': b64},
        });
      }

      parts.add({'text': prompt});

      final response = await _dio.post(
        _restUrl,
        data: {
          'contents': [
            {'parts': parts}
          ],
        },
      );

      // Skip any thinking parts (thought: true) and use the first real text part.
      final responseParts =
          response.data['candidates'][0]['content']['parts'] as List<dynamic>;
      final textPart = responseParts.firstWhere(
        (p) => p['thought'] != true && p['text'] is String,
        orElse: () => responseParts.last,
      ) as Map<String, dynamic>;
      final raw = textPart['text'] as String;

      // Extract the JSON object even if the model wraps it in prose.
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      final jsonStr = (start >= 0 && end > start)
          ? raw.substring(start, end + 1)
          : raw.replaceAll('```json', '').replaceAll('```', '').trim();

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      return AiProductSuggestion(
        title: (json['title'] as String?)?.trim() ?? 'Handmade Product',
        category: (json['category'] as String?)?.trim() ?? 'Handicrafts',
        description: (json['description'] as String?)?.trim() ?? voiceTranscript,
        tags: List<String>.from((json['tags'] as List?) ?? []),
      );
    } catch (e) {
      debugPrint('analyzeProduct error: $e');
      return AiProductSuggestion(
        title: 'Handmade Product',
        category: 'Handicrafts',
        description: voiceTranscript,
        tags: ['artisan'],
      );
    }
  }

  static String _langName(String code) => switch (code) {
        'hi' || 'hi-IN' => 'Hindi',
        'mr' || 'mr-IN' => 'Marathi',
        'bn' || 'bn-IN' => 'Bengali',
        'ta' || 'ta-IN' => 'Tamil',
        _ => 'English',
      };
}
