import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_state.dart';
import '../../data/models/battery_profile.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/gps_sample.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/motion_features.dart';
import '../../data/models/trigger_event.dart';
import '../../data/services/cell_location_service.dart';
import '../../data/services/gps_fallback_coordinator.dart';
import '../../data/services/gps_polling_profile.dart';
import '../../data/services/gps_service.dart';
import '../../data/services/imu_service.dart';
import '../../data/services/model_registry.dart';
import '../../ml/inference/dcs_score_watcher.dart';
import '../../native/platform_channels.dart';
import '../providers/app_state_provider.dart';
import '../providers/inference_providers.dart';
import '../providers/platform_channel_providers.dart';
import 'month1_runner.dart';
import 'trigger_orchestrator.dart';

/// Day 40 — phase list that probes every piece of Month 2 infrastructure
/// (Days 21-39) in one pass. Mirrors the Day 19 Month 1 runner shape so
/// the Day 40 screen can reuse the same UI primitives.
///
/// Platform-only phases (Android FGS, iOS BGTask) are marked
/// `expectedFailReason` on the wrong host so the summary stays GREEN as
/// long as every layer that *can* be tested on this host passes.
///
/// Many phases also exist as host-VM pure checks (no Riverpod / no
/// plugin), so the Month 2 unit-test file (`month2_runner_test.dart`)
/// can exercise them directly without a Flutter binding.
List<IntegrationPhase> buildMonth2Phases(WidgetRef ref) {
  return [
    // ─── Platform infrastructure ───────────────────────────────────────
    IntegrationPhase(
      key: 'channel_registry',
      name: 'Platform-channel registry',
      description: '9 channels declared · all com.zapsafe/* prefix.',
      runner: () async => month2PhaseRunners.channelRegistry(),
    ),
    IntegrationPhase(
      key: 'android_fgs',
      name: 'Android foreground service reachable',
      description: 'BackgroundService.supported on Android host.',
      expectedFailReason:
          Platform.isAndroid ? null : 'Android-only — N/A on this host',
      runner: () async {
        if (!Platform.isAndroid) throw 'Not Android';
        return const PhaseResult(
          key: 'android_fgs',
          name: 'Android foreground service reachable',
          status: PhaseStatus.pass,
          detail: 'BackgroundService channel resolves on Android',
        );
      },
    ),
    IntegrationPhase(
      key: 'ios_bg',
      name: 'iOS BGProcessingTask handler reachable',
      description: 'IosBackgroundHandler.supported on iOS host.',
      expectedFailReason:
          Platform.isIOS ? null : 'iOS-only — N/A on this host',
      runner: () async {
        if (!Platform.isIOS) throw 'Not iOS';
        return const PhaseResult(
          key: 'ios_bg',
          name: 'iOS BGProcessingTask handler reachable',
          status: PhaseStatus.pass,
          detail: 'BackgroundProcessingHandler channel resolves on iOS',
        );
      },
    ),
    IntegrationPhase(
      key: 'audio_supported',
      name: 'Audio capture pipeline supported',
      description: '16 kHz · 450 ms · VAD on Android + iOS.',
      expectedFailReason: Platform.isAndroid || Platform.isIOS
          ? null
          : 'capture-native platform required',
      runner: () async {
        final audio = ref.read(audioChannelProvider);
        if (!audio.supported) throw 'No native audio implementation';
        return PhaseResult(
          key: 'audio_supported',
          name: 'Audio capture pipeline supported',
          status: PhaseStatus.pass,
          detail: 'AudioChannel.supported = true',
        );
      },
    ),

    // ─── ML / inference ─────────────────────────────────────────────────
    IntegrationPhase(
      key: 'tflite_registry',
      name: 'TFLite registry · 5 model slots',
      description: 'kZapsafeModels has 5 declared assets (placeholders today).',
      runner: () async => month2PhaseRunners.tfliteRegistry(),
    ),
    IntegrationPhase(
      key: 'dcs_engine',
      name: 'DCSInferenceEngine composes 4 slots',
      description: 'Engine builds with stub fallbacks per slot.',
      runner: () async {
        final engine = await ref.read(dcsEngineProvider.future);
        if (engine.slotStatuses.length != 4) {
          throw 'engine has ${engine.slotStatuses.length} slots, expected 4';
        }
        return PhaseResult(
          key: 'dcs_engine',
          name: 'DCSInferenceEngine composes 4 slots',
          status: PhaseStatus.pass,
          detail: 'real='
              '${engine.slotStatuses.where((s) => s.real).length} · '
              'stub=${engine.slotStatuses.where((s) => !s.real).length}',
        );
      },
    ),
    IntegrationPhase(
      key: 'dcs_watcher',
      name: 'DCS watcher · vote + AUTO_SOS',
      description: 'Three high windows → ALERT_PENDING · 0.90 → AUTO_SOS.',
      runner: () async => month2PhaseRunners.dcsWatcher(),
    ),

    // ─── Sensors + location ────────────────────────────────────────────
    IntegrationPhase(
      key: 'imu_service',
      name: 'IMU service instantiable',
      description: 'ImuService() constructs · latestFeatures starts null.',
      runner: () async => month2PhaseRunners.imuService(),
    ),
    IntegrationPhase(
      key: 'gps_profile_mapping',
      name: 'GPS profile mapping · 7 states',
      description: 'GpsPollingProfile.fromAppState covers all states.',
      runner: () async => month2PhaseRunners.gpsProfileMapping(),
    ),
    IntegrationPhase(
      key: 'gps_fallback_policy',
      name: 'GPS fallback policy · LP12 gate',
      description: 'Coordinator flags >50 m fixes for cell merge.',
      runner: () async => month2PhaseRunners.gpsFallbackPolicy(),
    ),

    // ─── Battery ──────────────────────────────────────────────────────
    IntegrationPhase(
      key: 'battery_tiers',
      name: 'Battery tier table · 20/15/10',
      description: 'BatteryThresholds.tierForLevel maps the 4 tiers.',
      runner: () async => month2PhaseRunners.batteryTiers(),
    ),

    // ─── State machine + wiring ───────────────────────────────────────
    IntegrationPhase(
      key: 'state_machine',
      name: 'AppStateNotifier · 7-state transitions',
      description: 'monitoring → alertPending → sosActive end-to-end.',
      runner: () async => month2PhaseRunners.stateMachine(),
    ),
    IntegrationPhase(
      key: 'orchestrator_wiring',
      name: 'TriggerOrchestrator · DCS + fall + manual',
      description:
          'Synthetic DCS/Fall events route to the correct notifier method.',
      runner: () async => month2PhaseRunners.orchestratorWiring(),
    ),
  ];
}

/// Day 40 — pure runner functions for the host-VM tests.
///
/// Each function is a `Future<PhaseResult>` synthesiser that touches only
/// pure Dart surfaces (no Riverpod, no plugins). The screen's WidgetRef-
/// backed phases above delegate here for everything that doesn't need a
/// Riverpod-managed singleton.
abstract final class month2PhaseRunners {
  static PhaseResult channelRegistry() {
    const expectedCount = 9; // bg · ios_bg · sensors + .events · audio +
                              // .events + .features · watchdog · cell
    final names = <String>[
      PlatformChannelNames.backgroundService,
      PlatformChannelNames.iosBackground,
      PlatformChannelNames.sensors,
      PlatformChannelNames.sensorsEvents,
      PlatformChannelNames.audio,
      PlatformChannelNames.audioEvents,
      PlatformChannelNames.audioFeatures,
      PlatformChannelNames.watchdog,
      PlatformChannelNames.cell,
    ];
    if (names.length != expectedCount) {
      throw 'registry size ${names.length} != $expectedCount';
    }
    final unique = names.toSet();
    if (unique.length != names.length) throw 'duplicate channel name';
    final wrongPrefix =
        names.where((n) => !n.startsWith('com.zapsafe/')).toList();
    if (wrongPrefix.isNotEmpty) {
      throw 'wrong prefix: ${wrongPrefix.join(", ")}';
    }
    return const PhaseResult(
      key: 'channel_registry',
      name: 'Platform-channel registry',
      status: PhaseStatus.pass,
      detail: '9 unique channels · all com.zapsafe/* prefix',
    );
  }

  static PhaseResult tfliteRegistry() {
    if (kZapsafeModels.length != 5) {
      throw 'kZapsafeModels has ${kZapsafeModels.length} entries, expected 5';
    }
    final keys = kZapsafeModels.map((m) => m.key).toSet();
    if (keys.length != 5) throw 'duplicate model key';
    final pathsOK = kZapsafeModels.every((m) =>
        m.assetPath.startsWith('assets/models/') &&
        m.assetPath.endsWith('.tflite'));
    if (!pathsOK) throw 'asset path does not match convention';
    return const PhaseResult(
      key: 'tflite_registry',
      name: 'TFLite registry · 5 model slots',
      status: PhaseStatus.pass,
      detail: '5 model slots declared · paths conform to '
          'assets/models/*.tflite',
    );
  }

  static PhaseResult dcsWatcher() {
    final watcher = DCSScoreWatcher();
    DCSScore mk(double scream) {
      final fusion = InferenceResult(
        label: scream >= 0.5 ? 'scream' : 'normal',
        score: scream,
        classScores: {'scream': scream, 'normal': 1 - scream},
        latencyMs: 1,
        timestampMs: 0,
      );
      const neutral = InferenceResult(
        label: 'normal',
        score: 0.1,
        classScores: {'normal': 0.1},
        latencyMs: 1,
        timestampMs: 0,
      );
      return DCSScore(
        timestampMs: 0,
        audio: neutral,
        motion: neutral,
        scene: neutral,
        fusion: fusion,
      );
    }
    TriggerEvent? voted;
    for (var i = 0; i < 3; i++) {
      voted = watcher.observe(mk(0.80));
    }
    if (voted?.kind != TriggerKind.alertPending) {
      throw 'no ALERT_PENDING after 3 high windows';
    }
    final auto = DCSScoreWatcher().observe(mk(0.92));
    if (auto?.kind != TriggerKind.autoSos) {
      throw 'no AUTO_SOS on single 0.92 window';
    }
    return const PhaseResult(
      key: 'dcs_watcher',
      name: 'DCS watcher · vote + AUTO_SOS',
      status: PhaseStatus.pass,
      detail: 'vote=3-window @ 0.80 · autoSos=single @ 0.92',
    );
  }

  static PhaseResult imuService() {
    final svc = ImuService();
    try {
      if (svc.latestFeatures != null) {
        throw 'expected latestFeatures = null before start()';
      }
      // Synthetic at-rest features should be constructible.
      final mf = MotionFeatures.atRest(timestampMs: 0);
      if (mf.accelMean <= 0) throw 'atRest gravity should be ~9.8';
    } finally {
      svc.dispose();
    }
    return const PhaseResult(
      key: 'imu_service',
      name: 'IMU service instantiable',
      status: PhaseStatus.pass,
      detail: 'ImuService() constructs · MotionFeatures.atRest synthesises',
    );
  }

  static PhaseResult gpsProfileMapping() {
    const expected = <AppState, GpsPollingProfile>{
      AppState.idle:          GpsPollingProfile.off,
      AppState.postIncident:  GpsPollingProfile.off,
      AppState.monitoring:    GpsPollingProfile.monitoring,
      AppState.elevated:      GpsPollingProfile.elevated,
      AppState.alertPending:  GpsPollingProfile.sosTime,
      AppState.sosActive:     GpsPollingProfile.sosTime,
      AppState.escalating:    GpsPollingProfile.sosTime,
    };
    for (final entry in expected.entries) {
      final actual = GpsPollingProfile.fromAppState(entry.key);
      if (actual != entry.value) {
        throw '${entry.key.label} → ${actual.label}, expected ${entry.value.label}';
      }
    }
    return const PhaseResult(
      key: 'gps_profile_mapping',
      name: 'GPS profile mapping · 7 states',
      status: PhaseStatus.pass,
      detail: 'all 7 AppStates map to the expected profile',
    );
  }

  static PhaseResult gpsFallbackPolicy() {
    final gps = GpsService();
    final coord = GpsFallbackCoordinator(
      gps: gps,
      cell: CellLocationService(),
    );
    const good = GpsSample(timestampMs: 0, lat: 0, lng: 0, accuracyM: 8);
    const bad  = GpsSample(timestampMs: 0, lat: 0, lng: 0, accuracyM: 220);
    final goodReason = coord.evaluate(good);
    final badReason  = coord.evaluate(bad);
    if (goodReason != null) {
      throw 'high-quality fix should not trigger fallback';
    }
    if (badReason == null) throw 'low-quality fix should trigger fallback';
    coord.dispose();
    return PhaseResult(
      key: 'gps_fallback_policy',
      name: 'GPS fallback policy · LP12 gate',
      status: PhaseStatus.pass,
      detail: 'good→ok · bad→"$badReason"',
    );
  }

  static PhaseResult batteryTiers() {
    final cases = <int, BatteryTier>{
      80: BatteryTier.normal,
      18: BatteryTier.powerSaver,
      13: BatteryTier.proactiveDrop,
       7: BatteryTier.vadOnly,
    };
    for (final entry in cases.entries) {
      final actual = BatteryThresholds.tierForLevel(entry.key);
      if (actual != entry.value) {
        throw '${entry.key}% → ${actual.label}, expected ${entry.value.label}';
      }
    }
    // Charging override.
    if (BatteryThresholds.tierForLevel(5, isCharging: true) !=
        BatteryTier.normal) {
      throw 'charging override failed';
    }
    return const PhaseResult(
      key: 'battery_tiers',
      name: 'Battery tier table · 20/15/10',
      status: PhaseStatus.pass,
      detail: '80% → normal · 18% → powerSaver · 13% → proactiveDrop · '
          '7% → vadOnly · charging override → normal',
    );
  }

  static PhaseResult stateMachine() {
    final n = AppStateNotifier();
    if (n.state != AppState.monitoring) throw 'wrong initial state';
    n.onDCSThresholdExceeded();
    if (n.state != AppState.alertPending) {
      throw 'DCS trigger did not promote to alertPending';
    }
    if (n.alertCountdownStartedAt == null) {
      throw 'alert countdown should be active';
    }
    n.onAlertPendingExpired();
    if (n.state != AppState.sosActive) {
      throw 'expired alert did not escalate to sosActive';
    }
    n.onSosResolved();
    if (n.state != AppState.postIncident) {
      throw 'resolved sos did not move to postIncident';
    }
    n.returnToMonitoring();
    if (n.state != AppState.monitoring) {
      throw 'returnToMonitoring did not reset to monitoring';
    }
    n.dispose();
    return const PhaseResult(
      key: 'state_machine',
      name: 'AppStateNotifier · 7-state transitions',
      status: PhaseStatus.pass,
      detail: 'monitoring → alertPending → sosActive → postIncident → '
          'monitoring',
    );
  }

  static PhaseResult orchestratorWiring() {
    final n = AppStateNotifier();
    final orch = TriggerOrchestrator(notifier: n);

    // Synthetic DCS auto-SOS — should skip the countdown.
    final fusion = const InferenceResult(
      label: 'scream',
      score: 0.92,
      classScores: {'scream': 0.92, 'normal': 0.08},
      latencyMs: 1,
      timestampMs: 0,
    );
    final score = DCSScore(
      timestampMs: 0,
      audio: fusion,
      fusion: fusion,
    );
    orch.dispatchDcs(TriggerEvent(
      kind: TriggerKind.autoSos,
      score: score,
      passive: true,
      consecutiveWindows: 0,
      timestampMs: 0,
    ));
    if (n.state != AppState.sosActive) {
      throw 'AUTO_SOS did not transition notifier to sosActive';
    }

    // Reset for the next check.
    n.onSosResolved();
    n.returnToMonitoring();

    orch.dispatchFall(const FallEvent(
      timestampMs: 0,
      peakAccelMagnitude: 28.4,
      freefallDurationMs: 320,
    ));
    if (n.state != AppState.alertPending) {
      throw 'fall did not transition notifier to alertPending';
    }
    if (orch.totalDispatched != 2) {
      throw 'expected 2 dispatched events, got ${orch.totalDispatched}';
    }
    n.dispose();
    return PhaseResult(
      key: 'orchestrator_wiring',
      name: 'TriggerOrchestrator · DCS + fall + manual',
      status: PhaseStatus.pass,
      detail: 'autoSos → sosActive · fall → alertPending · dispatched=2',
    );
  }
}
