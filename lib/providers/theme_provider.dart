import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.read(localStorageProvider);
    return storage.getThemeModeKey() == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void setDarkMode(bool enabled) {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    ref.read(localStorageProvider).saveThemeModeKey(enabled ? 'dark' : 'light');
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
