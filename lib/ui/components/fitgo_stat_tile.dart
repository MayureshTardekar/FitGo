import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';
import 'fitgo_card.dart';

/// Compact icon + value + label card used in metric grids.
class FitGoStatTile extends StatelessWidget {
  const FitGoStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
    this.trend,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? unit;
  final String? trend;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final accent = color ?? tokens.ember;

    return FitGoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FitGoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(FitGoRadii.input),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const Spacer(),
              if (trend != null)
                Text(
                  trend!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.mint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: FitGoSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
