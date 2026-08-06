/// SOS session + backend bridge — connects [AppStateNotifier] to [SosService].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/models/app_state.dart';
import '../../data/models/gps_sample.dart';
import '../../data/services/sos_service.dart';
import 'app_state_provider.dart';
import 'auth_providers.dart';
import 'battery_providers.dart';
import 'gps_providers.dart';

// ─── Service ──────────────────────────────────────────────────────────────────

final sosServiceProvider = Provider<SosService>((ref) {
  return SosService(ref.watch(apiClientProvider));
});

// ─── Active session ───────────────────────────────────────────────────────────

@immutable
class ActiveSosSession {
  const ActiveSosSession({required this.sosId, this.event});

  final String sosId;
  final SosEvent? event;

  ActiveSosSession copyWith({String? sosId, SosEvent? event}) =>
      ActiveSosSession(
        sosId: sosId ?? this.sosId,
        event: event ?? this.event,
      );
}

class ActiveSosSessionNotifier extends StateNotifier<ActiveSosSession?> {
  ActiveSosSessionNotifier() : super(null);

  void setSession(SosEvent event) {
    state = ActiveSosSession(sosId: event.id, event: event);
  }

  void clear() => state = null;
}

final activeSosSessionProvider =
    StateNotifierProvider<ActiveSosSessionNotifier, ActiveSosSession?>(
  (_) => ActiveSosSessionNotifier(),
);

/// Maps [TriggerMethod] from the state machine to backend trigger types.
SosTriggerType triggerTypeForMethod(TriggerMethod method) => switch (method) {
      TriggerMethod.manual ||
      TriggerMethod.doubleTap ||
      TriggerMethod.voiceCue =>
        SosTriggerType.manualButton,
      TriggerMethod.fall => SosTriggerType.shake,
      TriggerMethod.dcs => SosTriggerType.aiDetected,
      TriggerMethod.external => SosTriggerType.manualButton,
    };

// ─── Backend side-effects ─────────────────────────────────────────────────────

/// Listens to [appStateProvider] and fires SOS HTTP calls at the right
/// transitions. Policy lives in the state machine; I/O lives here.
final sosBackendBridgeProvider = Provider<void>((ref) {
  final sos = ref.read(sosServiceProvider);
  final session = ref.read(activeSosSessionProvider.notifier);
  final gps = ref.read(gpsServiceProvider);

  ref.listen<AppState>(appStateProvider, (prev, next) async {
    if (prev == next) return;

    // Entering SOS_ACTIVE → POST /sos/trigger/
    if (next == AppState.sosActive &&
        prev != AppState.sosActive &&
        prev != AppState.escalating) {
      if (kUseMockData) {
        session.setSession(SosEvent(
          id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
          status: 'active',
          triggerType: 'manual_button',
          isLive: true,
        ));
        return;
      }

      try {
        final latest = gps.latest;
        final batteryLevel = ref.read(batteryProfileProvider).level;
        final event = await sos.trigger(
          triggerType: SosTriggerType.manualButton,
          location: latest,
          batteryLevel: batteryLevel >= 0 ? batteryLevel : null,
        );
        session.setSession(event);
        if (kDebugMode) {
          debugPrint('[sos] triggered ${event.id} dispatch=${event.dispatch}');
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('[sos] trigger failed: $e\n$st');
      }
    }

    // Genuine cancel while a session exists → POST cancel (real PIN path).
    if (prev != null &&
        (prev == AppState.sosActive || prev == AppState.alertPending) &&
        next == AppState.monitoring &&
        !ref.read(appStateProvider.notifier).silentlyEscalating) {
      final active = ref.read(activeSosSessionProvider);
      if (active != null && !kUseMockData) {
        try {
          await sos.cancel(sosId: active.sosId);
        } catch (e) {
          if (kDebugMode) debugPrint('[sos] cancel failed: $e');
        }
      }
      session.clear();
    }

    // Resolved / back to monitoring after incident.
    if (next == AppState.postIncident ||
        next == AppState.monitoring && prev == AppState.postIncident) {
      session.clear();
    }
  });
});

/// During SOS_ACTIVE, stream GPS fixes to POST /sos/<id>/location/.
final sosLocationStreamProvider = Provider<void>((ref) {
  StreamSubscription<GpsSample>? sub;

  ref.listen<AppState>(appStateProvider, (prev, next) async {
    await sub?.cancel();
    sub = null;

    if (next != AppState.sosActive && next != AppState.escalating) return;

    final sosId = ref.read(activeSosSessionProvider)?.sosId;
    if (sosId == null) return;

    if (kUseMockData) return;

    final sos = ref.read(sosServiceProvider);
    final gps = ref.read(gpsServiceProvider);
    final batteryLevel = ref.read(batteryProfileProvider).level;

    sub = gps.samples.listen((sample) async {
      try {
        await sos.postLocation(
          sosId: sosId,
          sample: sample,
          batteryPercent: batteryLevel >= 0 ? batteryLevel : null,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[sos] location ping failed: $e');
      }
    });
  });

  ref.onDispose(() => sub?.cancel());
});

/// Hydrate an in-flight SOS from the backend on authenticated cold start.
final sosSessionHydratorProvider = FutureProvider<void>((ref) async {
  if (kUseMockData) return;
  final loggedIn = ref.watch(isLoggedInProvider);
  if (!loggedIn) return;

  final sos = ref.read(sosServiceProvider);
  final session = ref.read(activeSosSessionProvider.notifier);
  final notifier = ref.read(appStateProvider.notifier);

  try {
    final active = await sos.fetchActive();
    if (active == null || !active.isLive) return;

    session.setSession(active);
    notifier.restoreActiveSos();
  } catch (e) {
    if (kDebugMode) debugPrint('[sos] hydrate skipped: $e');
  }
});
