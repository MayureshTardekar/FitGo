import 'package:fitgo/models/goal_plan.dart';
import 'package:fitgo/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile(String activityLevel) => UserProfile(
  weightKg: 70,
  heightCm: 175,
  age: 30,
  gender: 'male',
  activityLevel: activityLevel,
);

void main() {
  test('activity level changes estimated daily burn', () {
    final sedentary = _profile('sedentary');
    final light = _profile('light');
    final moderate = _profile('moderate');
    final active = _profile('active');

    expect(light.tdee, greaterThan(sedentary.tdee));
    expect(moderate.tdee, greaterThan(light.tdee));
    expect(active.tdee, greaterThan(moderate.tdee));
  });

  test('default calorie goal follows the selected activity level', () {
    final sedentary = _profile('sedentary');
    final active = _profile('active');

    expect(sedentary.calorieGoal, sedentary.tdee);
    expect(active.calorieGoal, active.tdee);
    expect(active.calorieGoal, greaterThan(sedentary.calorieGoal));
  });

  test('copy preserves the activity level and goals', () {
    final original = _profile('moderate')
      ..targetWeightKg = 65
      ..goalTargetDate = '2099-01-01';
    final copy = original.copy();

    expect(copy.activityLevel, 'moderate');
    expect(copy.calorieGoal, original.calorieGoal);
    expect(copy.weeklyCalorieGoal, original.weeklyCalorieGoal);
    expect(copy.targetWeightKg, 65);
    expect(copy.goalTargetDate, '2099-01-01');
  });

  test('default water goal never falls below the hydration floor', () {
    final profile = UserProfile(
      weightKg: 35,
      heightCm: 150,
      age: 30,
      gender: 'female',
    );

    expect(profile.waterGoalMl, GoalPlan.minDailyWaterMl);
  });

  test('a saved target date becomes a goal plan', () {
    final profile = _profile('light')
      ..targetWeightKg = 65
      ..goalTargetDate = '2099-01-01';

    final plan = profile.goalPlan;

    expect(profile.hasGoalPlan, isTrue);
    expect(plan, isNotNull);
    expect(plan!.isLoss, isTrue);
    expect(plan.dailyCalories, greaterThan(0));
    expect(plan.dailyWaterMl, 2500);
  });

  test('an incomplete goal does not produce a plan', () {
    final profile = _profile('light')..targetWeightKg = 65;

    expect(profile.hasGoalPlan, isFalse);
    expect(profile.goalPlan, isNull);
  });

  test('unknown activity levels fall back to the light multiplier', () {
    expect(UserProfile.activityMultiplier('unknown'), 1.4);
  });
}
