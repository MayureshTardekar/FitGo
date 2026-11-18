import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/ai_chat_message.dart';
import '../services/ai/ai_chat_store.dart';
import '../services/ai/ai_context_builder.dart';
import '../services/ai/ai_failure.dart';
import '../services/ai/ai_key_store.dart';
import '../services/ai/ai_prompts.dart';
import '../services/ai/ai_usage.dart';
import '../services/ai/gemini_client.dart';
import '../services/local_storage.dart';
import 'storage_provider.dart';

final aiKeyStoreProvider = Provider<AiKeyStore>((ref) => SecureAiKeyStore());

final aiHttpClientFactoryProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

final aiNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final aiChatStoreProvider = Provider<AiChatStore>(
  (ref) => AiChatStore(ref.read(localStorageProvider)),
);

class AiSettings {
  const AiSettings({
    required this.hasKey,
    required this.keyLast4,
    required this.consentAccepted,
    required this.usage,
  });

  final bool hasKey;
  final String? keyLast4;
  final bool consentAccepted;
  final AiUsage usage;

  String get maskedKey => keyLast4 == null ? '••••••••' : '••••••••$keyLast4';
}

class AiSettingsException implements Exception {
  const AiSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  static const consentSetting = 'ai_consent_v1';

  @override
  Future<AiSettings> build() => _read();

  Future<AiSettings> _read() async {
    final storage = ref.read(localStorageProvider);
    final keyStore = ref.read(aiKeyStoreProvider);
    final now = ref.read(aiNowProvider)();

    String? key;
    try {
      key = await keyStore.readKey(storage.namespace);
    } catch (_) {
      // A locked or temporarily unavailable keystore should not break Profile.
      key = null;
    }

    return AiSettings(
      hasKey: key != null,
      keyLast4: key == null || key.length <= 4
          ? null
          : key.substring(key.length - 4),
      consentAccepted: storage.getSetting<bool>(consentSetting, false),
      usage: AiUsageStore(storage).load(now),
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _read());
  }

  Future<void> saveKey(String raw, {required bool consent}) async {
    final key = raw.trim();
    if (key.length < 20 || key.contains(RegExp(r'\s'))) {
      throw const AiSettingsException('Paste a valid Gemini API key.');
    }
    if (!consent &&
        !ref
            .read(localStorageProvider)
            .getSetting<bool>(consentSetting, false)) {
      throw const AiSettingsException(
        'Please accept the AI privacy note before saving a key.',
      );
    }

    final storage = ref.read(localStorageProvider);
    try {
      await ref.read(aiKeyStoreProvider).writeKey(storage.namespace, key);
      await storage.saveLocalSetting(consentSetting, true);
    } catch (_) {
      throw const AiSettingsException(
        'Could not save the key in this device’s secure storage.',
      );
    }

    state = AsyncData(await _read());
  }

  Future<void> acceptConsent() async {
    await ref.read(localStorageProvider).saveLocalSetting(consentSetting, true);
    state = AsyncData(await _read());
  }

  Future<void> removeKey() async {
    final storage = ref.read(localStorageProvider);
    try {
      await ref.read(aiKeyStoreProvider).deleteKey(storage.namespace);
    } catch (_) {
      throw const AiSettingsException(
        'Could not remove the key from secure storage.',
      );
    }
    await storage.saveLocalSetting(consentSetting, false);
    state = AsyncData(await _read());
  }

  Future<void> clearHistory() async {
    final storage = ref.read(localStorageProvider);
    await AiChatStore(storage).clear();
    ref.invalidate(aiChatProvider);
    state = AsyncData(await _read());
  }

  /// Removes the key, consent, usage counters, and chat history for this
  /// account. A future account-deletion flow should call this before removing
  /// the local namespace.
  Future<void> deleteAllAiData() async {
    final storage = ref.read(localStorageProvider);
    try {
      await ref.read(aiKeyStoreProvider).deleteKey(storage.namespace);
    } catch (_) {
      // Continue clearing local data even if the keystore is unavailable.
    }
    await storage.deleteLocalSetting(consentSetting);
    await AiUsageStore(storage).clear();
    await AiChatStore(storage).clear();
    ref.invalidate(aiChatProvider);
    state = AsyncData(await _read());
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
      AiSettingsNotifier.new,
    );

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.sending = false,
    this.failure,
    this.usingModel,
    this.lastUserMessage,
  });

  final List<AiChatMessage> messages;
  final bool sending;
  final AiFailure? failure;
  final String? usingModel;
  final String? lastUserMessage;

  bool get hasMessages => messages.isNotEmpty;

  bool get canRetry =>
      !sending && lastUserMessage != null && (failure?.retryable ?? false);

  AiChatState copyWith({
    List<AiChatMessage>? messages,
    bool? sending,
    AiFailure? failure,
    bool clearFailure = false,
    String? usingModel,
    bool clearUsingModel = false,
    String? lastUserMessage,
    bool clearLastUserMessage = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      failure: clearFailure ? null : (failure ?? this.failure),
      usingModel: clearUsingModel ? null : (usingModel ?? this.usingModel),
      lastUserMessage: clearLastUserMessage
          ? null
          : (lastUserMessage ?? this.lastUserMessage),
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  static const maxUserMessageLength = 2000;

  // These fields are reassigned because Riverpod reruns `build` on the same
  // notifier when the provider is invalidated. They must not be `final`.
  late LocalStorage _storage;
  late AiChatStore _chatStore;
  late AiUsageStore _usageStore;
  late AiKeyStore _keyStore;
  late DateTime Function() _now;
  late GeminiClient _gemini;

  bool _disposed = false;
  int _generation = 0;

  @override
  AiChatState build() {
    // A resume sync, account switch, or history clear invalidates this
    // provider. Reset the per-build flags so a rebuild cannot throw a
    // LateInitializationError or let an in-flight reply from the previous
    // account reach the new state.
    _disposed = false;
    _generation++;

    _storage = ref.read(localStorageProvider);
    _chatStore = AiChatStore(_storage);
    _usageStore = AiUsageStore(_storage);
    _keyStore = ref.read(aiKeyStoreProvider);
    _now = ref.read(aiNowProvider);
    _gemini = GeminiClient(
      clientFactory: ref.read(aiHttpClientFactoryProvider),
    );

    final gemini = _gemini;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      gemini.cancel();
    });

    return AiChatState(messages: _chatStore.load());
  }

  Future<void> send(String raw) async {
    if (state.sending) return;
    var text = raw.trim();
    if (text.isEmpty) return;
    if (text.length > maxUserMessageLength) {
      text = text.substring(0, maxUserMessageLength).trim();
    }

    final message = AiChatMessage(
      role: AiChatRole.user,
      text: text,
      createdAt: _now(),
    );
    final messages = [...state.messages, message];
    state = state.copyWith(
      messages: messages,
      sending: true,
      clearFailure: true,
      clearUsingModel: true,
      lastUserMessage: text,
    );

    // Remember the generation before the local write. If the user taps stop
    // while the message is being saved, cancel() bumps the generation and this
    // send must not start a network request afterwards.
    final generation = _generation;

    try {
      await _chatStore.save(messages);
    } catch (_) {
      // The in-memory conversation can still continue if local disk is full.
    }
    if (!_isCurrent(generation)) return;

    await _requestReply();
  }

  Future<void> retry() async {
    if (state.sending || state.lastUserMessage == null) return;
    state = state.copyWith(
      sending: true,
      clearFailure: true,
      clearUsingModel: true,
    );
    await _requestReply();
  }

  void cancel() {
    if (!state.sending) return;
    _generation++;
    _gemini.cancel();
    state = state.copyWith(sending: false, clearUsingModel: true);
  }

  void dismissFailure() {
    if (state.failure == null) return;
    state = state.copyWith(clearFailure: true);
  }

  Future<void> clear() async {
    _generation++;
    _gemini.cancel();
    await _chatStore.clear();
    if (_disposed) return;
    state = const AiChatState();
  }

  Future<void> _requestReply() async {
    final generation = ++_generation;
    final key = await _readKey();
    if (!_isCurrent(generation)) return;

    if (key == null) {
      _fail(generation, const AiFailure(AiFailureCode.missingKey));
      return;
    }
    if (!_storage.getSetting<bool>(AiSettingsNotifier.consentSetting, false)) {
      _fail(generation, const AiFailure(AiFailureCode.consentRequired));
      return;
    }

    final now = _now();
    final snapshot = const AiContextBuilder().fromStorage(_storage, now: now);
    final history = _messagesForRequest(state.messages);
    if (history.isEmpty) {
      _fail(generation, const AiFailure(AiFailureCode.badRequest));
      return;
    }

    var usage = _usageStore.load(now);
    final route = const AiModelRouter().route(usage);
    var skipPremium = false;
    var usageChanged = false;
    AiFailure? lastFailure;

    for (final model in route) {
      if (!_isCurrent(generation)) return;

      if (model.premium) {
        if (skipPremium) continue;
        if (!usage.premiumAvailable) {
          skipPremium = true;
          continue;
        }
      }

      state = state.copyWith(usingModel: model.label);

      try {
        final reply = await _gemini.generate(
          apiKey: key,
          model: model,
          systemPrompt: AiPrompts.system,
          context: snapshot.prompt,
          messages: history,
          timeout: model.premium
              ? const Duration(seconds: 40)
              : const Duration(seconds: 25),
        );
        if (!_isCurrent(generation)) return;

        usage = await _usageStore.record(model, now);
        usageChanged = true;
        final updated = [
          ...state.messages,
          AiChatMessage(
            role: AiChatRole.model,
            text: reply.text,
            createdAt: _now(),
          ),
        ];
        try {
          await _chatStore.save(updated);
        } catch (_) {
          // Keep the answer visible even if the last write fails.
        }
        if (!_isCurrent(generation)) return;

        state = state.copyWith(
          messages: updated,
          sending: false,
          clearFailure: true,
          clearUsingModel: true,
          clearLastUserMessage: true,
        );
        if (usageChanged) _refreshSettings();
        return;
      } on AiException catch (error) {
        if (!_isCurrent(generation)) return;
        final failure = error.failure;

        if (failure.code == AiFailureCode.cancelled) {
          state = state.copyWith(
            sending: false,
            clearUsingModel: true,
            clearFailure: true,
          );
          return;
        }

        if (failure.countsAgainstQuota) {
          usage = await _usageStore.record(model, now);
          usageChanged = true;
          if (!_isCurrent(generation)) return;
        }

        if (!failure.canFallback) {
          _fail(generation, failure);
          if (usageChanged) _refreshSettings();
          return;
        }

        lastFailure = failure;
        // A quota, overload, timeout, or empty answer is unlikely to improve
        // on the other premium model. Go straight to Flash Lite. A missing
        // model is the exception: the second premium model may still exist.
        if (model.premium && failure.code != AiFailureCode.modelUnavailable) {
          skipPremium = true;
        }
      }
    }

    if (!_isCurrent(generation)) return;
    _fail(
      generation,
      lastFailure ?? const AiFailure(AiFailureCode.unavailable),
    );
    if (usageChanged) _refreshSettings();
  }

  Future<String?> _readKey() async {
    try {
      return await _keyStore.readKey(_storage.namespace);
    } catch (_) {
      return null;
    }
  }

  List<AiChatMessage> _messagesForRequest(List<AiChatMessage> messages) {
    final recent = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;
    final merged = <AiChatMessage>[];
    for (final message in recent) {
      if (merged.isNotEmpty && merged.last.role == message.role) {
        final previous = merged.removeLast();
        merged.add(
          AiChatMessage(
            role: message.role,
            text: '${previous.text}\n\n${message.text}',
            createdAt: message.createdAt,
          ),
        );
      } else {
        merged.add(message);
      }
    }
    while (merged.isNotEmpty && merged.first.role != AiChatRole.user) {
      merged.removeAt(0);
    }
    return merged;
  }

  void _fail(int generation, AiFailure failure) {
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      sending: false,
      failure: failure,
      clearUsingModel: true,
    );
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _refreshSettings() {
    if (_disposed) return;
    ref.invalidate(aiSettingsProvider);
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(
  AiChatNotifier.new,
);
