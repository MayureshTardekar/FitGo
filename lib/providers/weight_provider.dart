import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';
import 'storage_provider.dart';

class WeightNotifier extends Notifier<List<WeightEntry>> {
  @override
  List<WeightEntry> build() {
    final storage = ref.read(localStorageProvider);
    return storage.getWeightHistory();
  }

  void logWeight(double weight) {
    final storage = ref.read(localStorageProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final entry = WeightEntry(dateKey: dateKey, weight: weight);
    storage.saveWeight(entry);

    final today = storage.getToday();
    today.weight = weight;
    storage.saveMetrics(today);

    state = storage.getWeightHistory();
  }
}

final weightProvider =
    NotifierProvider<WeightNotifier, List<WeightEntry>>(WeightNotifier.new);
