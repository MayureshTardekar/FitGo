import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Full-width primary action with an inline loading state.
class FitGoPrimaryButton extends StatelessWidget {
  const FitGoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.tonal = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tonal ? tokens.ember : theme.colorScheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: FitGoSpacing.xs),
              ],
              Text(label),
            ],
          );

    final button = tonal
        ? FilledButton.tonal(
            onPressed: enabled ? onPressed : null,
            child: child,
          )
        : FilledButton(onPressed: enabled ? onPressed : null, child: child);

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
