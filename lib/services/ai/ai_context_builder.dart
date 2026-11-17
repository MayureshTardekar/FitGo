import 'dart:math';

import 'package:intl/intl.dart';

import '../../models/daily_metrics.dart';
import '../../models/user_profile.dart';
import '../../models/weight_entry.dart';
import '../local_storage.dart';

enum AiTrackStatus { onTrack, slightlyOff, offTrack, notEnoughData }

/// A deterministic, PII-free view of the user's FitGo data.
///
/// The app owns the on-track calculation. The AI receives this snapshot and is
/// instructed to explain it, never to replace it or mutate a goal.
class AiContextSnapshot {
  const AiContextSnapshot({
    required this.prompt,
    required this.status,
    required this.daysLogged7,
    required this.avgCalories7,
    required this.avgWaterMl7,
    required this.avgSteps7,
    required this.avgSleepMinutes7,
    required this.avgProteinG7,
    required this.avgCarbsG7,
    required this.avgFatG7,
    required this.weightChange14,
    required this.expectedWeightChange14,
    required this.reasons,
  });

  final String prompt;
  final AiTrackStatus status;
  final int daysLogged7;
  final int avgCalories7;
  final int avgWaterMl7;
  final int avgSteps7;
  final int avgSleepMinutes7;
  final int avgProteinG7;
  final int avgCarbsG7;
  final int avgFatG7;
  final double? weightChange14;
  final double? expectedWeightChange14;
  final List<String> reasons;

  String get statusLabel => switch (status) {
    AiTrackStatus.onTrack => 'ON_TRACK',
    AiTrackStatus.slightlyOff => 'SLIGHTLY_OFF',
    AiTrackStatus.offTrack => 'OFF_TRACK',
    AiTrackStatus.notEnoughData => 'NOT_ENOUGH_DATA',
  };
}

class AiContextBuilder {
  const AiContextBuilder();

  AiContextSnapshot fromStorage(LocalStorage storage, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return build(
      profile: storage.getProfile(),
      metrics: storage.getMetricsRange(
        current.subtract(const Duration(days: 27)),
        current,
      ),
      weights: storage.getWeightHistory(lastNDays: 90),
      now: current,
      units: storage.getSetting<String>('unit_system', 'metric'),
    );
  }

  AiContextSnapshot build({
    required UserProfile? profile,
    required List<DailyMetrics> metrics,
    required List<WeightEntry> weights,
    required DateTime now,
    String units = 'metric',
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final metricsByDate = {
      for (final metric in metrics) metric.dateKey: metric,
    };

    final last7 = _days(today, 0, 7, metricsByDate);
    final previous7 = _days(today, 7, 7, metricsByDate);
    final daysLogged7 = last7.where(_isLogged).length;

    final avgCalories7 = _average(last7, _hasCalories, (m) => m.totalCalories);
    final avgWater7 = _average(last7, _hasWater, (m) => m.waterMl);
    final avgSteps7 = _average(last7, _hasSteps, (m) => m.steps);
    final avgSleep7 = _average(last7, _hasSleep, (m) => m.sleepMinutes);
    final avgProtein7 = _average(last7, _hasNutrition, (m) => m.proteinGrams);
    final avgCarbs7 = _average(last7, _hasNutrition, (m) => m.carbsGrams);
    final avgFat7 = _average(last7, _hasNutrition, (m) => m.fatGrams);

    final prevCalories = _average(
      previous7,
      _hasCalories,
      (m) => m.totalCalories,
    );
    final prevWater = _average(previous7, _hasWater, (m) => m.waterMl);
    final prevSteps = _average(previous7, _hasSteps, (m) => m.steps);
    final prevSleep = _average(previous7, _hasSleep, (m) => m.sleepMinutes);

    final calorieTarget = profile?.dailyQuota ?? 0;
    final waterTarget = profile?.waterGoalMl ?? 0;
    final calorieDays = last7.where(_hasCalories).length;
    final waterDays = last7.where(_hasWater).length;
    final calorieDaysHit = calorieTarget <= 0
        ? 0
        : last7
              .where(_hasCalories)
              .where(
                (m) =>
                    (m.totalCalories - calorieTarget).abs() <=
                    max(100, (calorieTarget * 0.1).round()),
              )
              .length;
    final waterDaysHit = waterTarget <= 0
        ? 0
        : last7
              .where(_hasWater)
              .where((m) => m.waterMl >= (waterTarget * 0.9).round())
              .length;

    final weightSummary = _weightSummary(
      profile: profile,
      metrics: metrics,
      weights: weights,
      today: today,
    );

    final measures = <_TrackMeasure>[
      if (profile != null && calorieDays > 0 && calorieTarget > 0)
        _calorieMeasure(avgCalories7, calorieTarget),
      if (profile != null && waterDays > 0 && waterTarget > 0)
        _waterMeasure(avgWater7, waterTarget),
      if (weightSummary.measure != null) weightSummary.measure!,
    ];

    final reasons = measures
        .where((measure) => measure.reason != null)
        .map((measure) => measure.reason!)
        .toList();

    AiTrackStatus status;
    if (profile == null || daysLogged7 < 3 || measures.isEmpty) {
      status = AiTrackStatus.notEnoughData;
      if (profile == null) {
        reasons.add('the FitGo profile is not set up yet');
      } else if (daysLogged7 < 3) {
        reasons.add('fewer than 3 days were logged this week');
      } else {
        reasons.add('not enough calorie, water, or weight data yet');
      }
    } else {
      final offCount = measures
          .where((measure) => measure.level == _MeasureLevel.off)
          .length;
      final slightCount = measures
          .where((measure) => measure.level == _MeasureLevel.slight)
          .length;
      status = offCount >= 2
          ? AiTrackStatus.offTrack
          : (offCount == 1 || slightCount > 0)
          ? AiTrackStatus.slightlyOff
          : AiTrackStatus.onTrack;
      if (status == AiTrackStatus.onTrack) {
        reasons.add(
          'intake, hydration, and weight trend are close to the plan',
        );
      }
    }

    final prompt = StringBuffer()
      ..writeln(
        'FITGO SNAPSHOT (read-only; no name, email, account ID, or API key).',
      )
      ..writeln('Today: ${_dateKey(today)}')
      ..writeln('Preferred units: $units');

    if (profile == null) {
      prompt.writeln('Profile: not set up yet.');
    } else {
      prompt
        ..writeln(
          'Profile: age ${profile.age}; ${profile.gender}; height '
          '${profile.heightCm.toStringAsFixed(0)} cm; current weight '
          '${profile.weightKg.toStringAsFixed(1)} kg; activity '
          '${profile.activityLevel}.',
        )
        ..writeln(
          'Daily targets: ${profile.dailyQuota} kcal; '
          '${profile.waterGoalMl} ml water; TDEE ${profile.tdee} kcal.',
        );

      final plan = profile.goalPlan;
      if (plan == null) {
        prompt.writeln(
          'Weight goal: ${profile.weightGoal}; no target weight/date set.',
        );
      } else {
        prompt.writeln(
          'Weight goal: ${plan.goalType}; ${plan.currentWeightKg.toStringAsFixed(1)} '
          'kg to ${plan.targetWeightKg.toStringAsFixed(1)} kg by '
          '${_dateKey(plan.targetDate)} (${plan.days} days). '
          'Plan pace: ${plan.weeklyKgChange.toStringAsFixed(2)} kg/week; '
          'safe daily change: ${plan.dailyDelta} kcal.',
        );
      }
    }

    prompt
      ..writeln(
        'Last 7 days: $daysLogged7 logged; average intake $avgCalories7 kcal '
        '(target $calorieTarget) on $calorieDays days; average water '
        '$avgWater7 ml (goal $waterTarget) on $waterDays days; average steps '
        '$avgSteps7; average sleep ${_minutes(avgSleep7)}; average macros '
        '${avgProtein7}g protein / ${avgCarbs7}g carbs / ${avgFat7}g fat.',
      )
      ..writeln(
        'Calorie target hit: $calorieDaysHit/$calorieDays logged days; '
        'water goal met: $waterDaysHit/$waterDays logged days.',
      )
      ..writeln(
        'Previous 7 days for comparison: average intake $prevCalories kcal; '
        'water $prevWater ml; steps $prevSteps; sleep ${_minutes(prevSleep)}.',
      );

    final loggedLast7 = last7.where(_isLogged).toList();
    prompt.writeln('Daily logs (last 7, oldest first):');
    if (loggedLast7.isEmpty) {
      prompt.writeln('- none');
    } else {
      for (final metric in loggedLast7) {
        prompt.writeln('- ${_dailyLine(metric)}');
      }
    }

    prompt.writeln('Weight trend: ${weightSummary.text}');

    prompt
      ..writeln('APP ON-TRACK STATUS: ${_statusLabel(status)}')
      ..writeln(
        'App reasons: ${reasons.isEmpty ? 'none' : reasons.join('; ')}.',
      )
      ..writeln(
        'Use this status as authoritative. Explain it supportively and do not '
        'recalculate a different goal or tell the user to change their target.',
      );

    return AiContextSnapshot(
      prompt: prompt.toString().trim(),
      status: status,
      daysLogged7: daysLogged7,
      avgCalories7: avgCalories7,
      avgWaterMl7: avgWater7,
      avgSteps7: avgSteps7,
      avgSleepMinutes7: avgSleep7,
      avgProteinG7: avgProtein7,
      avgCarbsG7: avgCarbs7,
      avgFatG7: avgFat7,
      weightChange14: weightSummary.change,
      expectedWeightChange14: weightSummary.expected,
      reasons: reasons,
    );
  }

  List<DailyMetrics> _days(
    DateTime today,
    int startOffset,
    int count,
    Map<String, DailyMetrics> metricsByDate,
  ) {
    final days = <DailyMetrics>[];
    for (
      var offset = startOffset + count - 1;
      offset >= startOffset;
      offset--
    ) {
      final date = today.subtract(Duration(days: offset));
      final key = _dateKey(date);
      final metric = metricsByDate[key];
      days.add(metric ?? DailyMetrics(dateKey: key));
    }
    return days;
  }

  int _average(
    List<DailyMetrics> days,
    bool Function(DailyMetrics) hasValue,
    int Function(DailyMetrics) value,
  ) {
    final values = days.where(hasValue).map(value).toList();
    if (values.isEmpty) return 0;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  bool _isLogged(DailyMetrics metric) =>
      _hasCalories(metric) ||
      _hasWater(metric) ||
      _hasSteps(metric) ||
      _hasSleep(metric) ||
      _hasFasting(metric) ||
      _hasNutrition(metric) ||
      (metric.weight ?? 0) > 0;

  bool _hasCalories(DailyMetrics metric) =>
      metric.totalCalories > 0 ||
      metric.calorieEntries.isNotEmpty ||
      metric.nutritionEntries.isNotEmpty;

  bool _hasWater(DailyMetrics metric) => metric.waterMl > 0;

  bool _hasSteps(DailyMetrics metric) =>
      metric.steps > 0 ||
      metric.caloriesBurned > 0 ||
      metric.activities.isNotEmpty;

  bool _hasSleep(DailyMetrics metric) => metric.sleepMinutes > 0;

  bool _hasFasting(DailyMetrics metric) => metric.fastingStartEpoch != null;

  bool _hasNutrition(DailyMetrics metric) =>
      metric.proteinGrams > 0 ||
      metric.carbsGrams > 0 ||
      metric.fatGrams > 0 ||
      metric.nutritionEntries.isNotEmpty;

  _TrackMeasure _calorieMeasure(int average, int target) {
    final difference = average - target;
    final tolerance = max(100, (target * 0.1).round());
    if (difference.abs() <= tolerance) {
      return const _TrackMeasure(_MeasureLevel.good);
    }
    final direction = difference > 0 ? 'above' : 'below';
    final amount = difference.abs();
    if (amount <= 250) {
      return _TrackMeasure(
        _MeasureLevel.slight,
        'average intake is $amount kcal $direction the daily target',
      );
    }
    return _TrackMeasure(
      _MeasureLevel.off,
      'average intake is $amount kcal $direction the daily target',
    );
  }

  _TrackMeasure _waterMeasure(int average, int target) {
    final ratio = target <= 0 ? 1.0 : average / target;
    if (ratio >= 0.9) return const _TrackMeasure(_MeasureLevel.good);
    if (ratio >= 0.7) {
      return _TrackMeasure(
        _MeasureLevel.slight,
        'hydration averages ${(ratio * 100).round()}% of the daily goal',
      );
    }
    return _TrackMeasure(
      _MeasureLevel.off,
      'hydration averages ${(ratio * 100).round()}% of the daily goal',
    );
  }

  _WeightSummary _weightSummary({
    required UserProfile? profile,
    required List<DailyMetrics> metrics,
    required List<WeightEntry> weights,
    required DateTime today,
  }) {
    final byDate = <String, double>{};
    for (final entry in weights) {
      if (entry.weight > 0) byDate[entry.dateKey] = entry.weight;
    }
    for (final metric in metrics) {
      final value = metric.weight;
      if (value != null && value > 0 && !byDate.containsKey(metric.dateKey)) {
        byDate[metric.dateKey] = value;
      }
    }

    final cutoff = today.subtract(const Duration(days: 30));
    final entries = <_WeightPoint>[];
    for (final entry in byDate.entries) {
      final parsed = DateTime.tryParse(entry.key);
      if (parsed == null) continue;
      final date = DateTime(parsed.year, parsed.month, parsed.day);
      if (date.isAfter(today) || date.isBefore(cutoff)) continue;
      entries.add(_WeightPoint(date, entry.value));
    }
    entries.sort((a, b) => a.date.compareTo(b.date));

    if (entries.isEmpty) {
      return const _WeightSummary(
        text: 'no weight entries in the last 30 days',
      );
    }

    final latest = entries.last;
    final fourteenDaysAgo = today.subtract(const Duration(days: 14));
    final window = entries
        .where((entry) => !entry.date.isBefore(fourteenDaysAgo))
        .toList();
    final oldest = window.isEmpty ? entries.first : window.first;
    final spanDays = latest.date.difference(oldest.date).inDays;
    final change = spanDays >= 5 ? latest.weight - oldest.weight : null;
    final plan = profile?.goalPlan;
    final expected = plan == null || change == null
        ? null
        : plan.weeklyKgChange * spanDays / 7;

    final text = StringBuffer(
      'latest ${latest.weight.toStringAsFixed(1)} kg on '
      '${_dateKey(latest.date)}',
    );
    if (change == null) {
      text.write('; not enough entries for a trend');
    } else {
      text.write(
        '; ${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} kg over '
        '$spanDays days',
      );
      if (expected != null) {
        text.write(
          ' (plan expected ${expected >= 0 ? '+' : ''}'
          '${expected.toStringAsFixed(1)} kg)',
        );
      }
    }

    _TrackMeasure? measure;
    if (plan != null && change != null && expected != null) {
      if (plan.isMaintain) {
        if (change.abs() <= 0.5) {
          measure = const _TrackMeasure(_MeasureLevel.good);
        } else if (change.abs() <= 1.0) {
          measure = const _TrackMeasure(
            _MeasureLevel.slight,
            'weight is drifting from maintenance',
          );
        } else {
          measure = const _TrackMeasure(
            _MeasureLevel.off,
            'weight is moving away from maintenance',
          );
        }
      } else if (expected.abs() >= 0.05) {
        final ratio = change / expected;
        if (plan.isLoss) {
          if (change >= 0.1) {
            measure = const _TrackMeasure(
              _MeasureLevel.off,
              'weight is moving up instead of down',
            );
          } else if (ratio > 1.5) {
            measure = const _TrackMeasure(
              _MeasureLevel.slight,
              'weight is dropping faster than the safe plan',
            );
          } else if (ratio < 0.5) {
            measure = const _TrackMeasure(
              _MeasureLevel.slight,
              'weight is dropping slower than the plan',
            );
          } else {
            measure = const _TrackMeasure(_MeasureLevel.good);
          }
        } else {
          if (change <= -0.1) {
            measure = const _TrackMeasure(
              _MeasureLevel.off,
              'weight is moving down instead of up',
            );
          } else if (ratio > 1.5) {
            measure = const _TrackMeasure(
              _MeasureLevel.slight,
              'weight is rising faster than the safe plan',
            );
          } else if (ratio < 0.5) {
            measure = const _TrackMeasure(
              _MeasureLevel.slight,
              'weight is rising slower than the plan',
            );
          } else {
            measure = const _TrackMeasure(_MeasureLevel.good);
          }
        }
      }
    }

    return _WeightSummary(
      text: text.toString(),
      measure: measure,
      change: change,
      expected: expected,
    );
  }

  String _dailyLine(DailyMetrics metric) {
    final parts = <String>[];
    if (_hasCalories(metric)) parts.add('intake ${metric.totalCalories} kcal');
    if (_hasWater(metric)) parts.add('water ${metric.waterMl} ml');
    if (_hasSteps(metric)) parts.add('steps ${metric.steps}');
    if (_hasSleep(metric)) {
      parts.add('sleep ${_minutes(metric.sleepMinutes)}');
    }
    if (_hasFasting(metric)) {
      parts.add('fast ${_minutes(metric.fastingDurationMinutes)}');
    }
    if ((metric.weight ?? 0) > 0) {
      parts.add('weight ${metric.weight!.toStringAsFixed(1)} kg');
    }
    return '${metric.dateKey}: ${parts.isEmpty ? 'logged' : parts.join('; ')}';
  }

  String _minutes(int value) {
    if (value <= 0) return '0m';
    final hours = value ~/ 60;
    final minutes = value % 60;
    if (hours == 0) return '${minutes}m';
    return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  }

  String _dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  String _statusLabel(AiTrackStatus value) => switch (value) {
    AiTrackStatus.onTrack => 'ON_TRACK',
    AiTrackStatus.slightlyOff => 'SLIGHTLY_OFF',
    AiTrackStatus.offTrack => 'OFF_TRACK',
    AiTrackStatus.notEnoughData => 'NOT_ENOUGH_DATA',
  };
}

enum _MeasureLevel { good, slight, off }

class _TrackMeasure {
  const _TrackMeasure(this.level, [this.reason]);

  final _MeasureLevel level;
  final String? reason;
}

class _WeightSummary {
  const _WeightSummary({
    required this.text,
    this.measure,
    this.change,
    this.expected,
  });

  final String text;
  final _TrackMeasure? measure;
  final double? change;
  final double? expected;
}

class _WeightPoint {
  const _WeightPoint(this.date, this.weight);

  final DateTime date;
  final double weight;
}
