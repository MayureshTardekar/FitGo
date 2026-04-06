import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'calorie_provider.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';
import 'weekly_provider.dart' show DaySummary, Insight, InsightType, IconType;

enum Timeframe { thisWeek, thisMonth, thisYear }

class AnalyticsState {
  final Timeframe timeframe;
  final DateTime referenceDate;

  AnalyticsState({required this.timeframe, required this.referenceDate});

  AnalyticsState copyWith({Timeframe? timeframe, DateTime? referenceDate}) {
    return AnalyticsState(
      timeframe: timeframe ?? this.timeframe,
      referenceDate: referenceDate ?? this.referenceDate,
    );
  }
}

class AnalyticsTimeframeNotifier extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() => AnalyticsState(timeframe: Timeframe.thisWeek, referenceDate: DateTime.now());

  void updateTimeframe(Timeframe tf) => state = state.copyWith(timeframe: tf, referenceDate: DateTime.now());

  void previous() {
    state = state.copyWith(referenceDate: _shift(state.referenceDate, -1));
  }

  void next() {
    state = state.copyWith(referenceDate: _shift(state.referenceDate, 1));
  }

  DateTime _shift(DateTime current, int direction) {
     if (state.timeframe == Timeframe.thisWeek) {
        return current.add(Duration(days: 7 * direction));
     } else if (state.timeframe == Timeframe.thisMonth) {
        return DateTime(current.year, current.month + direction, 1);
     } else {
        return DateTime(current.year + direction, 1, 1);
     }
  }
}

final analyticsTimeframeProvider =
    NotifierProvider<AnalyticsTimeframeNotifier, AnalyticsState>(
      () => AnalyticsTimeframeNotifier(),
    );

class DashboardAnalytics {
  final String periodLabel;
  final bool canGoBack;
  final bool canGoForward;
  final int totalGoal;
  final int totalConsumed;
  final int remainingBudget;
  final int daysLeft;
  final int adjustedDailyTarget;
  final List<DaySummary> days;
  final double progress;
  final int projectedTotal;
  final int avgDailyIntake;
  final int highestDay;
  final int lowestDay;
  final String highestDayName;
  final String lowestDayName;
  final int totalWater;
  final int waterGoal;
  final int consistencyScore;
  final List<int> cumulativeIntake;
  final List<int> cumulativeTarget;
  final List<Insight> insights;
  final int streakDays;

  const DashboardAnalytics({
    required this.totalGoal,
    required this.totalConsumed,
    required this.remainingBudget,
    required this.daysLeft,
    required this.adjustedDailyTarget,
    required this.days,
    required this.progress,
    required this.projectedTotal,
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
    required this.periodLabel,
    required this.canGoBack,
    required this.canGoForward,
  });

  bool get isOnTrack => projectedTotal <= totalGoal;
  double get deviationPercent =>
      totalGoal > 0 ? ((projectedTotal - totalGoal) / totalGoal * 100) : 0;
}

final dashboardAnalyticsProvider =
    NotifierProvider<DashboardAnalyticsNotifier, DashboardAnalytics>(
      () => DashboardAnalyticsNotifier(),
    );

class DashboardAnalyticsNotifier extends Notifier<DashboardAnalytics> {
  @override
  DashboardAnalytics build() {
    ref.watch(calorieProvider);
    final timeframe = ref.watch(analyticsTimeframeProvider);
    return _calculate(timeframe);
  }

  DashboardAnalytics _calculate(AnalyticsState timeframeState) {
    final storage = ref.read(localStorageProvider);
    final profile = ref.read(profileProvider);
    final baseDailyTarget = profile?.calorieGoal ?? 2000;
    final dailyWaterGoal = profile?.waterGoalMl ?? 3000;

    final now = DateTime.now();
    final referenceDate = timeframeState.referenceDate;
    final timeframe = timeframeState.timeframe;
    final fmt = DateFormat('yyyy-MM-dd');
    final todayKey = fmt.format(now);

    DateTime start;
    DateTime end;
    int daysCount;
    String periodLabel = '';

    if (timeframe == Timeframe.thisWeek) {
      start = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
      daysCount = 7;
      final endW = start.add(const Duration(days: 6));
      periodLabel = '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(endW)}';
    } else if (timeframe == Timeframe.thisMonth) {
      start = DateTime(referenceDate.year, referenceDate.month, 1);
      daysCount = DateTime(referenceDate.year, referenceDate.month + 1, 0).day;
      periodLabel = DateFormat('MMMM yyyy').format(start);
    } else {
      start = DateTime(referenceDate.year, 1, 1);
      final isLeap =
          referenceDate.year % 4 == 0 && (referenceDate.year % 100 != 0 || referenceDate.year % 400 == 0);
      daysCount = isLeap ? 366 : 365;
      periodLabel = DateFormat('yyyy').format(start);
    }

    end = start.add(Duration(days: daysCount - 1));

    final metricsList = storage.getMetricsRange(start, end);

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

    for (int i = 0; i < daysCount; i++) {
      final date = start.add(Duration(days: i));
      final key = fmt.format(date);
      final isToday = key == todayKey;
      final isFuture = date.isAfter(now) && !isToday;

      // Determine dayName formatting
      String dayName;
      if (timeframe == Timeframe.thisWeek) {
        dayName = DateFormat('E').format(date);
      } else if (timeframe == Timeframe.thisMonth) {
        dayName = '${date.day}';
      } else {
        // Grouping by months is another strategy, but if we do day-by-day for year, it's 365 bars.
        dayName = DateFormat('MMM').format(
          date,
        ); // We might need to handle Year differently later if needed
      }

      final metricMatches = metricsList.where((m) => m.dateKey == key).toList();
      final cal = metricMatches.isNotEmpty
          ? metricMatches.first.totalCalories
          : 0;
      final water = metricMatches.isNotEmpty ? metricMatches.first.waterMl : 0;
      final entries = metricMatches.isNotEmpty
          ? metricMatches.first.calorieEntries
          : <int>[];

      if (!isFuture) {
        totalConsumed += cal;
        totalWater += water;
        runningTotal += cal;

        if (cal > 0) {
          if (cal > highest) {
            highest = cal;
            highestName = dayName;
          }
          if (cal < lowest) {
            lowest = cal;
            lowestName = dayName;
          }
        }

        if (cal > 0) {
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

      days.add(
        DaySummary(
          dateKey: key,
          dayName: dayName,
          calories: isFuture ? 0 : cal,
          waterMl: isFuture ? 0 : water,
          dailyTarget: baseDailyTarget,
          isToday: isToday,
          isFuture: isFuture,
          calorieEntries: isFuture ? [] : entries,
        ),
      );
    }

    if (lowest == 999999) lowest = 0;

    int totalGoal = baseDailyTarget * daysCount;
    int budgetAfterToday = totalGoal - pastDaysConsumed;

    // How many days left in the chosen timeframe after today?
    int daysLeft = 0;
    if (end.isAfter(now)) {
      daysLeft = end.difference(now).inDays;
    }
    final daysIncludingToday = daysLeft + 1;
    final adjustedDailyTarget = daysIncludingToday > 0
        ? (budgetAfterToday / daysIncludingToday).round()
        : baseDailyTarget;

    final completedDays = pastDaysCount + 1;
    final avgDaily = completedDays > 0
        ? (totalConsumed / completedDays).round()
        : 0;
    final projectedTotal = avgDaily * daysCount;

    final progress = totalGoal > 0
        ? (totalConsumed / totalGoal).clamp(0.0, 1.5)
        : 0.0;

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
    final consistencyScore = activeDays > 0
        ? ((withinTargetDays / activeDays) * 100).round()
        : 0;

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

    return DashboardAnalytics(
      totalGoal: totalGoal,
      totalConsumed: totalConsumed,
      remainingBudget: totalGoal - totalConsumed,
      daysLeft: daysLeft,
      adjustedDailyTarget: adjustedDailyTarget,
      days: adjustedDays,
      progress: progress,
      projectedTotal: projectedTotal,
      avgDailyIntake: avgDaily,
      highestDay: highest,
      lowestDay: lowest,
      highestDayName: highestName,
      lowestDayName: lowestName,
      totalWater: totalWater,
      waterGoal: dailyWaterGoal * daysCount,
      consistencyScore: consistencyScore,
      cumulativeIntake: cumulativeIntake,
      cumulativeTarget: cumulativeTarget,
      insights: _generateInsights(progress, consistencyScore, streakDays),
      streakDays: streakDays,
      periodLabel: periodLabel,
      canGoBack: storage.getFirstEntryDate() != null && start.isAfter(storage.getFirstEntryDate()!),
      canGoForward: end.isBefore(DateTime(now.year, now.month, now.day)),
    );
  }

  List<Insight> _generateInsights(double p, int score, int streak) {
    return [
      Insight(
        title: 'Overview',
        description: 'Your metrics are looking good for this period.',
        type: InsightType.info,
        icon: IconType.trending,
      ),
    ]; // Can be expanded later
  }
}
