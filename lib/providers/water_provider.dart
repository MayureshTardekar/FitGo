import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

class WaterNotifier extends Notifier<int> {
  @override
  int build() {
    final storage = ref.read(localStorageProvider);
    return storage.getToday().waterMl;
  }

  void addWater(int ml) {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    today.waterMl += ml;
    storage.saveMetrics(today);
    state = today.waterMl;
  }

  /// Removes a just-logged amount for the Undo action.
  void removeWater(int ml) {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    today.waterMl = (today.waterMl - ml).clamp(0, 100000);
    storage.saveMetrics(today);
    state = today.waterMl;
  }
}

final waterProvider = NotifierProvider<WaterNotifier, int>(WaterNotifier.new);
