import 'package:hive/hive.dart';

import 'goal_plan.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 2)
class UserProfile extends HiveObject {
  @HiveField(0)
  double weightKg;

  @HiveField(1)
  double heightCm;

  @HiveField(2)
  int age; // kept for backward compat, auto-calculated from DOB

  @HiveField(3)
  String gender; // 'male' or 'female'

  @HiveField(4)
  int calorieGoal;

  @HiveField(5)
  int waterGoalMl;

  @HiveField(6, defaultValue: 0)
  int weeklyCalorieGoal;

  @HiveField(7, defaultValue: 'maintain')
  String weightGoal; // 'lose', 'maintain', 'gain', 'custom'

  @HiveField(8, defaultValue: '')
  String dobString; // 'yyyy-MM-dd' date of birth

  @HiveField(9, defaultValue: 'light')
  String activityLevel; // 'sedentary', 'light', 'moderate', 'active'

  @HiveField(10, defaultValue: 0)
  double targetWeightKg;

  @HiveField(11, defaultValue: '')
  String goalTargetDate; // 'yyyy-MM-dd'

  UserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    int? calorieGoal,
    int? waterGoalMl,
    int? weeklyCalorieGoal,
    this.weightGoal = 'maintain',
    this.dobString = '',
    this.activityLevel = 'light',
    this.targetWeightKg = 0,
    this.goalTargetDate = '',
  }) : calorieGoal =
           calorieGoal ??
           _calcCalorieGoal(
             weightKg,
             heightCm,
             age,
             gender,
             activityLevel: activityLevel,
           ),
       waterGoalMl = waterGoalMl ?? _calcWaterGoal(weightKg),
       weeklyCalorieGoal = (weeklyCalorieGoal == null || weeklyCalorieGoal == 0)
           ? _calcWeeklyCalorieGoal(
               weightKg,
               heightCm,
               age,
               gender,
               weightGoal,
               activityLevel: activityLevel,
             )
           : weeklyCalorieGoal;

  /// Age from DOB
  static int ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  /// The daily quota derived from weekly goal
  int get dailyQuota =>
      weeklyCalorieGoal > 0 ? (weeklyCalorieGoal / 7).round() : calorieGoal;

  /// Mifflin-St Jeor BMR × activity multiplier → TDEE.
  static double activityMultiplier(String level) {
    return switch (level) {
      'sedentary' => 1.2,
      'moderate' => 1.55,
      'active' => 1.725,
      _ => 1.4,
    };
  }

  static const activityLevels = ['sedentary', 'light', 'moderate', 'active'];

  static int _calcCalorieGoal(
    double weight,
    double height,
    int age,
    String gender, {
    String activityLevel = 'light',
  }) {
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    return (bmr * activityMultiplier(activityLevel)).round();
  }

  /// ~35ml per kg body weight, never below the hydration floor.
  static int _calcWaterGoal(double weight) {
    return GoalPlan.waterGoalMlFor(weight);
  }

  /// Weekly calorie goal based on weight goal
  static int _calcWeeklyCalorieGoal(
    double weight,
    double height,
    int age,
    String gender,
    String goal, {
    String activityLevel = 'light',
  }) {
    final dailyTdee = _calcCalorieGoal(
      weight,
      height,
      age,
      gender,
      activityLevel: activityLevel,
    );
    switch (goal) {
      case 'lose':
        return (dailyTdee - 500) * 7;
      case 'gain':
        return (dailyTdee + 300) * 7;
      default:
        return dailyTdee * 7;
    }
  }

  int get tdee => _calcCalorieGoal(
    weightKg,
    heightCm,
    age,
    gender,
    activityLevel: activityLevel,
  );
  int get suggestedCalorieGoal => tdee;
  int get suggestedWaterGoal => _calcWaterGoal(weightKg);
  int get suggestedWeeklyGoal => _calcWeeklyCalorieGoal(
    weightKg,
    heightCm,
    age,
    gender,
    weightGoal,
    activityLevel: activityLevel,
  );

  /// Surplus or deficit per day vs TDEE
  int get dailySurplusDeficit => dailyQuota - tdee;

  DateTime? get goalTargetDateValue => DateTime.tryParse(goalTargetDate);

  bool get hasGoalPlan => targetWeightKg > 0 && goalTargetDateValue != null;

  /// The saved target date converted into daily targets, or null when no
  /// target weight/date has been chosen yet.
  GoalPlan? goalPlanFor([DateTime? today]) {
    final date = goalTargetDateValue;
    if (targetWeightKg <= 0 || date == null) return null;
    return GoalPlan.calculate(
      currentWeightKg: weightKg,
      targetWeightKg: targetWeightKg,
      targetDate: date,
      tdee: tdee,
      today: today ?? DateTime.now(),
    );
  }

  GoalPlan? get goalPlan => goalPlanFor();

  /// Detached copy, safe to store in a different Hive box or account cache.
  UserProfile copy() => UserProfile(
    weightKg: weightKg,
    heightCm: heightCm,
    age: age,
    gender: gender,
    calorieGoal: calorieGoal,
    waterGoalMl: waterGoalMl,
    weeklyCalorieGoal: weeklyCalorieGoal,
    weightGoal: weightGoal,
    dobString: dobString,
    activityLevel: activityLevel,
    targetWeightKg: targetWeightKg,
    goalTargetDate: goalTargetDate,
  );
}
