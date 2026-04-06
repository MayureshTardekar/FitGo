import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/supabase_service.dart';
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
    // Sync to cloud in background
    _syncToCloud(profile);
  }

  Future<void> updateGoals({
    int? calorieGoal,
    int? waterGoalMl,
    int? weeklyCalorieGoal,
    String? weightGoal,
  }) async {
    if (state == null) return;
    final profile = state!;
    if (calorieGoal != null) profile.calorieGoal = calorieGoal;
    if (waterGoalMl != null) profile.waterGoalMl = waterGoalMl;
    if (weeklyCalorieGoal != null)
      profile.weeklyCalorieGoal = weeklyCalorieGoal;
    if (weightGoal != null) profile.weightGoal = weightGoal;
    final storage = ref.read(localStorageProvider);
    await storage.saveProfile(profile);
    state = null; // force rebuild
    state = profile;
    _syncToCloud(profile);
  }

  void _syncToCloud(UserProfile profile) {
    if (!SupabaseService.isLoggedIn) return;
    // Fire and forget
    Future.microtask(() async {
      try {
        await SupabaseService.upsertProfile(profile);
      } catch (_) {}
    });
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);
