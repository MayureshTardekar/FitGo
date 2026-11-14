import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';
import 'fitgo_empty_state.dart';

/// Chart container with a title, legend, empty state, and accessibility
/// summary for custom painters.
class FitGoChartCard extends StatelessWidget {
  const FitGoChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.legend = const [],
    this.semanticsLabel,
    this.isEmpty = false,
    this.emptyTitle = 'No data yet',
    this.emptyMessage = 'Log a few days to see this chart.',
    this.trailing,
    this.height,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<({String label, Color color})> legend;
  final String? semanticsLabel;
  final bool isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? trailing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(FitGoSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow.a == 0
            ? null
            : [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Kept as an explicit null check so hive_generator's older
              // analyzer can parse this file.
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
          if (legend.isNotEmpty) ...[
            const SizedBox(height: FitGoSpacing.sm),
            Wrap(
              spacing: FitGoSpacing.md,
              runSpacing: FitGoSpacing.xs,
              children: [
                for (final item in legend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: FitGoSpacing.md),
          if (isEmpty)
            SizedBox(
              height: height ?? 140,
              child: FitGoEmptyState(
                icon: Icons.bar_chart_rounded,
                title: emptyTitle,
                message: emptyMessage,
              ),
            )
          else
            Semantics(
              label: semanticsLabel ?? title,
              child: RepaintBoundary(
                child: height == null
                    ? child
                    : SizedBox(height: height, child: child),
              ),
            ),
        ],
      ),
    );
  }
}
