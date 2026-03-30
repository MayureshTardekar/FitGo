import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'calorie_provider.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';

class DaySummary {
  final String dateKey;
  final String dayName;
  final int calories;
  final int waterMl;
  final int dailyTarget;
  final bool isToday;
  final bool isFuture;
  final List<int> calorieEntries;

  const DaySummary({
    required this.dateKey,
    required this.dayName,
    required this.calories,
    required this.waterMl,
    required this.dailyTarget,
    required this.isToday,
    required this.isFuture,
    this.calorieEntries = const [],
  });

  int get difference => calories - dailyTarget;
  bool get isOver => calories > dailyTarget;
  bool get isUnder => !isFuture && calories < dailyTarget && calories > 0;
  double get progress =>
      dailyTarget > 0 ? (calories / dailyTarget).clamp(0.0, 1.5) : 0.0;
}

class Insight {
  final String title;
  final String description;
  final InsightType type;
  final IconType icon;

  const Insight({
    required this.title,
    required this.description,
    required this.type,
    required this.icon,
  });
}

enum InsightType { positive, warning, negative, info }

enum IconType { trophy, fire, trending, target, alert, tip, streak, water }

class WeeklyAnalytics {
  final int weeklyGoal;
  final int totalConsumed;
  final int remainingBudget;
  final int daysLeft;
  final int adjustedDailyTarget;
  final List<DaySummary> days;
  final double weeklyProgress;
  final int projectedWeekTotal;
  // New advanced fields
  final int avgDailyIntake;
  final int highestDay;
  final int lowestDay;
  final String highestDayName;
  final String lowestDayName;
  final int totalWater;
  final int waterGoal;
  final int consistencyScore; // 0-100
  final List<int> cumulativeIntake; // running total for trend line
  final List<int> cumulativeTarget; // ideal cumulative for trend line
  final List<Insight> insights;
  final int streakDays; // consecutive days within target

  const WeeklyAnalytics({
    required this.weeklyGoal,
    required this.totalConsumed,
    required this.remainingBudget,
    required this.daysLeft,
    required this.adjustedDailyTarget,
    required this.days,
    required this.weeklyProgress,
    required this.projectedWeekTotal,
    required this.avgDailyIntake,
    required this.highestDay,
    required this.lowestDay,
    required this.highestDayName,
    required this.lowestDayName,
    required this.totalWater,
    required this.waterGoal,
    required this.consistencyScore,
    required this.cumulativeIntake,
    required this.cumulativeTarget,
    required this.insights,
    required this.streakDays,
  });

  bool get isOnTrack => projectedWeekTotal <= weeklyGoal;
  double get deviationPercent => weeklyGoal > 0
      ? ((projectedWeekTotal - weeklyGoal) / weeklyGoal * 100)
      : 0;
}

class WeeklyNotifier extends Notifier<WeeklyAnalytics> {
  @override
  WeeklyAnalytics build() {
    ref.watch(calorieProvider);
    return _calculate();
  }

  WeeklyAnalytics _calculate() {
    final storage = ref.read(localStorageProvider);
    final profile = ref.read(profileProvider);
    final weeklyGoal = profile?.weeklyCalorieGoal ?? 14000;
    final baseDailyTarget = profile?.calorieGoal ?? 2000;
    final dailyWaterGoal = profile?.waterGoalMl ?? 3000;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final fmt = DateFormat('yyyy-MM-dd');
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final weekMetrics = storage.getCurrentWeekMetrics();

    int totalConsumed = 0;
    int pastDaysConsumed = 0;
    int pastDaysCount = 0;
    int totalWater = 0;
    int highest = 0;
    int lowest = 999999;
    String highestName = '';
    String lowestName = '';
    int streakDays = 0;
    bool streakBroken = false;

    final days = <DaySummary>[];
    final cumulativeIntake = <int>[];
    final cumulativeTarget = <int>[];
    int runningTotal = 0;
    int runningTarget = 0;

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final key = fmt.format(date);
      final isToday = key == todayKey;
      final isFuture = date.isAfter(now) && !isToday;
      final metrics = weekMetrics[i];
      final cal = metrics.totalCalories;

      if (!isFuture) {
        totalConsumed += cal;
        totalWater += metrics.waterMl;
        runningTotal += cal;

        if (cal > 0) {
          if (cal > highest) {
            highest = cal;
            highestName = dayNames[i];
          }
          if (cal < lowest) {
            lowest = cal;
            lowestName = dayNames[i];
          }
        }

        // Streak: consecutive days within 10% of target
        if (!isFuture && cal > 0) {
          final withinTarget =
              (cal - baseDailyTarget).abs() < baseDailyTarget * 0.15;
          if (withinTarget && !streakBroken) {
            streakDays++;
          } else if (!withinTarget) {
            streakBroken = true;
            streakDays = 0;
          }
        }
      }
      if (!isToday && !isFuture) {
        pastDaysConsumed += cal;
        pastDaysCount++;
      }

      runningTarget += baseDailyTarget;
      cumulativeIntake.add(runningTotal);
      cumulativeTarget.add(runningTarget);

      days.add(DaySummary(
        dateKey: key,
        dayName: dayNames[i],
        calories: isFuture ? 0 : cal,
        waterMl: isFuture ? 0 : metrics.waterMl,
        dailyTarget: baseDailyTarget,
        isToday: isToday,
        isFuture: isFuture,
        calorieEntries: isFuture ? [] : metrics.calorieEntries,
      ));
    }

    if (lowest == 999999) lowest = 0;

    final remainingBudget = weeklyGoal - totalConsumed;
    final daysLeft = 7 - now.weekday;
    final daysIncludingToday = daysLeft + 1;

    final budgetAfterToday = weeklyGoal - pastDaysConsumed;
    final adjustedDailyTarget = daysIncludingToday > 0
        ? (budgetAfterToday / daysIncludingToday).round()
        : baseDailyTarget;

    final completedDays = pastDaysCount + 1;
    final avgDaily =
        completedDays > 0 ? (totalConsumed / completedDays).round() : 0;
    final projectedWeekTotal = (avgDaily * 7);

    final weeklyProgress = weeklyGoal > 0
        ? (totalConsumed / weeklyGoal).clamp(0.0, 1.5)
        : 0.0;

    // Consistency score: how close to target each day
    int withinTargetDays = 0;
    int activeDays = 0;
    for (final d in days) {
      if (!d.isFuture && d.calories > 0) {
        activeDays++;
        if ((d.calories - d.dailyTarget).abs() < d.dailyTarget * 0.15) {
          withinTargetDays++;
        }
      }
    }
    final consistencyScore =
        activeDays > 0 ? ((withinTargetDays / activeDays) * 100).round() : 0;

    // Adjust future/today targets
    final adjustedDays = days.map((d) {
      if (d.isToday || d.isFuture) {
        return DaySummary(
          dateKey: d.dateKey,
          dayName: d.dayName,
          calories: d.calories,
          waterMl: d.waterMl,
          dailyTarget: adjustedDailyTarget,
          isToday: d.isToday,
          isFuture: d.isFuture,
          calorieEntries: d.calorieEntries,
        );
      }
      return d;
    }).toList();

    // Generate insights
    final insights = _generateInsights(
      weekly: weeklyGoal,
      totalConsumed: totalConsumed,
      avgDaily: avgDaily,
      adjustedTarget: adjustedDailyTarget,
      baseDailyTarget: baseDailyTarget,
      projected: projectedWeekTotal,
      consistencyScore: consistencyScore,
      streakDays: streakDays,
      daysLeft: daysIncludingToday,
      highestDay: highest,
      highestDayName: highestName,
      lowestDay: lowest,
      lowestDayName: lowestName,
      totalWater: totalWater,
      waterGoal: dailyWaterGoal * completedDays,
    );

    return WeeklyAnalytics(
      weeklyGoal: weeklyGoal,
      totalConsumed: totalConsumed,
      remainingBudget: remainingBudget,
      daysLeft: daysIncludingToday,
      adjustedDailyTarget: adjustedDailyTarget,
      days: adjustedDays,
      weeklyProgress: weeklyProgress,
      projectedWeekTotal: projectedWeekTotal,
      avgDailyIntake: avgDaily,
      highestDay: highest,
      lowestDay: lowest,
      highestDayName: highestName,
      lowestDayName: lowestName,
      totalWater: totalWater,
      waterGoal: dailyWaterGoal * 7,
      consistencyScore: consistencyScore,
      cumulativeIntake: cumulativeIntake,
      cumulativeTarget: cumulativeTarget,
      insights: insights,
      streakDays: streakDays,
    );
  }

  List<Insight> _generateInsights({
    required int weekly,
    required int totalConsumed,
    required int avgDaily,
    required int adjustedTarget,
    required int baseDailyTarget,
    required int projected,
    required int consistencyScore,
    required int streakDays,
    required int daysLeft,
    required int highestDay,
    required String highestDayName,
    required int lowestDay,
    required String lowestDayName,
    required int totalWater,
    required int waterGoal,
  }) {
    final insights = <Insight>[];

    // Projection insight
    if (projected > 0) {
      if (projected <= weekly) {
        final under = weekly - projected;
        insights.add(Insight(
          title: 'On Track',
          description:
              'At your current pace, you\'ll finish ~$under kcal under budget. Keep it up!',
          type: InsightType.positive,
          icon: IconType.target,
        ));
      } else {
        final over = projected - weekly;
        insights.add(Insight(
          title: 'Over Pace',
          description:
              'Projected $over kcal over goal. Try $adjustedTarget kcal/day for the next $daysLeft days.',
          type: InsightType.warning,
          icon: IconType.alert,
        ));
      }
    }

    // Streak insight
    if (streakDays >= 3) {
      insights.add(Insight(
        title: '$streakDays-Day Streak!',
        description:
            'You\'ve been within 15% of your daily target for $streakDays days straight.',
        type: InsightType.positive,
        icon: IconType.streak,
      ));
    }

    // Consistency insight
    if (consistencyScore >= 80) {
      insights.add(Insight(
        title: 'Highly Consistent',
        description:
            'Your consistency score is $consistencyScore%. You\'re nailing your daily targets.',
        type: InsightType.positive,
        icon: IconType.trophy,
      ));
    } else if (consistencyScore > 0 && consistencyScore < 40) {
      insights.add(Insight(
        title: 'Inconsistent Intake',
        description:
            'Consistency is $consistencyScore%. Try to stay closer to $baseDailyTarget kcal each day for better results.',
        type: InsightType.negative,
        icon: IconType.tip,
      ));
    }

    // Variance insight
    if (highestDay > 0 && lowestDay > 0 && highestDay - lowestDay > baseDailyTarget * 0.5) {
      insights.add(Insight(
        title: 'Big Swings',
        description:
            'Your highest day ($highestDayName: $highestDay) is ${highestDay - lowestDay} kcal more than your lowest ($lowestDayName: $lowestDay). Smoother intake helps metabolism.',
        type: InsightType.info,
        icon: IconType.trending,
      ));
    }

    // Water insight
    if (waterGoal > 0 && totalWater > 0) {
      final waterPercent = (totalWater / waterGoal * 100).round();
      if (waterPercent >= 80) {
        insights.add(Insight(
          title: 'Hydration On Point',
          description: 'You\'ve hit $waterPercent% of your water goal this week.',
          type: InsightType.positive,
          icon: IconType.water,
        ));
      } else if (waterPercent < 50) {
        insights.add(Insight(
          title: 'Drink More Water',
          description:
              'Only $waterPercent% of your weekly water goal. Hydration helps with hunger management.',
          type: InsightType.warning,
          icon: IconType.water,
        ));
      }
    }

    // Budget redistribution tip
    if (daysLeft > 1 && daysLeft < 7 && adjustedTarget != baseDailyTarget) {
      final diff = adjustedTarget - baseDailyTarget;
      if (diff.abs() > 50) {
        insights.add(Insight(
          title: 'Adjusted Target',
          description: diff > 0
              ? 'You\'ve been under-eating, so you can have ${diff.abs()} extra kcal/day and still hit your goal.'
              : 'To compensate, aim for ${diff.abs()} fewer kcal/day for the remaining days.',
          type: diff > 0 ? InsightType.info : InsightType.warning,
          icon: IconType.target,
        ));
      }
    }

    return insights;
  }
}

final weeklyProvider =
    NotifierProvider<WeeklyNotifier, WeeklyAnalytics>(WeeklyNotifier.new);
