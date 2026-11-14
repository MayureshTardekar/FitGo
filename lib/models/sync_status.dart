/// Snapshot of the local outbox and the last successful cloud refresh.
class SyncStatus {
  const SyncStatus({
    required this.cloudEnabled,
    required this.pendingChanges,
    this.lastSyncedAt,
  });

  /// False for guest/local-only mode and when Supabase is unavailable.
  final bool cloudEnabled;

  /// Local records that still need to reach Supabase.
  final int pendingChanges;

  /// Last time a pull-first sync completed.
  final DateTime? lastSyncedAt;

  bool get hasPendingChanges => pendingChanges > 0;

  bool get isFullySynced =>
      cloudEnabled && !hasPendingChanges && lastSyncedAt != null;

  static const localOnly = SyncStatus(cloudEnabled: false, pendingChanges: 0);
}
