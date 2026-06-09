import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/daily_metrics.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import 'supabase_service.dart';

class LocalStorage {
  static const String _metricsBoxName = 'daily_metrics';
  static const String _weightBoxName = 'weight_entries';
  static const String _profileBoxName = 'user_profile';
  static const String _settingsBoxName = 'app_settings';

  late Box<DailyMetrics> _metricsBox;
  late Box<WeightEntry> _weightBox;
  late Box<UserProfile> _profileBox;
  late Box<dynamic> _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyMetricsAdapter());
    Hive.registerAdapter(WeightEntryAdapter());
    Hive.registerAdapter(UserProfileAdapter());
    _metricsBox = await _openBoxSafe<DailyMetrics>(_metricsBoxName);
    _weightBox = await _openBoxSafe<WeightEntry>(_weightBoxName);
    _profileBox = await _openBoxSafe<UserProfile>(_profileBoxName);
    _settingsBox = await _openBoxSafe<dynamic>(_settingsBoxName);
  }

  /// Opens a Hive box, deleting and recreating it if corrupt
  Future<Box<T>> _openBoxSafe<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name);
    }
  }

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // --- App Settings ---

  String getThemeModeKey() =>
      (_settingsBox.get('theme_mode', defaultValue: 'dark') as String?) ??
      'dark';

  Future<void> saveThemeModeKey(String value) async {
    await _settingsBox.put('theme_mode', value);
  }

  T getSetting<T>(String key, T defaultValue) {
    final value = _settingsBox.get(key);
    return value is T ? value : defaultValue;
  }

  Future<void> saveSetting(String key, Object? value) async {
    await _settingsBox.put(key, value);
    if (SupabaseService.isLoggedIn) {
      Future.microtask(() async {
        try {
          await SupabaseService.upsertAppSetting(key, value);
        } catch (_) {}
      });
    }
  }

  Future<void> importCloudData({
    List<DailyMetrics> metrics = const [],
    List<WeightEntry> weights = const [],
    Map<String, dynamic> settings = const {},
  }) async {
    for (final metric in metrics) {
      if (!_metricsBox.containsKey(metric.dateKey)) {
        await _metricsBox.put(metric.dateKey, metric);
      }
    }

    for (final weight in weights) {
      if (!_weightBox.containsKey(weight.dateKey)) {
        await _weightBox.put(weight.dateKey, weight);
      }
    }

    for (final entry in settings.entries) {
      if (!_settingsBox.containsKey(entry.key)) {
        await _settingsBox.put(entry.key, entry.value);
      }
    }
  }

  // --- User Profile ---

  UserProfile? getProfile() => _profileBox.get('profile');

  bool get hasProfile => _profileBox.containsKey('profile');

  Future<void> saveProfile(UserProfile profile) async {
    await _profileBox.put('profile', profile);
  }

  // --- Daily Metrics ---

  DailyMetrics getToday() {
    return _metricsBox.get(todayKey) ?? DailyMetrics(dateKey: todayKey);
  }

  Future<void> saveMetrics(DailyMetrics metrics) async {
    await _metricsBox.put(metrics.dateKey, metrics);
    if (SupabaseService.isLoggedIn) {
      Future.microtask(() async {
        try {
          await SupabaseService.upsertDailyMetrics(metrics);
        } catch (_) {}
      });
    }
  }

  /// Get metrics for a specific date
  DailyMetrics? getMetricsForDate(String dateKey) {
    return _metricsBox.get(dateKey);
  }

  /// Get the date of the very first data entry
  DateTime? getFirstEntryDate() {
    if (_metricsBox.isEmpty) return null;
    final keys = _metricsBox.keys.cast<String>().toList();
    if (keys.isEmpty) return null;
    keys.sort();
    return DateTime.tryParse(keys.first);
  }

  /// Get metrics for the current week (Monday to Sunday)
  List<DailyMetrics> getCurrentWeekMetrics() {
    final now = DateTime.now();
    // Monday = 1, so subtract (weekday - 1) to get Monday
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final fmt = DateFormat('yyyy-MM-dd');

    final results = <DailyMetrics>[];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final key = fmt.format(date);
      final metrics = _metricsBox.get(key);
      if (metrics != null) {
        results.add(metrics);
      } else {
        // Return empty metrics for days with no data
        results.add(DailyMetrics(dateKey: key));
      }
    }
    return results;
  }

  /// Get metrics for a date range
  List<DailyMetrics> getMetricsRange(DateTime start, DateTime end) {
    final fmt = DateFormat('yyyy-MM-dd');
    final results = <DailyMetrics>[];
    var current = start;
    while (!current.isAfter(end)) {
      final key = fmt.format(current);
      results.add(_metricsBox.get(key) ?? DailyMetrics(dateKey: key));
      current = current.add(const Duration(days: 1));
    }
    return results;
  }

  // --- Weight ---

  Future<void> saveWeight(WeightEntry entry) async {
    await _weightBox.put(entry.dateKey, entry);
    if (SupabaseService.isLoggedIn) {
      Future.microtask(() async {
        try {
          await SupabaseService.upsertWeight(entry);
        } catch (_) {}
      });
    }
  }

  List<WeightEntry> getWeightHistory({int lastNDays = 30}) {
    final entries = _weightBox.values.toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    if (entries.length > lastNDays) {
      return entries.sublist(entries.length - lastNDays);
    }
    return entries;
  }

  List<DailyMetrics> getAllMetrics() => _metricsBox.values.toList();

  List<WeightEntry> getAllWeights() => _weightBox.values.toList();

  Map<String, dynamic> getAllSettings() {
    return {
      for (final key in _settingsBox.keys)
        if (key is String) key: _settingsBox.get(key),
    };
  }
}
