import 'dart:io';

import 'package:fitgo/models/ai_chat_message.dart';
import 'package:fitgo/providers/ai_provider.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/screens/ai_chat_screen.dart';
import 'package:fitgo/services/ai/ai_failure.dart';
import 'package:fitgo/services/ai/ai_key_store.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:fitgo/ui/profile/ai_settings_sheet.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _FakeKeyStore implements AiKeyStore {
  final Map<String, String> keys = {};

  @override
  Future<String?> readKey(String namespace) async => keys[namespace];

  @override
  Future<void> writeKey(String namespace, String key) async {
    keys[namespace] = key;
  }

  @override
  Future<void> deleteKey(String namespace) async {
    keys.remove(namespace);
  }
}

/// Avoids touching Hive from inside a widget test, where platform I/O and the
/// fake clock can deadlock each other. The real notifier is covered by
/// `ai_test.dart`.
class _FakeChatNotifier extends AiChatNotifier {
  _FakeChatNotifier(this.initialMessages);

  final List<AiChatMessage> initialMessages;

  @override
  AiChatState build() => AiChatState(messages: initialMessages);

  @override
  Future<void> send(String raw) async {
    final text = raw.trim();
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiChatMessage(
          role: AiChatRole.user,
          text: text,
          createdAt: DateTime(2026, 5, 20),
        ),
      ],
      failure: const AiFailure(AiFailureCode.missingKey),
      lastUserMessage: text,
      sending: false,
    );
  }
}

void main() {
  late Directory tempDir;
  late LocalStorage storage;
  late _FakeKeyStore keyStore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_ai_widget_test_');
    storage = LocalStorage();
    await storage.init(userId: 'widget_account', hivePath: tempDir.path);
    keyStore = _FakeKeyStore();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget wrap(Widget child, {AiChatNotifier Function()? chat}) {
    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        aiKeyStoreProvider.overrideWithValue(keyStore),
        if (chat != null) aiChatProvider.overrideWith(chat),
      ],
      child: MaterialApp(
        theme: FitGoTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      ),
    );
  }

  void useSmallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('empty chat fits 320pt at 200% text and rotates prompts', (
    tester,
  ) async {
    useSmallScreen(tester);
    keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
    await tester.runAsync(
      () => storage.saveLocalSetting(AiSettingsNotifier.consentSetting, true),
    );

    await tester.pumpWidget(wrap(const AiChatScreen()));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Your coach, grounded in your logs'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, 'Summarize week');

    await tester.pump(const Duration(seconds: 5));
    final rotated = tester.widget<TextField>(find.byType(TextField));
    expect(rotated.decoration?.hintText, 'How is my water going?');
  });

  testWidgets('chat shows existing history and sends without a key', (
    tester,
  ) async {
    useSmallScreen(tester);
    final fakeChat = _FakeChatNotifier([
      AiChatMessage(
        role: AiChatRole.user,
        text: 'How was my week?',
        createdAt: DateTime(2026, 5, 20),
      ),
      AiChatMessage(
        role: AiChatRole.model,
        text: 'You logged every day. Keep the same water routine.',
        createdAt: DateTime(2026, 5, 20),
      ),
    ]);

    await tester.pumpWidget(wrap(const AiChatScreen(), chat: () => fakeChat));
    await settle(tester);

    expect(find.textContaining('You logged every day'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Summarize week');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await settle(tester);

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Summarize week'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Add your Gemini key in Profile → Preferences to start.'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sheet fits 320pt at 200% text without a key', (
    tester,
  ) async {
    useSmallScreen(tester);

    await tester.pumpWidget(wrap(const Scaffold(body: AiSettingsSheet())));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Gemini API key'), findsOneWidget);
    expect(find.text('Get a free key'), findsOneWidget);
  });

  testWidgets('settings sheet fits 320pt at 200% text with a saved key', (
    tester,
  ) async {
    useSmallScreen(tester);
    keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
    await tester.runAsync(
      () => storage.saveLocalSetting(AiSettingsNotifier.consentSetting, true),
    );

    await tester.pumpWidget(wrap(const Scaffold(body: AiSettingsSheet())));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Gemini key saved'), findsOneWidget);
    expect(find.text('Replace key'), findsOneWidget);
    expect(find.text('Delete AI data'), findsOneWidget);
  });
}
