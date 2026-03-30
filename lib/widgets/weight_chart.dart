import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/weight_provider.dart';

class WeightChart extends ConsumerWidget {
  const WeightChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(weightProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No weight data yet.\nLog your weight to see the chart!',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
        .toList();

    final weights = entries.map((e) => e.weight).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = (weights.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withAlpha(80),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 2,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (entries.length > 7) ? (entries.length / 5).ceil().toDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) return const SizedBox();
                  final date = entries[index].dateKey;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      date.substring(5), // "MM-DD"
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withAlpha(30),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg',
                  TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
