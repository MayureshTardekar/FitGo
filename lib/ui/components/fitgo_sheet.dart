import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';

/// Standard bottom sheet shell with safe-area and keyboard padding.
class FitGoSheet extends StatelessWidget {
  const FitGoSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(
      FitGoSpacing.lg,
      FitGoSpacing.xs,
      FitGoSpacing.lg,
      FitGoSpacing.lg,
    ),
    this.showClose = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null || showClose) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (showClose)
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: FitGoSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: FitGoSpacing.md),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a consistent, rounded, keyboard-aware modal sheet.
Future<T?> showFitGoSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.tokens.surface,
    builder: builder,
  );
}
