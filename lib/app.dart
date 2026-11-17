import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'core/day_boundary.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/local_data_refresh.dart';
import 'providers/monthly_calorie_alert_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/water_provider.dart';
import 'routing/app_router.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'ui/adaptive/fitgo_scroll_behavior.dart';

class FitGoApp extends ConsumerStatefulWidget {
  const FitGoApp({super.key});

  @override
  ConsumerState<FitGoApp> createState() => _FitGoAppState();
}

class _FitGoAppState extends ConsumerState<FitGoApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notificationSubscription;
  StreamSubscription<NotificationActionEvent>? _actionSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void> _accountQueue = Future<void>.value();
  final Set<String> _guestImportPrompted = {};
  bool _syncing = false;
  String? _syncedUserId;
  DateTime? _lastResumeSync;
  Timer? _midnightTimer;
  String _dayKey = localDateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();

    _authSubscription = SupabaseService.authStateChanges.listen((authState) {
      final userId = authState.session?.user.id;
      if (userId == null) {
        unawaited(_handleSignedOut());
        return;
      }
      unawaited(_syncCloud(userId));
    });

    _notificationSubscription = NotificationService.onNotificationTap.listen(
      _handleNotificationPayload,
    );
    _actionSubscription = NotificationService.onNotificationAction.listen(
      _handleNotificationAction,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        unawaited(_syncCloud(userId));
      }

      final pendingAction = NotificationService.consumePendingLaunchAction();
      if (pendingAction != null) {
        _handleNotificationAction(pendingAction);
      } else {
        final pending = NotificationService.consumePendingLaunchPayload();
        if (pending != null) {
          _handleNotificationPayload(pending);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _notificationSubscription?.cancel();
    _actionSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _handleDayRollover();
    _scheduleMidnightRefresh();
    // The calorie alert is one-shot; re-arm it for the next chosen time so a
    // notification is never left over from an earlier day or month. Read it
    // immediately so the re-arm happens even when no screen is watching it.
    ref.invalidate(monthlyCalorieAlertProvider);
    ref.read(monthlyCalorieAlertProvider);

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    if (_lastResumeSync != null &&
        now.difference(_lastResumeSync!) < const Duration(minutes: 2)) {
      return;
    }
    _lastResumeSync = now;
    unawaited(_syncCloud(userId, force: true));
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    var delay = nextLocalMidnight(now).difference(now);
    if (delay.isNegative) delay = const Duration(seconds: 1);
    _midnightTimer = Timer(delay + const Duration(seconds: 1), () {
      _handleDayRollover();
      _scheduleMidnightRefresh();
    });
  }

  /// Refreshes daily providers when the local civil day changes while the app
  /// is open or after it returns from the background.
  void _handleDayRollover() {
    final currentDay = localDateKey(DateTime.now());
    if (currentDay == _dayKey) return;
    _dayKey = currentDay;
    if (!mounted) return;
    refreshLocalDataProviders(ref);
  }

  /// Routes notification payloads such as `fitgo://fasting` and
  /// `fitgo://profile?section=notifications`.
  void _handleNotificationPayload(String payload) {
    final target = notificationTarget(payload);
    if (target.isEmpty) return;

    switch (target) {
      case 'fasting':
      case 'fast':
      case 'food':
      case 'nutrition':
        ref.read(routerProvider).go('/');
        return;
      case 'trends':
        ref.read(routerProvider).go('/trends');
        return;
      case 'profile':
      default:
        ref.read(routerProvider).go('/profile');
        return;
    }
  }

  void _handleNotificationAction(NotificationActionEvent event) {
    switch (event.action) {
      case NotificationAction.addWater:
        ref.read(waterProvider.notifier).addWater(250);
        _showNotificationMessage('250 ml added');
        break;
      case NotificationAction.endFast:
        ref.read(fastingProvider.notifier).stopFasting();
        _showNotificationMessage('Fast ended');
        break;
    }
    ref.read(routerProvider).go('/');
  }

  void _showNotificationMessage(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Serializes account switches so a sign-out cannot change namespaces while
  /// a sign-in sync is still reading the previous account's boxes.
  Future<void> _enqueueAccountTask(Future<void> Function() task) {
    _accountQueue = _accountQueue.then((_) async {
      try {
        await task();
      } catch (_) {
        // A failed switch falls back to the next task; local data is untouched.
      }
    });
    return _accountQueue;
  }

  Future<void> _handleSignedOut() {
    return _enqueueAccountTask(() async {
      _syncedUserId = null;
      final storage = ref.read(localStorageProvider);
      await storage.switchToAccount(null);
      if (!mounted) return;
      refreshLocalDataProviders(ref);
    });
  }

  /// Opens the signed-in user's isolated cache, offers guest import once, and
  /// runs a pull-first sync. Runs once per Supabase user unless forced.
  Future<void> _syncCloud(String userId, {bool force = false}) {
    return _enqueueAccountTask(() => _performCloudSync(userId, force: force));
  }

  Future<void> _performCloudSync(String userId, {required bool force}) async {
    if (_syncing || (!force && _syncedUserId == userId)) return;
    _syncing = true;
    _syncedUserId = userId;

    try {
      final storage = ref.read(localStorageProvider);
      await storage.switchToAccount(userId);
      if (!mounted) return;
      refreshLocalDataProviders(ref);

      if (!storage.hasData && !_guestImportPrompted.contains(userId)) {
        _guestImportPrompted.add(userId);
        if (await storage.guestHasImportableData()) {
          await _offerGuestImport(storage);
          if (!mounted) return;
          refreshLocalDataProviders(ref);
        }
      }

      await storage.syncWithCloud();
      if (!mounted) return;
      refreshLocalDataProviders(ref);
    } catch (_) {
      // Offline is fine: local data remains the source of truth.
      _syncedUserId = null;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _offerGuestImport(LocalStorage storage) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import guest data?'),
        content: const Text(
          'FitGo found progress saved on this device from guest mode. '
          'Import it into your account? Records already in this account are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (shouldImport != true) return;

    final imported = await storage.importGuestData();
    if (!mounted) return;
    ref.invalidate(guestDataAvailableProvider);

    final messengerContext = rootNavigatorKey.currentContext;
    if (messengerContext == null || !messengerContext.mounted) return;
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      SnackBar(
        content: Text(
          imported == 0
              ? 'Nothing new to import'
              : '$imported local record${imported == 1 ? '' : 's'} imported',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'FitGo',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: FitGoTheme.darkTheme,
      theme: FitGoTheme.lightTheme,
      themeAnimationDuration: const Duration(milliseconds: 250),
      scrollBehavior: const FitGoScrollBehavior(),
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
