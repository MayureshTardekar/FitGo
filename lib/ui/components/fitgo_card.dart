import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Tonal surface card with a 1 px border and a soft light-mode shadow.
class FitGoCard extends StatelessWidget {
  const FitGoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FitGoSpacing.lg),
    this.onTap,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final effectiveRadius = radius ?? tokens.cardRadius;

    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? tokens.surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(effectiveRadius),
      border: Border.all(color: borderColor ?? tokens.border),
      boxShadow: tokens.shadow.a == 0
          ? null
          : [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    );

    final card = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(effectiveRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
