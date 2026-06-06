import 'package:hive/hive.dart';

part 'daily_metrics.g.dart';

@HiveType(typeId: 0)
class DailyMetrics extends HiveObject {
  @HiveField(0)
  final String dateKey;

  @HiveField(1)
  int totalCalories;

  @HiveField(2)
  int waterMl;

  @HiveField(3)
  double? weight;

  @HiveField(4)
  int? fastingStartEpoch;

  @HiveField(5)
  int fastingDurationMinutes;

  @HiveField(6)
  List<int> calorieEntries;

  // ─── New fields ────────────────────────────────────────────────────────

  @HiveField(7, defaultValue: 0)
  int steps;

  @HiveField(8, defaultValue: 0)
  int caloriesBurned; // total from steps + activities

  @HiveField(9, defaultValue: <String>[])
  List<String> activities; // stored as "name|minutes|caloriesBurned"

  @HiveField(10, defaultValue: 0)
  int sleepMinutes;

  @HiveField(11, defaultValue: '')
  String sleepBedtime; // "HH:mm"

  @HiveField(12, defaultValue: '')
  String sleepWakeTime; // "HH:mm"

  @HiveField(13, defaultValue: 0)
  int proteinGrams;

  @HiveField(14, defaultValue: 0)
  int carbsGrams;

  @HiveField(15, defaultValue: 0)
  int fatGrams;

  @HiveField(16, defaultValue: 0)
  int fiberGrams;

  @HiveField(17, defaultValue: 0)
  int sugarGrams;

  @HiveField(18, defaultValue: <String>[])
  List<String> nutritionEntries; // "label|calories|protein|carbs|fat|fiber|sugar"

  @HiveField(19, defaultValue: 60)
  int fastingReminderMinutes;

  @HiveField(20, defaultValue: true)
  bool fastingReminderEnabled;

  @HiveField(21)
  int? fastingLastReminderEpoch;

  DailyMetrics({
    required this.dateKey,
    this.totalCalories = 0,
    this.waterMl = 0,
    this.weight,
    this.fastingStartEpoch,
    this.fastingDurationMinutes = 960,
    List<int>? calorieEntries,
    this.steps = 0,
    this.caloriesBurned = 0,
    List<String>? activities,
    this.sleepMinutes = 0,
    this.sleepBedtime = '',
    this.sleepWakeTime = '',
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.sugarGrams = 0,
    List<String>? nutritionEntries,
    this.fastingReminderMinutes = 60,
    this.fastingReminderEnabled = true,
    this.fastingLastReminderEpoch,
  }) : calorieEntries = calorieEntries ?? [],
       activities = activities ?? [],
       nutritionEntries = nutritionEntries ?? [];

  /// Net calories = eaten - burned
  int get netCalories => totalCalories - caloriesBurned;
}
