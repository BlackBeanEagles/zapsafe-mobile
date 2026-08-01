import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inference_result.dart';
import '../../data/services/crowd_panic_detector.dart';
import '../../data/services/crowd_panic_pipeline.dart';
import '../../data/services/detection_event_service.dart';
import '../../data/services/gunshot_audio_pipeline.dart';
import '../../data/services/gunshot_detector.dart';
import '../../data/services/k_confinement_detector.dart';
import '../../data/services/k_confinement_pipeline.dart';
import '../../data/services/motion_audio_pipeline.dart';
import '../../data/services/motion_audio_pipeline_b.dart';
import '../../data/services/motion_detector_b.dart';
import '../../data/services/motion_detector_v2.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../data/services/scream_audio_pipeline.dart';
import '../../data/services/scream_detector_v2.dart';
import '../../data/services/vehicle_crash_detector.dart';
import '../../data/services/vehicle_crash_pipeline.dart';
import 'detection_event_providers.dart';
import 'platform_channel_providers.dart';

/// Day 259 — wires the two models that passed real-data validation
/// (m1_scream_v2, m2_motion_v2) all the way to the backend.
///
/// Every other model measured against real data on this pass — 12 audio
/// models from the mel-image families, 8 IMU models — was either exactly
/// constant, indistinguishable from int8 quantisation noise, or scored
/// worse than chance. None of them are wired here. See
/// assets/models/PREPROCESSING_SPEC.md for the evidence per model.
///
/// Both pipelines below follow the same shape: build the real detector,
/// feed it live hardware, and POST every confident result through the
/// *existing* `/api/v1/ml/detection-events/` endpoint — its `event_type`
/// enum already has `scream` and `motion`, so no backend schema change was
/// needed for either model wired today.
///
/// Day 262 — added `mg_gunshot_retrain` (AUC 0.8913 on real AudioSet/
/// UrbanSound8K/FSD50K gunshot data, up from fp32 AUC 0.538 near-chance)
/// and `m2_motion_b_retrain` (test AUC 0.9808 on held-out real SisFall
/// falls, up from bit-exact 0.0). Both required a real backend schema
/// change (`EventType.GUNSHOT`, `EventType.MOTION_B`) — see
/// `zapsafe_backend/ml/migrations/` and
/// `assets/models/DAY262_GUNSHOT_MOTIONB_WIRING.md`.

/// Scream detector, loaded once. Null on a host with no native TFLite or a
/// still-placeholder asset — callers must check before using the pipeline.
final screamDetectorProvider = FutureProvider<ScreamDetectorV2?>((ref) async {
  final detector = await ScreamDetectorV2.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live scream pipeline: native 22,050 Hz / 3 s PCM stream -> mel ->
/// m1_scream_v2. Null while the detector is still loading or failed to load.
final screamAudioPipelineProvider =
    Provider<ScreamAudioPipeline?>((ref) {
  final detectorAsync = ref.watch(screamDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = ScreamAudioPipeline(
    detector: detector,
    windows: audio.pcmStream,
  );
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final motionDetectorProvider = FutureProvider<MotionDetectorV2?>((ref) async {
  final detector = await MotionDetectorV2.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live motion pipeline: accelerometer + gyroscope -> 100-sample window ->
/// m2_motion_v2. Null while the detector is still loading or failed to load.
final motionAudioPipelineProvider =
    Provider<MotionAudioPipeline?>((ref) {
  final detectorAsync = ref.watch(motionDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final pipeline = MotionAudioPipeline(detector: detector);
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final gunshotDetectorProvider = FutureProvider<GunshotDetectorV2?>((ref) async {
  final detector = await GunshotDetectorV2.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live gunshot pipeline: native 16,000 Hz / 3 s PCM stream -> mel image ->
/// mg_gunshot_retrain. Null while the detector is still loading or failed
/// to load.
final gunshotAudioPipelineProvider =
    Provider<GunshotAudioPipeline?>((ref) {
  final detectorAsync = ref.watch(gunshotDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = GunshotAudioPipeline(
    detector: detector,
    windows: audio.pcmStream,
  );
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final motionBDetectorProvider = FutureProvider<MotionDetectorB?>((ref) async {
  final detector = await MotionDetectorB.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live motion pipeline #2: accelerometer + gyroscope -> 128-sample window
/// -> m2_motion_b_retrain. Runs independently of [motionAudioPipelineProvider]
/// (m2_motion_v2) — see `motion_detector_b.dart` for why the two are not
/// fused.
final motionAudioPipelineBProvider =
    Provider<MotionAudioPipelineB?>((ref) {
  final detectorAsync = ref.watch(motionBDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final pipeline = MotionAudioPipelineB(detector: detector);
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final crowdPanicDetectorProvider =
    FutureProvider<CrowdPanicDetector?>((ref) async {
  final detector = await CrowdPanicDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live crowd-panic fusion pipeline: native audio PCM stream + accelerometer
/// /gyroscope stream -> s_crowd_panic (audio + IMU fusion). Null while the
/// detector is still loading or failed to load. See
/// `crowd_panic_pipeline.dart`'s class doc for the concurrent-capture
/// design decision (cache-and-fire-on-freshness, never infer on a stale or
/// missing side).
final crowdPanicFusionPipelineProvider =
    Provider<CrowdPanicFusionPipeline?>((ref) {
  final detectorAsync = ref.watch(crowdPanicDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = CrowdPanicFusionPipeline(
    detector: detector,
    audioWindows: audio.pcmStream,
  );
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final vehicleCrashDetectorProvider =
    FutureProvider<VehicleCrashDetector?>((ref) async {
  final detector = await VehicleCrashDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live vehicle-crash fusion pipeline: native audio PCM stream +
/// accelerometer/gyroscope stream -> i_vehicle_crash (audio + IMU fusion).
/// Null while the detector is still loading or failed to load. See
/// `vehicle_crash_pipeline.dart`'s class doc for the concurrent-capture
/// design decision, identical in structure to
/// `crowdPanicFusionPipelineProvider`'s.
final vehicleCrashFusionPipelineProvider =
    Provider<VehicleCrashFusionPipeline?>((ref) {
  final detectorAsync = ref.watch(vehicleCrashDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = VehicleCrashFusionPipeline(
    detector: detector,
    audioWindows: audio.pcmStream,
  );
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

final kConfinementDetectorProvider =
    FutureProvider<KConfinementDetector?>((ref) async {
  final detector = await KConfinementDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live k_confinement fusion pipeline: accelerometer/gyroscope stream ->
/// k_confinement_decorrelated (IMU + light fusion). Null while the detector
/// is still loading or failed to load. **The `light` input is a real native
/// sensor reading (`Sensor.TYPE_LIGHT`) on Android as of Day 274, mapped
/// through a documented heuristic (see `luxToModelLight` in
/// `light_sensor_channel.dart`); on iOS, or an Android device without a
/// light sensor, it falls back to a fixed placeholder value** — see
/// `k_confinement_pipeline.dart`'s class doc for the full honest breakdown.
/// Check `pipeline.usesRealLightSensor` (an instance getter) at runtime to
/// know which is actually happening for a given running instance.
final kConfinementFusionPipelineProvider =
    Provider<KConfinementFusionPipeline?>((ref) {
  final detectorAsync = ref.watch(kConfinementDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final pipeline = KConfinementFusionPipeline(detector: detector);
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

/// Submits every confident [InferenceResult] from both live pipelines to
/// `POST /api/v1/ml/detection-events/`. Reading this provider (e.g. from
/// app start-up) is what turns the wiring on; it produces no widget output
/// of its own.
///
/// A submission failure (offline, 401, etc.) is logged and swallowed —
/// detection must keep running even when the network does not cooperate.
final liveDetectionEventSubmitterProvider =
    FutureProvider<void>((ref) async {
  final service = ref.watch(detectionEventServiceProvider);
  final tier = await PhoneCapabilityDetector.cachedTier() ??
      PhoneCapabilityTier.low;

  final subs = <StreamSubscription<InferenceResult>>[];

  final scream = ref.watch(screamAudioPipelineProvider);
  if (scream != null) {
    subs.add(scream.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.scream,
          tier,
        )));
  }

  final motion = ref.watch(motionAudioPipelineProvider);
  if (motion != null) {
    subs.add(motion.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.motion,
          tier,
        )));
  }

  final gunshot = ref.watch(gunshotAudioPipelineProvider);
  if (gunshot != null) {
    subs.add(gunshot.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.gunshot,
          tier,
        )));
  }

  final motionB = ref.watch(motionAudioPipelineBProvider);
  if (motionB != null) {
    subs.add(motionB.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.motionB,
          tier,
        )));
  }

  final crowdPanic = ref.watch(crowdPanicFusionPipelineProvider);
  if (crowdPanic != null) {
    subs.add(crowdPanic.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.crowdPanic,
          tier,
        )));
  }

  final vehicleCrash = ref.watch(vehicleCrashFusionPipelineProvider);
  if (vehicleCrash != null) {
    subs.add(vehicleCrash.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.vehicleCrash,
          tier,
        )));
  }

  final kConfinement = ref.watch(kConfinementFusionPipelineProvider);
  if (kConfinement != null) {
    subs.add(kConfinement.results.listen((r) => _submit(
          service,
          r,
          DetectionEventType.kConfinement,
          tier,
        )));
  }

  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
});

Future<void> _submit(
  DetectionEventService service,
  InferenceResult r,
  DetectionEventType type,
  PhoneCapabilityTier tier,
) async {
  if (!r.isConfident) return;
  try {
    await service.submit(
      eventType: type,
      confidence: r.score,
      tier: tier.name,
      detectionMode: 'ai',
      inferenceMs: r.latencyMs.toDouble(),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[liveDetectionEventSubmitter] submit failed for '
          '${type.value}: $e');
    }
  }
}
