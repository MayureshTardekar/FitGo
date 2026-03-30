import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});
