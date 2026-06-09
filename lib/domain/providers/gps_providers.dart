import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_state.dart';
import '../../data/models/gps_sample.dart';
import '../../data/services/gps_service.dart';
import 'auth_providers.dart';

/// Singleton [GpsService] wired to the canonical [apiClientProvider]
/// so batch uploads ride the same Dio instance as auth.
final gpsServiceProvider = Provider<GpsService>((ref) {
  final api = ref.read(apiClientProvider);
  final svc = GpsService(api: api);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Broadcast stream of [GpsSample]s. Empty until [GpsService.start] is
/// called.
final gpsSamplesStreamProvider = StreamProvider<GpsSample>((ref) {
  return ref.watch(gpsServiceProvider).samples;
});

/// **Day 38 note** — the canonical state machine now lives in
/// `appStateProvider` (see `app_state_provider.dart`). This `StateProvider`
/// stays around as a backward-compat surface for the Day 37 demo
/// screen, which manipulates it directly. The bridge in
/// `appStateGpsBridgeProvider` mirrors central → legacy on every
/// transition so the two views never drift.
final gpsAppStateProvider =
    StateProvider<AppState>((_) => AppState.monitoring);
