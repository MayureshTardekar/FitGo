import 'package:fitgo/models/goal_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 1, 1);

  test('a realistic loss target becomes a daily calorie and water plan', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 70,
      targetWeightKg: 65,
      targetDate: DateTime(2026, 3, 12),
      tdee: 2400,
      today: today,
    );

    expect(plan.days, 70);
    expect(plan.isLoss, isTrue);
    expect(plan.totalKcal, -38500);
    expect(plan.dailyDelta, -550);
    expect(plan.dailyCalories, 1850);
    expect(plan.dailyWaterMl, 2500);
    expect(plan.weeklyKgChange, closeTo(-0.5, 0.001));
    expect(plan.requestedDateTooAggressive, isFalse);
  });

  test('an aggressive loss date keeps the raw calculated intake', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 70,
      targetWeightKg: 60,
      targetDate: DateTime(2026, 1, 15),
      tdee: 2400,
      today: today,
    );

    expect(plan.dailyDelta, closeTo(-5500, 1));
    expect(plan.dailyCalories, closeTo(-3100, 1));
    expect(plan.requestedDateTooAggressive, isTrue);
  });

  test('positive raw intake below former floor remains unchanged', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 80,
      targetWeightKg: 75,
      targetDate: DateTime(2026, 2, 15),
      tdee: 1800,
      today: today,
    );

    expect(plan.dailyDelta, closeTo(-856, 1));
    expect(plan.dailyCalories, closeTo(944, 1));
    expect(plan.requestedDateTooAggressive, isFalse);
  });

  test('a gain target keeps the raw calculated surplus', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 60,
      targetWeightKg: 65,
      targetDate: DateTime(2026, 3, 12),
      tdee: 2400,
      today: today,
    );

    expect(plan.isGain, isTrue);
    expect(plan.dailyDelta, closeTo(550, 1));
    expect(plan.dailyCalories, closeTo(2950, 1));
    expect(plan.requestedDateTooAggressive, isFalse);
  });

  test('matching the current weight produces a maintenance plan', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 70,
      targetWeightKg: 70,
      targetDate: DateTime(2026, 1, 31),
      tdee: 2400,
      today: today,
    );

    expect(plan.isMaintain, isTrue);
    expect(plan.dailyCalories, 2400);
    expect(plan.dailyDelta, 0);
    expect(plan.totalKcal, 0);
    expect(plan.earliestSafeDate, today);
    expect(plan.requestedDateTooAggressive, isFalse);
  });

  test('a past target date is treated as one day and flagged', () {
    final plan = GoalPlan.calculate(
      currentWeightKg: 70,
      targetWeightKg: 65,
      targetDate: DateTime(2025, 12, 31),
      tdee: 2400,
      today: today,
    );

    expect(plan.days, 1);
    expect(plan.requestedDateTooAggressive, isTrue);
    expect(plan.earliestSafeDate.isAfter(today), isTrue);
  });

  test('water target rounds to the nearest 250 ml', () {
    expect(GoalPlan.waterGoalMlFor(70), 2500);
    expect(GoalPlan.waterGoalMlFor(65), 2250);
    expect(GoalPlan.waterGoalMlFor(60), 2000);
  });

  test('water target never falls below the hydration floor', () {
    expect(GoalPlan.waterGoalMlFor(40), GoalPlan.minDailyWaterMl);
    expect(GoalPlan.waterGoalMlFor(30), GoalPlan.minDailyWaterMl);
    expect(GoalPlan.waterGoalMlFor(20), GoalPlan.minDailyWaterMl);
  });
}
