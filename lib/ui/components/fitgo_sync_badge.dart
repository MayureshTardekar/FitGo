import 'package:flutter/material.dart';

import '../theme/fitgo_tokens.dart';
import 'fitgo_pill.dart';

enum FitGoSyncState { offline, syncing, synced }

/// Subtle sync/offline indicator. Never blocks the UI.
class FitGoSyncBadge extends StatelessWidget {
  const FitGoSyncBadge({super.key, required this.state, this.syncedAt});

  final FitGoSyncState state;
  final DateTime? syncedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (label, icon, color) = switch (state) {
      FitGoSyncState.offline => (
        'Offline · saved locally',
        Icons.cloud_off_rounded,
        tokens.textSecondary,
      ),
      FitGoSyncState.syncing => ('Syncing…', Icons.sync_rounded, tokens.amber),
      FitGoSyncState.synced => (
        _syncedLabel(),
        Icons.cloud_done_rounded,
        tokens.mint,
      ),
    };

    return FitGoPill(label: label, icon: icon, color: color);
  }

  String _syncedLabel() {
    if (syncedAt == null) return 'Synced';
    final diff = DateTime.now().difference(syncedAt!);
    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inHours < 1) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }
}
