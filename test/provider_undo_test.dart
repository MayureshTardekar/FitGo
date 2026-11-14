import 'dart:io';

import 'package:fitgo/models/daily_metrics.dart';
import 'package:fitgo/models/meal_template.dart';
import 'package:fitgo/models/sync_status.dart';
import 'package:fitgo/providers/calorie_provider.dart';
import 'package:fitgo/providers/meal_library_provider.dart';
import 'package:fitgo/providers/storage_provider.dart';
import 'package:fitgo/providers/sync_status_provider.dart';
import 'package:fitgo/providers/water_provider.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDir;
  late LocalStorage storage;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_provider_test_');
    storage = LocalStorage();
    await storage.init(userId: null, hivePath: tempDir.path);
    container = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(storage)],
    );
  });

  tearDown(() async {
    container.dispose();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('removeLastEntry undoes a meal and keeps remaining totals', () async {
    final notifier = container.read(nutritionProvider.notifier);

    notifier.addNutrition(
      label: 'Oats',
      calories: 300,
      proteinGrams: 10,
      carbsGrams: 45,
      fatGrams: 6,
    );
    notifier.addNutrition(label: 'Dal', calories: 400, proteinGrams: 22);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(nutritionProvider).totalCalories, 700);
    expect(container.read(nutritionProvider).entries, hasLength(2));

    final removed = notifier.removeLastEntry();
    await Future<void>.delayed(Duration.zero);

    expect(removed?.label, 'Dal');
    final state = container.read(nutritionProvider);
    expect(state.totalCalories, 300);
    expect(state.proteinGrams, 10);
    expect(state.entries, hasLength(1));
    expect(storage.getToday().totalCalories, 300);
    expect(storage.getToday().nutritionEntries, hasLength(1));
  });

  test('undo keeps calories from a v2 log that had no meal entries', () async {
    final dateKey = storage.getToday().dateKey;
    await storage.saveMetrics(
      DailyMetrics(
        dateKey: dateKey,
        totalCalories: 400,
        calorieEntries: const [400],
      ),
    );

    final notifier = container.read(nutritionProvider.notifier);
    expect(container.read(nutritionProvider).totalCalories, 400);

    notifier.addNutrition(label: 'Lunch', calories: 250);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(nutritionProvider).totalCalories, 650);
    expect(container.read(nutritionProvider).entries, hasLength(2));

    final removed = notifier.removeLastEntry();
    await Future<void>.delayed(Duration.zero);

    expect(removed?.label, 'Lunch');
    expect(container.read(nutritionProvider).totalCalories, 400);
    expect(container.read(nutritionProvider).entries.single.calories, 400);
    expect(storage.getToday().totalCalories, 400);
    expect(storage.getToday().calorieEntries, [400]);
  });

  test('untracked earlier calories survive later meal additions', () async {
    final dateKey = storage.getToday().dateKey;
    await storage.saveMetrics(
      DailyMetrics(
        dateKey: dateKey,
        totalCalories: 650,
        calorieEntries: const [400, 250],
        // State left behind by the old add path: the legacy 400 kcal has no
        // matching nutrition entry.
        nutritionEntries: const ['Lunch|250|0|0|0|0|0'],
      ),
    );

    final notifier = container.read(nutritionProvider.notifier);
    final restored = container.read(nutritionProvider);
    expect(restored.totalCalories, 650);
    expect(restored.entries, hasLength(2));

    notifier.addNutrition(label: 'Snack', calories: 100);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(nutritionProvider).totalCalories, 750);

    notifier.removeLastEntry();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(nutritionProvider).totalCalories, 650);
    expect(storage.getToday().totalCalories, 650);
  });

  test(
    'removeEntryAt removes an older meal without reordering the rest',
    () async {
      final notifier = container.read(nutritionProvider.notifier);
      notifier.addNutrition(label: 'Breakfast', calories: 250);
      notifier.addNutrition(label: 'Lunch', calories: 550);
      notifier.addNutrition(label: 'Snack', calories: 120);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.removeEntryAt(1), isTrue);
      await Future<void>.delayed(Duration.zero);

      final entries = container.read(nutritionProvider).entries;
      expect(entries.map((entry) => entry.label), ['Breakfast', 'Snack']);
      expect(container.read(nutritionProvider).totalCalories, 370);
      expect(notifier.removeEntryAt(9), isFalse);
    },
  );

  test('water can be logged and undone without going below zero', () async {
    final notifier = container.read(waterProvider.notifier);

    notifier.addWater(250);
    notifier.addWater(250);
    expect(container.read(waterProvider), 500);

    notifier.removeWater(250);
    expect(container.read(waterProvider), 250);

    notifier.removeWater(1000);
    expect(container.read(waterProvider), 0);
    expect(storage.getToday().waterMl, 0);
  });

  test('meal library deduplicates recents and keeps saved meals', () async {
    final notifier = container.read(mealLibraryProvider.notifier);
    const oats = MealTemplate(
      id: 'oats',
      name: 'Oats',
      calories: 320,
      proteinGrams: 12,
    );

    await notifier.recordLogged(oats);
    await notifier.recordLogged(oats);
    await notifier.saveMeal(oats);
    await notifier.recordLogged(oats);

    final state = container.read(mealLibraryProvider);
    expect(state.recent, hasLength(1));
    expect(state.recent.single.useCount, 3);
    expect(state.saved, hasLength(1));
    expect(state.isSaved(oats), isTrue);

    await notifier.toggleSaved(oats);
    expect(container.read(mealLibraryProvider).saved, isEmpty);
  });

  test(
    'meal library persists recent and saved meals across rebuilds',
    () async {
      final notifier = container.read(mealLibraryProvider.notifier);
      const soup = MealTemplate(id: 'soup', name: 'Soup', calories: 180);

      await notifier.recordLogged(soup);
      await notifier.saveMeal(soup);
      container.invalidate(mealLibraryProvider);

      final restored = container.read(mealLibraryProvider);
      expect(restored.recent.single.name, 'Soup');
      expect(restored.saved.single.name, 'Soup');
    },
  );

  test('sync status stream starts with the current snapshot', () async {
    final status = await storage.syncStatusStream.first;

    expect(status.cloudEnabled, isFalse);
    expect(status.pendingChanges, 0);
    expect(status.lastSyncedAt, isNull);
  });

  test('sync labels distinguish local-only and pending saves', () {
    const localOnly = SyncStatus(cloudEnabled: false, pendingChanges: 0);
    const pending = SyncStatus(cloudEnabled: true, pendingChanges: 2);
    final synced = SyncStatus(
      cloudEnabled: true,
      pendingChanges: 0,
      lastSyncedAt: DateTime(2026, 11, 14),
    );

    expect(savedLocallyLabel(localOnly), 'Saved on this device');
    expect(savedLocallyLabel(pending), 'Saved on this device · Sync pending');
    expect(savedLocallyLabel(synced), 'Saved on this device · Sync pending');
    expect(localOnly.isFullySynced, isFalse);
    expect(pending.hasPendingChanges, isTrue);
    expect(synced.isFullySynced, isTrue);
  });
}
