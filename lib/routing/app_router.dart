import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/profile_provider.dart';
import '../screens/analytics_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/past_day_screen.dart';
import '../screens/profile_screen.dart';
import '../services/supabase_service.dart';
import '../ui/adaptive/main_shell.dart';
import '../ui/components/fitgo_error_state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Decides where the router should send the user.
///
/// The app is offline-first: once a local profile exists, signing out leaves
/// the user in guest mode instead of forcing them back to the auth screen.
@visibleForTesting
String? resolveFitGoRedirect({
  required bool loggedIn,
  required bool hasProfile,
  required String location,
  required bool isRedoSetup,
}) {
  final isAuth = location == '/auth';
  final isOnboarding = location == '/onboarding';

  // No local profile yet: onboarding is the only screen that can create one.
  if (!hasProfile) {
    if (!loggedIn) {
      if (isAuth || isOnboarding) return null;
      return '/auth';
    }
    if (isOnboarding) return null;
    return '/onboarding';
  }

  // A local profile exists, so the app is usable offline.
  if (isAuth) {
    // Signed-in users have nothing to do on the auth screen.
    return loggedIn ? '/' : null;
  }
  if (isOnboarding && !isRedoSetup) return '/';
  return null;
}

/// Extracts the destination from notification payloads such as
/// `fitgo://fasting` or `fitgo://profile?section=notifications`.
String notificationTarget(String payload) {
  final uri = Uri.tryParse(payload);
  if (uri == null) return '';
  return uri.host.isNotEmpty ? uri.host : uri.path.replaceFirst('/', '');
}

/// Notifies [GoRouter] when authentication or the local profile changes so
/// redirects can be re-evaluated without recreating the router.
class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();

  final profileSubscription = ref.listen(
    profileProvider,
    (_, _) => refresh.refresh(),
  );
  final authSubscription = SupabaseService.authStateChanges.listen(
    (_) => refresh.refresh(),
  );

  ref.onDispose(() {
    profileSubscription.close();
    authSubscription.cancel();
    refresh.dispose();
  });

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => resolveFitGoRedirect(
      loggedIn: SupabaseService.isLoggedIn,
      hasProfile: ref.read(profileProvider) != null,
      location: state.matchedLocation,
      isRedoSetup: state.uri.queryParameters['redo'] == '1',
    ),
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Supabase finishes OAuth by opening this callback. The SDK consumes
      // the session; send the router back to the gate afterwards.
      GoRoute(path: '/login-callback', redirect: (context, state) => '/'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trends',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/past-day',
        builder: (context, state) => PastDayLogScreen(
          initialDate: DateTime.tryParse(
            state.uri.queryParameters['date'] ?? '',
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: FitGoErrorState(
          title: 'Page not found',
          message: 'That link does not point to a screen in FitGo.',
          retryLabel: 'Go home',
          onRetry: () => context.go('/'),
        ),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
