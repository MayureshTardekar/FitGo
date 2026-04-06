import 'package:hive/hive.dart';

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
  }) : calorieGoal =
           calorieGoal ?? _calcCalorieGoal(weightKg, heightCm, age, gender),
       waterGoalMl = waterGoalMl ?? _calcWaterGoal(weightKg),
       weeklyCalorieGoal = (weeklyCalorieGoal == null || weeklyCalorieGoal == 0)
           ? _calcWeeklyCalorieGoal(weightKg, heightCm, age, gender, weightGoal)
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

  /// Mifflin-St Jeor BMR → TDEE
  static int _calcCalorieGoal(
    double weight,
    double height,
    int age,
    String gender,
  ) {
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    return (bmr * 1.4).round();
  }

  /// ~35ml per kg body weight
  static int _calcWaterGoal(double weight) {
    return ((weight * 35) / 250).round() * 250;
  }

  /// Weekly calorie goal based on weight goal
  static int _calcWeeklyCalorieGoal(
    double weight,
    double height,
    int age,
    String gender,
    String goal,
  ) {
    final dailyTdee = _calcCalorieGoal(weight, height, age, gender);
    switch (goal) {
      case 'lose':
        return (dailyTdee - 500) * 7;
      case 'gain':
        return (dailyTdee + 300) * 7;
      default:
        return dailyTdee * 7;
    }
  }

  int get tdee => _calcCalorieGoal(weightKg, heightCm, age, gender);
  int get suggestedCalorieGoal => tdee;
  int get suggestedWaterGoal => _calcWaterGoal(weightKg);
  int get suggestedWeeklyGoal =>
      _calcWeeklyCalorieGoal(weightKg, heightCm, age, gender, weightGoal);

  /// Surplus or deficit per day vs TDEE
  int get dailySurplusDeficit => dailyQuota - tdee;
}
