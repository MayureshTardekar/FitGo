import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_metrics.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

class NutritionTargets {
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;
  final int sugarGrams;

  const NutritionTargets({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.sugarGrams,
  });
}

class NutritionEntry {
  final String label;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;
  final int sugarGrams;

  const NutritionEntry({
    required this.label,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
  });

  String toStorageString() {
    final cleanLabel = label.trim().isEmpty
        ? 'Food'
        : label.trim().replaceAll('|', '/');
    return [
      cleanLabel,
      calories,
      proteinGrams,
      carbsGrams,
      fatGrams,
      fiberGrams,
      sugarGrams,
    ].join('|');
  }

  static NutritionEntry fromStorageString(String value) {
    final parts = value.split('|');
    if (parts.length < 7) {
      throw const FormatException('Invalid nutrition entry');
    }

    return NutritionEntry(
      label: parts[0],
      calories: int.tryParse(parts[1]) ?? 0,
      proteinGrams: int.tryParse(parts[2]) ?? 0,
      carbsGrams: int.tryParse(parts[3]) ?? 0,
      fatGrams: int.tryParse(parts[4]) ?? 0,
      fiberGrams: int.tryParse(parts[5]) ?? 0,
      sugarGrams: int.tryParse(parts[6]) ?? 0,
    );
  }
}

class NutritionState {
  final int totalCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int fiberGrams;
  final int sugarGrams;
  final List<NutritionEntry> entries;
  final NutritionTargets targets;

  const NutritionState({
    this.totalCalories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    this.entries = const [],
    required this.targets,
  });

  int get macroCalories => proteinGrams * 4 + carbsGrams * 4 + fatGrams * 9;

  int get remainingCalories => targets.calories - totalCalories;

  double progressFor(int value, int target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }
}

class NutritionNotifier extends Notifier<NutritionState> {
  @override
  NutritionState build() {
    ref.watch(profileProvider);
    return _loadState();
  }

  NutritionState _loadState() {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    final profile = ref.read(profileProvider);
    final dailyCalories = profile?.dailyQuota ?? profile?.calorieGoal ?? 2000;
    final weightKg = profile?.weightKg ?? 70.0;
    final targets = _buildTargets(dailyCalories, weightKg);

    return NutritionState(
      totalCalories: today.totalCalories,
      proteinGrams: today.proteinGrams,
      carbsGrams: today.carbsGrams,
      fatGrams: today.fatGrams,
      fiberGrams: today.fiberGrams,
      sugarGrams: today.sugarGrams,
      entries: _readEntries(today),
      targets: targets,
    );
  }

  NutritionTargets _buildTargets(int calories, double weightKg) {
    final protein = _clampInt((weightKg * 1.6).round(), 70, 220);
    final fat = _clampInt((calories * 0.27 / 9).round(), 35, 120);
    final carbsRaw = (calories - protein * 4 - fat * 9) / 4;
    final carbs = carbsRaw < 80
        ? 80
        : carbsRaw > 420
        ? 420
        : carbsRaw.round();
    final fiber = calories >= 1800 ? 30 : 25;
    final sugar = _clampInt((calories * 0.10 / 4).round(), 25, 65);

    return NutritionTargets(
      calories: calories,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      fiberGrams: fiber,
      sugarGrams: sugar,
    );
  }

  List<NutritionEntry> _readEntries(DailyMetrics today) {
    final entries = <NutritionEntry>[];

    for (final value in today.nutritionEntries) {
      try {
        entries.add(NutritionEntry.fromStorageString(value));
      } catch (_) {
        // Ignore malformed old/local entries.
      }
    }

    if (entries.isEmpty && today.calorieEntries.isNotEmpty) {
      return today.calorieEntries
          .map(
            (calories) => NutritionEntry(label: 'Calories', calories: calories),
          )
          .toList();
    }

    return entries;
  }

  void addCalories(int amount) {
    addNutrition(label: 'Quick add', calories: amount);
  }

  void addNutrition({
    required int calories,
    String label = 'Food',
    int proteinGrams = 0,
    int carbsGrams = 0,
    int fatGrams = 0,
    int fiberGrams = 0,
    int sugarGrams = 0,
  }) {
    if (calories <= 0) return;

    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    final entry = NutritionEntry(
      label: label,
      calories: calories,
      proteinGrams: _clampInt(proteinGrams, 0, 500),
      carbsGrams: _clampInt(carbsGrams, 0, 800),
      fatGrams: _clampInt(fatGrams, 0, 400),
      fiberGrams: _clampInt(fiberGrams, 0, 200),
      sugarGrams: _clampInt(sugarGrams, 0, 400),
    );

    today.totalCalories += entry.calories;
    today.proteinGrams += entry.proteinGrams;
    today.carbsGrams += entry.carbsGrams;
    today.fatGrams += entry.fatGrams;
    today.fiberGrams += entry.fiberGrams;
    today.sugarGrams += entry.sugarGrams;
    today.calorieEntries.add(entry.calories);
    today.nutritionEntries.add(entry.toStorageString());
    storage.saveMetrics(today);
    state = _loadState();
  }

  void setCalories(int total) {
    setNutrition(
      calories: total,
      proteinGrams: state.proteinGrams,
      carbsGrams: state.carbsGrams,
      fatGrams: state.fatGrams,
      fiberGrams: state.fiberGrams,
      sugarGrams: state.sugarGrams,
    );
  }

  void setNutrition({
    required int calories,
    required int proteinGrams,
    required int carbsGrams,
    required int fatGrams,
    required int fiberGrams,
    required int sugarGrams,
  }) {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();

    today.totalCalories = _clampInt(calories, 0, 20000);
    today.proteinGrams = _clampInt(proteinGrams, 0, 500);
    today.carbsGrams = _clampInt(carbsGrams, 0, 800);
    today.fatGrams = _clampInt(fatGrams, 0, 400);
    today.fiberGrams = _clampInt(fiberGrams, 0, 200);
    today.sugarGrams = _clampInt(sugarGrams, 0, 400);
    today.calorieEntries = today.totalCalories > 0 ? [today.totalCalories] : [];
    today.nutritionEntries = today.totalCalories > 0
        ? [
            NutritionEntry(
              label: 'Manual total',
              calories: today.totalCalories,
              proteinGrams: today.proteinGrams,
              carbsGrams: today.carbsGrams,
              fatGrams: today.fatGrams,
              fiberGrams: today.fiberGrams,
              sugarGrams: today.sugarGrams,
            ).toStorageString(),
          ]
        : [];

    storage.saveMetrics(today);
    state = _loadState();
  }
}

final nutritionProvider = NotifierProvider<NutritionNotifier, NutritionState>(
  NutritionNotifier.new,
);

class CalorieNotifier extends Notifier<int> {
  @override
  int build() {
    return ref.watch(nutritionProvider).totalCalories;
  }

  void addCalories(int amount) {
    ref.read(nutritionProvider.notifier).addCalories(amount);
  }

  void setCalories(int total) {
    ref.read(nutritionProvider.notifier).setCalories(total);
  }
}

final calorieProvider = NotifierProvider<CalorieNotifier, int>(
  CalorieNotifier.new,
);
