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
    final original = _profile('moderate');
    final copy = original.copy();

    expect(copy.activityLevel, 'moderate');
    expect(copy.calorieGoal, original.calorieGoal);
    expect(copy.weeklyCalorieGoal, original.weeklyCalorieGoal);
  });

  test('unknown activity levels fall back to the light multiplier', () {
    expect(UserProfile.activityMultiplier('unknown'), 1.4);
  });
}
