import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/daily_metrics.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';

class LocalStorage {
  static const String _metricsBoxName = 'daily_metrics';
  static const String _weightBoxName = 'weight_entries';
  static const String _profileBoxName = 'user_profile';

  late Box<DailyMetrics> _metricsBox;
  late Box<WeightEntry> _weightBox;
  late Box<UserProfile> _profileBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(DailyMetricsAdapter());
    Hive.registerAdapter(WeightEntryAdapter());
    Hive.registerAdapter(UserProfileAdapter());
    _metricsBox = await _openBoxSafe<DailyMetrics>(_metricsBoxName);
    _weightBox = await _openBoxSafe<WeightEntry>(_weightBoxName);
    _profileBox = await _openBoxSafe<UserProfile>(_profileBoxName);
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
  }

  /// Get metrics for a specific date
  DailyMetrics? getMetricsForDate(String dateKey) {
    return _metricsBox.get(dateKey);
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
  }

  List<WeightEntry> getWeightHistory({int lastNDays = 30}) {
    final entries = _weightBox.values.toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    if (entries.length > lastNDays) {
      return entries.sublist(entries.length - lastNDays);
    }
    return entries;
  }
}
