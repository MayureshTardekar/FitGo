import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/analytics_provider.dart';
import '../providers/local_data_refresh.dart';
import '../providers/storage_provider.dart';
import '../providers/weekly_provider.dart';
import '../ui/components/fitgo_card.dart';
import '../ui/components/fitgo_pill.dart';
import '../ui/components/fitgo_segmented_control.dart';
import '../ui/components/fitgo_section_header.dart';
import '../ui/theme/fitgo_tokens.dart';
import '../ui/today/meal_sheet.dart';

/// Trends answers one question: how is this week tracking against budget?
/// Heatmaps and projections belong in detail screens, not here.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final timeframe = ref.watch(analyticsTimeframeProvider).timeframe;
    final history = _historyEntries(analytics, timeframe);

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: RefreshIndicator(
        onRefresh: () async {
          final storage = ref.read(localStorageProvider);
          await storage.syncWithCloud();
          refreshLocalDataProviders(ref);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  FitGoSpacing.md,
                  FitGoSpacing.xs,
                  FitGoSpacing.md,
                  0,
                ),
                child: _PeriodHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  FitGoSpacing.md,
                  FitGoSpacing.md,
                  FitGoSpacing.md,
                  0,
                ),
                child: _IntakeChartCard(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  FitGoSpacing.md,
                  FitGoSpacing.sm,
                  FitGoSpacing.md,
                  0,
                ),
                child: _InsightCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitGoSpacing.md,
                  FitGoSpacing.xl,
                  FitGoSpacing.md,
                  0,
                ),
                child: FitGoSectionHeader(
                  title: timeframe == Timeframe.thisYear
                      ? 'Monthly totals'
                      : 'History',
                  subtitle: 'Tap a row to review or edit that log.',
                ),
              ),
            ),
            if (history.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(FitGoSpacing.lg),
                  child: Text('Nothing logged in this period yet.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FitGoSpacing.md,
                  0,
                  FitGoSpacing.md,
                  FitGoSpacing.xxxl,
                ),
                sliver: SliverList.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: FitGoSpacing.xs),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    if (entry is _MonthEntry) {
                      return _MonthHistoryRow(entry: entry);
                    }
                    return _DayHistoryRow(day: entry as DaySummary);
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: FitGoSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  List<Object> _historyEntries(
    DashboardAnalytics analytics,
    Timeframe timeframe,
  ) {
    if (timeframe != Timeframe.thisYear) {
      return analytics.days
          .where((day) => !day.isFuture)
          .toList()
          .reversed
          .toList();
    }

    final months = <int, _MonthEntry>{};
    for (final day in analytics.days) {
      if (day.isFuture) continue;
      final date = DateTime.parse(day.dateKey);
      final entry = months.putIfAbsent(
        date.month,
        () => _MonthEntry(month: DateTime(date.year, date.month)),
      );
      entry
        ..intake += day.calories
        ..budget += day.dailyTarget;
    }

    return months.values.toList()..sort((a, b) => b.month.compareTo(a.month));
  }
}

class _PeriodHeader extends ConsumerWidget {
  const _PeriodHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsTimeframeProvider);
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final controller = ref.read(analyticsTimeframeProvider.notifier);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: analytics.canGoBack ? controller.previous : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                analytics.periodLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next period',
              onPressed: analytics.canGoForward ? controller.next : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: FitGoSpacing.xs),
        FitGoSegmentedControl<Timeframe>(
          values: const [
            Timeframe.thisWeek,
            Timeframe.thisMonth,
            Timeframe.thisYear,
          ],
          labels: const ['Week', 'Month', 'Year'],
          selected: state.timeframe,
          onChanged: controller.updateTimeframe,
        ),
      ],
    );
  }
}

class _IntakeChartCard extends ConsumerWidget {
  const _IntakeChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final timeframe = ref.watch(analyticsTimeframeProvider).timeframe;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final buckets = _buildBuckets(analytics, timeframe);
    final over = analytics.remainingBudget < 0;

    final maxY = buckets.fold<double>(
      0,
      (value, bucket) =>
          math.max(value, math.max(bucket.intake, bucket.budget).toDouble()),
    );
    final chartMax = maxY <= 0 ? 2000.0 : maxY * 1.18;

    return FitGoCard(
      padding: const EdgeInsets.all(FitGoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Intake vs budget',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FitGoPill(
                label: over
                    ? '${analytics.remainingBudget.abs()} over'
                    : '${analytics.remainingBudget} left',
                color: over
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.xxs),
          Text(
            '${analytics.totalConsumed} of ${analytics.totalGoal} kcal for ${analytics.periodLabel.toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: FitGoSpacing.md),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: tokens.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        final bucket = buckets[index];
                        final show = switch (timeframe) {
                          Timeframe.thisWeek => true,
                          Timeframe.thisMonth =>
                            index == 0 || (index + 1) % 5 == 0,
                          Timeframe.thisYear => true,
                        };
                        if (!show) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            bucket.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: bucket.isToday
                                  ? tokens.emberDeep
                                  : tokens.textSecondary,
                              fontWeight: bucket.isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: timeframe == Timeframe.thisMonth
                                  ? 9
                                  : 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bucket = buckets[group.x];
                      return BarTooltipItem(
                        '${bucket.label}\n'
                        '${bucket.intake} kcal\n'
                        'Budget ${bucket.budget}',
                        theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].intake.toDouble(),
                          width: switch (timeframe) {
                            Timeframe.thisWeek => 22,
                            Timeframe.thisMonth => 6,
                            Timeframe.thisYear => 14,
                          },
                          color: buckets[i].intake > buckets[i].budget
                              ? theme.colorScheme.error
                              : tokens.ember,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: buckets[i].budget.toDouble(),
                            color: tokens.surfaceMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FitGoSpacing.xs),
          Row(
            children: [
              _LegendDot(color: tokens.ember, label: 'Intake'),
              const SizedBox(width: FitGoSpacing.md),
              _LegendDot(color: tokens.surfaceMuted, label: 'Budget'),
            ],
          ),
        ],
      ),
    );
  }

  List<_ChartBucket> _buildBuckets(
    DashboardAnalytics analytics,
    Timeframe timeframe,
  ) {
    if (timeframe != Timeframe.thisYear) {
      return analytics.days
          .map(
            (day) => _ChartBucket(
              label: day.dayName,
              intake: day.calories,
              budget: day.dailyTarget,
              isToday: day.isToday,
            ),
          )
          .toList();
    }

    final buckets = <_ChartBucket>[];
    for (var month = 1; month <= 12; month++) {
      var intake = 0;
      var budget = 0;
      for (final day in analytics.days) {
        final date = DateTime.parse(day.dateKey);
        if (date.month != month) continue;
        intake += day.calories;
        budget += day.dailyTarget;
      }
      buckets.add(
        _ChartBucket(
          label: DateFormat('MMM').format(DateTime(2000, month)),
          intake: intake,
          budget: budget,
        ),
      );
    }
    return buckets;
  }
}

class _ChartBucket {
  const _ChartBucket({
    required this.label,
    required this.intake,
    required this.budget,
    this.isToday = false,
  });

  final String label;
  final int intake;
  final int budget;
  final bool isToday;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: context.tokens.border),
          ),
        ),
        const SizedBox(width: FitGoSpacing.xxs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }
}

class _InsightCard extends ConsumerWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(
      dashboardAnalyticsProvider.select(
        (analytics) =>
            analytics.insights.isEmpty ? null : analytics.insights.first,
      ),
    );
    if (insight == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (color, icon) = switch (insight.type) {
      InsightType.positive => (
        theme.colorScheme.tertiary,
        Icons.trending_up_rounded,
      ),
      InsightType.warning => (tokens.emberDeep, Icons.warning_amber_rounded),
      InsightType.negative => (
        theme.colorScheme.error,
        Icons.error_outline_rounded,
      ),
      InsightType.info => (tokens.aqua, Icons.lightbulb_outline_rounded),
    };

    return FitGoCard(
      padding: const EdgeInsets.all(FitGoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FitGoRadii.input),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: FitGoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHistoryRow extends StatelessWidget {
  const _DayHistoryRow({required this.day});

  final DaySummary day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final date = DateTime.parse(day.dateKey);
    final isToday = day.isToday;
    final title = isToday ? 'Today' : DateFormat('EEE, d MMM').format(date);
    final over = day.isOver;
    final diff = day.difference;

    return FitGoCard(
      padding: EdgeInsets.zero,
      onTap: () {
        if (isToday) {
          showMealSheet(context);
        } else {
          context.push('/past-day?date=${day.dateKey}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FitGoSpacing.md,
          vertical: FitGoSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isToday
                    ? tokens.ember.withValues(alpha: 0.14)
                    : tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(FitGoRadii.input),
              ),
              alignment: Alignment.center,
              child: Text(
                isToday ? 'Today' : DateFormat('d').format(date),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday ? tokens.emberDeep : tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: isToday ? 10 : 15,
                ),
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: day.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: tokens.surfaceMuted,
                      color: over ? theme.colorScheme.error : tokens.ember,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Text(
              '${day.calories} kcal',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: FitGoSpacing.xs),
            Text(
              diff >= 0 ? '+$diff' : '$diff',
              style: theme.textTheme.labelMedium?.copyWith(
                color: over
                    ? theme.colorScheme.error
                    : theme.colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: FitGoSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthEntry {
  _MonthEntry({required this.month});

  final DateTime month;
  int intake = 0;
  int budget = 0;

  bool get isOver => intake > budget;

  double get progress => budget > 0 ? (intake / budget).clamp(0.0, 1.5) : 0;
}

class _MonthHistoryRow extends ConsumerWidget {
  const _MonthHistoryRow({required this.entry});

  final _MonthEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return FitGoCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          ref.read(analyticsTimeframeProvider.notifier).showMonth(entry.month),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FitGoSpacing.md,
          vertical: FitGoSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.surfaceMuted,
                borderRadius: BorderRadius.circular(FitGoRadii.input),
              ),
              alignment: Alignment.center,
              child: Text(
                DateFormat('MMM').format(entry.month),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(entry.month),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: entry.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: tokens.surfaceMuted,
                      color: entry.isOver
                          ? theme.colorScheme.error
                          : tokens.ember,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FitGoSpacing.sm),
            Text(
              '${entry.intake}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ' / ${entry.budget}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(width: FitGoSpacing.xxs),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
