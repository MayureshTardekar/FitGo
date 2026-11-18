import 'dart:convert';

import '../../models/ai_chat_message.dart';
import '../local_storage.dart';

/// Account-scoped conversation history.
///
/// History is stored with [LocalStorage.saveLocalSetting] so it stays on the
/// device and is never queued for Supabase. The list is capped and only the
/// most recent turns are sent to Gemini.
class AiChatStore {
  const AiChatStore(this.storage);

  static const historySetting = 'ai_chat_history_v1';
  static const draftSetting = 'ai_chat_draft_v1';
  static const maxMessages = 40;
  static const maxTextLength = 4000;
  static const maxDraftLength = 2000;

  final LocalStorage storage;

  String loadDraft() {
    final draft = storage.getSetting<String>(draftSetting, '');
    return draft.length > maxDraftLength
        ? draft.substring(0, maxDraftLength)
        : draft;
  }

  /// Keeps an unsent composer draft on this device, outside cloud sync.
  Future<void> saveDraft(String draft) async {
    if (draft.isEmpty) {
      await storage.deleteLocalSetting(draftSetting);
      return;
    }
    final boundedDraft = draft.length > maxDraftLength
        ? draft.substring(0, maxDraftLength)
        : draft;
    await storage.saveLocalSetting(draftSetting, boundedDraft);
  }

  List<AiChatMessage> load() {
    final raw = storage.getSetting<String>(historySetting, '');
    if (raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final messages = decoded
          .map(AiChatMessage.fromJson)
          .whereType<AiChatMessage>()
          .map(
            (message) => message.text.length > maxTextLength
                ? AiChatMessage(
                    role: message.role,
                    text: message.text.substring(0, maxTextLength),
                    createdAt: message.createdAt,
                  )
                : message,
          )
          .toList();
      return _normalise(messages);
    } catch (_) {
      // A corrupt local history should never block the chat.
      return const [];
    }
  }

  Future<void> save(List<AiChatMessage> messages) async {
    final normalised = _normalise(messages);
    if (normalised.isEmpty) {
      await clear();
      return;
    }

    await storage.saveLocalSetting(
      historySetting,
      jsonEncode(normalised.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> clear() => storage.deleteLocalSetting(historySetting);

  List<AiChatMessage> _normalise(List<AiChatMessage> messages) {
    final copy = List<AiChatMessage>.of(messages);
    final trimmed = copy.length > maxMessages
        ? copy.sublist(copy.length - maxMessages)
        : copy;

    // A conversation should start with the user's question.
    while (trimmed.isNotEmpty && !trimmed.first.isUser) {
      trimmed.removeAt(0);
    }
    return trimmed;
  }
}
