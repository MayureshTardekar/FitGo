import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Whether the separate guest namespace has records the account does not.
final guestDataAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(localStorageProvider).guestHasImportableData();
  } catch (_) {
    return false;
  }
});
