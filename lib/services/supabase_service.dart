import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../models/daily_metrics.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // ─── Auth ──────────────────────────────────────────────────────────────

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static String? get userId => currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.fitgo.fitgo://login-callback',
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // ─── Profile Sync ──────────────────────────────────────────────────────

  static Future<void> upsertProfile(UserProfile profile) async {
    final uid = userId;
    if (uid == null) return;

    await client.from('user_profiles').upsert({
      'id': uid,
      'weight_kg': profile.weightKg,
      'height_cm': profile.heightCm,
      'age': profile.age,
      'gender': profile.gender,
      'calorie_goal': profile.calorieGoal,
      'water_goal_ml': profile.waterGoalMl,
      'weekly_calorie_goal': profile.weeklyCalorieGoal,
      'weight_goal': profile.weightGoal,
      'dob_string': profile.dobString,
    });
  }

  static Future<UserProfile?> fetchProfile() async {
    final uid = userId;
    if (uid == null) return null;

    final data = await client
        .from('user_profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;

    return UserProfile(
      weightKg: (data['weight_kg'] as num).toDouble(),
      heightCm: (data['height_cm'] as num).toDouble(),
      age: data['age'] as int,
      gender: data['gender'] as String,
      calorieGoal: data['calorie_goal'] as int?,
      waterGoalMl: data['water_goal_ml'] as int?,
      weeklyCalorieGoal: data['weekly_calorie_goal'] as int?,
      weightGoal: data['weight_goal'] as String? ?? 'maintain',
      dobString: data['dob_string'] as String? ?? '',
    );
  }

  // ─── Daily Metrics Sync ────────────────────────────────────────────────

  static Future<void> upsertDailyMetrics(DailyMetrics m) async {
    final uid = userId;
    if (uid == null) return;

    final payload = {
      'user_id': uid,
      'date_key': m.dateKey,
      'total_calories': m.totalCalories,
      'water_ml': m.waterMl,
      'weight': m.weight,
      'fasting_start_epoch': m.fastingStartEpoch,
      'fasting_duration_minutes': m.fastingDurationMinutes,
      'calorie_entries': m.calorieEntries,
      'steps': m.steps,
      'calories_burned': m.caloriesBurned,
      'activities': m.activities,
      'sleep_minutes': m.sleepMinutes,
      'sleep_bedtime': m.sleepBedtime,
      'sleep_wake_time': m.sleepWakeTime,
      'protein_grams': m.proteinGrams,
      'carbs_grams': m.carbsGrams,
      'fat_grams': m.fatGrams,
      'fiber_grams': m.fiberGrams,
      'sugar_grams': m.sugarGrams,
      'nutrition_entries': m.nutritionEntries,
      'fasting_reminder_minutes': m.fastingReminderMinutes,
      'fasting_reminder_enabled': m.fastingReminderEnabled,
      'fasting_last_reminder_epoch': m.fastingLastReminderEpoch,
    };

    try {
      await client
          .from('daily_metrics')
          .upsert(payload, onConflict: 'user_id,date_key');
    } catch (_) {
      final legacyPayload = Map<String, dynamic>.of(payload)
        ..remove('protein_grams')
        ..remove('carbs_grams')
        ..remove('fat_grams')
        ..remove('fiber_grams')
        ..remove('sugar_grams')
        ..remove('nutrition_entries')
        ..remove('fasting_reminder_minutes')
        ..remove('fasting_reminder_enabled')
        ..remove('fasting_last_reminder_epoch');
      await client
          .from('daily_metrics')
          .upsert(legacyPayload, onConflict: 'user_id,date_key');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMetricsRange(
    String fromDate,
    String toDate,
  ) async {
    final uid = userId;
    if (uid == null) return [];

    return await client
        .from('daily_metrics')
        .select()
        .eq('user_id', uid)
        .gte('date_key', fromDate)
        .lte('date_key', toDate)
        .order('date_key');
  }

  // ─── Weight Entries Sync ───────────────────────────────────────────────

  static Future<void> upsertWeight(WeightEntry w) async {
    final uid = userId;
    if (uid == null) return;

    await client.from('weight_entries').upsert({
      'user_id': uid,
      'date_key': w.dateKey,
      'weight': w.weight,
    }, onConflict: 'user_id,date_key');
  }

  static Future<void> upsertAppSetting(String key, Object? value) async {
    final uid = userId;
    if (uid == null) return;

    await client.from('app_settings').upsert({
      'user_id': uid,
      'setting_key': key,
      'setting_value': value,
    }, onConflict: 'user_id,setting_key');
  }

  static Future<void> upsertAppSettings(Map<String, dynamic> settings) async {
    final uid = userId;
    if (uid == null || settings.isEmpty) return;

    await client
        .from('app_settings')
        .upsert(
          settings.entries
              .map(
                (entry) => {
                  'user_id': uid,
                  'setting_key': entry.key,
                  'setting_value': entry.value,
                },
              )
              .toList(),
          onConflict: 'user_id,setting_key',
        );
  }

  // ─── Bulk Sync (on login / app start) ──────────────────────────────────

  /// Push all local Hive data to Supabase
  static Future<void> syncToCloud({
    required UserProfile? profile,
    required List<DailyMetrics> metrics,
    required List<WeightEntry> weights,
    Map<String, dynamic> settings = const {},
  }) async {
    if (!isLoggedIn) return;

    try {
      if (profile != null) await upsertProfile(profile);

      for (final m in metrics) {
        await upsertDailyMetrics(m);
      }

      for (final w in weights) {
        await upsertWeight(w);
      }

      if (settings.isNotEmpty) {
        await upsertAppSettings(settings);
      }
    } catch (_) {
      // Silently fail — offline-first, will retry next time
    }
  }
}
