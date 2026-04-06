import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/weekly_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _TimeframeToggle(),
          const SizedBox(height: 16),
          const _ScoreRing(),
          SizedBox(height: 16),
          _QuickStats(),
          SizedBox(height: 16),
          _CumulativeTrendChart(),
          SizedBox(height: 16),
          _DailyBarChart(),
          SizedBox(height: 16),
          _CalorieHeatmapRow(),
          SizedBox(height: 16),
          _DayByDayExpander(),
          SizedBox(height: 16),
          _InsightsCard(),
          SizedBox(height: 16),
          _ProjectionCard(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Timeframe Toggle ────────────────────────────────────────────────────────
class _TimeframeToggle extends ConsumerWidget {
  const _TimeframeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeframeState = ref.watch(analyticsTimeframeProvider);
    final timeframe = timeframeState.timeframe;
    final analytics = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: analytics.canGoBack
                  ? () => ref.read(analyticsTimeframeProvider.notifier).previous()
                  : null,
            ),
            Expanded(
              child: Text(
                analytics.periodLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: analytics.canGoForward
                  ? () => ref.read(analyticsTimeframeProvider.notifier).next()
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<Timeframe>(
          segments: const [
            ButtonSegment(value: Timeframe.thisWeek, label: Text('Week')),
            ButtonSegment(value: Timeframe.thisMonth, label: Text('Month')),
            ButtonSegment(value: Timeframe.thisYear, label: Text('Year')),
          ],
          selected: {timeframe},
          onSelectionChanged: (set) {
            ref.read(analyticsTimeframeProvider.notifier).updateTimeframe(set.first);
          },
          style: SegmentedButton.styleFrom(
            foregroundColor: cs.onSurface,
            selectedForegroundColor: cs.onPrimary,
            selectedBackgroundColor: cs.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ─── Score Ring ──────────────────────────────────────────────────────────────

class _ScoreRing extends ConsumerWidget {
  const _ScoreRing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final score = weekly.consistencyScore;
    final ringColor = score >= 70
        ? const Color(0xFFFFBA08)
        : score >= 40
        ? const Color(0xFFE85D04)
        : cs.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Animated score ring
            SizedBox(
              width: 90,
              height: 90,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: value,
                    color: ringColor,
                    trackColor: cs.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ringColor,
                          ),
                        ),
                        Text(
                          'score',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consistency Score',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score >= 70
                        ? 'Excellent! You\'re hitting your targets consistently.'
                        : score >= 40
                        ? 'Good effort. Try to stay within 15% of your daily target.'
                        : 'Your intake varies a lot. Aim for steady daily portions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (weekly.streakDays >= 2) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE85D04).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Color(0xFFFF9800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${weekly.streakDays}-day streak',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Quick Stats Row ─────────────────────────────────────────────────────────

class _QuickStats extends ConsumerWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isOver = w.remainingBudget < 0;

    return Row(
      children: [
        _MiniStat(
          label: 'Consumed',
          value: '${w.totalConsumed}',
          unit: 'kcal',
          icon: Icons.local_fire_department,
          color: cs.error,
        ),
        const SizedBox(width: 8),
        _MiniStat(
          label: 'Remaining',
          value: '${w.remainingBudget.abs()}',
          unit: isOver ? 'over' : 'left',
          icon: isOver ? Icons.warning_amber : Icons.check_circle_outline,
          color: isOver ? cs.error : const Color(0xFFFFBA08),
        ),
        const SizedBox(width: 8),
        _MiniStat(
          label: 'Avg / Day',
          value: '${w.avgDailyIntake}',
          unit: 'kcal',
          icon: Icons.show_chart,
          color: cs.primary,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                unit,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Cumulative Trend Chart (Line + Area) ────────────────────────────────────

class _CumulativeTrendChart extends ConsumerStatefulWidget {
  const _CumulativeTrendChart();
  @override
  ConsumerState<_CumulativeTrendChart> createState() =>
      _CumulativeTrendChartState();
}

class _CumulativeTrendChartState extends ConsumerState<_CumulativeTrendChart> {
  bool _isCumulative = true;

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final actualSpots = <FlSpot>[];
    final targetSpots = <FlSpot>[];

    double maxY = 0;

    if (_isCumulative) {
      double highestTarget = w.cumulativeTarget.last.toDouble();
      double highestActual = 0;
      for (int i = 0; i < 7; i++) {
        targetSpots.add(FlSpot(i.toDouble(), w.cumulativeTarget[i].toDouble()));
        if (!w.days[i].isFuture) {
          final double val = w.cumulativeIntake[i].toDouble();
          actualSpots.add(FlSpot(i.toDouble(), val));
          if (val > highestActual) highestActual = val;
        }
      }
      maxY =
          (highestActual > highestTarget ? highestActual : highestTarget) *
          1.15;
      if (maxY == 0) maxY = 10000;
    } else {
      double maxDaily = w.adjustedDailyTarget.toDouble();
      for (int i = 0; i < 7; i++) {
        final double tgt = w.adjustedDailyTarget > 0
            ? w.adjustedDailyTarget.toDouble()
            : 2000.0;
        targetSpots.add(FlSpot(i.toDouble(), tgt));
        if (!w.days[i].isFuture) {
          actualSpots.add(FlSpot(i.toDouble(), w.days[i].calories.toDouble()));
          if (w.days[i].calories > maxDaily)
            maxDaily = w.days[i].calories.toDouble();
        }
      }
      maxY = maxDaily * 1.35;
      if (maxY == 0) maxY = 2500;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isCumulative ? 'Cumulative Trend' : 'Daily Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton('Daily', !_isCumulative, () {
                        setState(() {
                          _isCumulative = false;
                        });
                      }, cs),
                      _buildToggleButton('Cumul', _isCumulative, () {
                        setState(() {
                          _isCumulative = true;
                        });
                      }, cs),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isCumulative
                        ? 'Your intake vs ideal pace toward ${w.totalGoal} kcal'
                        : 'Daily zigzag pattern vs target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                _LegendDot(color: cs.primary, label: 'Actual'),
                const SizedBox(width: 12),
                _LegendDot(color: cs.outlineVariant, label: 'Target'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withAlpha(50),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: maxY / 4 > 0 ? maxY / 4 : 1,
                        getTitlesWidget: (v, _) => Text(
                          _formatK(v),
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= w.days.length) {
                            return const SizedBox();
                          }
                          int step = w.days.length > 14 ? (w.days.length / 7).ceil() : 1;
                          if (i % step != 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              w.days[i].dayName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: w.days[i].isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: w.days[i].isToday
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Target line (dashed)
                    LineChartBarData(
                      spots: targetSpots,
                      isCurved: false,
                      color: cs.outlineVariant,
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.outlineVariant.withAlpha(15),
                      ),
                    ),
                    // Actual line
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: cs.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          bool isOver = false;
                          if (index >= 0 && index < targetSpots.length) {
                            // Compare current actual tracking vs target mapping array for the same day
                            isOver = spot.y > targetSpots[index].y;
                          }
                          return FlDotCirclePainter(
                            radius: isOver ? 5.5 : 4,
                            color: isOver ? cs.error : cs.primary,
                            strokeWidth: 2,
                            strokeColor: cs.surface,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cs.primary.withAlpha(25),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final day = w.days[s.x.toInt()];
                        return LineTooltipItem(
                          '${day.dayName}: ${s.y.toInt()} kcal',
                          TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    String text,
    bool isSelected,
    VoidCallback onTap,
    ColorScheme cs,
  ) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _formatK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Daily Bar Chart ─────────────────────────────────────────────────────────

class _DailyBarChart extends ConsumerWidget {
  const _DailyBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final maxY = _calcMaxY(w);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Intake',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final day = w.days[group.x];
                        final diff = day.difference;
                        final sign = diff >= 0 ? '+' : '';
                        return BarTooltipItem(
                          '${day.dayName}\n${day.calories} kcal\n$sign$diff',
                          TextStyle(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
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
                        reservedSize: 42,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= w.days.length) {
                            return const SizedBox();
                          }
                          int step = w.days.length > 14 ? (w.days.length / 7).ceil() : 1;
                          if (i % step != 0) return const SizedBox();
                          final day = w.days[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  day.dayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: day.isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: day.isToday
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                                if (!day.isFuture && day.calories > 0)
                                  Text(
                                    '${day.calories}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: cs.outlineVariant.withAlpha(50),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: w.days.asMap().entries.map((e) {
                    final i = e.key;
                    final day = e.value;

                    List<BarChartRodStackItem>? stackItems;
                    Color barColor = _barColor(day, cs);

                    // Dynamic split logic (No hardcoded values):
                    // Base color for normal bounds, Red for the part exceeding dailyTarget
                    if (!day.isFuture && day.isOver && day.dailyTarget > 0) {
                      barColor = Colors.transparent;
                      final double limit = day.dailyTarget.toDouble();
                      final double total = day.calories.toDouble();
                      stackItems = [
                        BarChartRodStackItem(
                          0,
                          limit,
                          const Color(0xFFFFBA08),
                        ), // Safe limit (Yellow/Orange)
                        BarChartRodStackItem(
                          limit,
                          total,
                          cs.error,
                        ), // Over limit portion (Red)
                      ];
                    }

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: day.isFuture
                              ? day.dailyTarget * 0.15
                              : day.calories.toDouble(),
                          width: 24,
                          color: barColor,
                          rodStackItems: stackItems,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: day.dailyTarget.toDouble(),
                            color: cs.outlineVariant.withAlpha(30),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: w.adjustedDailyTarget.toDouble(),
                        color: cs.primary.withAlpha(100),
                        strokeWidth: 2,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            fontSize: 9,
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          labelResolver: (_) => '${w.adjustedDailyTarget}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calcMaxY(DashboardAnalytics w) {
    double m = w.adjustedDailyTarget.toDouble();
    for (final d in w.days) {
      if (d.calories > m) m = d.calories.toDouble();
    }
    return (m * 1.3).ceilToDouble();
  }

  Color _barColor(DaySummary day, ColorScheme cs) {
    if (day.isFuture) return cs.outlineVariant.withAlpha(40);
    if (day.calories == 0) return cs.outlineVariant.withAlpha(60);
    if (day.isOver) return cs.error;
    if (day.progress >= 0.85) return const Color(0xFFE85D04);
    return const Color(0xFFFFBA08);
  }
}

// ─── Calorie Heatmap Row ─────────────────────────────────────────────────────

class _CalorieHeatmapRow extends ConsumerWidget {
  const _CalorieHeatmapRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeframe Heatmap',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Intensity shows how close to target each day',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: w.days.length > 7 ? 4 : 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: w.days.map((day) {
                return SizedBox(
                  width: w.days.length > 7 ? 28 : 40,
                  child: Column(
                    children: [
                      Text(
                        w.days.length > 31 ? '' : day.dayName,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: day.isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: day.isToday
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: w.days.length > 31 ? 0 : 4),
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _heatColor(day, cs),
                            borderRadius: BorderRadius.circular(4),
                            border: day.isToday
                                ? Border.all(color: cs.primary, width: 1.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: !day.isFuture && day.calories > 0
                              ? Text(
                                  w.days.length > 14 ? '' : '${day.calories}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: day.isOver
                                        ? Colors.white
                                        : cs.onSurface,
                                  ),
                                )
                              : Icon(
                                  day.isFuture ? Icons.remove : Icons.close,
                                  size: w.days.length > 14 ? 8 : 12,
                                  color: cs.onSurfaceVariant,
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeatLegend(
                  color: cs.surfaceContainerHighest,
                  label: 'No data',
                ),
                const SizedBox(width: 8),
                const _HeatLegend(color: Color(0xFFFAA307), label: 'On target'),
                const SizedBox(width: 8),
                const _HeatLegend(color: Color(0xFFE85D04), label: 'Close'),
                const SizedBox(width: 8),
                _HeatLegend(color: cs.error, label: 'Over'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _heatColor(DaySummary day, ColorScheme cs) {
    if (day.isFuture) return cs.surfaceContainerHighest;
    if (day.calories == 0) return cs.surfaceContainerHighest;
    final deviation = (day.calories - day.dailyTarget).abs() / day.dailyTarget;
    if (day.isOver) {
      if (deviation > 0.2) return cs.error;
      return const Color(0xFFE85D04);
    }
    if (deviation < 0.1) return const Color(0xFFFFBA08);
    if (deviation < 0.2) return const Color(0xFFFAA307);
    return const Color(0xFFF48C06);
  }
}

class _HeatLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _HeatLegend({required this.color, required this.label});

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
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Day by Day Expandable List ──────────────────────────────────────────────

class _DayByDayExpander extends ConsumerWidget {
  const _DayByDayExpander();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Day Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...w.days
                .where((d) => !d.isFuture)
                .map((day) => _ExpandableDayTile(day: day)),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDayTile extends StatelessWidget {
  final DaySummary day;

  const _ExpandableDayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final diff = day.difference;
    final diffText = diff >= 0 ? '+$diff' : '$diff';
    final diffColor = diff > 0 ? cs.error : const Color(0xFFFFBA08);

    return ExpansionTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: day.isToday ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: day.isToday ? Border.all(color: cs.primary, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          day.dayName,
          style: TextStyle(
            fontSize: 11,
            fontWeight: day.isToday ? FontWeight.bold : FontWeight.w500,
            color: day.isToday ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            '${day.calories} kcal',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            diffText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              color: diffColor,
            ),
          ),
        ],
      ),
      subtitle: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: day.progress.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: cs.surfaceContainerHighest,
          color: day.isOver ? cs.error : const Color(0xFFFFBA08),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DetailChip(
                    label: 'Target',
                    value: '${day.dailyTarget}',
                    unit: 'kcal',
                    color: cs.primary,
                  ),
                  _DetailChip(
                    label: 'Actual',
                    value: '${day.calories}',
                    unit: 'kcal',
                    color: cs.onSurface,
                  ),
                  _DetailChip(
                    label: 'Water',
                    value: '${day.waterMl}',
                    unit: 'ml',
                    color: const Color(0xFFF48C06),
                  ),
                  _DetailChip(
                    label: 'Progress',
                    value: '${(day.progress * 100).toInt()}',
                    unit: '%',
                    color: day.isOver ? cs.error : const Color(0xFFFFBA08),
                  ),
                ],
              ),
              if (day.calorieEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Calorie Log:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: day.calorieEntries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: color,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Insights Card ───────────────────────────────────────────────────────────

class _InsightsCard extends ConsumerWidget {
  const _InsightsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);

    if (w.insights.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...w.insights.map((insight) => _InsightRow(insight: insight)),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final Insight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final typeColor = switch (insight.type) {
      InsightType.positive => const Color(0xFFFFBA08),
      InsightType.warning => const Color(0xFFE85D04),
      InsightType.negative => cs.error,
      InsightType.info => cs.primary,
    };

    final iconData = switch (insight.icon) {
      IconType.trophy => Icons.emoji_events,
      IconType.fire => Icons.local_fire_department,
      IconType.trending => Icons.trending_up,
      IconType.target => Icons.gps_fixed,
      IconType.alert => Icons.warning_amber_rounded,
      IconType.tip => Icons.tips_and_updates,
      IconType.streak => Icons.bolt,
      IconType.water => Icons.water_drop,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 16, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
                Text(
                  insight.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
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

// ─── Projection Card ─────────────────────────────────────────────────────────

class _ProjectionCard extends ConsumerWidget {
  const _ProjectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dashboardAnalyticsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isOnTrack = w.isOnTrack;
    final projDiff = w.projectedTotal - w.totalGoal;

    return Card(
      color: isOnTrack
          ? const Color(0xFFFFBA08).withAlpha(15)
          : cs.error.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isOnTrack ? Icons.rocket_launch : Icons.warning_amber,
                  color: isOnTrack ? const Color(0xFFFFBA08) : cs.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Period-End Projection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Projection gauge
            _ProjectionGauge(
              projected: w.projectedTotal,
              goal: w.totalGoal,
              isOnTrack: isOnTrack,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniProjectionStat(
                  label: 'Projected',
                  value: w.projectedTotal,
                  color: cs.onSurface,
                ),
                _MiniProjectionStat(
                  label: 'Goal',
                  value: w.totalGoal,
                  color: cs.onSurfaceVariant,
                ),
                _MiniProjectionStat(
                  label: isOnTrack ? 'Under' : 'Over',
                  value: projDiff.abs(),
                  color: isOnTrack ? const Color(0xFFFFBA08) : cs.error,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showEditGoal(context, ref, w.totalGoal),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOnTrack
                            ? 'On track! Aim for ${w.adjustedDailyTarget} kcal/day to finish strong.'
                            : 'Reduce to ${w.adjustedDailyTarget} kcal/day to get back on track.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGoal(BuildContext context, WidgetRef ref, int current) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Weekly Calorie Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Weekly budget (kcal)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) {
                ref
                    .read(profileProvider.notifier)
                    .updateGoals(weeklyCalorieGoal: v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ProjectionGauge extends StatelessWidget {
  final int projected;
  final int goal;
  final bool isOnTrack;

  const _ProjectionGauge({
    required this.projected,
    required this.goal,
    required this.isOnTrack,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = goal > 0 ? (projected / goal).clamp(0.0, 1.5) : 0.0;
    final goalPosition = goal > 0
        ? (1.0 / max(ratio, 1.0)).clamp(0.0, 1.0)
        : 0.5;

    return Column(
      children: [
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final markerPos = (goalPosition * width).clamp(16, width - 16);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) =>
                            LinearProgressIndicator(
                              value: value,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: isOnTrack
                                  ? const Color(0xFFFFBA08)
                                  : cs.error,
                            ),
                      ),
                    ),
                  ),
                  // Goal marker
                  Positioned(
                    left: markerPos - 1,
                    top: -2,
                    child: Container(width: 2, height: 24, color: cs.onSurface),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniProjectionStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniProjectionStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            fontFeatures: const [FontFeature.tabularFigures()],
            color: color,
          ),
        ),
        Text(
          'kcal',
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
