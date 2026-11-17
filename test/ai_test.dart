import 'dart:convert';
import 'dart:io';

import 'package:fitgo/models/ai_chat_message.dart';
import 'package:fitgo/models/daily_metrics.dart';
import 'package:fitgo/models/user_profile.dart';
import 'package:fitgo/models/weight_entry.dart';
import 'package:fitgo/providers/ai_provider.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/services/ai/ai_chat_store.dart';
import 'package:fitgo/services/ai/ai_context_builder.dart';
import 'package:fitgo/services/ai/ai_failure.dart';
import 'package:fitgo/services/ai/ai_key_store.dart';
import 'package:fitgo/services/ai/ai_models.dart';
import 'package:fitgo/services/ai/ai_prompts.dart';
import 'package:fitgo/services/ai/ai_usage.dart';
import 'package:fitgo/services/ai/gemini_client.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';

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

String _dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

UserProfile _profile({double weightKg = 70}) => UserProfile(
  weightKg: weightKg,
  heightCm: 175,
  age: 30,
  gender: 'male',
  calorieGoal: 2200,
  waterGoalMl: 2500,
  weeklyCalorieGoal: 15400,
  weightGoal: 'lose',
  activityLevel: 'light',
  targetWeightKg: 65,
  goalTargetDate: '2026-08-20',
);

DailyMetrics _metric(
  DateTime date, {
  int calories = 2200,
  int water = 2500,
  int steps = 8000,
  int sleep = 450,
  double? weight,
}) => DailyMetrics(
  dateKey: _dateKey(date),
  totalCalories: calories,
  waterMl: water,
  steps: steps,
  sleepMinutes: sleep,
  weight: weight,
);

http.Response _answer(String text) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late Directory tempDir;
  late LocalStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_ai_test_');
    storage = LocalStorage();
    await storage.init(userId: 'account_a', hivePath: tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AiModelRouter', () {
    test('alternates premium models then falls back automatically', () {
      const router = AiModelRouter();

      final first = router.route(AiUsage.empty('2026-05-20'));
      expect(first.map((model) => model.id), [
        'gemini-3.8-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
      ]);

      final ninth = router.route(
        const AiUsage(dateKey: '2026-05-20', premiumUsed: 9, fallbackUsed: 0),
      );
      expect(ninth.map((model) => model.id), [
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
      ]);

      final exhausted = router.route(
        const AiUsage(dateKey: '2026-05-20', premiumUsed: 10, fallbackUsed: 8),
      );
      expect(exhausted.single.id, 'gemini-3.5-flash-lite');
    });

    test('usage counters are account scoped and reset on a new day', () async {
      final now = DateTime(2026, 5, 20, 12);
      final usageStore = AiUsageStore(storage);
      final first = await usageStore.record(AiModels.flash38, now);
      final second = await usageStore.record(AiModels.flash36, now);
      expect(first.premiumUsed, 1);
      expect(second.premiumUsed, 2);

      await storage.switchToAccount('account_b');
      expect(usageStore.load(now).premiumUsed, 0);

      await storage.switchToAccount('account_a');
      expect(usageStore.load(now).premiumUsed, 2);
      expect(usageStore.load(now.add(const Duration(days: 1))).premiumUsed, 0);
    });
  });

  group('AiChatStore', () {
    test('caps history, starts with the user, and clears on demand', () async {
      final chatStore = AiChatStore(storage);
      final messages = List.generate(
        55,
        (index) => AiChatMessage(
          role: index.isEven ? AiChatRole.user : AiChatRole.model,
          text: 'message $index',
          createdAt: DateTime(2026, 5, 20).add(Duration(minutes: index)),
        ),
      );

      await chatStore.save(messages);
      final loaded = chatStore.load();

      expect(loaded.length, lessThanOrEqualTo(AiChatStore.maxMessages));
      expect(loaded.first.isUser, isTrue);
      expect(loaded.last.text, 'message 54');

      await chatStore.clear();
      expect(chatStore.load(), isEmpty);
    });

    test('history is isolated per account', () async {
      final chatStore = AiChatStore(storage);
      await chatStore.save([
        AiChatMessage(
          role: AiChatRole.user,
          text: 'account A question',
          createdAt: DateTime(2026, 5, 20),
        ),
      ]);

      await storage.switchToAccount('account_b');
      expect(chatStore.load(), isEmpty);

      await storage.switchToAccount('account_a');
      expect(chatStore.load().single.text, 'account A question');
    });
  });

  group('AiContextBuilder', () {
    test('builds an on-track, PII-free snapshot from FitGo data', () {
      final now = DateTime(2026, 5, 20);
      final metrics = List.generate(
        7,
        (index) => _metric(
          now.subtract(Duration(days: 6 - index)),
          weight: index == 6 ? 69.0 : null,
        ),
      );
      final weights = [
        WeightEntry(
          dateKey: _dateKey(now.subtract(const Duration(days: 14))),
          weight: 70.0,
        ),
        WeightEntry(dateKey: _dateKey(now), weight: 69.0),
      ];

      final snapshot = const AiContextBuilder().build(
        profile: _profile(),
        metrics: metrics,
        weights: weights,
        now: now,
      );

      expect(snapshot.status, AiTrackStatus.onTrack);
      expect(snapshot.daysLogged7, 7);
      expect(snapshot.avgCalories7, 2200);
      expect(snapshot.avgWaterMl7, 2500);
      expect(snapshot.weightChange14, -1.0);
      expect(snapshot.prompt, contains('Private progress classification'));
      expect(snapshot.prompt, contains('ON_TRACK'));
      expect(snapshot.prompt, isNot(contains('APP ON-TRACK STATUS')));
      expect(snapshot.prompt, contains('FITGO SNAPSHOT'));
      expect(snapshot.prompt.toLowerCase(), isNot(contains('@')));
      expect(snapshot.prompt, isNot(contains('account_a')));
      expect(snapshot.prompt, isNot(contains('test-key')));
    });

    test(
      'coach prompt keeps answers direct and hides internal status labels',
      () {
        expect(AiPrompts.system, contains('Answer the exact question'));
        expect(AiPrompts.system, contains('Mention progress status only when'));
        expect(AiPrompts.system, contains('Do not give unsolicited plans'));
        expect(AiPrompts.system, contains('restriction, fasting, or exercise'));
      },
    );

    test('marks two large misses as off track and sparse logs as unknown', () {
      final now = DateTime(2026, 5, 20);
      final offMetrics = List.generate(
        7,
        (index) => _metric(
          now.subtract(Duration(days: 6 - index)),
          calories: 3100,
          water: 600,
        ),
      );
      final off = const AiContextBuilder().build(
        profile: _profile(),
        metrics: offMetrics,
        weights: const [],
        now: now,
      );
      expect(off.status, AiTrackStatus.offTrack);
      expect(off.reasons.join(' '), contains('hydration'));

      final sparse = const AiContextBuilder().build(
        profile: _profile(),
        metrics: [_metric(now)],
        weights: const [],
        now: now,
      );
      expect(sparse.status, AiTrackStatus.notEnoughData);

      final noProfile = const AiContextBuilder().build(
        profile: null,
        metrics: offMetrics,
        weights: const [],
        now: now,
      );
      expect(noProfile.status, AiTrackStatus.notEnoughData);
      expect(noProfile.prompt, contains('Profile: not set up yet.'));
    });
  });

  group('GeminiClient', () {
    test('maps provider errors and extracts only answer text', () async {
      final cases = <int, AiFailureCode>{
        401: AiFailureCode.invalidKey,
        404: AiFailureCode.modelUnavailable,
        429: AiFailureCode.quota,
        500: AiFailureCode.unavailable,
      };

      for (final entry in cases.entries) {
        final client = GeminiClient(
          clientFactory: () => MockClient(
            (_) async => http.Response('{"error":{"message":"x"}}', entry.key),
          ),
        );
        await expectLater(
          client.generate(
            apiKey: 'test-key-not-real-1234567890',
            model: AiModels.flashLite35,
            systemPrompt: 'system',
            context: 'context',
            messages: [
              AiChatMessage(
                role: AiChatRole.user,
                text: 'hello',
                createdAt: DateTime(2026, 5, 20),
              ),
            ],
          ),
          throwsA(
            isA<AiException>().having(
              (error) => error.failure.code,
              'code',
              entry.value,
            ),
          ),
        );
      }

      final success = GeminiClient(
        clientFactory: () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('contents'), isTrue);
          final generationConfig =
              body['generationConfig'] as Map<String, dynamic>;
          expect(generationConfig['maxOutputTokens'], 512);
          expect(request.headers['x-goog-api-key'], isNotEmpty);
          expect(request.url.query, isNot(contains('test-key')));
          return _answer(' Here is your week. ');
        }),
      );
      final reply = await success.generate(
        apiKey: 'test-key-not-real-1234567890',
        model: AiModels.flash38,
        systemPrompt: 'system',
        context: 'context',
        messages: [
          AiChatMessage(
            role: AiChatRole.user,
            text: 'summarize',
            createdAt: DateTime(2026, 5, 20),
          ),
        ],
      );
      expect(reply.text, 'Here is your week.');
      expect(reply.modelId, AiModels.flash38.id);
    });

    test('treats blocked output as a safety failure', () async {
      final client = GeminiClient(
        clientFactory: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'SAFETY',
                  'content': {
                    'parts': [
                      {'text': 'should not be returned'},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

      await expectLater(
        client.generate(
          apiKey: 'test-key-not-real-1234567890',
          model: AiModels.flash38,
          systemPrompt: 'system',
          context: 'context',
          messages: [
            AiChatMessage(
              role: AiChatRole.user,
              text: 'hello',
              createdAt: DateTime(2026, 5, 20),
            ),
          ],
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.failure.code,
            'code',
            AiFailureCode.safety,
          ),
        ),
      );
    });
  });

  group('AiChatNotifier', () {
    late _FakeKeyStore keyStore;
    late List<String> requests;

    setUp(() {
      keyStore = _FakeKeyStore();
      requests = [];
    });

    ProviderContainer containerFor(http.Client client, DateTime now) {
      return ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          aiKeyStoreProvider.overrideWithValue(keyStore),
          aiHttpClientFactoryProvider.overrideWithValue(() => client),
          aiNowProvider.overrideWithValue(() => now),
        ],
      );
    }

    test('falls back to Flash Lite when premium quota is exhausted', () async {
      final now = DateTime(2026, 5, 20, 12);
      keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
      await storage.saveLocalSetting(AiSettingsNotifier.consentSetting, true);
      await storage.saveLocalSetting(AiUsageStore.dateSetting, _dateKey(now));
      await storage.saveLocalSetting(AiUsageStore.premiumSetting, 8);
      await storage.saveProfile(_profile());

      final client = MockClient((request) async {
        final path = request.url.path;
        requests.add(path);
        if (path.contains('3.8-flash')) {
          return http.Response('{"error":{"message":"quota"}}', 429);
        }
        if (path.contains('flash-lite')) {
          return _answer('Flash Lite kept this chat working.');
        }
        return http.Response('{"error":{"message":"unexpected"}}', 500);
      });
      final container = containerFor(client, now);
      addTearDown(container.dispose);

      await container.read(aiChatProvider.notifier).send('Summarize my week');
      final state = container.read(aiChatProvider);

      expect(requests, hasLength(2));
      expect(requests.first, contains('gemini-3.8-flash'));
      expect(requests.last, contains('gemini-3.5-flash-lite'));
      expect(state.sending, isFalse);
      expect(state.failure, isNull);
      expect(state.messages.last.isUser, isFalse);
      expect(state.messages.last.text, 'Flash Lite kept this chat working.');

      final settings = await container.read(aiSettingsProvider.future);
      expect(settings.usage.premiumUsed, 9);
      expect(settings.usage.fallbackUsed, 1);
      expect(settings.hasKey, isTrue);

      final history = AiChatStore(storage).load();
      expect(history, hasLength(2));
      expect(history.first.text, 'Summarize my week');
    });

    test('does not send anything without a key or consent', () async {
      final now = DateTime(2026, 5, 20, 12);
      final client = MockClient((request) async {
        requests.add(request.url.path);
        return _answer('should not be used');
      });

      final noKeyContainer = containerFor(client, now);
      addTearDown(noKeyContainer.dispose);
      await noKeyContainer.read(aiChatProvider.notifier).send('Summarize week');
      expect(
        noKeyContainer.read(aiChatProvider).failure?.code,
        AiFailureCode.missingKey,
      );
      expect(requests, isEmpty);

      keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
      final noConsent = containerFor(client, now);
      addTearDown(noConsent.dispose);
      await noConsent.read(aiChatProvider.notifier).send('Summarize week');
      expect(
        noConsent.read(aiChatProvider).failure?.code,
        AiFailureCode.consentRequired,
      );
      expect(requests, isEmpty);
    });

    test(
      'stops after an invalid key instead of spending other models',
      () async {
        final now = DateTime(2026, 5, 20, 12);
        keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
        await storage.saveLocalSetting(AiSettingsNotifier.consentSetting, true);
        await storage.saveProfile(_profile());

        final client = MockClient((request) async {
          requests.add(request.url.path);
          return http.Response(
            '{"error":{"message":"API key not valid"}}',
            400,
          );
        });
        final container = containerFor(client, now);
        addTearDown(container.dispose);

        await container.read(aiChatProvider.notifier).send('Summarize week');
        final state = container.read(aiChatProvider);
        expect(requests, hasLength(1));
        expect(state.failure?.code, AiFailureCode.invalidKey);
        expect(state.canRetry, isFalse);
      },
    );

    test('stop before the request starts never sends anything', () async {
      final now = DateTime(2026, 5, 20, 12);
      keyStore.keys[storage.namespace] = 'test-key-not-real-1234567890';
      await storage.saveLocalSetting(AiSettingsNotifier.consentSetting, true);
      await storage.saveProfile(_profile());

      final client = MockClient((request) async {
        requests.add(request.url.path);
        return _answer('should not be requested');
      });
      final container = containerFor(client, now);
      addTearDown(container.dispose);

      final notifier = container.read(aiChatProvider.notifier);
      final send = notifier.send('Summarize week');
      notifier.cancel();
      await send;

      final state = container.read(aiChatProvider);
      expect(requests, isEmpty);
      expect(state.sending, isFalse);
      expect(state.failure, isNull);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.text, 'Summarize week');
    });
  });
}
