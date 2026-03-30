import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

class CalorieNotifier extends Notifier<int> {
  @override
  int build() {
    final storage = ref.read(localStorageProvider);
    return storage.getToday().totalCalories;
  }

  void addCalories(int amount) {
    final storage = ref.read(localStorageProvider);
    final today = storage.getToday();
    today.totalCalories += amount;
    today.calorieEntries.add(amount);
    storage.saveMetrics(today);
    state = today.totalCalories;
  }
}

final calorieProvider =
    NotifierProvider<CalorieNotifier, int>(CalorieNotifier.new);
