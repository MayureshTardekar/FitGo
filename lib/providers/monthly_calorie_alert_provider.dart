import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/notification_service.dart';
import 'calorie_provider.dart';
import 'profile_provider.dart';
import 'storage_provider.dart';

class MonthlyCalorieAlertState {
  final bool enabled;
  final int monthlyLimit;
  final int warningPercent;
  final int alertHour;
  final int alertMinute;
  final String message;
  final int monthTotal;
  final String monthKey;

  const MonthlyCalorieAlertState({
    required this.enabled,
    required this.monthlyLimit,
    required this.warningPercent,
    required this.alertHour,
    required this.alertMinute,
    required this.message,
    required this.monthTotal,
    required this.monthKey,
  });

  int get warningAt => (monthlyLimit * warningPercent / 100).round();
  int get remaining => monthlyLimit - monthTotal;
  bool get isInWarningZone => enabled && monthTotal >= warningAt;
  bool get isOverLimit => enabled && monthTotal >= monthlyLimit;

  String get alertTimeLabel =>
      '${alertHour.toString().padLeft(2, '0')}:${alertMinute.toString().padLeft(2, '0')}';
}

class MonthlyCalorieAlertNotifier extends Notifier<MonthlyCalorieAlertState> {
  static const _enabledKey = 'monthly_calorie_alert_enabled';
  static const _limitKey = 'monthly_calorie_alert_limit';
  static const _warningKey = 'monthly_calorie_alert_warning_percent';
  static const _hourKey = 'monthly_calorie_alert_hour';
  static const _minuteKey = 'monthly_calorie_alert_minute';
  static const _messageKey = 'monthly_calorie_alert_message';
  static const _lastImmediateKey = 'monthly_calorie_alert_last_immediate';

  static const defaultMessage =
      "Your calories are going out of bound. Don't eat unless it is planned.";

  @override
  MonthlyCalorieAlertState build() {
    ref.watch(nutritionProvider);
    ref.watch(profileProvider);
    final loaded = _loadState();
    Future.microtask(() => _syncNativeAlert(loaded));
    return loaded;
  }

  MonthlyCalorieAlertState _loadState() {
    final storage = ref.read(localStorageProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final monthTotal = storage
        .getMetricsRange(start, now)
        .fold<int>(0, (sum, day) => sum + day.totalCalories);

    return MonthlyCalorieAlertState(
      enabled: storage.getSetting<bool>(_enabledKey, true),
      monthlyLimit: storage.getSetting<int>(_limitKey, 40000),
      warningPercent: storage.getSetting<int>(_warningKey, 90),
      alertHour: storage.getSetting<int>(_hourKey, 21),
      alertMinute: storage.getSetting<int>(_minuteKey, 0),
      message: storage.getSetting<String>(_messageKey, defaultMessage),
      monthTotal: monthTotal,
      monthKey: DateFormat('yyyy-MM').format(now),
    );
  }

  Future<void> updateSettings({
    bool? enabled,
    int? monthlyLimit,
    int? warningPercent,
    int? alertHour,
    int? alertMinute,
    String? message,
  }) async {
    final storage = ref.read(localStorageProvider);
    if (enabled != null) await storage.saveSetting(_enabledKey, enabled);
    if (monthlyLimit != null) {
      await storage.saveSetting(
        _limitKey,
        monthlyLimit.clamp(1000, 200000).toInt(),
      );
    }
    if (warningPercent != null) {
      await storage.saveSetting(
        _warningKey,
        warningPercent.clamp(50, 100).toInt(),
      );
    }
    if (alertHour != null) {
      await storage.saveSetting(_hourKey, alertHour.clamp(0, 23).toInt());
    }
    if (alertMinute != null) {
      await storage.saveSetting(_minuteKey, alertMinute.clamp(0, 59).toInt());
    }
    if (message != null) {
      final clean = message.trim().isEmpty ? defaultMessage : message.trim();
      await storage.saveSetting(_messageKey, clean);
    }

    state = _loadState();
    await _syncNativeAlert(state, allowImmediate: true);
  }

  Future<void> _syncNativeAlert(
    MonthlyCalorieAlertState value, {
    bool allowImmediate = true,
  }) async {
    if (!NotificationService.isSupported) return;

    if (!value.enabled || !value.isInWarningZone) {
      await NotificationService.cancelMonthlyCalorieAlert();
      return;
    }

    await NotificationService.requestPermission();
    final title = value.isOverLimit
        ? 'Monthly calorie limit crossed'
        : 'Monthly calorie warning';
    final message = _messageFor(value);

    await NotificationService.scheduleMonthlyCalorieAlert(
      title: title,
      message: message,
      hour: value.alertHour,
      minute: value.alertMinute,
    );

    if (!allowImmediate) return;
    final level = value.isOverLimit ? 'over' : 'warn';
    final alertKey = '${value.monthKey}:$level';
    final storage = ref.read(localStorageProvider);
    if (storage.getSetting<String>(_lastImmediateKey, '') == alertKey) return;

    await NotificationService.showMonthlyCalorieAlertNow(
      title: title,
      message: message,
    );
    await storage.saveSetting(_lastImmediateKey, alertKey);
  }

  String _messageFor(MonthlyCalorieAlertState value) {
    final left = value.remaining < 0 ? 0 : value.remaining;
    return value.message
        .replaceAll('{total}', value.monthTotal.toString())
        .replaceAll('{limit}', value.monthlyLimit.toString())
        .replaceAll('{left}', left.toString());
  }
}

final monthlyCalorieAlertProvider =
    NotifierProvider<MonthlyCalorieAlertNotifier, MonthlyCalorieAlertState>(
      MonthlyCalorieAlertNotifier.new,
    );
