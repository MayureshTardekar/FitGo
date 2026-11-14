import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import 'storage_provider.dart';

class UnitSystemNotifier extends Notifier<UnitSystem> {
  static const settingKey = 'unit_system';

  @override
  UnitSystem build() {
    final storage = ref.read(localStorageProvider);
    final stored = storage.getSetting<String>(settingKey, 'metric');
    return stored == 'imperial' ? UnitSystem.imperial : UnitSystem.metric;
  }

  Future<void> setSystem(UnitSystem system) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveSetting(
      settingKey,
      system == UnitSystem.imperial ? 'imperial' : 'metric',
    );
    state = system;
  }
}

final unitSystemProvider = NotifierProvider<UnitSystemNotifier, UnitSystem>(
  UnitSystemNotifier.new,
);
