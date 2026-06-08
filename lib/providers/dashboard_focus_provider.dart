import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

enum DashboardFocusMode { auto, fasting, nutrition, full }

class DashboardFocusModeNotifier extends Notifier<DashboardFocusMode> {
  static const _key = 'dashboard_focus_mode';

  @override
  DashboardFocusMode build() {
    final storage = ref.read(localStorageProvider);
    final saved = storage.getSetting<String>(
      _key,
      DashboardFocusMode.auto.name,
    );
    return DashboardFocusMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => DashboardFocusMode.auto,
    );
  }

  Future<void> setMode(DashboardFocusMode mode) async {
    await ref.read(localStorageProvider).saveSetting(_key, mode.name);
    state = mode;
  }
}

final dashboardFocusModeProvider =
    NotifierProvider<DashboardFocusModeNotifier, DashboardFocusMode>(
      DashboardFocusModeNotifier.new,
    );
