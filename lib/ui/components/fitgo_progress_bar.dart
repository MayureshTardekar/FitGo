import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Animated progress bar with semantic colour support.
class FitGoProgressBar extends StatelessWidget {
  const FitGoProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.trackColor,
    this.height = 10,
    this.semanticLabel,
  });

  final double progress;
  final Color? color;
  final Color? trackColor;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final clamped = progress.clamp(0.0, 1.0);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FitGoRadii.pill),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: clamped),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: trackColor ?? tokens.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color ?? tokens.ember),
          ),
        ),
      ),
    );
  }
}
