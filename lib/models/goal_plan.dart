import 'dart:math';

/// A date-based weight goal converted into safe daily targets.
///
/// The estimate uses 7,700 kcal per kilogram, a common approximation for body
/// mass change. A very short deadline is capped at a conservative deficit or
/// surplus instead of recommending a crash diet.
class GoalPlan {
  const GoalPlan({
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.targetDate,
    required this.tdee,
    required this.dailyCalories,
    required this.dailyWaterMl,
    required this.dailyDelta,
    required this.days,
    required this.totalKcal,
    required this.earliestSafeDate,
    required this.requestedDateTooAggressive,
  });

  static const int kcalPerKg = 7700;
  static const int maxDailyDeficit = 750;
  static const int maxDailySurplus = 500;
  static const int minDailyCalories = 1200;
  static const int minDailyWaterMl = 1500;

  final double currentWeightKg;
  final double targetWeightKg;
  final DateTime targetDate;
  final int tdee;
  final int dailyCalories;
  final int dailyWaterMl;

  /// Positive for a surplus, negative for a deficit.
  final int dailyDelta;
  final int days;

  /// Positive for a gain plan, negative for a loss plan.
  final int totalKcal;
  final DateTime earliestSafeDate;
  final bool requestedDateTooAggressive;

  double get totalKgChange => targetWeightKg - currentWeightKg;
  bool get isLoss => totalKgChange < -0.05;
  bool get isGain => totalKgChange > 0.05;
  bool get isMaintain => !isLoss && !isGain;

  double get weeklyKgChange => dailyDelta * 7 / kcalPerKg;

  String get goalType => isLoss
      ? 'lose'
      : isGain
      ? 'gain'
      : 'maintain';

  /// A safe daily water target based on body weight.
  ///
  /// The 1,500 ml floor protects small users and very aggressive plans from
  /// being given a hydration target that is too low.
  static int waterGoalMlFor(double weightKg) {
    final rounded = ((weightKg * 35) / 250).round() * 250;
    return rounded < minDailyWaterMl ? minDailyWaterMl : rounded;
  }

  factory GoalPlan.calculate({
    required double currentWeightKg,
    required double targetWeightKg,
    required DateTime targetDate,
    required int tdee,
    required DateTime today,
  }) {
    assert(currentWeightKg > 0);
    assert(targetWeightKg > 0);
    assert(tdee > 0);

    final todayDay = DateTime(today.year, today.month, today.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final days = max(1, targetDay.difference(todayDay).inDays);
    final kgChange = targetWeightKg - currentWeightKg;
    final totalKcal = (kgChange * kcalPerKg).round();
    final isLoss = kgChange < -0.05;
    final isGain = kgChange > 0.05;

    if (!isLoss && !isGain) {
      return GoalPlan(
        currentWeightKg: currentWeightKg,
        targetWeightKg: targetWeightKg,
        targetDate: targetDay,
        tdee: tdee,
        dailyCalories: tdee,
        dailyWaterMl: waterGoalMlFor(currentWeightKg),
        dailyDelta: 0,
        days: days,
        totalKcal: 0,
        earliestSafeDate: todayDay,
        requestedDateTooAggressive: false,
      );
    }

    final totalMagnitude = totalKcal.abs();
    final requestedDelta = totalKcal / days;
    final dailyCalories = (tdee + requestedDelta).round();
    final safeDays = tdee <= 0
        ? days
        : max(1, (totalMagnitude / tdee).ceil());
    final earliestSafeDate = todayDay.add(Duration(days: safeDays));
    final requestedDateTooAggressive = dailyCalories < 0;

    return GoalPlan(
      currentWeightKg: currentWeightKg,
      targetWeightKg: targetWeightKg,
      targetDate: targetDay,
      tdee: tdee,
      dailyCalories: dailyCalories,
      dailyWaterMl: waterGoalMlFor(currentWeightKg),
      dailyDelta: dailyCalories - tdee,
      days: days,
      totalKcal: totalKcal,
      earliestSafeDate: earliestSafeDate,
      requestedDateTooAggressive: requestedDateTooAggressive,
    );
  }
}
