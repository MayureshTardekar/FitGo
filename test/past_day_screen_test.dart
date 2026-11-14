import 'dart:io';

import 'package:fitgo/models/daily_metrics.dart';
import 'package:fitgo/providers/analytics_provider.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/screens/past_day_screen.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  late Directory tempDir;
  late LocalStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_past_day_test_');
    storage = LocalStorage();
    await storage.init(userId: null, hivePath: tempDir.path);
  });

  tearDown(() async {
    // Hive is left open on purpose: closing a disk box inside a widget test's
    // fake-async zone hangs. The process exit releases the file handles, and
    // these temporary directories contain only a few kilobytes.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } on FileSystemException {
      // Open Hive handles keep the directory alive on Windows.
    }
  });

  testWidgets('saving a past day refreshes the Trends calculation', (
    tester,
  ) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateKey = DateFormat('yyyy-MM-dd').format(yesterday);
      await tester.runAsync(
        () => storage.saveMetrics(
          DailyMetrics(
            dateKey: dateKey,
            totalCalories: 400,
            calorieEntries: const [400],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            theme: FitGoTheme.light,
            home: const PastDayLogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PastDayLogScreen)),
      );

      // A year view contains yesterday unless the test runs on 1 January.
      final timeframe = container.read(analyticsTimeframeProvider.notifier);
      timeframe.updateTimeframe(Timeframe.thisYear);
      final now = DateTime.now();
      if (now.month == 1 && now.day == 1) {
        timeframe.previous();
      }

      int? caloriesForYesterday() {
        final analytics = container.read(dashboardAnalyticsProvider);
        for (final day in analytics.days) {
          if (day.dateKey == dateKey) return day.calories;
        }
        return null;
      }

      expect(caloriesForYesterday(), 400);

      await tester.enterText(find.byType(TextField).first, '550');
      final saveButton = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);

      // The screen persists through Hive, so let the real event loop finish
      // the write and its post-save invalidation before checking Trends.
      await tester.runAsync(() async {
        for (var i = 0; i < 20; i++) {
          if (storage.getMetricsForDate(dateKey)?.totalCalories == 550) break;
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.pump();

      expect(storage.getMetricsForDate(dateKey)?.totalCalories, 550);
      expect(caloriesForYesterday(), 550);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
