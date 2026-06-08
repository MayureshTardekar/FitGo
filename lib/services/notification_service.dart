import 'dart:io';

import 'package:flutter/services.dart';

class NotificationService {
  static const _channel = MethodChannel('fitgo/notifications');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> scheduleMonthlyCalorieAlert({
    required String title,
    required String message,
    required int hour,
    required int minute,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('scheduleMonthlyCalorieAlert', {
        'title': title,
        'message': message,
        'hour': hour,
        'minute': minute,
      });
    } catch (_) {}
  }

  static Future<void> showMonthlyCalorieAlertNow({
    required String title,
    required String message,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('showMonthlyCalorieAlertNow', {
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  static Future<void> cancelMonthlyCalorieAlert() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('cancelMonthlyCalorieAlert');
    } catch (_) {}
  }

  static Future<void> scheduleFastingReminder({
    required int intervalMinutes,
    required int untilEpoch,
    String title = 'Drink water',
    String message = 'Stay zero-calorie until your fast ends.',
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('scheduleFastingReminder', {
        'intervalMinutes': intervalMinutes,
        'untilEpoch': untilEpoch,
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  static Future<void> showFastingReminderNow({
    String title = 'Drink water',
    String message = 'Stay zero-calorie until your fast ends.',
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('showFastingReminderNow', {
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  static Future<void> cancelFastingReminder() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('cancelFastingReminder');
    } catch (_) {}
  }
}
