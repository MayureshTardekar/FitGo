import 'package:fitgo/core/units.dart';
import 'package:fitgo/models/user_profile.dart';
import 'package:fitgo/ui/profile/goal_planner_sheet.dart';
import 'package:fitgo/ui/theme/fitgo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('goal planner fits a 320pt screen at 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final targetDate = DateTime.now().add(const Duration(days: 84));
    final profile = UserProfile(
      weightKg: 70,
      heightCm: 175,
      age: 30,
      gender: 'male',
      calorieGoal: 2400,
      waterGoalMl: 2500,
      weeklyCalorieGoal: 16800,
      weightGoal: 'lose',
      activityLevel: 'light',
      targetWeightKg: 65,
      goalTargetDate: DateFormat('yyyy-MM-dd').format(targetDate),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: FitGoTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: GoalPlannerSheet(profile: profile, units: UnitSystem.metric),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Plan your goal'), findsOneWidget);
    expect(find.text('Daily intake'), findsOneWidget);
    expect(find.text('Use this plan'), findsOneWidget);
  });
}
