import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/quiet_hours.dart';
import '../../data/services/push_service.dart';
import '../../presentation/navigation/app_router.dart';
import 'auth_providers.dart';

/// Singleton [PushService] — created lazily, owned by the provider scope.
///
/// Wired to the canonical [apiClientProvider] so `registerWithBackend()` uses
/// the same Dio instance (single auth interceptor, single base URL) as the
/// rest of the app.
final pushServiceProvider = Provider<PushService>((ref) {
  final api = ref.read(apiClientProvider);
  final service = PushService();
  // Fire-and-forget init — failures fall back to stub mode internally.
  unawaited(service.init(api: api));
  // Day 17 — keep quiet hours in sync with the user-controllable provider.
  ref.listen<QuietHoursConfig>(quietHoursProvider, (_, next) {
    service.quietHours = next;
  }, fireImmediately: true);
  ref.onDispose(service.dispose);
  return service;
});

/// Resolves the current FCM token (or stub) the first time it's watched.
/// Uses `ref.watch` so that invalidating [pushServiceProvider] re-runs this.
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  return ref.watch(pushServiceProvider).getToken();
});

/// Current notification-permission status. **Watching this triggers the OS
/// permission dialog** — only consume from an explicit "request permission"
/// button handler, never from a passive build method.
final pushPermissionProvider =
    FutureProvider<PushPermissionOutcome>((ref) async {
  return ref.watch(pushServiceProvider).requestPermission();
});

/// Day 17 — user-controllable quiet hours config (suppresses CHECK_IN_REMINDER
/// during the window). SOS pushes never honour this.
final quietHoursProvider =
    StateProvider<QuietHoursConfig>((ref) => QuietHoursConfig.defaults);

/// Day 17 — most recently delivered nav intent. UIs that want to display the
/// last route the push system drove read this.
final lastPushNavIntentProvider =
    StateProvider<PushNavIntent?>((_) => null);

/// Day 17 — side-effect subscription that listens to the push-service nav
/// stream and routes [GoRouter] accordingly. Returns nothing meaningful — its
/// value is just the [StreamSubscription] so it survives garbage collection
/// while the provider is alive.
///
/// Wire by `ref.watch(...)`-ing this in a top-level widget (see `main.dart`)
/// so it stays alive as long as the app does.
final pushNavigationListenerProvider =
    Provider<StreamSubscription<PushNavIntent>>((ref) {
  final service = ref.watch(pushServiceProvider);
  final router = ref.watch(routerProvider);

  final sub = service.navigationIntents.listen((intent) {
    // Track the latest intent for UI surfaces that want to display it.
    ref.read(lastPushNavIntentProvider.notifier).state = intent;
    // Forward to GoRouter — the route was resolved upstream in PushService.
    router.go(intent.route, extra: intent.extra);
  });

  ref.onDispose(sub.cancel);

  // Fire any cold-start payload after listeners are attached.
  service.emitColdStartIntentIfAny();

  return sub;
});
