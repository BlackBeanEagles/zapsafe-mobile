import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/core/constants/app_flags.dart';
import 'package:zapsafe_mobile/domain/providers/app_bootstrap_providers.dart';
import 'package:zapsafe_mobile/presentation/navigation/app_router.dart';

/// Day 321 — the Day 5 navigation index is a build harness, not a product
/// surface, and these pin it that way.
///
/// It is a 3,753-line screen listing all 387 build-log screens. Before this
/// it was reachable in a production build two different ways: the route `/`
/// rendered it unconditionally, and `productionAuthRedirect` explicitly
/// exempted that path from the auth guard, so even a logged-out user could
/// open it and page through every internal screen.
///
/// These tests fail if either hole reopens.
void main() {
  group('the dev index is not reachable as a product surface', () {
    test('AppRoutes.appHome points at the dashboard in a production shell', () {
      // Everything user-tappable ("exit decoy", "disable stealth") must route
      // through appHome. If this ever resolves to AppRoutes.home again, those
      // buttons drop a real user into the dev index.
      expect(kProductionShell, isTrue,
          reason: 'default build is the production shell');
      expect(AppRoutes.appHome, AppRoutes.dashboard);
      expect(AppRoutes.appHome, isNot(AppRoutes.home));
    });

    test('a logged-out user is redirected away from the dev index', () {
      // This is the regression: the guard used to return false for
      // AppRoutes.home, which let an unauthenticated user reach it.
      expect(
        productionAuthRedirect(isLoggedIn: false, location: AppRoutes.home),
        isTrue,
        reason: 'the dev index must be guarded like any other route',
      );
    });

    test('auth entry points stay reachable while logged out', () {
      // Guard against over-correcting: locking these would make the app
      // impossible to sign in to.
      for (final open in [
        AppRoutes.phoneEntry,
        AppRoutes.otpVerify,
        AppRoutes.onboarding,
      ]) {
        expect(
          productionAuthRedirect(isLoggedIn: false, location: open),
          isFalse,
          reason: '$open must stay open to logged-out users',
        );
      }
    });

    test('a logged-in user is never redirected', () {
      for (final loc in [
        AppRoutes.home,
        AppRoutes.dashboard,
        AppRoutes.phoneEntry,
      ]) {
        expect(
          productionAuthRedirect(isLoggedIn: true, location: loc),
          isFalse,
        );
      }
    });
  });
}
