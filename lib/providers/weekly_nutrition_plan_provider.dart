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
  final String weekLabel;
  final int daysIncludingToday;
  final List<WeeklyPlanItem> items;
  final String headline;
  final String guidance;

  const WeeklyNutritionPlanState({
    required this.weekLabel,
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
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayKey = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 1)));
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekMetrics = storage.getCurrentWeekMetrics();
    final daysIncludingToday = 8 - now.weekday;

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
    final weekEnd = monday.add(const Duration(days: 6));

    return WeeklyNutritionPlanState(
      weekLabel:
          '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(weekEnd)}',
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

  (String, String) _coach(List<WeeklyPlanItem> items) {
    final limits = items.where((item) => item.isLimit).toList();
    final overWeekly = limits.where((item) => item.isOverWeekly).toList()
      ..sort(
        (a, b) => (b.consumed - b.target).compareTo(a.consumed - a.target),
      );
    if (overWeekly.isNotEmpty) {
      final top = overWeekly.first;
      return (
        '${top.label} weekly limit crossed',
        '${top.amount(top.consumed - top.target)} extra ho gaya. Aaj ${top.label.toLowerCase()} stop, water piyo, next meal light rakho.',
      );
    }

    final todayOver = limits.where((item) => item.isTodayOver).toList()
      ..sort((a, b) => b.leftForToday.abs().compareTo(a.leftForToday.abs()));
    if (todayOver.isNotEmpty) {
      final top = todayOver.first;
      return (
        '${top.label} stop for today',
        'Aaj ${top.amount(top.todayConsumed)} ho gaya, target ${top.amount(top.adjustedTodayTarget)} tha. Ab water, protein/fiber clean, carbs/fat avoid.',
      );
    }

    final close = limits.where((item) => item.isClose).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    if (close.isNotEmpty) {
      final top = close.first;
      return (
        '${top.label} tight hai',
        '${top.amount(top.remaining)} left for week. Aaj controlled rakho, kal ka budget ${top.amount(top.adjustedNextDayTarget)} ke around hoga.',
      );
    }

    final water = items.firstWhere((item) => item.key == 'water');
    if (water.isBehindGoal) {
      return (
        'Plan under control',
        'Macros okay. Water ${water.amount(water.target - water.consumed)} short hai this week, pehle hydration complete karo.',
      );
    }

    final protein = items.firstWhere((item) => item.key == 'protein');
    if (protein.isBehindGoal) {
      return (
        'Protein pending',
        '${protein.amount(protein.target - protein.consumed)} protein short hai week ke liye. Next meal lean protein rakho.',
      );
    }

    return (
      'Plan clean hai',
      'Aaj ka execution simple: targets ke andar ho, water maintain karo, unnecessary snacks avoid.',
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
}

final weeklyNutritionPlanProvider =
    NotifierProvider<WeeklyNutritionPlanNotifier, WeeklyNutritionPlanState>(
      WeeklyNutritionPlanNotifier.new,
    );
