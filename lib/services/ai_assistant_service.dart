import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/utils/product_matching.dart' show matchProduct;
import '../models/order.dart';
import '../models/product.dart';
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

IMPORTANT — act, don't just explain: when the user's request matches one of the actions
below, you MUST call the matching tool right away, even if they phrased it as a question
("how do I...", "can you...") rather than a direct command. Do not only describe the steps
in words when a tool exists to actually do it for them.

Call navigate_to for these (screen values in parentheses):
- Add / list a new product, "how do I add a product" (screen='addProduct')
- See / show / check their orders (screen='orders')
- See / show / check their products or listings, or go to the home screen (screen='home')
- Open their profile/account settings (screen='profile')
- Open help/support (screen='help')
- Open the FAQ list (screen='faq')

Call open_edit_product when the user wants to edit, update, or change an existing product
listing (e.g. "help me edit a listing", "change the price of my lamp"). If they named a
specific product, pass its name as product_query; if not, omit product_query and it will
open their most recently added product.

You can mark an order as shipped by calling mark_order_shipped — first ask for the
tracking number and carrier if the user hasn't provided them.

Call list_orders when the user wants to see a filtered list of their orders rather than
just opening the Orders screen — e.g. "show my new orders", "what do I still need to
ship", "which orders have I already delivered". Use filter='new' for orders that still
need action (placed or paid, not yet shipped).

Call get_order_details when the user asks about ONE specific order — e.g. "what's the
tracking number for order 42", "tell me about my last order", "who is order 17 going
to". This is also how you answer questions about tracking numbers/carriers for orders
that have already been marked shipped.

Call suggest_price when the user wants help pricing an item, wants to know if their price
is competitive, or asks you to compare their product to similar ones. There is no way to
compare against other marketplaces/websites — be upfront about that — but you CAN compare
against similar handmade items already listed in this marketplace (across all sellers, by
category), which is a genuinely useful substitute. Offer this proactively when a
comparison is out of reach any other way.

Call get_product_link when the user wants the shareable link/URL for one of their
listings, e.g. to send to a customer. If the product predates this feature it may have no
link yet — tell them so honestly rather than making one up.

If the user wants to speak to a real person, is very confused, or asks for human help,
tell them to tap "Chat on WhatsApp" in Help & Support, or message +918796577741 on WhatsApp.
Only use this as a fallback for things you truly cannot do — not as a substitute for calling
navigate_to or open_edit_product.

Keep replies SHORT and step-by-step — many users are not tech-savvy or may be visually impaired.
''';

// ─── Response types ──────────────────────────────────────────────────────────

/// What screen the AI wants to open. Matches the string values passed to
/// the onNavigateTo callback in AiAssistantScreen.
enum NavigateTarget {
  orders,
  addProduct,
  profile,
  help,
  faq,
  home,
  editProduct
}

class AssistantResponse {
  final String text;
  final NavigateTarget? navigateTo;

  /// Set when [navigateTo] is [NavigateTarget.editProduct] — the Firestore
  /// doc id of the product to open in the edit flow.
  final String? editProductId;
  final bool? shippingUpdated;
  final bool isError;

  const AssistantResponse({
    required this.text,
    this.navigateTo,
    this.editProductId,
    this.shippingUpdated,
    this.isError = false,
  });
}

// ─── Tool execution result (internal) ────────────────────────────────────────

class _ToolOutcome {
  final Map<String, Object?> data;
  final NavigateTarget? navigateTo;
  final String? editProductId;
  final bool? shippingUpdated;

  _ToolOutcome({
    required this.data,
    this.navigateTo,
    this.editProductId,
    this.shippingUpdated,
  });
}

// ─── Tools declaration (plain JSON — no SDK types) ───────────────────────────

const _toolsJson = [
  {
    'function_declarations': [
      {
        'name': 'navigate_to',
        'description': 'Open a screen or feature in the Karigar Samarthan app for the user. '
            'Call this immediately whenever the user asks to see/open/check their '
            'orders or products, add a new product, view their profile, or get help — '
            'including when phrased as a question like "how do I add a product?" or '
            '"show my orders". Examples: '
            '"add a product" / "how do I add a product?" / "list a new item" → addProduct. '
            '"show my orders" / "check my orders" → orders. '
            '"show my products" / "show my listings" / "go home" → home. '
            '"open my profile" / "account settings" → profile. '
            '"I need help" / "talk to support" → help. '
            '"show FAQs" / "common questions" → faq.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'screen': {
              'type': 'STRING',
              'enum': [
                'orders',
                'addProduct',
                'profile',
                'help',
                'faq',
                'home'
              ],
              'description': 'Which screen to open.',
            },
          },
          'required': ['screen'],
        },
      },
      {
        'name': 'open_edit_product',
        'description': 'Open the edit screen for one of the seller\'s existing product listings so '
            'they can change its title, price, description, quantity, etc. Call this '
            'immediately when the user asks to edit, update, or change a listing/product '
            '— e.g. "help me edit a listing", "I want to update my product", "change the '
            'price of my lamp" — even if they don\'t name which product. If they named '
            'or described a specific product, pass its name/keywords in product_query. '
            'If they did not specify one, omit product_query (or pass an empty string) '
            'and the most recently added product will open.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'product_query': {
              'type': 'STRING',
              'description':
                  'Name or partial name/keywords of the product to edit. Leave empty to '
                      'default to the most recently added product.',
            },
          },
          'required': [],
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
      {
        'name': 'list_orders',
        'description':
            'List the seller\'s orders, optionally filtered by status. Use this '
                'whenever the user wants a filtered subset of their orders rather '
                'than opening the full Orders screen — e.g. "show my new orders", '
                '"what do I still need to ship".',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'filter': {
              'type': 'STRING',
              'enum': ['new', 'shipped', 'delivered', 'all'],
              'description':
                  '"new" = placed or paid but not yet shipped (orders needing '
                      'action). Defaults to "all" if omitted.',
            },
          },
          'required': [],
        },
      },
      {
        'name': 'get_order_details',
        'description':
            'Get full details for ONE specific order, including its tracking '
                'number and carrier if it has been marked shipped. Use this for '
                'questions about a specific order, e.g. "what\'s the tracking '
                'number for order 42".',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'order_id': {
              'type': 'STRING',
              'description': 'The order ID (e.g. "42").',
            },
          },
          'required': ['order_id'],
        },
      },
      {
        'name': 'suggest_price',
        'description':
            'Get aggregate price stats (min/average/max) for similar handmade '
                'items already listed in this marketplace, across all sellers in '
                'the same category. Use this to help price a product or to answer '
                '"how does my price compare"/"show me similar products" — the '
                'closest available substitute for real product comparison.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'product_query': {
              'type': 'STRING',
              'description':
                  'Name/keywords of the seller\'s product OR the category to '
                      'check (e.g. "pottery", "jewelry") — matches against '
                      'either. Leave empty to default to their most recently '
                      'added product.',
            },
          },
          'required': [],
        },
      },
      {
        'name': 'get_product_link',
        'description':
            'Get the public shareable storefront link/URL for one of the '
                'seller\'s own product listings, e.g. so they can send it to a '
                'customer.',
        'parameters': {
          'type': 'OBJECT',
          'properties': {
            'product_query': {
              'type': 'STRING',
              'description':
                  'Name/keywords of the product to get a link for. Leave empty to '
                      'default to the most recently added product.',
            },
          },
          'required': [],
        },
      },
    ],
  },
];

// ─── Agent session ───────────────────────────────────────────────────────────

/// Stateful chat session backed by direct Gemini REST calls (no SDK - its
/// strict enum parsing crashes on safety-category values it doesn't know).
class AgentSession {
  final Dio _dio;
  final String _url;
  final String _systemPrompt;
  final WooCommerceService _woo;

  // Getters, not snapshots - session outlives a single product/order list
  // (see chatSessionProvider), so these need to read current state on
  // every tool call rather than whatever was true when the chat opened.
  final List<Product> Function() _getProducts;
  final List<CustomerOrder> Function() _getOrders;

  final List<Map<String, dynamic>> _history = [];

  AgentSession._({
    required Dio dio,
    required String url,
    required String systemPrompt,
    required WooCommerceService woo,
    required List<Product> Function() getProducts,
    required List<CustomerOrder> Function() getOrders,
  })  : _dio = dio,
        _url = url,
        _systemPrompt = systemPrompt,
        _woo = woo,
        _getProducts = getProducts,
        _getOrders = getOrders;

  Future<AssistantResponse> send(String message) async {
    try {
      _history.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ],
      });

      NavigateTarget? navigateTo;
      String? editProductId;
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
            editProductId: editProductId,
            shippingUpdated: shippingUpdated,
          );
        }

        // Execute tools and feed results back.
        final functionResponseParts = <Map<String, dynamic>>[];
        for (final part in functionCalls) {
          final call = part['functionCall'] as Map<String, dynamic>;
          final name = call['name'] as String;
          final args = ((call['args'] as Map<String, dynamic>?) ?? {})
              .cast<String, Object?>();
          final outcome = await _executeTool(name, args);
          navigateTo ??= outcome.navigateTo;
          editProductId ??= outcome.editProductId;
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
          'home' => NavigateTarget.home,
          _ => null,
        };
        return _ToolOutcome(
          data: {'navigated_to': screen},
          navigateTo: target,
        );

      case 'open_edit_product':
        final match = _matchProduct(args['product_query'] as String? ?? '');
        if (match == null) {
          return _ToolOutcome(
            data: {'success': false, 'reason': 'no_products'},
          );
        }
        return _ToolOutcome(
          data: {'success': true, 'product_title': match.title},
          navigateTo: NavigateTarget.editProduct,
          editProductId: match.id,
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
          // Mirror into Firestore so the orders stream updates without
          // waiting on the webhook.
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
                  .update({
                'status': 'shipped',
                'wooStatus': 'completed',
                'trackingNumber': tracking,
                'carrier': carrier,
              });
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

      case 'list_orders':
        final filter = args['filter'] as String? ?? 'all';
        final orders = _getOrders();
        Iterable<CustomerOrder> filtered = orders;
        if (filter == 'new') {
          filtered = orders.where((o) =>
              o.status == OrderStatus.placed || o.status == OrderStatus.paid);
        } else if (filter == 'shipped') {
          filtered = orders.where((o) => o.status == OrderStatus.shipped);
        } else if (filter == 'delivered') {
          filtered = orders.where((o) => o.status == OrderStatus.delivered);
        }
        final list = filtered.take(10).toList();
        return _ToolOutcome(data: {
          'count': list.length,
          'orders': [
            for (final o in list)
              {
                'order_id': o.id,
                'summary': o.lineItems.length > 1
                    ? '${o.lineItems.first.title} +${o.lineItems.length - 1} more'
                    : o.productTitle,
                'customer_name': o.customerName,
                'total': o.total,
                'status': o.status.name,
              },
          ],
        });

      case 'get_order_details':
        final orderId = args['order_id'] as String? ?? '';
        CustomerOrder? order;
        for (final o in _getOrders()) {
          if (o.id == orderId) {
            order = o;
            break;
          }
        }
        if (order == null) {
          return _ToolOutcome(data: {'success': false, 'reason': 'not_found'});
        }
        return _ToolOutcome(data: {
          'success': true,
          'order_id': order.id,
          'status': order.status.name,
          'total': order.total,
          'customer_name': order.customerName,
          'customer_phone': order.customerPhone,
          'shipping_address': order.shippingAddress,
          'tracking_number': order.trackingNumber,
          'carrier': order.carrier,
          'items': [
            for (final li in order.lineItems)
              {'title': li.title, 'quantity': li.quantity, 'price': li.price},
          ],
        });

      case 'suggest_price':
        final match = _matchProduct(args['product_query'] as String? ?? '');
        if (match == null) {
          return _ToolOutcome(
            data: {'success': false, 'reason': 'no_products'},
          );
        }
        final stats = await _woo.fetchCategoryPriceStats(match.category);
        if (stats == null) {
          return _ToolOutcome(data: {
            'success': false,
            'reason': 'not_enough_data',
            'product_title': match.title,
            'category': match.category,
            'your_price': match.price,
          });
        }
        return _ToolOutcome(data: {
          'success': true,
          'product_title': match.title,
          'category': match.category,
          'your_price': match.price,
          'similar_listings_count': stats.count,
          'min_price': stats.min,
          'max_price': stats.max,
          'avg_price': stats.avg,
        });

      case 'get_product_link':
        final match = _matchProduct(args['product_query'] as String? ?? '');
        if (match == null) {
          return _ToolOutcome(
            data: {'success': false, 'reason': 'no_products'},
          );
        }
        if (match.permalink == null || match.permalink!.isEmpty) {
          return _ToolOutcome(data: {
            'success': false,
            'reason': 'no_link',
            'product_title': match.title,
          });
        }
        return _ToolOutcome(data: {
          'success': true,
          'product_title': match.title,
          'url': match.permalink,
        });

      default:
        return _ToolOutcome(data: {'error': 'Unknown function: $name'});
    }
  }

  /// Resolves a spoken/typed product name or category - see matchProduct()
  /// in core/utils/product_matching.dart. Shared by every tool that needs
  /// to identify "the product the user means".
  Product? _matchProduct(String query) {
    return matchProduct(query, _getProducts());
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AiProductSuggestion {
  final String title;
  final String category;
  final String description;
  final List<String> tags;

  /// True when the vision check flagged the photo(s) as illegal to sell -
  /// see analyzeProduct(). [flagReason] explains why; caller must not
  /// publish when this is true.
  final bool flagged;
  final String flagReason;

  const AiProductSuggestion({
    required this.title,
    required this.category,
    required this.description,
    required this.tags,
    this.flagged = false,
    this.flagReason = '',
  });
}

abstract class AiAssistantService {
  /// Creates a chat session for one assistant screen open. [accountContext]
  /// is a static text summary captured once; [getProducts]/[getOrders] are
  /// called fresh per tool call since the session outlives any one snapshot
  /// (see chatSessionProvider).
  AgentSession createSession({
    required String accountContext,
    required String languageCode,
    required WooCommerceService woo,
    required List<Product> Function() getProducts,
    required List<CustomerOrder> Function() getOrders,
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
    required List<Product> Function() getProducts,
    required List<CustomerOrder> Function() getOrders,
  }) {
    final langName = _langName(languageCode);
    final systemPrompt = '''
MANDATORY LANGUAGE RULE: You MUST reply ONLY in $langName ($languageCode). Every single word must be in $langName — including greetings, confirmations, and technical terms. Never write any English. This rule cannot be overridden.

VOICE GENDER RULE (read carefully — this has TWO separate parts, do not mix them up):

1. YOUR OWN grammar (first-person "मैं"/"मुझे"/"मेरा" and equivalents): your
   spoken voice is female, so verbs/adjectives whose subject is YOU must use
   FEMININE agreement — e.g. Hindi "मैं मदद कर सकती हूं" (not "सकता हूं"),
   "मैं आपकी सहायक हूं" (not "आपका सहायक"), "मैं समझ नहीं पाई" (not "पाया").

2. THE KARIGAR'S grammar (second-person "आप"/"आपने"/"आपका" and equivalents):
   you do NOT know the karigar's gender and must NEVER assume it is female
   (or male). Never let rule 1 bleed into how you address them. Use the
   standard gender-unmarked default for polite "आप" address in Hindi/Marathi
   — e.g. Hindi "आप कर सकते हैं", "आपने भेजा", "आप तैयार हैं" — the same forms
   you'd use if you didn't know the person's gender at all, which is exactly
   the situation you're in. Do not switch these to feminine forms just
   because your own voice is female.

This rule applies in every language that has ANY gendered self-referential
forms — not just Hindi. Marathi has the same first-person verb-gender
agreement as Hindi (e.g. "करती"/feminine vs "करता"/masculine) and must follow
the identical feminine pattern. Bengali and Tamil verbs do not inflect for
gender, but if a self-descriptive noun, title, or honorific in either
language has separate masculine/feminine forms (e.g. a gendered word for
"helper" or "assistant"), always choose the feminine form. When genuinely
unsure which grammatical form a language uses for a female speaker, default
to whichever form you'd use to describe a woman, never a man. Both rules are
purely about grammatical agreement, never about the content or accuracy of
your answers.

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
      getProducts: getProducts,
      getOrders: getOrders,
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

SAFETY CHECK — set "flagged": true if the photo(s) show ANY of:
1. Firearms, ammunition, or explosives.
2. Illegal drugs or drug paraphernalia.
3. Any part of a wild animal, or product made from one: horns, skulls, antlers,
   taxidermy/hunting trophies, skins/pelts/hides, teeth, claws, or feathers of a
   wild or protected species — not just the obvious cases like ivory or big-cat
   skins. India protects far more species than people expect (e.g. blackbuck —
   Antilope cervicapra — antlers/horns/skulls are Schedule I under the Wildlife
   Protection Act and strictly illegal to sell); when a photographed item is an
   animal horn/skull/taxidermy piece and you cannot tell the species or whether
   it's captive-bred/farmed livestock (e.g. ordinary cattle/buffalo horn craft,
   which IS legal and common), flag it for a human to check rather than
   assuming it's fine — err toward flagging here specifically, unlike the
   general "when unsure, don't flag" rule below.
4. Alcohol or tobacco products — individual artisans on this marketplace do not
   hold the special excise licenses required to legally sell these.
5. Sexually explicit or pornographic content: nudity, or a real/depicted person
   shown in a sexually suggestive way. Judge this by what the image actually
   shows, NOT by what the item is labeled/described as — e.g. an image of a
   person's body posed/framed suggestively is flagged even if described as
   "lingerie", "swimwear", or "art". This does NOT apply to a normal clothing
   product photo with no such content (flat-lay, on a mannequin/hanger, or the
   garment alone) — ordinary innerwear/lingerie/swimwear listings are legal
   products here like any other clothing, as long as the photo is a standard
   product shot and not sexualized imagery of a person.
6. Counterfeit/unauthorized branded goods: the item, its packaging, or its tags
   clearly display a well-known brand's actual name/logo/trademark (e.g. Nike,
   Adidas, Gucci, Calvin Klein, Rolex). This is a handmade-artisan marketplace —
   sellers are never authorized resellers of major fashion/luxury brands, so a
   recognizable brand logo on the item itself means counterfeit. Only flag when
   an actual brand name/logo is visibly printed/stitched/engraved on the item —
   a product that merely looks similar in style, with no branding shown, is not
   a counterfeit and must not be flagged.

Do NOT flag ordinary Indian handicrafts — decorative or ceremonial blades
(kirpans, ceremonial swords/daggers sold as craft items), kitchen knives, tools,
or anything that is a normal, lawful artisan product even if it looks
sharp/pointed. Also do not flag ordinary cattle/buffalo horn or bone craft
(combs, buttons, handles) — that's legal livestock byproduct, common in Indian
handicrafts; the wildlife rule above is about wild/protected species
specifically. When genuinely unsure about anything other than case 3 above, do
not flag — false accusations block a real artisan's livelihood. If flagged,
explain briefly in "flagReason" (in $langName); otherwise leave it empty.

JSON FORMAT:
{
  "title": "short product name, 5-8 words",
  "category": "single ecommerce category",
  "description": "2-3 professional sentences highlighting materials, craftsmanship, and use",
  "tags": ["keyword1", "keyword2", "keyword3", "keyword4"],
  "flagged": false,
  "flagReason": ""
}

Artisan's spoken description: $voiceTranscript
''';

      // Images first, then the prompt text.
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
          // Single-pass extraction, no multi-step reasoning needed -
          // thinkingBudget: 0 skips flash's default "thinking" pass,
          // cuts latency and throttling risk.
          'generationConfig': {
            'thinkingConfig': {'thinkingBudget': 0},
          },
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
        description:
            (json['description'] as String?)?.trim() ?? voiceTranscript,
        tags: List<String>.from((json['tags'] as List?) ?? []),
        flagged: json['flagged'] as bool? ?? false,
        flagReason: (json['flagReason'] as String?)?.trim() ?? '',
      );
    } catch (e) {
      debugPrint('analyzeProduct error: $e');
      // Rethrow instead of returning a placeholder - defaulting flagged to
      // false here would publish unscreened photos on any API failure.
      // Caller (add_product_flow._runAi) reverts to the photo step so the
      // artisan can retry.
      rethrow;
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
