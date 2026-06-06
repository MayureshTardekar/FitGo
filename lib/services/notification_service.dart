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
}
