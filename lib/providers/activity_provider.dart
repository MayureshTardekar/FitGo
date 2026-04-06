import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_provider.dart';
import 'storage_provider.dart';

/// MET values for common activities
/// MET × weight(kg) × duration(hours) = calories burned
class ActivityPreset {
  final String name;
  final String icon;
  final double met;

  const ActivityPreset(this.name, this.icon, this.met);
}

const activityPresets = [
  ActivityPreset('Walking', '🚶', 3.5),
  ActivityPreset('Running', '🏃', 9.8),
  ActivityPreset('Cycling', '🚴', 7.5),
  ActivityPreset('Swimming', '🏊', 8.0),
  ActivityPreset('Gym / Weights', '🏋️', 6.0),
  ActivityPreset('Yoga', '🧘', 3.0),
  ActivityPreset('HIIT', '💪', 10.0),
  ActivityPreset('Dancing', '💃', 5.5),
  ActivityPreset('Sports', '⚽', 7.0),
  ActivityPreset('Household', '🏠', 3.3),
  ActivityPreset('Stretching', '🤸', 2.5),
  ActivityPreset('Stairs', '🪜', 8.0),
];

class ActivityState {
  final int steps;
  final int stepCalories;
  final int activityCalories;
  final int totalBurned;
  final List<LoggedActivity> activities;
  final int sleepMinutes;
  final String bedtime;
  final String wakeTime;

  const ActivityState({
    this.steps = 0,
    this.stepCalories = 0,
    this.activityCalories = 0,
    this.totalBurned = 0,
    this.activities = const [],
    this.sleepMinutes = 0,
    this.bedtime = '',
    this.wakeTime = '',
  });
}

class LoggedActivity {
  final String name;
  final int minutes;
  final int caloriesBurned;

  const LoggedActivity(this.name, this.minutes, this.caloriesBurned);

  String toStorageString() => '$name|$minutes|$caloriesBurned';

  static LoggedActivity fromStorageString(String s) {
    final parts = s.split('|');
    return LoggedActivity(
      parts[0],
      int.tryParse(parts[1]) ?? 0,
      int.tryParse(parts[2]) ?? 0,
    );
  }
}

class ActivityNotifier extends Notifier<ActivityState> {
  @override
  ActivityState build() {
    try {
      return _loadState();
    } catch (_) {
      return const ActivityState();
    }
  }

  ActivityState _loadState() {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    final profile = ref.read(profileProvider);
    final weightKg = profile?.weightKg ?? 70.0;

    final activityStrings = today.activities;
    final activities = <LoggedActivity>[];
    for (final s in activityStrings) {
      try {
        activities.add(LoggedActivity.fromStorageString(s));
      } catch (_) {
        // Skip malformed entries
      }
    }

    final activityCals = activities.fold<int>(
      0,
      (sum, a) => sum + a.caloriesBurned,
    );
    final stepCals = _calcStepCalories(today.steps, weightKg);

    return ActivityState(
      steps: today.steps,
      stepCalories: stepCals,
      activityCalories: activityCals,
      totalBurned: stepCals + activityCals,
      activities: activities,
      sleepMinutes: today.sleepMinutes,
      bedtime: today.sleepBedtime,
      wakeTime: today.sleepWakeTime,
    );
  }

  /// ~0.04 kcal per step per kg body weight (average)
  /// More precise: steps × stride_length(m) × 0.57(kcal/kg/km) × weight(kg)
  static int _calcStepCalories(int steps, double weightKg) {
    if (steps <= 0) return 0;
    // Average stride ~0.75m, so distance = steps × 0.00075 km
    // Calories = distance(km) × weight(kg) × 0.57
    final distanceKm = steps * 0.00075;
    return (distanceKm * weightKg * 0.57).round();
  }

  void updateSteps(int steps) {
    final storage = ref.read(localStorageProvider);
    final profile = ref.read(profileProvider);
    final today = storage.getToday();

    today.steps = steps;
    final stepCals = _calcStepCalories(steps, profile?.weightKg ?? 70);
    final activityCals = state.activityCalories;
    today.caloriesBurned = stepCals + activityCals;
    storage.saveMetrics(today);

    state = ActivityState(
      steps: steps,
      stepCalories: stepCals,
      activityCalories: activityCals,
      totalBurned: stepCals + activityCals,
      activities: state.activities,
      sleepMinutes: state.sleepMinutes,
      bedtime: state.bedtime,
      wakeTime: state.wakeTime,
    );
  }

  void addActivity(String name, int minutes, double met) {
    final storage = ref.read(localStorageProvider);
    final profile = ref.read(profileProvider);
    final today = storage.getToday();
    final weightKg = profile?.weightKg ?? 70;

    // MET × weight(kg) × duration(hours)
    final burned = (met * weightKg * (minutes / 60)).round();
    final activity = LoggedActivity(name, minutes, burned);

    today.activities.add(activity.toStorageString());
    final activityCals = state.activityCalories + burned;
    today.caloriesBurned = state.stepCalories + activityCals;
    storage.saveMetrics(today);

    state = ActivityState(
      steps: state.steps,
      stepCalories: state.stepCalories,
      activityCalories: activityCals,
      totalBurned: state.stepCalories + activityCals,
      activities: [...state.activities, activity],
      sleepMinutes: state.sleepMinutes,
      bedtime: state.bedtime,
      wakeTime: state.wakeTime,
    );
  }

  void updateSleep({
    required String bedtime,
    required String wakeTime,
    required int minutes,
  }) {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    today.sleepBedtime = bedtime;
    today.sleepWakeTime = wakeTime;
    today.sleepMinutes = minutes;
    storage.saveMetrics(today);

    state = ActivityState(
      steps: state.steps,
      stepCalories: state.stepCalories,
      activityCalories: state.activityCalories,
      totalBurned: state.totalBurned,
      activities: state.activities,
      sleepMinutes: minutes,
      bedtime: bedtime,
      wakeTime: wakeTime,
    );
  }
}

final activityProvider = NotifierProvider<ActivityNotifier, ActivityState>(
  ActivityNotifier.new,
);
