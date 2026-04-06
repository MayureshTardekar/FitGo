import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

class FastingState {
  final bool isFasting;
  final Duration elapsed;
  final Duration target;
  final DateTime? startTime;

  const FastingState({
    this.isFasting = false,
    this.elapsed = Duration.zero,
    this.target = const Duration(hours: 16),
    this.startTime,
  });

  double get progress => target.inSeconds > 0
      ? (elapsed.inSeconds / target.inSeconds).clamp(0.0, 1.0)
      : 0.0;

  bool get isComplete => elapsed >= target;

  /// How much overtime past the target
  Duration get overtime => isComplete ? elapsed - target : Duration.zero;

  FastingState copyWith({
    bool? isFasting,
    Duration? elapsed,
    Duration? target,
    DateTime? startTime,
  }) {
    return FastingState(
      isFasting: isFasting ?? this.isFasting,
      elapsed: elapsed ?? this.elapsed,
      target: target ?? this.target,
      startTime: startTime ?? this.startTime,
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
      return FastingState(
        isFasting: true,
        elapsed: elapsed,
        target: target,
        startTime: startTime,
      );
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
    storage.saveMetrics(today);

    final elapsed = now.difference(start);
    state = FastingState(
      isFasting: true,
      elapsed: elapsed,
      target: Duration(minutes: durationMinutes),
      startTime: start,
    );
    _startTicker();
  }

  /// Edit the start time of an ongoing fast
  void editStartTime(DateTime newStart) {
    if (!state.isFasting) return;

    final now = DateTime.now();
    // Don't allow future start or > 24h ago
    if (newStart.isAfter(now)) return;
    if (now.difference(newStart).inHours > 24) return;

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
  }

  /// Mark the fast as ended at a custom time (for "I ended earlier")
  void stopFastingAt(DateTime endTime) {
    _ticker?.cancel();
    final epoch = _findActiveFastingEpoch();
    if (epoch != null) {
      _clearFasting(epoch.dateKey);
    }
    state = const FastingState();
  }

  void stopFasting() {
    _ticker?.cancel();
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

    final startTime = DateTime.fromMillisecondsSinceEpoch(epoch.epoch);
    final elapsed = DateTime.now().difference(startTime);
    state = state.copyWith(elapsed: elapsed, startTime: startTime);
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
      storage.saveMetrics(metrics);
    }
    // Also clear today if different
    final today = storage.getToday();
    if (today.fastingStartEpoch != null && today.dateKey != dateKey) {
      today.fastingStartEpoch = null;
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

  _FastingEpoch({
    required this.epoch,
    required this.durationMinutes,
    required this.dateKey,
  });
}

final fastingProvider = NotifierProvider<FastingNotifier, FastingState>(
  FastingNotifier.new,
);
