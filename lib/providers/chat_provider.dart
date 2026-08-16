import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai_assistant_service.dart';

/// A single AI assistant chat message.
class ChatMessage {
  final String text;
  final bool fromAi;
  final DateTime at;
  ChatMessage(this.text, this.fromAi) : at = DateTime.now();
}

/// Holds the AI assistant's chat transcript for the lifetime of the app
/// process (not tied to AiAssistantScreen's widget lifecycle). The chat is
/// presented as a modal that gets popped whenever the assistant navigates
/// the karigar elsewhere (e.g. "show me my orders") - without this living
/// outside the screen's State, every trip through a navigate_to tool call
/// silently wiped the conversation. Cross-session/cross-device persistence
/// (surviving an app restart, or syncing across devices) is a separate,
/// larger feature - this only fixes in-session loss.
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  void add(ChatMessage message) => state = [...state, message];
}

final chatMessagesProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
  (ref) => ChatNotifier(),
);

/// A cached [AgentSession] tagged with the app language it was built for.
/// The session's system prompt hardcodes "reply ONLY in $langName" at
/// creation time and that instruction is resent with every turn - so if the
/// karigar changes the app's language mid-conversation, the cached session
/// must be thrown away and rebuilt, not silently reused in the old language.
typedef ChatSessionEntry = ({AgentSession session, String languageCode});

/// Holds the live Gemini session (its `_history` of prior turns is what
/// gives the AI actual memory of the conversation) alongside
/// [chatMessagesProvider]'s UI transcript - both need to survive the same
/// modal-close/reopen cycle, or the UI would show old messages the AI
/// itself no longer remembers.
class ChatSessionNotifier extends StateNotifier<ChatSessionEntry?> {
  ChatSessionNotifier() : super(null);

  void set(AgentSession session, String languageCode) =>
      state = (session: session, languageCode: languageCode);
}

final chatSessionProvider =
    StateNotifierProvider<ChatSessionNotifier, ChatSessionEntry?>(
  (ref) => ChatSessionNotifier(),
);
