import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';
import 'fitgo_primary_button.dart';

/// Error state with a retry action and an offline-friendly message.
class FitGoErrorState extends StatelessWidget {
  const FitGoErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.retryLabel = 'Try again',
    this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FitGoSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: tokens.danger),
            const SizedBox(height: FitGoSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: FitGoSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: FitGoSpacing.lg),
              FitGoPrimaryButton(
                label: retryLabel,
                onPressed: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
