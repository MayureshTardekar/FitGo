import 'dart:io';

import 'package:fitgo/models/daily_metrics.dart';
import 'package:fitgo/models/user_profile.dart';
import 'package:fitgo/models/weight_entry.dart';
import 'package:fitgo/services/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

UserProfile _profile({double weightKg = 70}) =>
    UserProfile(weightKg: weightKg, heightCm: 175, age: 30, gender: 'male');

void main() {
  late Directory tempDir;
  late LocalStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitgo_storage_test_');
    storage = LocalStorage();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('account namespaces keep profiles and daily logs isolated', () async {
    await storage.init(userId: null, hivePath: tempDir.path);

    await storage.saveProfile(_profile(weightKg: 70));
    await storage.saveMetrics(
      DailyMetrics(dateKey: '2026-11-13', totalCalories: 500),
    );
    await storage.saveWeight(WeightEntry(dateKey: '2026-11-13', weight: 70));

    expect(storage.isGuest, isTrue);
    expect(storage.hasData, isTrue);

    await storage.switchToAccount('user-a');
    expect(storage.isGuest, isFalse);
    expect(storage.hasData, isFalse);
    expect(storage.getProfile(), isNull);
    expect(storage.getMetricsForDate('2026-11-13'), isNull);
    expect(storage.getWeightHistory(), isEmpty);

    await storage.saveMetrics(
      DailyMetrics(dateKey: '2026-11-13', totalCalories: 800),
    );

    await storage.switchToAccount('user-b');
    expect(storage.getMetricsForDate('2026-11-13'), isNull);

    await storage.switchToAccount('user-a');
    expect(storage.getMetricsForDate('2026-11-13')?.totalCalories, 800);

    await storage.switchToAccount(null);
    expect(storage.getMetricsForDate('2026-11-13')?.totalCalories, 500);
    expect(storage.getProfile()?.weightKg, 70);
  });

  test(
    'legacy shared cache migrates to guest, never the active account',
    () async {
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(DailyMetricsAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(WeightEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(UserProfileAdapter());
      }

      final legacyMetrics = await Hive.openBox<DailyMetrics>('daily_metrics');
      await legacyMetrics.put(
        '2026-11-12',
        DailyMetrics(dateKey: '2026-11-12', totalCalories: 640),
      );
      await legacyMetrics.close();

      final legacyProfile = await Hive.openBox<UserProfile>('user_profile');
      await legacyProfile.put('profile', _profile(weightKg: 68));
      await legacyProfile.close();

      await storage.init(userId: 'user-a', hivePath: tempDir.path);

      expect(storage.isGuest, isFalse);
      expect(storage.hasData, isFalse);
      expect(await storage.guestHasData(), isTrue);

      await storage.switchToAccount(null);
      expect(storage.getMetricsForDate('2026-11-12')?.totalCalories, 640);
      expect(storage.getProfile()?.weightKg, 68);
    },
  );

  test('cloud merge only overwrites local records when safe', () async {
    await storage.init(userId: null, hivePath: tempDir.path);
    await storage.saveMetrics(
      DailyMetrics(dateKey: '2026-11-13', totalCalories: 500),
    );

    await storage.importCloudData(
      metrics: [DailyMetrics(dateKey: '2026-11-13', totalCalories: 900)],
    );
    expect(storage.getMetricsForDate('2026-11-13')?.totalCalories, 500);

    await storage.importCloudData(
      metrics: [DailyMetrics(dateKey: '2026-11-13', totalCalories: 900)],
      overwrite: true,
    );
    expect(storage.getMetricsForDate('2026-11-13')?.totalCalories, 900);
  });

  test(
    'guest import copies data into an account and keeps the source',
    () async {
      await storage.init(userId: null, hivePath: tempDir.path);
      await storage.saveProfile(_profile(weightKg: 72));
      await storage.saveMetrics(
        DailyMetrics(dateKey: '2026-11-11', totalCalories: 420),
      );

      await storage.switchToAccount('user-a');
      expect(await storage.guestHasImportableData(), isTrue);
      final imported = await storage.importGuestData();

      expect(imported, 2);
      expect(storage.getProfile()?.weightKg, 72);
      expect(storage.getMetricsForDate('2026-11-11')?.totalCalories, 420);
      expect(await storage.guestHasData(), isTrue);
      expect(await storage.guestHasImportableData(), isFalse);
    },
  );

  test('cloud refresh preserves records with a pending local edit', () async {
    await storage.init(userId: null, hivePath: tempDir.path);
    await storage.saveMetrics(
      DailyMetrics(dateKey: '2026-11-10', totalCalories: 420),
    );

    await storage.switchToAccount('user-a');
    await storage.importGuestData();
    expect(storage.pendingChangeCount, greaterThan(0));

    await storage.importCloudData(
      metrics: [DailyMetrics(dateKey: '2026-11-10', totalCalories: 999)],
      overwrite: true,
    );

    expect(storage.getMetricsForDate('2026-11-10')?.totalCalories, 420);
  });

  test('theme preference is device-wide, account settings are not', () async {
    await storage.init(userId: null, hivePath: tempDir.path);
    await storage.saveThemeModeKey('dark');
    await storage.saveSetting('unit_system', 'imperial');

    await storage.switchToAccount('user-a');

    expect(storage.getThemeModeKey(), 'dark');
    expect(storage.getSetting<String>('unit_system', 'metric'), 'metric');
  });
}
