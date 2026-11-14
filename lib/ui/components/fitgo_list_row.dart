import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// iOS-settings-style row with optional leading icon and trailing value.
class FitGoListRow extends StatelessWidget {
  const FitGoListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final foreground = destructive
        ? theme.colorScheme.error
        : tokens.textPrimary;
    final secondary = destructive
        ? theme.colorScheme.error
        : tokens.textSecondary;

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FitGoSpacing.md,
            vertical: FitGoSpacing.sm,
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (destructive ? theme.colorScheme.error : tokens.ember)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 19,
                    color: destructive ? theme.colorScheme.error : tokens.ember,
                  ),
                ),
                const SizedBox(width: FitGoSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else ...[
                if (trailingText != null)
                  Text(
                    trailingText!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                if (showChevron && onTap != null) ...[
                  const SizedBox(width: FitGoSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textSecondary,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
