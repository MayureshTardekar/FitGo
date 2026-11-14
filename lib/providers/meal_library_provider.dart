import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/meal_template.dart';
import 'storage_provider.dart';

class MealLibraryState {
  const MealLibraryState({this.recent = const [], this.saved = const []});

  final List<MealTemplate> recent;
  final List<MealTemplate> saved;

  bool isSaved(MealTemplate meal) {
    return saved.any((item) => item.key == meal.key);
  }
}

class MealLibraryNotifier extends Notifier<MealLibraryState> {
  static const recentKey = 'recent_meals_v1';
  static const savedKey = 'saved_meals_v1';

  @override
  MealLibraryState build() {
    final storage = ref.read(localStorageProvider);
    return MealLibraryState(
      recent: MealTemplate.decodeList(
        storage.getSetting<String>(recentKey, ''),
      ),
      saved: MealTemplate.decodeList(storage.getSetting<String>(savedKey, '')),
    );
  }

  /// Newest first, de-duplicated by name + calories.
  Future<void> recordLogged(MealTemplate meal) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var useCount = meal.useCount;
    for (final item in [...state.recent, ...state.saved]) {
      if (item.key == meal.key) {
        useCount = item.useCount;
        break;
      }
    }
    final updated = meal.copyWith(lastUsedEpoch: now, useCount: useCount + 1);
    final recent = <MealTemplate>[
      updated,
      ...state.recent.where((item) => item.key != meal.key),
    ].take(12).toList();

    state = MealLibraryState(recent: recent, saved: state.saved);
    final storage = ref.read(localStorageProvider);
    await storage.saveLocalSetting(recentKey, MealTemplate.encodeList(recent));
  }

  Future<void> saveMeal(MealTemplate meal) async {
    final now = DateTime.now();
    final template = meal.copyWith(
      id: '${now.microsecondsSinceEpoch}',
      lastUsedEpoch: now.millisecondsSinceEpoch,
    );
    final saved = <MealTemplate>[
      template,
      ...state.saved.where((item) => item.key != meal.key),
    ].take(40).toList();

    state = MealLibraryState(recent: state.recent, saved: saved);
    final storage = ref.read(localStorageProvider);
    await storage.saveSetting(savedKey, MealTemplate.encodeList(saved));
  }

  Future<void> removeSaved(String id) async {
    final saved = state.saved.where((item) => item.id != id).toList();
    if (saved.length == state.saved.length) return;

    state = MealLibraryState(recent: state.recent, saved: saved);
    final storage = ref.read(localStorageProvider);
    await storage.saveSetting(savedKey, MealTemplate.encodeList(saved));
  }

  Future<void> toggleSaved(MealTemplate meal) async {
    if (state.isSaved(meal)) {
      final match = state.saved.firstWhere(
        (item) => item.key == meal.key,
        orElse: () => meal,
      );
      await removeSaved(match.id);
    } else {
      await saveMeal(meal);
    }
  }
}

final mealLibraryProvider =
    NotifierProvider<MealLibraryNotifier, MealLibraryState>(
      MealLibraryNotifier.new,
    );
