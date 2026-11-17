import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/daily_metrics.dart';
import '../models/sync_status.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import 'supabase_service.dart';

/// Offline-first Hive storage with one isolated cache per account.
///
/// Every Supabase user gets separate boxes (`fitgo_v3_user_<id>_*`), and
/// local-only/guest use gets its own namespace. This prevents one account's
/// unsynced health data from ever being uploaded under another account.
///
/// Cloud sync is pull-first and never overwrites a local record that still has
/// a pending change. Locally changed records are kept in an outbox until the
/// matching upload succeeds.
class LocalStorage {
  static const String _legacyMetricsBoxName = 'daily_metrics';
  static const String _legacyWeightBoxName = 'weight_entries';
  static const String _legacyProfileBoxName = 'user_profile';
  static const String _legacySettingsBoxName = 'app_settings';

  static const String _deviceMetaBoxName = 'fitgo_device_meta';
  static const String _deviceSettingsBoxName = 'fitgo_device_settings';
  static const String _guestNamespace = 'guest';
  static const String _namespacePrefix = 'fitgo_v3';
  static const String _legacyMigrationKey = 'legacy_shared_cache_migrated_v2';
  static const String _lastSyncedAtKey = 'last_synced_at';

  static const String _profilePendingKey = 'profile';

  late Box<DailyMetrics> _metricsBox;
  late Box<WeightEntry> _weightBox;
  late Box<UserProfile> _profileBox;
  late Box<dynamic> _settingsBox;
  late Box<dynamic> _pendingBox;

  late Box<dynamic> _deviceMetaBox;
  late Box<dynamic> _deviceSettingsBox;

  String _namespace = _guestNamespace;
  bool _initialized = false;
  bool _flushing = false;
  DateTime? _lastSyncedAt;
  int _dataRevision = 0;

  /// Increments whenever account-owned log data changes.
  ///
  /// Derived caches must include this in their keys: Riverpod reuses a
  /// notifier instance across `invalidate`, so instance-level caches survive
  /// unless the data itself changes their key.
  int get dataRevision => _dataRevision;

  void _bumpDataRevision() => _dataRevision++;

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  /// The namespace currently backing this instance.
  String get namespace => _namespace;

  bool get isGuest => _namespace == _guestNamespace;

  /// Live outbox/sync state for the active account.
  SyncStatus get syncStatus => SyncStatus(
    cloudEnabled: _cloudEnabled,
    pendingChanges: _initialized ? _pendingBox.length : 0,
    lastSyncedAt: _lastSyncedAt,
  );

  /// Emits the current status on subscribe, then every change.
  Stream<SyncStatus> get syncStatusStream async* {
    yield syncStatus;
    yield* _syncStatusController.stream;
  }

  void _emitSyncStatus() {
    if (!_initialized || _syncStatusController.isClosed) return;
    _syncStatusController.add(syncStatus);
  }

  /// Whether the active namespace has any user-created profile or log data.
  bool get hasData =>
      _profileBox.containsKey('profile') ||
      _metricsBox.isNotEmpty ||
      _weightBox.isNotEmpty;

  Future<void> init({String? userId, String? hivePath}) async {
    if (hivePath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(hivePath);
    }
    _registerAdapters();

    _deviceMetaBox = await _openBoxSafe<dynamic>(_deviceMetaBoxName);
    _deviceSettingsBox = await _openBoxSafe<dynamic>(_deviceSettingsBoxName);
    _lastSyncedAt = _readLastSyncedAt();

    _namespace = _namespaceFor(userId);
    await _migrateLegacySharedCache();
    await _openNamespace();
    _initialized = true;
    _emitSyncStatus();
  }

  /// Switches to the namespace for [userId], or guest mode when null.
  ///
  /// The caller must refresh every provider that reads storage afterwards.
  Future<void> switchToAccount(String? userId) async {
    final target = _namespaceFor(userId);
    if (_initialized && target == _namespace) return;

    await _closeCurrentBoxes();
    _namespace = target;
    await _openNamespace();
    _initialized = true;
    _bumpDataRevision();
    _emitSyncStatus();
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DailyMetricsAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WeightEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserProfileAdapter());
    }
  }

  String _namespaceFor(String? userId) {
    if (userId == null || userId.isEmpty) return _guestNamespace;
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'user_$safe';
  }

  String _boxName(String namespace, String kind) =>
      '${_namespacePrefix}_${namespace}_$kind';

  Future<Box<T>> _openBoxSafe<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (_) {
      await Hive.deleteBoxFromDisk(name);
      return await Hive.openBox<T>(name);
    }
  }

  Future<Box<T>?> _openExistingBox<T>(String name) async {
    if (!await Hive.boxExists(name)) return null;
    return _openBoxSafe<T>(name);
  }

  Future<void> _openNamespace() async {
    _metricsBox = await _openBoxSafe<DailyMetrics>(
      _boxName(_namespace, 'metrics'),
    );
    _weightBox = await _openBoxSafe<WeightEntry>(
      _boxName(_namespace, 'weights'),
    );
    _profileBox = await _openBoxSafe<UserProfile>(
      _boxName(_namespace, 'profile'),
    );
    _settingsBox = await _openBoxSafe<dynamic>(
      _boxName(_namespace, 'settings'),
    );
    _pendingBox = await _openBoxSafe<dynamic>(_boxName(_namespace, 'pending'));
  }

  Future<void> _closeCurrentBoxes() async {
    if (!_initialized) return;
    _initialized = false;
    await _pendingBox.close();
    await _settingsBox.close();
    await _profileBox.close();
    await _weightBox.close();
    await _metricsBox.close();
  }

  /// Moves the pre-3.0 shared cache into the guest namespace once.
  ///
  /// The old boxes were shared by every account, so assigning them to whichever
  /// account happens to be signed in would recreate the cross-account upload
  /// bug. Guest is the only safe owner; signed-in users are offered an explicit
  /// import afterwards.
  Future<void> _migrateLegacySharedCache() async {
    if (_deviceMetaBox.get(_legacyMigrationKey, defaultValue: false) == true) {
      return;
    }

    final guestMetrics = await _openBoxSafe<DailyMetrics>(
      _boxName(_guestNamespace, 'metrics'),
    );
    final guestWeights = await _openBoxSafe<WeightEntry>(
      _boxName(_guestNamespace, 'weights'),
    );
    final guestProfile = await _openBoxSafe<UserProfile>(
      _boxName(_guestNamespace, 'profile'),
    );
    final guestSettings = await _openBoxSafe<dynamic>(
      _boxName(_guestNamespace, 'settings'),
    );

    await _copyLegacyMetrics(guestMetrics);
    await _copyLegacyWeights(guestWeights);
    await _copyLegacyProfile(guestProfile);
    await _copyLegacySettings(guestSettings);

    await _deviceMetaBox.put(_legacyMigrationKey, true);

    if (_namespace != _guestNamespace) {
      await guestSettings.close();
      await guestProfile.close();
      await guestWeights.close();
      await guestMetrics.close();
    }

    await _deleteLegacyBox(_legacyMetricsBoxName);
    await _deleteLegacyBox(_legacyWeightBoxName);
    await _deleteLegacyBox(_legacyProfileBoxName);
    await _deleteLegacyBox(_legacySettingsBoxName);
  }

  Future<void> _copyLegacyMetrics(Box<DailyMetrics> target) async {
    final legacy = await _openExistingBox<DailyMetrics>(_legacyMetricsBoxName);
    if (legacy == null) return;
    for (final metric in legacy.values) {
      if (!target.containsKey(metric.dateKey)) {
        await target.put(metric.dateKey, metric.copy());
      }
    }
    await legacy.close();
  }

  Future<void> _copyLegacyWeights(Box<WeightEntry> target) async {
    final legacy = await _openExistingBox<WeightEntry>(_legacyWeightBoxName);
    if (legacy == null) return;
    for (final weight in legacy.values) {
      if (!target.containsKey(weight.dateKey)) {
        await target.put(weight.dateKey, weight.copy());
      }
    }
    await legacy.close();
  }

  Future<void> _copyLegacyProfile(Box<UserProfile> target) async {
    final legacy = await _openExistingBox<UserProfile>(_legacyProfileBoxName);
    if (legacy == null) return;
    final profile = legacy.get('profile');
    if (profile != null && !target.containsKey('profile')) {
      await target.put('profile', profile.copy());
    }
    await legacy.close();
  }

  Future<void> _copyLegacySettings(Box<dynamic> target) async {
    final legacy = await _openExistingBox<dynamic>(_legacySettingsBoxName);
    if (legacy == null) return;

    for (final key in legacy.keys) {
      if (key is! String) continue;
      if (key == 'theme_mode') {
        // Theme is a device preference, so it stays outside account boxes.
        if (!_deviceSettingsBox.containsKey('theme_mode')) {
          final value = legacy.get(key);
          if (value != null) {
            await _deviceSettingsBox.put('theme_mode', value);
          }
        }
      } else if (!target.containsKey(key)) {
        await target.put(key, legacy.get(key));
      }
    }
    await legacy.close();
  }

  Future<void> _deleteLegacyBox(String name) async {
    if (await Hive.boxExists(name)) {
      await Hive.deleteBoxFromDisk(name);
    }
  }

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool get _cloudEnabled {
    if (isGuest) return false;
    try {
      return SupabaseService.isLoggedIn;
    } catch (_) {
      // Unit tests and first-run startup may not have Supabase initialized.
      return false;
    }
  }

  // --- Device settings (not account data) ---

  DateTime? _readLastSyncedAt() {
    final value = _deviceMetaBox.get(_lastSyncedAtKey);
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _markSyncedNow() async {
    _lastSyncedAt = DateTime.now();
    await _deviceMetaBox.put(
      _lastSyncedAtKey,
      _lastSyncedAt!.toIso8601String(),
    );
    _emitSyncStatus();
  }

  String getThemeModeKey() =>
      (_deviceSettingsBox.get('theme_mode', defaultValue: 'system')
          as String?) ??
      'system';

  Future<void> saveThemeModeKey(String value) async {
    await _deviceSettingsBox.put('theme_mode', value);
  }

  // --- Account settings ---

  T getSetting<T>(String key, T defaultValue) {
    final value = _settingsBox.get(key);
    return value is T ? value : defaultValue;
  }

  Future<void> saveSetting(String key, Object? value) async {
    await _settingsBox.put(key, value);
    if (!_cloudEnabled) return;

    final pendingKey = 'setting|$key';
    final stamp = await _markPending(pendingKey);
    unawaited(_pushSetting(key, value, stamp));
  }

  /// Stores an account-local value without adding it to the cloud outbox.
  ///
  /// Use for transient state such as an onboarding draft that should not
  /// overwrite a synced setting on another device.
  Future<void> saveLocalSetting(String key, Object? value) async {
    await _settingsBox.put(key, value);
  }

  /// Removes an account-local setting without touching the cloud outbox.
  Future<void> deleteLocalSetting(String key) async {
    await _settingsBox.delete(key);
  }

  // --- Cloud import and outbox ---

  /// Imports cloud records without clobbering unsynced local edits.
  ///
  /// When [overwrite] is true, records with a pending local change are still
  /// preserved. Pass false to keep every local record that already exists.
  Future<void> importCloudData({
    List<DailyMetrics> metrics = const [],
    List<WeightEntry> weights = const [],
    Map<String, dynamic> settings = const {},
    bool overwrite = false,
  }) async {
    for (final metric in metrics) {
      final pendingKey = 'metric|${metric.dateKey}';
      final localExists = _metricsBox.containsKey(metric.dateKey);
      final hasPendingEdit = _pendingBox.containsKey(pendingKey);
      if ((overwrite && !hasPendingEdit) || !localExists) {
        await _metricsBox.put(metric.dateKey, metric.copy());
      }
    }

    for (final weight in weights) {
      final pendingKey = 'weight|${weight.dateKey}';
      final localExists = _weightBox.containsKey(weight.dateKey);
      final hasPendingEdit = _pendingBox.containsKey(pendingKey);
      if ((overwrite && !hasPendingEdit) || !localExists) {
        await _weightBox.put(weight.dateKey, weight.copy());
      }
    }

    for (final entry in settings.entries) {
      final pendingKey = 'setting|${entry.key}';
      final localExists = _settingsBox.containsKey(entry.key);
      final hasPendingEdit = _pendingBox.containsKey(pendingKey);
      if ((overwrite && !hasPendingEdit) || !localExists) {
        await _settingsBox.put(entry.key, entry.value);
      }
    }
    _bumpDataRevision();
  }

  /// Pulls cloud data first, then retries pending local uploads.
  ///
  /// Existing local records may be refreshed from the cloud, but records with
  /// an outbox entry are always preserved.
  Future<void> syncWithCloud({bool overwrite = true}) async {
    if (!_cloudEnabled) return;

    var reachedCloud = false;
    try {
      final cloudProfile = await SupabaseService.fetchProfile();
      final cloudMetrics = await SupabaseService.fetchAllMetrics();
      final cloudWeights = await SupabaseService.fetchAllWeights();
      final cloudSettings = await SupabaseService.fetchAppSettings();

      if (cloudProfile != null &&
          !_pendingBox.containsKey(_profilePendingKey)) {
        await _profileBox.put('profile', cloudProfile.copy());
      }

      await importCloudData(
        metrics: cloudMetrics,
        weights: cloudWeights,
        settings: cloudSettings,
        overwrite: overwrite,
      );
      reachedCloud = true;
    } catch (_) {
      // Offline or a partial fetch: local data remains authoritative.
    }

    await flushPendingChanges();
    if (reachedCloud) {
      await _markSyncedNow();
    }
    _emitSyncStatus();
  }

  /// Retries every local change that has not reached Supabase yet.
  Future<void> flushPendingChanges() async {
    if (!_cloudEnabled || _flushing || _pendingBox.isEmpty) return;
    _flushing = true;

    try {
      final keys = _pendingBox.keys.whereType<String>().toList();
      for (final key in keys) {
        final stamp = _pendingBox.get(key);
        if (stamp == null) continue;

        try {
          if (key == _profilePendingKey) {
            final profile = getProfile();
            if (profile == null) {
              await _pendingBox.delete(key);
              continue;
            }
            await SupabaseService.upsertProfile(profile);
          } else if (key.startsWith('metric|')) {
            final dateKey = key.substring('metric|'.length);
            final metric = getMetricsForDate(dateKey);
            if (metric == null) {
              await _pendingBox.delete(key);
              continue;
            }
            await SupabaseService.upsertDailyMetrics(metric);
          } else if (key.startsWith('weight|')) {
            final dateKey = key.substring('weight|'.length);
            final weight = _weightBox.get(dateKey);
            if (weight == null) {
              await _pendingBox.delete(key);
              continue;
            }
            await SupabaseService.upsertWeight(weight);
          } else if (key.startsWith('setting|')) {
            final settingKey = key.substring('setting|'.length);
            if (!_settingsBox.containsKey(settingKey)) {
              await _pendingBox.delete(key);
              continue;
            }
            await SupabaseService.upsertAppSetting(
              settingKey,
              _settingsBox.get(settingKey),
            );
          } else {
            await _pendingBox.delete(key);
            continue;
          }

          await _clearPendingIfUnchanged(key, stamp);
        } catch (_) {
          // Keep the outbox entry for the next retry.
        }
      }
    } finally {
      _flushing = false;
      _emitSyncStatus();
    }
  }

  int get pendingChangeCount => _pendingBox.length;

  Future<Object> _markPending(String key) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await _pendingBox.put(key, stamp);
    _emitSyncStatus();
    return stamp;
  }

  Future<void> _clearPendingIfUnchanged(String key, Object? stamp) async {
    if (_pendingBox.get(key) == stamp) {
      await _pendingBox.delete(key);
      _emitSyncStatus();
    }
  }

  Future<void> _pushMetric(DailyMetrics metric, Object stamp) async {
    try {
      await SupabaseService.upsertDailyMetrics(metric);
      await _clearPendingIfUnchanged('metric|${metric.dateKey}', stamp);
    } catch (_) {
      // Stays in the outbox.
    }
  }

  Future<void> _pushWeight(WeightEntry weight, Object stamp) async {
    try {
      await SupabaseService.upsertWeight(weight);
      await _clearPendingIfUnchanged('weight|${weight.dateKey}', stamp);
    } catch (_) {
      // Stays in the outbox.
    }
  }

  Future<void> _pushProfile(UserProfile profile, Object stamp) async {
    try {
      await SupabaseService.upsertProfile(profile);
      await _clearPendingIfUnchanged(_profilePendingKey, stamp);
    } catch (_) {
      // Stays in the outbox.
    }
  }

  Future<void> _pushSetting(String key, Object? value, Object stamp) async {
    try {
      await SupabaseService.upsertAppSetting(key, value);
      await _clearPendingIfUnchanged('setting|$key', stamp);
    } catch (_) {
      // Stays in the outbox.
    }
  }

  // --- Guest data ---

  /// Whether the separate guest namespace contains profile or log data.
  Future<bool> guestHasData() async {
    if (isGuest) return hasData;

    final metrics = await _openExistingBox<DailyMetrics>(
      _boxName(_guestNamespace, 'metrics'),
    );
    final weights = await _openExistingBox<WeightEntry>(
      _boxName(_guestNamespace, 'weights'),
    );
    final profile = await _openExistingBox<UserProfile>(
      _boxName(_guestNamespace, 'profile'),
    );

    final result =
        (metrics?.isNotEmpty ?? false) ||
        (weights?.isNotEmpty ?? false) ||
        (profile?.containsKey('profile') ?? false);

    if (metrics != null) await metrics.close();
    if (weights != null) await weights.close();
    if (profile != null) await profile.close();
    return result;
  }

  /// Whether guest mode has records that the active account does not.
  ///
  /// Used to keep the “Import guest data” action visible only while there is
  /// something new to copy. Existing account records always win.
  Future<bool> guestHasImportableData() async {
    if (isGuest) return false;

    final guestMetrics = await _openExistingBox<DailyMetrics>(
      _boxName(_guestNamespace, 'metrics'),
    );
    final guestWeights = await _openExistingBox<WeightEntry>(
      _boxName(_guestNamespace, 'weights'),
    );
    final guestProfile = await _openExistingBox<UserProfile>(
      _boxName(_guestNamespace, 'profile'),
    );
    final guestSettings = await _openExistingBox<dynamic>(
      _boxName(_guestNamespace, 'settings'),
    );

    var importable = false;
    if (guestMetrics != null) {
      importable = guestMetrics.keys.any(
        (key) => key is String && !_metricsBox.containsKey(key),
      );
      await guestMetrics.close();
    }
    if (!importable && guestWeights != null) {
      importable = guestWeights.keys.any(
        (key) => key is String && !_weightBox.containsKey(key),
      );
      await guestWeights.close();
    } else if (guestWeights != null) {
      await guestWeights.close();
    }
    if (!importable &&
        guestProfile != null &&
        guestProfile.containsKey('profile') &&
        !_profileBox.containsKey('profile')) {
      importable = true;
    }
    if (guestProfile != null) await guestProfile.close();
    if (!importable && guestSettings != null) {
      importable = guestSettings.keys.any(
        (key) =>
            key is String &&
            key != 'theme_mode' &&
            !_settingsBox.containsKey(key),
      );
    }
    if (guestSettings != null) await guestSettings.close();

    return importable;
  }

  /// Explicitly copies guest data into the active account namespace.
  ///
  /// Existing account records win on conflicts. Imported records are queued for
  /// upload, so they are never silently attributed to the wrong account.
  Future<int> importGuestData() async {
    if (isGuest) return 0;

    var imported = 0;

    final guestMetrics = await _openExistingBox<DailyMetrics>(
      _boxName(_guestNamespace, 'metrics'),
    );
    if (guestMetrics != null) {
      for (final metric in guestMetrics.values) {
        if (_metricsBox.containsKey(metric.dateKey)) continue;
        await _metricsBox.put(metric.dateKey, metric.copy());
        await _markPending('metric|${metric.dateKey}');
        imported++;
      }
      await guestMetrics.close();
    }

    final guestWeights = await _openExistingBox<WeightEntry>(
      _boxName(_guestNamespace, 'weights'),
    );
    if (guestWeights != null) {
      for (final weight in guestWeights.values) {
        if (_weightBox.containsKey(weight.dateKey)) continue;
        await _weightBox.put(weight.dateKey, weight.copy());
        await _markPending('weight|${weight.dateKey}');
        imported++;
      }
      await guestWeights.close();
    }

    final guestProfile = await _openExistingBox<UserProfile>(
      _boxName(_guestNamespace, 'profile'),
    );
    if (guestProfile != null) {
      final profile = guestProfile.get('profile');
      if (profile != null && !_profileBox.containsKey('profile')) {
        await _profileBox.put('profile', profile.copy());
        await _markPending(_profilePendingKey);
        imported++;
      }
      await guestProfile.close();
    }

    final guestSettings = await _openExistingBox<dynamic>(
      _boxName(_guestNamespace, 'settings'),
    );
    if (guestSettings != null) {
      for (final key in guestSettings.keys) {
        if (key is! String || key == 'theme_mode') continue;
        if (_settingsBox.containsKey(key)) continue;
        await _settingsBox.put(key, guestSettings.get(key));
        await _markPending('setting|$key');
        imported++;
      }
      await guestSettings.close();
    }

    await flushPendingChanges();
    _bumpDataRevision();
    return imported;
  }

  // --- User Profile ---

  UserProfile? getProfile() => _profileBox.get('profile');

  bool get hasProfile => _profileBox.containsKey('profile');

  Future<void> saveProfile(UserProfile profile) async {
    await _profileBox.put('profile', profile.copy());
    _bumpDataRevision();
    if (!_cloudEnabled) return;

    final stamp = await _markPending(_profilePendingKey);
    unawaited(_pushProfile(profile, stamp));
  }

  // --- Daily Metrics ---

  DailyMetrics getToday() {
    return _metricsBox.get(todayKey) ?? DailyMetrics(dateKey: todayKey);
  }

  Future<void> saveMetrics(DailyMetrics metrics) async {
    await _metricsBox.put(metrics.dateKey, metrics.copy());
    _bumpDataRevision();
    if (!_cloudEnabled) return;

    final pendingKey = 'metric|${metrics.dateKey}';
    final stamp = await _markPending(pendingKey);
    unawaited(_pushMetric(metrics, stamp));
  }

  DailyMetrics? getMetricsForDate(String dateKey) {
    return _metricsBox.get(dateKey);
  }

  DateTime? getFirstEntryDate() {
    if (_metricsBox.isEmpty) return null;
    final keys = _metricsBox.keys.cast<String>().toList();
    if (keys.isEmpty) return null;
    keys.sort();
    return DateTime.tryParse(keys.first);
  }

  List<DailyMetrics> getCurrentWeekMetrics() {
    final now = DateTime.now();
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
        results.add(DailyMetrics(dateKey: key));
      }
    }
    return results;
  }

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
    await _weightBox.put(entry.dateKey, entry.copy());
    _bumpDataRevision();
    if (!_cloudEnabled) return;

    final pendingKey = 'weight|${entry.dateKey}';
    final stamp = await _markPending(pendingKey);
    unawaited(_pushWeight(entry, stamp));
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

  /// Removes every account-owned record, including the local outbox.
  Future<void> clearAll() async {
    await _pendingBox.clear();
    await _settingsBox.clear();
    await _profileBox.clear();
    await _weightBox.clear();
    await _metricsBox.clear();
    _bumpDataRevision();
    _emitSyncStatus();
  }
}
