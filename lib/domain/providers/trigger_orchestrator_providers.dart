import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fall_event.dart';
import '../../data/models/trigger_event.dart';
import '../integration/trigger_orchestrator.dart';
import 'app_state_provider.dart';
import 'imu_providers.dart';
import 'inference_providers.dart';

/// Day 39 — singleton [TriggerOrchestrator] bound to the central
/// [AppStateNotifier].
final triggerOrchestratorProvider = Provider<TriggerOrchestrator>((ref) {
  final notifier = ref.read(appStateProvider.notifier);
  final orch = TriggerOrchestrator(notifier: notifier);
  ref.onDispose(orch.dispose);
  return orch;
});

/// Eager-attach bootstrap. Watching this provider once from a screen
/// keeps the orchestrator alive and subscribed to:
///   • [triggerEventStreamProvider] (DCS alerts + auto-SOS)
///   • [fallEventStreamProvider] (IMU fall events)
///
/// The streams come from Riverpod `StreamProvider`s that wrap async work —
/// we convert their `AsyncValue` emissions to plain `Stream`s via local
/// `StreamController`s so the orchestrator's `attach()` contract stays
/// simple (`Stream<T>` in, no Riverpod knowledge).
final triggerOrchestratorBootstrapProvider =
    Provider<TriggerOrchestrator>((ref) {
  final orch = ref.watch(triggerOrchestratorProvider);

  final dcsController = StreamController<TriggerEvent>.broadcast();
  final fallController = StreamController<FallEvent>.broadcast();

  ref.listen<AsyncValue<TriggerEvent>>(
    triggerEventStreamProvider,
    (_, next) {
      next.whenData(dcsController.add);
    },
  );
  ref.listen<AsyncValue<FallEvent>>(
    fallEventStreamProvider,
    (_, next) {
      next.whenData(fallController.add);
    },
  );

  orch.attach(
    dcsEvents:  dcsController.stream,
    fallEvents: fallController.stream,
  );

  ref.onDispose(() async {
    await orch.detach();
    await dcsController.close();
    await fallController.close();
  });

  return orch;
});
