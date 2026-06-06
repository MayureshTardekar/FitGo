import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../models/daily_metrics.dart';
import 'calorie_provider.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';
import 'water_provider.dart';

enum WeeklyPlanKind { limit, goal }

class WeeklyPlanItem {
  final String key;
  final String label;
  final String unit;
  final WeeklyPlanKind kind;
  final int consumed;
  final int target;
  final int consumedBeforeToday;
  final int todayConsumed;
  final int yesterdayConsumed;
  final int adjustedTodayTarget;
  final int adjustedNextDayTarget;

  const WeeklyPlanItem({
    required this.key,
    required this.label,
    required this.unit,
    required this.kind,
    required this.consumed,
    required this.target,
    required this.consumedBeforeToday,
    required this.todayConsumed,
    required this.yesterdayConsumed,
    required this.adjustedTodayTarget,
    required this.adjustedNextDayTarget,
  });

  int get remaining => target - consumed;
  int get leftForToday => adjustedTodayTarget - todayConsumed;
  bool get isLimit => kind == WeeklyPlanKind.limit;
  bool get isGoal => kind == WeeklyPlanKind.goal;
  bool get isOverWeekly => isLimit && consumed > target;
  bool get isTodayOver => isLimit && todayConsumed > adjustedTodayTarget;
  bool get isClose => isLimit && progress >= 0.85 && !isOverWeekly;
  bool get isBehindGoal => isGoal && consumed < target;
  double get progress =>
      target > 0 ? (consumed / target).clamp(0.0, 1.0).toDouble() : 0.0;

  String amount(int value) => unit == 'ml' ? '$value ml' : '$value $unit';
}

class WeeklyNutritionPlanState {
  final bool enabled;
  final String weekLabel;
  final String startDateKey;
  final int cycleDay;
  final int consistencyStreak;
  final int daysIncludingToday;
  final List<WeeklyPlanItem> items;
  final String headline;
  final String guidance;

  const WeeklyNutritionPlanState({
    required this.enabled,
    required this.weekLabel,
    required this.startDateKey,
    required this.cycleDay,
    required this.consistencyStreak,
    required this.daysIncludingToday,
    required this.items,
    required this.headline,
    required this.guidance,
  });

  WeeklyPlanItem item(String key) =>
      items.firstWhere((item) => item.key == key);
}

class WeeklyNutritionPlanNotifier extends Notifier<WeeklyNutritionPlanState> {
  static const _targetPrefix = 'weekly_plan_target_';
  static const _startDateKey = 'weekly_plan_start_date';
  static const _enabledKey = 'weekly_plan_enabled';

  @override
  WeeklyNutritionPlanState build() {
    ref.watch(nutritionProvider);
    ref.watch(waterProvider);
    ref.watch(profileProvider);
    return _calculate();
  }

  WeeklyNutritionPlanState _calculate() {
    final storage = ref.read(localStorageProvider);
    final profile = ref.read(profileProvider);
    final nutrition = ref.read(nutritionProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final enabled = storage.getSetting<bool>(_enabledKey, false);
    final yesterdayKey = DateFormat(
      'yyyy-MM-dd',
    ).format(today.subtract(const Duration(days: 1)));
    final savedStart = DateTime.tryParse(
      storage.getSetting<String>(_startDateKey, ''),
    );
    final anchor = savedStart == null
        ? today
        : DateTime(savedStart.year, savedStart.month, savedStart.day);

    final daysFromAnchor = today.difference(anchor).inDays;
    final cycleOffset = daysFromAnchor >= 0 ? (daysFromAnchor ~/ 7) * 7 : 0;
    final cycleStart = daysFromAnchor >= 0
        ? anchor.add(Duration(days: cycleOffset))
        : today;
    final cycleEnd = cycleStart.add(const Duration(days: 6));
    final weekMetrics = storage.getMetricsRange(cycleStart, cycleEnd);
    final daysIncludingToday =
        cycleEnd.difference(today).inDays.clamp(0, 6).toInt() + 1;

    final defaultTargets = {
      'calories':
          profile?.weeklyCalorieGoal ?? AppConstants.dailyCalorieGoalKcal * 7,
      'protein': nutrition.targets.proteinGrams * 7,
      'carbs': nutrition.targets.carbsGrams * 7,
      'fat': nutrition.targets.fatGrams * 7,
      'fiber': nutrition.targets.fiberGrams * 7,
      'sugar': nutrition.targets.sugarGrams * 7,
      'water': (profile?.waterGoalMl ?? AppConstants.dailyWaterGoalMl) * 7,
    };

    int targetFor(String key) {
      return storage.getSetting<int>(
        '$_targetPrefix$key',
        defaultTargets[key]!,
      );
    }

    int sumFor(String key) {
      return weekMetrics.fold<int>(0, (sum, day) => sum + _valueFor(day, key));
    }

    int beforeTodayFor(String key) {
      return weekMetrics
          .where((day) => day.dateKey.compareTo(todayKey) < 0)
          .fold<int>(0, (sum, day) => sum + _valueFor(day, key));
    }

    int todayFor(String key) {
      return weekMetrics
          .where((day) => day.dateKey == todayKey)
          .fold<int>(0, (sum, day) => sum + _valueFor(day, key));
    }

    int yesterdayFor(String key) {
      return weekMetrics
          .where((day) => day.dateKey == yesterdayKey)
          .fold<int>(0, (sum, day) => sum + _valueFor(day, key));
    }

    WeeklyPlanItem item({
      required String key,
      required String label,
      required String unit,
      required WeeklyPlanKind kind,
    }) {
      final target = targetFor(key);
      final consumedBeforeToday = beforeTodayFor(key);
      final adjustedTodayTarget = daysIncludingToday > 0
          ? ((target - consumedBeforeToday) / daysIncludingToday).round()
          : target;
      final remainingAfterToday = target - sumFor(key);
      final nextDays = daysIncludingToday - 1;

      return WeeklyPlanItem(
        key: key,
        label: label,
        unit: unit,
        kind: kind,
        consumed: sumFor(key),
        target: target,
        consumedBeforeToday: consumedBeforeToday,
        todayConsumed: todayFor(key),
        yesterdayConsumed: yesterdayFor(key),
        adjustedTodayTarget: adjustedTodayTarget < 0 ? 0 : adjustedTodayTarget,
        adjustedNextDayTarget: nextDays > 0
            ? (remainingAfterToday / nextDays).round().clamp(0, target).toInt()
            : 0,
      );
    }

    final items = [
      item(
        key: 'calories',
        label: 'Calories',
        unit: 'kcal',
        kind: WeeklyPlanKind.limit,
      ),
      item(key: 'carbs', label: 'Carbs', unit: 'g', kind: WeeklyPlanKind.limit),
      item(key: 'fat', label: 'Fat', unit: 'g', kind: WeeklyPlanKind.limit),
      item(key: 'sugar', label: 'Sugar', unit: 'g', kind: WeeklyPlanKind.limit),
      item(
        key: 'protein',
        label: 'Protein',
        unit: 'g',
        kind: WeeklyPlanKind.goal,
      ),
      item(key: 'fiber', label: 'Fiber', unit: 'g', kind: WeeklyPlanKind.goal),
      item(key: 'water', label: 'Water', unit: 'ml', kind: WeeklyPlanKind.goal),
    ];

    final coach = _coach(items);
    final consistencyStreak = _consistencyStreak(
      weekMetrics,
      cycleStart,
      today,
      items,
    );

    return WeeklyNutritionPlanState(
      enabled: enabled,
      weekLabel:
          '${DateFormat('MMM d').format(cycleStart)} - ${DateFormat('MMM d').format(cycleEnd)}',
      startDateKey: DateFormat('yyyy-MM-dd').format(cycleStart),
      cycleDay: today.difference(cycleStart).inDays.clamp(0, 6).toInt() + 1,
      consistencyStreak: consistencyStreak,
      daysIncludingToday: daysIncludingToday,
      items: items,
      headline: coach.$1,
      guidance: coach.$2,
    );
  }

  int _valueFor(DailyMetrics day, String key) {
    return switch (key) {
      'calories' => day.totalCalories,
      'protein' => day.proteinGrams,
      'carbs' => day.carbsGrams,
      'fat' => day.fatGrams,
      'fiber' => day.fiberGrams,
      'sugar' => day.sugarGrams,
      'water' => day.waterMl,
      _ => 0,
    };
  }

  int _consistencyStreak(
    List<DailyMetrics> metrics,
    DateTime cycleStart,
    DateTime today,
    List<WeeklyPlanItem> items,
  ) {
    final targets = {
      for (final item in items.where((item) => item.isLimit))
        item.key: (item.target / 7).ceil(),
    };

    int streak = 0;
    for (
      var date = today;
      !date.isBefore(cycleStart);
      date = date.subtract(const Duration(days: 1))
    ) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      final day = metrics.firstWhere(
        (metric) => metric.dateKey == key,
        orElse: () => DailyMetrics(dateKey: key),
      );
      final hasProgress =
          day.totalCalories > 0 || day.waterMl > 0 || day.steps > 0;
      if (!hasProgress) break;

      final insideLimits =
          day.totalCalories <= (targets['calories'] ?? 999999) &&
          day.carbsGrams <= (targets['carbs'] ?? 999999) &&
          day.fatGrams <= (targets['fat'] ?? 999999) &&
          day.sugarGrams <= (targets['sugar'] ?? 999999);
      if (!insideLimits) break;
      streak++;
    }
    return streak;
  }

  (String, String) _coach(List<WeeklyPlanItem> items) {
    final limits = items.where((item) => item.isLimit).toList();
    final overWeekly = limits.where((item) => item.isOverWeekly).toList()
      ..sort(
        (a, b) => (b.consumed - b.target).compareTo(a.consumed - a.target),
      );
    if (overWeekly.isNotEmpty) {
      final top = overWeekly.first;
      return (
        '${top.label} plan limit crossed',
        'You are ${top.amount(top.consumed - top.target)} over your 7-day ${top.label.toLowerCase()} limit. Pause ${top.label.toLowerCase()}-heavy foods today, hydrate, and keep the next meal light.',
      );
    }

    final todayOver = limits.where((item) => item.isTodayOver).toList()
      ..sort((a, b) => b.leftForToday.abs().compareTo(a.leftForToday.abs()));
    if (todayOver.isNotEmpty) {
      final top = todayOver.first;
      return (
        'Pause ${top.label} today',
        'Today you logged ${top.amount(top.todayConsumed)} against a ${top.amount(top.adjustedTodayTarget)} target. Switch to water and clean protein/fiber; avoid extra carbs and fats.',
      );
    }

    final close = limits.where((item) => item.isClose).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    if (close.isNotEmpty) {
      final top = close.first;
      return (
        '${top.label} is tight',
        '${top.amount(top.remaining)} left for this 7-day plan. Keep today controlled; tomorrow should stay near ${top.amount(top.adjustedNextDayTarget)}.',
      );
    }

    final water = items.firstWhere((item) => item.key == 'water');
    if (water.isBehindGoal) {
      return (
        'Plan under control',
        'Macros are under control. You are ${water.amount(water.target - water.consumed)} short on water for this plan, so prioritize hydration.',
      );
    }

    final protein = items.firstWhere((item) => item.key == 'protein');
    if (protein.isBehindGoal) {
      return (
        'Protein pending',
        'You are ${protein.amount(protein.target - protein.consumed)} short on protein for this plan. Make the next meal protein-forward.',
      );
    }

    return (
      'Plan is clean',
      'You are within target. Keep water steady and avoid unnecessary snacks.',
    );
  }

  Future<void> updateTargets({
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? fiber,
    int? sugar,
    int? water,
  }) async {
    final storage = ref.read(localStorageProvider);
    final updates = {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'water': water,
    };

    for (final entry in updates.entries) {
      final value = entry.value;
      if (value != null && value > 0) {
        await storage.saveSetting('$_targetPrefix${entry.key}', value);
      }
    }

    state = _calculate();
  }

  Future<void> resetStartDate(DateTime startDate) async {
    final normalized = DateTime(startDate.year, startDate.month, startDate.day);
    await ref
        .read(localStorageProvider)
        .saveSetting(
          _startDateKey,
          DateFormat('yyyy-MM-dd').format(normalized),
        );
    state = _calculate();
  }

  Future<void> setEnabled(bool enabled) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveSetting(_enabledKey, enabled);
    if (enabled) {
      final current = storage.getSetting<String>(_startDateKey, '');
      if (current.isEmpty) {
        await resetStartDate(DateTime.now());
        return;
      }
    }
    state = _calculate();
  }

  Future<void> startToday() async {
    final storage = ref.read(localStorageProvider);
    await storage.saveSetting(_enabledKey, true);
    await resetStartDate(DateTime.now());
  }
}

final weeklyNutritionPlanProvider =
    NotifierProvider<WeeklyNutritionPlanNotifier, WeeklyNutritionPlanState>(
      WeeklyNutritionPlanNotifier.new,
    );
