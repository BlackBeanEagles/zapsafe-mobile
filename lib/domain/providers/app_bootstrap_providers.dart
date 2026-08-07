/// Global app bootstrap — keeps production integrations alive for the full session.
///
/// Watches:
///   • [triggerOrchestratorBootstrapProvider] — DCS + fall → state machine
///   • [dcsDetectionLogSubmitterProvider]     — DCS fusion score → detection-log (Day 322)
///   • [batteryMonitoringBootstrapProvider]   — starts real battery_plus reads + 1h sample log (Day 328)
///   • [appStateGpsBridgeProvider]            — state → GPS cadence
///   • [sosBackendBridgeProvider]             — state → SOS HTTP
///   • [sosLocationStreamProvider]            — GPS → SOS location pings
///   • [appStateNavigationBridgeProvider]     — state → GoRouter
///   • [sosSessionHydratorProvider]           — cold-start active SOS
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/models/app_state.dart';
import '../../presentation/navigation/app_router.dart';
import 'app_state_provider.dart';
import 'auth_providers.dart';
import 'battery_monitoring_providers.dart';
import 'dcs_detection_log_providers.dart';
import 'gps_providers.dart';
import 'sos_providers.dart';
import 'trigger_orchestrator_providers.dart';

/// Routes that require an authenticated session when [kProductionShell] is on.
const _protectedPrefixes = <String>{
  AppRoutes.dashboard,
  // Day 302 note: `AppRoutes.productionDashboard` (Day 279 production
  // dashboard screen) is referenced by other in-flight work but that
  // screen/route does not exist on `main` yet — omitted here rather than
  // fabricated, so this stays a real guard list, not an aspirational one.
  AppRoutes.settingsV2,
  AppRoutes.contactsV2,
  AppRoutes.evidenceVault,
  AppRoutes.alertDashboardV2,
  AppRoutes.alertPending,
  AppRoutes.sosActive,
};

bool _isProtectedRoute(String location) {
  for (final prefix in _protectedPrefixes) {
    if (location == prefix || location.startsWith('$prefix/')) return true;
  }
  return false;
}

/// Production auth guard — dev Day 5 index stays open at `/`.
bool productionAuthRedirect({
  required bool isLoggedIn,
  required String location,
}) {
  if (!kProductionShell) return false;
  if (isLoggedIn) return false;
  if (location == AppRoutes.phoneEntry || location == AppRoutes.otpVerify) {
    return false;
  }
  if (location == AppRoutes.onboarding) return false;
  if (location == AppRoutes.home) return false;
  return _isProtectedRoute(location);
}

/// Navigate to alert-pending / sos-active when the state machine transitions.
final appStateNavigationBridgeProvider = Provider<void>((ref) {
  final router = ref.watch(routerProvider);

  ref.listen<AppState>(appStateProvider, (prev, next) {
    if (prev == next) return;

    final location = router.routeInformationProvider.value.uri.path;

    switch (next) {
      case AppState.alertPending:
        if (location != AppRoutes.alertPending) {
          router.go(AppRoutes.alertPending);
        }
        break;
      case AppState.sosActive:
      case AppState.escalating:
        if (location != AppRoutes.sosActive) {
          router.go(AppRoutes.sosActive);
        }
        break;
      case AppState.monitoring:
      case AppState.postIncident:
        if (location == AppRoutes.alertPending ||
            location == AppRoutes.sosActive) {
          if (kProductionShell) {
            router.go(AppRoutes.dashboard);
          } else {
            router.pop();
          }
        }
        break;
      default:
        break;
    }
  });
});

/// Single provider to watch from [ZapSafeApp] — wires all global side effects.
final appBootstrapProvider = Provider<void>((ref) {
  ref.watch(triggerOrchestratorBootstrapProvider);
  ref.watch(dcsDetectionLogSubmitterProvider); // Day 322
  ref.watch(batteryMonitoringBootstrapProvider); // Day 328
  ref.watch(appStateGpsBridgeProvider);
  ref.watch(sosBackendBridgeProvider);
  ref.watch(sosLocationStreamProvider);
  ref.watch(appStateNavigationBridgeProvider);

  // Hydrate backend session + start GPS when authenticated.
  ref.listen<bool>(isLoggedInProvider, (prev, loggedIn) async {
    if (loggedIn) {
      unawaited(ref.read(sosSessionHydratorProvider.future));
      final gps = ref.read(gpsServiceProvider);
      if (!gps.isRunning) {
        try {
          await gps.start();
        } catch (e) {
          if (kDebugMode) debugPrint('[bootstrap] gps.start failed: $e');
        }
      }
      ref.read(appStateProvider.notifier).powerOn();
    }
  }, fireImmediately: true);
});
