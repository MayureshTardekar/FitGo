import 'package:fitgo/models/user_profile.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/screens/onboarding_screen.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// In-memory storage so widget tests never touch Hive file I/O.
class _FakeStorage extends LocalStorage {
  final Map<String, Object?> values = {};

  @override
  T getSetting<T>(String key, T defaultValue) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> saveSetting(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> saveLocalSetting(String key, Object? value) async {
    values[key] = value;
  }

  @override
  UserProfile? getProfile() => null;

  @override
  bool get hasProfile => false;
}

void main() {
  late _FakeStorage storage;
  late GoRouter router;

  setUp(() {
    storage = _FakeStorage();

    router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const Scaffold(body: Text('Auth')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
  });

  Widget app() {
    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: MaterialApp.router(theme: FitGoTheme.light, routerConfig: router),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('welcome continues to body details and switches units', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Your day, in one place'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await settle(tester);

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('Metric'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);

    await tester.tap(find.text('Imperial'));
    await settle(tester);

    expect(find.text('lb'), findsOneWidget);
    expect(find.text('in'), findsOneWidget);
    expect(storage.values['onboarding_draft_v1'], isNotEmpty);
  });

  testWidgets('onboarding draft resumes after a restart', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('Get started'));
    await settle(tester);

    await tester.tap(find.text('Tap to select'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).at(0), '82');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('How active is a typical week?'), findsOneWidget);

    // Simulate a cold start: tear down the tree, then rebuild it with the
    // same account storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    router.dispose();
    router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('How active is a typical week?'), findsOneWidget);
  });
}
