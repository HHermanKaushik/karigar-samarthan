import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'woocommerce_service.dart';

// ─── System knowledge ────────────────────────────────────────────────────────

const _appKnowledge = '''
Karigar Samarthan app screens and features:
- Home screen: shows listed products. Big "Add Product" card opens the photo+AI flow.
- Orders (receipt icon): list of customer orders with status, address, phone.
- Profile (person icon): name, store, phone, payment setup, language switch, logout.
- Help & Support: call support or ask AI, plus FAQ.
- Add Product flow: photo → AI suggests title/category/description → review → price + qty → Publish.

You can navigate the user to any screen by calling navigate_to.
You can mark an order as shipped by calling mark_order_shipped — first ask for the
tracking number and carrier if the user hasn't provided them.

Keep replies SHORT and step-by-step — many users are not tech-savvy or may be visually impaired.
''';

// ─── Response types ──────────────────────────────────────────────────────────

/// What screen the AI wants to open. Matches the string values passed to
/// the onNavigateTo callback in AiAssistantScreen.
enum NavigateTarget { orders, addProduct, profile, help }

class AssistantResponse {
  final String text;
  final NavigateTarget? navigateTo;
  final bool? shippingUpdated;

  const AssistantResponse({
    required this.text,
    this.navigateTo,
    this.shippingUpdated,
  });
}

// ─── Tool execution result (internal) ────────────────────────────────────────

class _ToolOutcome {
  final Map<String, Object?> data;
  final NavigateTarget? navigateTo;
  final bool? shippingUpdated;

  _ToolOutcome({required this.data, this.navigateTo, this.shippingUpdated});
}

// ─── Agent session ───────────────────────────────────────────────────────────

/// A stateful chat session with Gemini + WooCommerce tool execution.
/// Create once per assistant screen open; discard on close.
class AgentSession {
  final ChatSession _chat;
  final WooCommerceService _woo;

  AgentSession._(this._chat, this._woo);

  Future<AssistantResponse> send(String message) async {
    try {
      var geminiResponse =
          await _chat.sendMessage(Content.text(message));

      NavigateTarget? navigateTo;
      bool? shippingUpdated;

      // Process function-call turns until the model returns a text response.
      while (geminiResponse.candidates.isNotEmpty) {
        final calls = geminiResponse.candidates.first.content.parts
            .whereType<FunctionCall>()
            .toList();
        if (calls.isEmpty) break;

        for (final call in calls) {
          final outcome = await _executeTool(call.name, call.args);
          navigateTo ??= outcome.navigateTo;
          shippingUpdated ??= outcome.shippingUpdated;
          geminiResponse = await _chat.sendMessage(
            Content.functionResponse(call.name, outcome.data),
          );
        }
      }

      return AssistantResponse(
        text: geminiResponse.text ?? '',
        navigateTo: navigateTo,
        shippingUpdated: shippingUpdated,
      );
    } catch (e) {
      return const AssistantResponse(
          text: 'Sorry, I had a problem. Please try again.');
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

// ─── Tools declaration ───────────────────────────────────────────────────────

final _tools = [
  Tool(functionDeclarations: [
    FunctionDeclaration(
      'navigate_to',
      'Open a screen or feature in the Karigar Samarthan app for the user. '
          'Call this when the user asks to see their orders, add a product, '
          'view their profile, or get help.',
      Schema.object(
        properties: {
          'screen': Schema.enumString(
            enumValues: ['orders', 'addProduct', 'profile', 'help'],
            description: 'Which screen to open.',
          ),
        },
        requiredProperties: ['screen'],
      ),
    ),
    FunctionDeclaration(
      'mark_order_shipped',
      'Mark a customer order as shipped by recording the tracking number '
          'and carrier, and notifying the customer. Ask the user for the '
          'tracking number and carrier if they have not yet provided them.',
      Schema.object(
        properties: {
          'order_id': Schema.string(
              description: 'The order ID (e.g. "42").'),
          'tracking_number': Schema.string(
              description: 'The shipping tracking number.'),
          'carrier': Schema.string(
              description:
                  'Carrier name, e.g. India Post, DTDC, BlueDart, Delhivery.'),
        },
        requiredProperties: ['order_id', 'tracking_number', 'carrier'],
      ),
    ),
  ]),
];

// ─── Service ──────────────────────────────────────────────────────────────────

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
    final systemPrompt = '''
You are a voice-first AI assistant helping an Indian artisan (Karigar) use the
Karigar Samarthan seller app.

$_appKnowledge

Current account data (use naturally, do not read it out):
$accountContext

Reply ONLY in the user's language (BCP-47 code: $languageCode).
If the user's message is in a different script, still reply in $languageCode.
Keep answers short and conversational — this is a voice interface.
''';

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      tools: _tools,
      systemInstruction: Content.system(systemPrompt),
    );

    return AgentSession._(model.startChat(), woo);
  }

  @override
  Future<AiProductSuggestion> analyzeProduct({
    required List<String> imagePaths,
    required String voiceTranscript,
    required String languageCode,
  }) async {
    try {
      const prompt = '''
You are helping an Indian artisan create an ecommerce product listing.

IMPORTANT:
Return ONLY valid JSON. Do NOT include markdown. Do NOT include explanation.

JSON FORMAT:
{
  "title": "...",
  "category": "...",
  "description": "...",
  "tags": ["...", "..."]
}

Rules:
- title must be SHORT — only the product name
- category should be ecommerce-friendly
- description should sound professional (2-3 sentences)
- tags should be simple search keywords

Artisan description:
''';

      final response = await _dio.post(
        _restUrl,
        data: {
          "contents": [
            {
              "parts": [
                {"text": '$prompt\n$voiceTranscript'}
              ]
            }
          ]
        },
      );

      final raw =
          response.data['candidates'][0]['content']['parts'][0]['text'] as String;
      final cleaned =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      return AiProductSuggestion(
        title: json['title'] ?? 'Handmade Product',
        category: json['category'] ?? 'Handicrafts',
        description: json['description'] ?? voiceTranscript,
        tags: List<String>.from(json['tags'] ?? []),
      );
    } catch (e) {
      return AiProductSuggestion(
        title: 'Handmade Product',
        category: 'Handicrafts',
        description: voiceTranscript,
        tags: ['artisan'],
      );
    }
  }
}
