import 'package:fitgo/routing/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFitGoRedirect', () {
    test('sends signed-out users without a profile to auth', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: false,
          hasProfile: false,
          location: '/',
          isRedoSetup: false,
        ),
        '/auth',
      );
    });

    test('allows auth and guest onboarding without a profile', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: false,
          hasProfile: false,
          location: '/auth',
          isRedoSetup: false,
        ),
        isNull,
      );
      expect(
        resolveFitGoRedirect(
          loggedIn: false,
          hasProfile: false,
          location: '/onboarding',
          isRedoSetup: false,
        ),
        isNull,
      );
    });

    test('sends signed-in users without a profile to onboarding', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: true,
          hasProfile: false,
          location: '/',
          isRedoSetup: false,
        ),
        '/onboarding',
      );
      expect(
        resolveFitGoRedirect(
          loggedIn: true,
          hasProfile: false,
          location: '/onboarding',
          isRedoSetup: false,
        ),
        isNull,
      );
    });

    test('local profiles are usable offline in guest mode', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: false,
          hasProfile: true,
          location: '/',
          isRedoSetup: false,
        ),
        isNull,
      );
      expect(
        resolveFitGoRedirect(
          loggedIn: false,
          hasProfile: true,
          location: '/auth',
          isRedoSetup: false,
        ),
        isNull,
      );
    });

    test('signed-in profiles leave the auth screen', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: true,
          hasProfile: true,
          location: '/auth',
          isRedoSetup: false,
        ),
        '/',
      );
    });

    test('onboarding is skipped unless the user asked to redo setup', () {
      expect(
        resolveFitGoRedirect(
          loggedIn: true,
          hasProfile: true,
          location: '/onboarding',
          isRedoSetup: false,
        ),
        '/',
      );
      expect(
        resolveFitGoRedirect(
          loggedIn: true,
          hasProfile: true,
          location: '/onboarding',
          isRedoSetup: true,
        ),
        isNull,
      );
    });
  });

  group('notificationTarget', () {
    test('reads destinations from custom scheme payloads', () {
      expect(notificationTarget('fitgo://fasting'), 'fasting');
      expect(
        notificationTarget('fitgo://profile?section=notifications'),
        'profile',
      );
      expect(notificationTarget('fitgo:///fasting'), 'fasting');
    });

    test('accepts plain paths and ignores empty payloads', () {
      expect(notificationTarget('/trends'), 'trends');
      expect(notificationTarget(''), '');
    });
  });
}
