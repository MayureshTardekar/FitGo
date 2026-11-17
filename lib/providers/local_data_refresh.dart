import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'activity_provider.dart';
import 'ai_provider.dart';
import 'analytics_provider.dart';
import 'calorie_provider.dart';
import 'meal_library_provider.dart';
import 'monthly_calorie_alert_provider.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';
import 'sync_status_provider.dart';
import 'theme_provider.dart';
import 'timer_provider.dart';
import 'units_provider.dart';
import 'water_provider.dart';
import 'weekly_nutrition_plan_provider.dart';
import 'weekly_provider.dart';
import 'weight_provider.dart';

/// Invalidates every provider whose state is derived from local storage.
///
/// Call this after switching accounts or importing data so no screen keeps
/// showing the previous account's profile, logs, settings, or units.
void refreshLocalDataProviders(WidgetRef ref) {
  ref.invalidate(profileProvider);
  ref.invalidate(nutritionProvider);
  ref.invalidate(waterProvider);
  ref.invalidate(fastingProvider);
  ref.invalidate(activityProvider);
  ref.invalidate(weightProvider);
  ref.invalidate(weeklyProvider);
  ref.invalidate(weeklyNutritionPlanProvider);
  ref.invalidate(monthlyCalorieAlertProvider);
  ref.invalidate(mealLibraryProvider);
  ref.invalidate(syncStatusProvider);
  ref.invalidate(themeModeProvider);
  ref.invalidate(unitSystemProvider);
  ref.invalidate(dashboardAnalyticsProvider);
  ref.invalidate(guestDataAvailableProvider);
  // AI keys and chat history are scoped to the active account. Invalidating
  // both providers prevents the previous account's conversation or usage from
  // remaining in memory after a sign-in, sign-out, or guest import.
  ref.invalidate(aiSettingsProvider);
  ref.invalidate(aiChatProvider);
}
