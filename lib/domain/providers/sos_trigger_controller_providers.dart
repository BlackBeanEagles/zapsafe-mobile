/// Day 321 — provider wiring for [SosTriggerController].
///
/// Deliberately built on top of [triggerOrchestratorProvider] (the same
/// singleton `sos_trigger_button.dart` and `appBootstrapProvider` already
/// share) — not a second orchestrator instance. Reading this provider does
/// NOT itself attach the DCS/fall streams; that stays
/// [triggerOrchestratorBootstrapProvider]'s job (already watched from
/// [appBootstrapProvider]), so this file adds no new stream subscriptions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sos/sos_trigger_controller.dart';
import 'app_state_provider.dart';
import 'trigger_orchestrator_providers.dart';

final sosTriggerControllerProvider = Provider<SosTriggerController>((ref) {
  final orchestrator = ref.watch(triggerOrchestratorProvider);
  final notifier = ref.read(appStateProvider.notifier);
  return SosTriggerController(orchestrator: orchestrator, notifier: notifier);
});
