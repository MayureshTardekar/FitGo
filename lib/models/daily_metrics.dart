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
  }) : calorieEntries = calorieEntries ?? [],
       activities = activities ?? [];

  /// Net calories = eaten - burned
  int get netCalories => totalCalories - caloriesBurned;
}
