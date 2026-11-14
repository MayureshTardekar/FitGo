import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Animated progress ring with centre content and screen-reader semantics.
class FitGoRing extends StatelessWidget {
  const FitGoRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 220,
    this.strokeWidth = 14,
    this.color,
    this.trackColor,
    this.semanticLabel = 'Progress',
    this.duration = const Duration(milliseconds: 600),
  });

  final double progress;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final String semanticLabel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clamped = progress.clamp(0.0, 1.0);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()} percent',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: clamped),
                duration: reduceMotion ? Duration.zero : duration,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    progress: value,
                    track: trackColor ?? tokens.surfaceMuted,
                    color: color ?? tokens.ember,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color track;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = track);
    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5707963267948966,
      6.283185307179586 * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.track != track ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
