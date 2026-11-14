import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Small status/tag chip.
class FitGoPill extends StatelessWidget {
  const FitGoPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final foreground = color ?? tokens.textSecondary;
    final bg = background ?? foreground.withValues(alpha: 0.12);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );

    return Semantics(
      label: label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Inside a Row the pill can receive unbounded width. Only use a
          // flexible label when the parent gives us a width to wrap into.
          final canWrap = constraints.hasBoundedWidth;
          final labelText = Text(
            label,
            maxLines: canWrap ? 2 : 1,
            overflow: canWrap ? TextOverflow.ellipsis : TextOverflow.clip,
            style: textStyle,
          );

          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FitGoSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(FitGoRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: foreground),
                  const SizedBox(width: 4),
                ],
                if (canWrap) Flexible(child: labelText) else labelText,
              ],
            ),
          );
        },
      ),
    );
  }
}
