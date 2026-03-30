import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'providers/profile_provider.dart';
import 'providers/storage_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/supabase_service.dart';

class FitGoApp extends StatelessWidget {
  const FitGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitGo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: FitGoTheme.darkTheme,
      theme: FitGoTheme.darkTheme,
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

        // Check if user has local data (offline / skipped login)
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
    final profile = ref.watch(profileProvider);

    // Has local profile = user skipped login before or was using offline
    if (profile != null) {
      return const _MainShell();
    }

    // No profile, not logged in = show auth
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
      final localProfile = ref.read(profileProvider);

      // If no local profile, try fetching from cloud
      if (localProfile == null) {
        final cloudProfile = await SupabaseService.fetchProfile();
        if (cloudProfile != null && mounted) {
          final storage = ref.read(localStorageProvider);
          await storage.saveProfile(cloudProfile);
          ref.invalidate(profileProvider);
        }
      } else {
        // Has local profile — push to cloud
        await SupabaseService.upsertProfile(localProfile);
      }
    } catch (_) {
      // Offline — no problem, local data works
    }
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

  static const _screens = [
    HomeScreen(),
    AnalyticsScreen(),
  ];

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
