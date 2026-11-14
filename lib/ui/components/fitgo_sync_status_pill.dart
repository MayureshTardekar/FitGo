import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/sync_status.dart';
import '../../providers/sync_status_provider.dart';
import '../theme/fitgo_tokens.dart';
import 'fitgo_pill.dart';

/// Compact status used on Today. It never blocks logging.
class SyncStatusPill extends ConsumerWidget {
  const SyncStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = theme.colorScheme;

    final (label, icon, color, background) = switch (status) {
      SyncStatus(cloudEnabled: false) => (
        'Saved on this device',
        Icons.smartphone_rounded,
        tokens.textSecondary,
        tokens.surfaceMuted,
      ),
      SyncStatus(:final pendingChanges) when pendingChanges > 0 => (
        'Sync pending · $pendingChanges',
        Icons.cloud_upload_outlined,
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      SyncStatus(:final lastSyncedAt) when lastSyncedAt != null => (
        'Synced ${relativeSyncTime(lastSyncedAt)}',
        Icons.cloud_done_outlined,
        scheme.onTertiaryContainer,
        scheme.tertiaryContainer,
      ),
      _ => (
        'Not backed up yet',
        Icons.cloud_off_outlined,
        tokens.textSecondary,
        tokens.surfaceMuted,
      ),
    };

    return FitGoPill(
      label: label,
      icon: icon,
      color: color,
      background: background,
    );
  }
}

String relativeSyncTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
