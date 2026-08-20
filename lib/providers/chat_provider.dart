import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_assistant_service.dart';

/// A single AI assistant chat message.
class ChatMessage {
  final String text;
  final bool fromAi;
  final DateTime at;
  ChatMessage(this.text, this.fromAi) : at = DateTime.now();
}

/// Chat transcript for the app process lifetime, not tied to
/// AiAssistantScreen's widget lifecycle - the assistant's modal gets
/// popped on navigate_to calls, which would otherwise wipe the
/// conversation. Doesn't survive an app restart.
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  void add(ChatMessage message) => state = [...state, message];
}

final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(),
);

/// [AgentSession] tagged with the language it was built for - the system
/// prompt hardcodes the reply language, so a language switch mid-
/// conversation means rebuilding the session, not reusing it.
typedef ChatSessionEntry = ({AgentSession session, String languageCode});

/// Holds the live Gemini session (`_history` is the AI's actual memory)
/// alongside [chatMessagesProvider]'s UI transcript so both survive a
/// modal close/reopen in sync.
class ChatSessionNotifier extends StateNotifier<ChatSessionEntry?> {
  ChatSessionNotifier() : super(null);

  void set(AgentSession session, String languageCode) =>
      state = (session: session, languageCode: languageCode);
}

final chatSessionProvider =
    StateNotifierProvider<ChatSessionNotifier, ChatSessionEntry?>(
  (ref) => ChatSessionNotifier(),
);
