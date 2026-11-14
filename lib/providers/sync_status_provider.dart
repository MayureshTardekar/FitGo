import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_status.dart';
import 'storage_provider.dart';

/// Live outbox state for the active account.
///
/// Local writes update this immediately, so the UI can confirm a save before
/// Supabase finishes uploading. It never blocks logging.
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final storage = ref.watch(localStorageProvider);
    final subscription = storage.syncStatusStream.listen((status) {
      state = status;
    });
    ref.onDispose(subscription.cancel);
    return storage.syncStatus;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

/// Short, plain-language label for a saved action.
///
/// A signed-in save is always queued first, so it is honest to say the change
/// is on this device and waiting for the network even if the upload completes
/// a moment later. The sync pill updates to “Synced” when it lands.
String savedLocallyLabel(SyncStatus status) {
  if (!status.cloudEnabled) return 'Saved on this device';
  return 'Saved on this device · Sync pending';
}
