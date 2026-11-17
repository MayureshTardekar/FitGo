import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import 'storage_provider.dart';

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final storage = ref.read(localStorageProvider);
    return storage.getProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveProfile(profile);
    state = profile;
  }

  Future<void> updateGoals({
    int? calorieGoal,
    int? waterGoalMl,
    int? weeklyCalorieGoal,
    String? weightGoal,
    double? targetWeightKg,
    String? goalTargetDate,
  }) async {
    if (state == null) return;
    final profile = state!;
    if (calorieGoal != null) profile.calorieGoal = calorieGoal;
    if (waterGoalMl != null) profile.waterGoalMl = waterGoalMl;
    if (weeklyCalorieGoal != null) {
      profile.weeklyCalorieGoal = weeklyCalorieGoal;
    }
    if (weightGoal != null) profile.weightGoal = weightGoal;
    if (targetWeightKg != null) profile.targetWeightKg = targetWeightKg;
    if (goalTargetDate != null) profile.goalTargetDate = goalTargetDate;
    final storage = ref.read(localStorageProvider);
    await storage.saveProfile(profile);
    state = null; // force rebuild
    state = profile;
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);
