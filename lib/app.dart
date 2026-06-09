import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/activity_provider.dart';
import 'providers/calorie_provider.dart';
import 'providers/dashboard_focus_provider.dart';
import 'providers/monthly_calorie_alert_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/water_provider.dart';
import 'providers/weekly_nutrition_plan_provider.dart';
import 'providers/weekly_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';

class FitGoApp extends ConsumerWidget {
  const FitGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FitGo',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: FitGoTheme.darkTheme,
      theme: FitGoTheme.lightTheme,
      home: const _AuthGate(),
    );
  }
}

/// Listens to Supabase auth state changes
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        // If logged in OR has local profile (offline mode), go to app
        final isLoggedIn = SupabaseService.isLoggedIn;
        if (isLoggedIn) {
          // Sync local data to cloud in background
          _syncInBackground();
          return const _ProfileGate();
        }

        // Require cloud login so progress can sync across devices.
        return const _OfflineOrAuthGate();
      },
    );
  }

  void _syncInBackground() {
    // Profile sync happens in _ProfileGate.initState
  }
}

/// Shows auth screen OR lets user through if they have local profile
class _OfflineOrAuthGate extends ConsumerWidget {
  const _OfflineOrAuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AuthScreen();
  }
}

/// Routes to onboarding if no profile exists, otherwise to main shell
class _ProfileGate extends ConsumerStatefulWidget {
  const _ProfileGate();

  @override
  ConsumerState<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<_ProfileGate> {
  bool _synced = false;

  @override
  void initState() {
    super.initState();
    _tryFetchCloudProfile();
  }

  Future<void> _tryFetchCloudProfile() async {
    if (_synced) return;
    _synced = true;

    try {
      final storage = ref.read(localStorageProvider);
      final localProfile = ref.read(profileProvider);
      final cloudProfile = await SupabaseService.fetchProfile();
      final cloudMetrics = await SupabaseService.fetchAllMetrics();
      final cloudWeights = await SupabaseService.fetchAllWeights();
      final cloudSettings = await SupabaseService.fetchAppSettings();

      if (localProfile == null && cloudProfile != null) {
        await storage.saveProfile(cloudProfile);
      }

      await storage.importCloudData(
        metrics: cloudMetrics,
        weights: cloudWeights,
        settings: cloudSettings,
      );

      final profileForSync = localProfile ?? cloudProfile;
      await SupabaseService.syncToCloud(
        profile: profileForSync,
        metrics: storage.getAllMetrics(),
        weights: storage.getAllWeights(),
        settings: storage.getAllSettings(),
      );

      _refreshLocalProviders();
    } catch (_) {
      // Offline - no problem, local data works
    }
  }

  void _refreshLocalProviders() {
    if (!mounted) return;
    ref.invalidate(profileProvider);
    ref.invalidate(nutritionProvider);
    ref.invalidate(waterProvider);
    ref.invalidate(fastingProvider);
    ref.invalidate(activityProvider);
    ref.invalidate(weightProvider);
    ref.invalidate(weeklyProvider);
    ref.invalidate(weeklyNutritionPlanProvider);
    ref.invalidate(monthlyCalorieAlertProvider);
    ref.invalidate(dashboardFocusModeProvider);
    ref.invalidate(themeModeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const OnboardingScreen();
    }
    return const _MainShell();
  }
}

/// Bottom navigation shell with Dashboard and Analytics tabs
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  static const _screens = [HomeScreen(), AnalyticsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
