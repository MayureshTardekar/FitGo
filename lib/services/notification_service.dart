import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_schedule.dart';

/// Cross-platform local notification service.
///
/// Android and iOS are both supported through `flutter_local_notifications`,
/// so callers no longer have to care which platform they are running on.
enum NotificationAction { addWater, endFast }

/// A notification action plus the payload that triggered it.
class NotificationActionEvent {
  const NotificationActionEvent({required this.action, required this.payload});

  final NotificationAction action;
  final String payload;
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialised = false;
  static Future<void>? _initFuture;
  static String? _pendingLaunchPayload;
  static NotificationActionEvent? _pendingLaunchAction;

  static const _monthlyAlertId = 1001;
  static const _fastingReminderIdStart = 2000;
  static const _fastingReminderIdEnd = 2060;
  static const _maxFastingReminders = 60;

  static const _addWaterActionId = 'add_water';
  static const _endFastActionId = 'end_fast';
  static const _fastingCategoryId = 'fasting_reminder';

  static const _calorieGuardChannel = AndroidNotificationDetails(
    'calorie_guard',
    'Calorie guard',
    channelDescription: 'Daily monthly calorie budget warning',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _fastingChannel = AndroidNotificationDetails(
    'fasting_reminders_v2',
    'Fasting reminders',
    channelDescription: 'Hydration reminders during a fast',
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction(
        _addWaterActionId,
        '+250 ml',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        _endFastActionId,
        'End fast',
        showsUserInterface: true,
      ),
    ],
  );

  static const _darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const _fastingDarwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    categoryIdentifier: _fastingCategoryId,
  );

  static final _fastingCategory = DarwinNotificationCategory(
    _fastingCategoryId,
    actions: [
      DarwinNotificationAction.plain(
        _addWaterActionId,
        '+250 ml',
        options: {DarwinNotificationActionOption.foreground},
      ),
      DarwinNotificationAction.plain(
        _endFastActionId,
        'End fast',
        options: {DarwinNotificationActionOption.foreground},
      ),
    ],
  );

  /// Fired whenever the user taps a notification. Payloads are route names
  /// (for example `fitgo://fasting`) so the navigation layer can decide where
  /// to go.
  static final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  static final StreamController<NotificationActionEvent> _actionController =
      StreamController<NotificationActionEvent>.broadcast();

  static Stream<String> get onNotificationTap => _tapController.stream;

  static Stream<NotificationActionEvent> get onNotificationAction =>
      _actionController.stream;

  /// Returns and clears the payload that launched the app from a terminated
  /// state. Call this once the navigation layer is ready.
  static String? consumePendingLaunchPayload() {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return payload;
  }

  /// Returns and clears an action that launched the app from a terminated
  /// state.
  static NotificationActionEvent? consumePendingLaunchAction() {
    final action = _pendingLaunchAction;
    _pendingLaunchAction = null;
    return action;
  }

  /// Whether this platform can schedule local notifications.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Initialises timezone data and the notifications plugin.
  ///
  /// Safe to call more than once; concurrent callers await the same future.
  static Future<void> init() {
    if (_initialised) return Future<void>.value();
    return _initFuture ??= _initialise();
  }

  static Future<void> _initialise() async {
    if (!isSupported) {
      _initialised = true;
      return;
    }

    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // Fall back to UTC if the native timezone cannot be resolved.
        tz.setLocalLocation(tz.UTC);
      }

      const android = AndroidInitializationSettings('ic_stat_fitgo');
      final darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [_fastingCategory],
      );

      await _plugin.initialize(
        settings: InitializationSettings(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: _handleResponse,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundResponse,
      );

      // Pick up a tap or action that launched the app from a terminated state.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final response = launchDetails?.notificationResponse;
      final launchPayload = response?.payload ?? '';
      if ((launchDetails?.didNotificationLaunchApp ?? false) &&
          launchPayload.isNotEmpty) {
        // The app may still be starting, so keep the payload until the
        // navigation layer is ready and calls the consume methods.
        final action = _actionFor(response?.actionId);
        if (action != null) {
          _pendingLaunchAction = NotificationActionEvent(
            action: action,
            payload: launchPayload,
          );
        } else {
          _pendingLaunchPayload = launchPayload;
        }
      }

      _initialised = true;
    } catch (error) {
      debugPrint('NotificationService.init failed: $error');
    } finally {
      _initFuture = null;
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    if (!_initialised || !isSupported) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          final ios = _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
          return await ios?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              false;
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          return await android?.requestNotificationsPermission() ?? false;
        default:
          return false;
      }
    } catch (error) {
      debugPrint('NotificationService.requestPermission failed: $error');
      return false;
    }
  }

  /// Whether the user currently allows FitGo to show notifications.
  static Future<bool> notificationsEnabled() async {
    await init();
    if (!_initialised || !isSupported) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          return await android?.areNotificationsEnabled() ?? false;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          final ios = _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
          final permissions = await ios?.checkPermissions();
          return permissions?.isEnabled ?? false;
        default:
          return false;
      }
    } catch (error) {
      debugPrint('NotificationService.notificationsEnabled failed: $error');
      return false;
    }
  }

  static Future<void> scheduleMonthlyCalorieAlert({
    required String title,
    required String message,
    required int hour,
    required int minute,
  }) async {
    await init();
    if (!_initialised || !isSupported) return;

    try {
      // Build the wall-clock time from the device clock first, then convert
      // that instant. This keeps the alert at the chosen local time even if
      // the timezone plugin falls back to UTC.
      final when = NotificationSchedule.nextDaily(DateTime.now(), hour, minute);

      await _plugin.zonedSchedule(
        id: _monthlyAlertId,
        title: title,
        body: message,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: _calorieGuardChannel,
          iOS: _darwinDetails,
          macOS: _darwinDetails,
        ),
        // One-shot on purpose: a repeating alert would keep using the totals
        // captured when it was first scheduled, including after month reset.
        // The provider reschedules the next alert when the app opens or data
        // changes.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'fitgo://profile?section=notifications',
      );
    } catch (error) {
      debugPrint('scheduleMonthlyCalorieAlert failed: $error');
    }
  }

  static Future<void> showMonthlyCalorieAlertNow({
    required String title,
    required String message,
  }) async {
    await _showNow(
      id: _monthlyAlertId + 5000,
      title: title,
      message: message,
      details: const NotificationDetails(
        android: _calorieGuardChannel,
        iOS: _darwinDetails,
        macOS: _darwinDetails,
      ),
      payload: 'fitgo://profile?section=notifications',
    );
  }

  static Future<void> cancelMonthlyCalorieAlert() async {
    await init();
    if (!_initialised || !isSupported) return;
    try {
      await _plugin.cancel(id: _monthlyAlertId);
    } catch (error) {
      debugPrint('cancelMonthlyCalorieAlert failed: $error');
    }
  }

  static Future<void> scheduleFastingReminder({
    required int intervalMinutes,
    required int untilEpoch,
    int? lastReminderEpoch,
    String title = 'Drink water',
    String message = 'Stay zero-calorie until your fast ends.',
  }) async {
    await init();
    if (!_initialised || !isSupported) return;

    await cancelFastingReminder();

    final safeInterval = intervalMinutes.clamp(15, 24 * 60);
    final end = DateTime.fromMillisecondsSinceEpoch(untilEpoch);
    final lastReminder = lastReminderEpoch == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastReminderEpoch);
    final times = NotificationSchedule.fastingReminders(
      now: DateTime.now(),
      end: end,
      interval: Duration(minutes: safeInterval),
      lastReminder: lastReminder,
      maxCount: _maxFastingReminders,
    );

    var id = _fastingReminderIdStart;
    try {
      for (final fireAt in times) {
        if (id >= _fastingReminderIdEnd) break;
        await _plugin.zonedSchedule(
          id: id++,
          title: title,
          body: message,
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: const NotificationDetails(
            android: _fastingChannel,
            iOS: _fastingDarwinDetails,
            macOS: _fastingDarwinDetails,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'fitgo://fasting',
        );
      }
    } catch (error) {
      debugPrint('scheduleFastingReminder failed: $error');
    }
  }

  static Future<void> showFastingReminderNow({
    String title = 'Drink water',
    String message = 'Stay zero-calorie until your fast ends.',
  }) async {
    await _showNow(
      id: _fastingReminderIdStart + 5000,
      title: title,
      message: message,
      details: const NotificationDetails(
        android: _fastingChannel,
        iOS: _fastingDarwinDetails,
        macOS: _fastingDarwinDetails,
      ),
      payload: 'fitgo://fasting',
    );
  }

  static Future<void> cancelFastingReminder() async {
    await init();
    if (!_initialised || !isSupported) return;
    try {
      for (var id = _fastingReminderIdStart; id < _fastingReminderIdEnd; id++) {
        await _plugin.cancel(id: id);
      }
    } catch (error) {
      debugPrint('cancelFastingReminder failed: $error');
    }
  }

  static Future<void> _showNow({
    required int id,
    required String title,
    required String message,
    required NotificationDetails details,
    required String payload,
  }) async {
    await init();
    if (!_initialised || !isSupported) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: message,
        notificationDetails: details,
        payload: payload,
      );
    } catch (error) {
      debugPrint('NotificationService.show failed: $error');
    }
  }

  static void _handleResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final action = _actionFor(response.actionId);
    if (action == null) {
      _tapController.add(payload);
      return;
    }

    _actionController.add(
      NotificationActionEvent(action: action, payload: payload),
    );
  }

  static NotificationAction? _actionFor(String? actionId) {
    return switch (actionId) {
      _addWaterActionId => NotificationAction.addWater,
      _endFastActionId => NotificationAction.endFast,
      _ => null,
    };
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundResponse(NotificationResponse response) {
    // Actions use `showsUserInterface`, so tapping one opens the app and the
    // main-isolate handler above can update providers.
  }
}
