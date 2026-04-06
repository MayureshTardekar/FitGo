import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils.dart';
import '../providers/timer_provider.dart';

class RadialDial extends ConsumerWidget {
  const RadialDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fasting = ref.watch(fastingProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Red → Yellow → Green gradient based on progress
    final progressColor = _getProgressColor(fasting.progress);
    final glowColor = progressColor.withAlpha(60);

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect behind the dial
          if (fasting.isFasting)
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: glowColor, blurRadius: 30, spreadRadius: 5),
                ],
              ),
            ),
          // The dial itself
          CustomPaint(
            size: const Size(220, 220),
            painter: _RadialDialPainter(
              progress: fasting.progress,
              trackColor: colorScheme.surfaceContainerHighest,
              progressColor: progressColor,
              isFasting: fasting.isFasting,
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fasting.isFasting) ...[
                // Percentage
                Text(
                  '${(fasting.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              // Elapsed time — monospace to prevent jitter
              Text(
                fasting.isFasting
                    ? formatDuration(fasting.elapsed)
                    : '00:00:00',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: fasting.isFasting
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              if (fasting.isFasting) ...[
                Text(
                  fasting.isComplete
                      ? 'Goal reached!'
                      : '${formatDurationShort(fasting.target - fasting.elapsed)} remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fasting.isComplete
                        ? const Color(0xFFFFBA08)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: fasting.isComplete
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (fasting.isComplete) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+${formatDurationShort(fasting.elapsed - fasting.target)} overtime',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFBA08),
                    ),
                  ),
                ],
              ] else
                Text(
                  'Ready to fast',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Oxblood (0%) → Brick Ember → Cayenne → Saffron → Amber (100%)
  static Color _getProgressColor(double progress) {
    if (progress <= 0) return const Color(0xFF9D0208); // Oxblood
    if (progress >= 1.0) return const Color(0xFFFFBA08); // Amber Flame

    const colors = [
      Color(0xFF9D0208), // Oxblood
      Color(0xFFD00000), // Brick Ember
      Color(0xFFDC2F02), // Red Ochre
      Color(0xFFE85D04), // Cayenne Red
      Color(0xFFF48C06), // Deep Saffron
      Color(0xFFFAA307), // Orange
      Color(0xFFFFBA08), // Amber Flame
    ];

    final segment = progress * (colors.length - 1);
    final index = segment.floor().clamp(0, colors.length - 2);
    final t = segment - index;

    return Color.lerp(colors[index], colors[index + 1], t)!;
  }
}

class _RadialDialPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final bool isFasting;

  _RadialDialPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.isFasting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const strokeWidth = 14.0;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (!isFasting) return;

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

    // Draw gradient arc
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Use a sweep gradient for the arc
    if (progress > 0) {
      progressPaint.shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: _buildGradientColors(),
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);

      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);

      // Draw end cap dot for polish
      final endAngle = -pi / 2 + sweepAngle;
      final capX = center.dx + radius * cos(endAngle);
      final capY = center.dy + radius * sin(endAngle);
      final capPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(capX, capY), strokeWidth / 2, capPaint);
    }

    // Tick marks at 25%, 50%, 75%
    for (final fraction in [0.25, 0.5, 0.75]) {
      final tickAngle = -pi / 2 + 2 * pi * fraction;
      final innerR = radius - strokeWidth / 2 - 4;
      final outerR = radius + strokeWidth / 2 + 4;
      final tickPaint = Paint()
        ..color = trackColor.withAlpha(150)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(
          center.dx + innerR * cos(tickAngle),
          center.dy + innerR * sin(tickAngle),
        ),
        Offset(
          center.dx + outerR * cos(tickAngle),
          center.dy + outerR * sin(tickAngle),
        ),
        tickPaint,
      );
    }
  }

  List<Color> _buildGradientColors() {
    return [
      const Color(0xFF9D0208), // Oxblood
      const Color(0xFFD00000), // Brick Ember
      const Color(0xFFDC2F02), // Red Ochre
      const Color(0xFFE85D04), // Cayenne Red
      const Color(0xFFF48C06), // Deep Saffron
      const Color(0xFFFAA307), // Orange
      const Color(0xFFFFBA08), // Amber Flame
    ];
  }

  @override
  bool shouldRepaint(_RadialDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isFasting != isFasting ||
      oldDelegate.trackColor != trackColor;
}
