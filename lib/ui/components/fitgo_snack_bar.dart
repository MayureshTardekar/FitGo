import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Consistent floating snack bar with optional undo.
void showFitGoSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isError) ...[
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.onInverseSurface,
                size: 18,
              ),
              const SizedBox(width: FitGoSpacing.xs),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}
