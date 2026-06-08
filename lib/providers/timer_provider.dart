import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import 'storage_provider.dart';

class FastingState {
  final bool isFasting;
  final Duration elapsed;
  final Duration target;
  final DateTime? startTime;
  final bool remindersEnabled;
  final Duration reminderInterval;
  final int? lastReminderEpoch;
  final int reminderSignal;

  const FastingState({
    this.isFasting = false,
    this.elapsed = Duration.zero,
    this.target = const Duration(hours: 16),
    this.startTime,
    this.remindersEnabled = true,
    this.reminderInterval = const Duration(hours: 1),
    this.lastReminderEpoch,
    this.reminderSignal = 0,
  });

  double get progress => target.inSeconds > 0
      ? (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0)
      : 0.0;

  bool get isComplete => elapsed >= target;

  /// How much overtime past the target
  Duration get overtime => isComplete ? elapsed - target : Duration.zero;

  Duration get untilNextReminder {
    if (!isFasting || !remindersEnabled || startTime == null) {
      return Duration.zero;
    }
    final last = lastReminderEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastReminderEpoch!)
        : startTime!;
    final next = last.add(reminderInterval);
    final remaining = next.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  FastingState copyWith({
    bool? isFasting,
    Duration? elapsed,
    Duration? target,
    DateTime? startTime,
    bool? remindersEnabled,
    Duration? reminderInterval,
    int? lastReminderEpoch,
    int? reminderSignal,
  }) {
    return FastingState(
      isFasting: isFasting ?? this.isFasting,
      elapsed: elapsed ?? this.elapsed,
      target: target ?? this.target,
      startTime: startTime ?? this.startTime,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderInterval: reminderInterval ?? this.reminderInterval,
      lastReminderEpoch: lastReminderEpoch ?? this.lastReminderEpoch,
      reminderSignal: reminderSignal ?? this.reminderSignal,
    );
  }
}

/// Stores the active fasting epoch separately from daily metrics
/// so it survives midnight crossovers
class FastingNotifier extends Notifier<FastingState>
    with WidgetsBindingObserver {
  Timer? _ticker;

  // We store the fasting start in today's metrics, but also check
  // yesterday's metrics on build() to handle midnight crossover
  @override
  FastingState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });

    WidgetsBinding.instance.addObserver(this);

    final epoch = _findActiveFastingEpoch();
    if (epoch != null) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(epoch.epoch);
      final elapsed = DateTime.now().difference(startTime);
      final target = Duration(minutes: epoch.durationMinutes);

      // Auto-stop if fast has been running for > 48 hours (user forgot)
      if (elapsed.inHours > 48) {
        _clearFasting(epoch.dateKey);
        return const FastingState();
      }

      _startTicker();
      final activeState = FastingState(
        isFasting: true,
        elapsed: elapsed,
        target: target,
        startTime: startTime,
        remindersEnabled: epoch.reminderEnabled,
        reminderInterval: Duration(minutes: epoch.reminderMinutes),
        lastReminderEpoch: epoch.lastReminderEpoch,
      );
      Future.microtask(() => _scheduleNativeReminderFor(activeState));
      return activeState;
    }

    return const FastingState();
  }

  void startFasting({int durationMinutes = 960, DateTime? startTime}) {
    // Prevent double-tap: if already fasting, ignore
    if (state.isFasting) return;

    final storage = ref.read(localStorageProvider);
    final start = startTime ?? DateTime.now();

    // Validate: start time can't be more than 24h ago
    final now = DateTime.now();
    if (now.difference(start).inHours > 48) return;

    final today = storage.getToday();
    today.fastingStartEpoch = start.millisecondsSinceEpoch;
    today.fastingDurationMinutes = durationMinutes;
    today.fastingReminderEnabled = state.remindersEnabled;
    today.fastingReminderMinutes = state.reminderInterval.inMinutes;
    today.fastingLastReminderEpoch = now.millisecondsSinceEpoch;
    storage.saveMetrics(today);

    final elapsed = now.difference(start);
    state = FastingState(
      isFasting: true,
      elapsed: elapsed,
      target: Duration(minutes: durationMinutes),
      startTime: start,
      remindersEnabled: state.remindersEnabled,
      reminderInterval: state.reminderInterval,
      lastReminderEpoch: now.millisecondsSinceEpoch,
    );
    _startTicker();
    _scheduleNativeReminder(requestPermission: true, showConfirmation: true);
  }

  /// Edit the start time of an ongoing fast
  void editStartTime(DateTime newStart) {
    if (!state.isFasting) return;

    final now = DateTime.now();
    // Don't allow future start or very stale starts
    if (newStart.isAfter(now)) return;
    if (now.difference(newStart).inHours > 48) return;

    final storage = ref.read(localStorageProvider);

    // Clear old date key if needed, write to the date key of newStart
    final oldEpoch = _findActiveFastingEpoch();
    if (oldEpoch != null && oldEpoch.dateKey != storage.todayKey) {
      _clearFasting(oldEpoch.dateKey);
    }

    final today = storage.getToday();
    today.fastingStartEpoch = newStart.millisecondsSinceEpoch;
    storage.saveMetrics(today);
    _recalculate();
    _scheduleNativeReminder();
  }

  void configureReminder({bool? enabled, int? intervalMinutes}) {
    final interval = intervalMinutes != null
        ? Duration(minutes: intervalMinutes)
        : state.reminderInterval;
    final nextEnabled = enabled ?? state.remindersEnabled;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    final epoch = _findActiveFastingEpoch();
    if (epoch != null) {
      final storage = ref.read(localStorageProvider);
      final metrics = storage.getMetricsForDate(epoch.dateKey);
      if (metrics != null) {
        metrics.fastingReminderEnabled = nextEnabled;
        metrics.fastingReminderMinutes = interval.inMinutes;
        metrics.fastingLastReminderEpoch = nowEpoch;
        storage.saveMetrics(metrics);
      }
    }

    state = state.copyWith(
      remindersEnabled: nextEnabled,
      reminderInterval: interval,
      lastReminderEpoch: nowEpoch,
    );

    if (nextEnabled) {
      _scheduleNativeReminder(
        requestPermission: true,
        showConfirmation: enabled == true,
      );
    } else {
      _cancelNativeReminder();
    }
  }

  /// Change fasting duration mid-fast
  void changeDuration(int newMinutes) {
    if (!state.isFasting) return;

    final epoch = _findActiveFastingEpoch();
    if (epoch == null) return;

    final storage = ref.read(localStorageProvider);
    final metrics = storage.getMetricsForDate(epoch.dateKey);
    if (metrics != null) {
      metrics.fastingDurationMinutes = newMinutes;
      storage.saveMetrics(metrics);
    }

    state = state.copyWith(target: Duration(minutes: newMinutes));
    _scheduleNativeReminder();
  }

  /// Mark the fast as ended at a custom time (for "I ended earlier")
  void stopFastingAt(DateTime endTime) {
    _ticker?.cancel();
    _cancelNativeReminder();
    final epoch = _findActiveFastingEpoch();
    if (epoch != null) {
      _clearFasting(epoch.dateKey);
    }
    state = const FastingState();
  }

  void stopFasting() {
    _ticker?.cancel();
    _cancelNativeReminder();
    final epoch = _findActiveFastingEpoch();
    if (epoch != null) {
      _clearFasting(epoch.dateKey);
    }

    state = const FastingState();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _recalculate();
    });
  }

  void _recalculate() {
    final epoch = _findActiveFastingEpoch();
    if (epoch == null) return;

    final now = DateTime.now();
    final startTime = DateTime.fromMillisecondsSinceEpoch(epoch.epoch);
    final elapsed = now.difference(startTime);
    if (elapsed >= Duration(minutes: epoch.durationMinutes)) {
      _cancelNativeReminder();
    }
    var nextState = state.copyWith(
      elapsed: elapsed,
      startTime: startTime,
      remindersEnabled: epoch.reminderEnabled,
      reminderInterval: Duration(minutes: epoch.reminderMinutes),
      lastReminderEpoch: epoch.lastReminderEpoch,
    );

    if (_shouldTriggerReminder(epoch, now, elapsed)) {
      final storage = ref.read(localStorageProvider);
      final metrics = storage.getMetricsForDate(epoch.dateKey);
      if (metrics != null) {
        metrics.fastingLastReminderEpoch = now.millisecondsSinceEpoch;
        storage.saveMetrics(metrics);
      }
      nextState = nextState.copyWith(
        lastReminderEpoch: now.millisecondsSinceEpoch,
        reminderSignal: state.reminderSignal + 1,
      );
    }

    state = nextState;
  }

  void _scheduleNativeReminder({
    bool requestPermission = false,
    bool showConfirmation = false,
  }) {
    _scheduleNativeReminderFor(
      state,
      requestPermission: requestPermission,
      showConfirmation: showConfirmation,
    );
  }

  void _scheduleNativeReminderFor(
    FastingState value, {
    bool requestPermission = false,
    bool showConfirmation = false,
  }) {
    if (!NotificationService.isSupported ||
        !value.isFasting ||
        !value.remindersEnabled ||
        value.startTime == null ||
        value.reminderInterval.inMinutes <= 0) {
      return;
    }

    final untilEpoch = value.startTime!
        .add(value.target)
        .millisecondsSinceEpoch;
    if (untilEpoch <= DateTime.now().millisecondsSinceEpoch) {
      _cancelNativeReminder();
      return;
    }

    unawaited(() async {
      if (requestPermission) {
        final granted = await NotificationService.requestPermission();
        if (!granted) return;
      }

      await NotificationService.scheduleFastingReminder(
        intervalMinutes: value.reminderInterval.inMinutes,
        untilEpoch: untilEpoch,
      );

      if (showConfirmation) {
        await NotificationService.showFastingReminderNow(
          title: 'Drink water',
          message:
              'Water reminders are active every ${_intervalLabel(value.reminderInterval)}. Stay zero-calorie.',
        );
      }
    }());
  }

  void _cancelNativeReminder() {
    unawaited(NotificationService.cancelFastingReminder());
  }

  String _intervalLabel(Duration interval) {
    if (interval.inMinutes % 60 == 0) return '${interval.inHours}h';
    return '${interval.inMinutes}m';
  }

  bool _shouldTriggerReminder(
    _FastingEpoch epoch,
    DateTime now,
    Duration elapsed,
  ) {
    if (!epoch.reminderEnabled || epoch.reminderMinutes <= 0) return false;
    if (elapsed >= Duration(minutes: epoch.durationMinutes)) return false;
    if (elapsed < Duration(minutes: epoch.reminderMinutes)) return false;

    final lastEpoch = epoch.lastReminderEpoch ?? epoch.epoch;
    final last = DateTime.fromMillisecondsSinceEpoch(lastEpoch);
    return now.difference(last) >= Duration(minutes: epoch.reminderMinutes);
  }

  /// Search today and yesterday for an active fasting epoch
  /// This handles midnight crossover
  _FastingEpoch? _findActiveFastingEpoch() {
    final storage = ref.read(localStorageProvider);

    // Check today first
    final today = storage.getToday();
    if (today.fastingStartEpoch != null) {
      return _FastingEpoch(
        epoch: today.fastingStartEpoch!,
        durationMinutes: today.fastingDurationMinutes,
        dateKey: today.dateKey,
        reminderMinutes: today.fastingReminderMinutes,
        reminderEnabled: today.fastingReminderEnabled,
        lastReminderEpoch: today.fastingLastReminderEpoch,
      );
    }

    // Check yesterday (midnight crossover case)
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final yMetrics = storage.getMetricsForDate(yKey);
    if (yMetrics != null && yMetrics.fastingStartEpoch != null) {
      return _FastingEpoch(
        epoch: yMetrics.fastingStartEpoch!,
        durationMinutes: yMetrics.fastingDurationMinutes,
        dateKey: yKey,
        reminderMinutes: yMetrics.fastingReminderMinutes,
        reminderEnabled: yMetrics.fastingReminderEnabled,
        lastReminderEpoch: yMetrics.fastingLastReminderEpoch,
      );
    }

    return null;
  }

  /// Clear fasting data from a specific date key
  void _clearFasting(String dateKey) {
    final storage = ref.read(localStorageProvider);
    final metrics = storage.getMetricsForDate(dateKey);
    if (metrics != null) {
      metrics.fastingStartEpoch = null;
      metrics.fastingLastReminderEpoch = null;
      storage.saveMetrics(metrics);
    }
    // Also clear today if different
    final today = storage.getToday();
    if (today.fastingStartEpoch != null && today.dateKey != dateKey) {
      today.fastingStartEpoch = null;
      today.fastingLastReminderEpoch = null;
      storage.saveMetrics(today);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && this.state.isFasting) {
      _recalculate();
      _startTicker();
    } else if (state == AppLifecycleState.paused) {
      _ticker?.cancel();
    }
  }
}

class _FastingEpoch {
  final int epoch;
  final int durationMinutes;
  final String dateKey;
  final int reminderMinutes;
  final bool reminderEnabled;
  final int? lastReminderEpoch;

  _FastingEpoch({
    required this.epoch,
    required this.durationMinutes,
    required this.dateKey,
    required this.reminderMinutes,
    required this.reminderEnabled,
    required this.lastReminderEpoch,
  });
}

final fastingProvider = NotifierProvider<FastingNotifier, FastingState>(
  FastingNotifier.new,
);
