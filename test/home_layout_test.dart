import 'dart:io';

import 'package:fitgo/models/sync_status.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/providers/sync_status_provider.dart';
import 'package:fitgo/screens/home_screen.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _PendingSyncStatusNotifier extends SyncStatusNotifier {
  @override
  SyncStatus build() =>
      const SyncStatus(cloudEnabled: true, pendingChanges: 12);
}

void main() {
  late Directory tempDir;
  late LocalStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_home_layout_test_');
    storage = LocalStorage();
    await storage.init(userId: null, hivePath: tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpToday(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          ...overrides,
        ],
        child: MaterialApp(
          theme: FitGoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Today fits a 320pt screen at 200% text', (tester) async {
    await pumpToday(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
  });

  testWidgets('Today header fits a pending sync at 200% text', (tester) async {
    await pumpToday(
      tester,
      overrides: [
        syncStatusProvider.overrideWith(_PendingSyncStatusNotifier.new),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Sync pending · 12'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
  });
}
