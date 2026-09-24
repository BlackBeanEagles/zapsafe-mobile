import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inference_result.dart';
import '../../data/services/detection_event_service.dart';
import '../../data/services/aggressive_speech_detector.dart';
import '../../data/services/glass_break_detector.dart';
import '../../data/services/glass_break_pipeline.dart';
import '../../data/services/gunshot_audio_pipeline.dart';
import '../../data/services/gunshot_detector.dart';
import '../../data/services/k_confinement_detector.dart';
import '../../data/services/k_confinement_pipeline.dart';
import '../../data/services/motion_audio_pipeline.dart';
import '../../data/services/motion_detector_v2.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../data/services/scream_audio_pipeline.dart';
import '../../data/services/scream_detector_v2.dart';
import '../../data/services/vehicle_crash_detector.dart';
import '../../data/services/vehicle_crash_pipeline.dart';
import '../../data/services/camera_frame_service.dart';
import '../../data/services/violence_burst_coordinator.dart';
import '../../data/services/violence_burst_detector.dart';
import '../../data/services/vocal_stress_detector.dart';
import '../../data/services/vocal_stress_pipeline.dart';
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

/// Day 328 — `s_crowd_panic`, `i_vehicle_crash` and
/// `k_confinement_decorrelated` are switched off here.
///
/// All three were measured against the shipped assets on real local data and
/// none can produce a usable detection on a phone. In short:
///
/// * `s_crowd_panic` separates its training classes by **data provenance**,
///   not by panic. Its negatives were paired with digital silence and its
///   "IMU" channel 0 is PAMAP2 chest *skin temperature* (`df.iloc[:, 20:26]`
///   starts at the chest temp column), which is ~35 for negatives and ~0 for
///   the synthetic positives. With the mel held byte-identical between
///   classes it still scores AUC 1.0000. On realistic acc+gyro it pins to
///   ~0.54, separates screaming from calm by 0.0048, and labels 97.5% of
///   *calm* windows "panic".
/// * `k_confinement_decorrelated` uses the same temperature-contaminated
///   slice. On realistic input it outputs ~0.019 and never fires at any
///   light value; `AUC(phone-real IMU vs training-slice IMU)` is **0.0063**
///   — near-perfect separation, inverted.
/// * `i_vehicle_crash` is well designed but its int8 output has collapsed to
///   a single quantization step (separation 0.0039 against an output scale
///   of 0.00390625), and it was trained on UCI-HAR in **g** while
///   `vehicle_crash_pipeline.dart` feeds `sensors_plus` **m/s²** — 8x
///   larger, saturating 16.7% of every window. In app units: AUC 0.5000.
///
/// Each costs a continuous mel + IMU inference and none can clear
/// [InferenceResult.confidenceThreshold], so leaving them running spends
/// battery to produce labels that are noise. Disabling is a pure win, and it
/// removes the risk that a future threshold change turns that 97.5%-false
/// `panic` label into submitted `crowd_panic` danger events.
///
/// The detectors, pipelines, tests and submission wiring are all left in
/// place: flip this to `false` once a retrained asset lands. Full evidence
/// and the retraining requirements are in
/// `assets/models/DAY328_DUAL_INPUT_DEAD_ON_PHONE.md`; reproduce with
/// `tools/day328_dual_input_probe/`.
const bool kDualInputModelsDisabled = true;

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

/// Day 346 — `m_glass_breaking_v3`, shipped after being measured at AUC
/// 0.7819 on 265 real FSD50K positives (its recorded 1.0 came from 13 and
/// did not survive). Its curve is the best in this project: recall 0.826 at
/// precision 0.830. See assets/models/DAY346B_GUNSHOT_GLASS_CROSS_CORPUS.md.
/// Day 352 — `h_aggressive_v4_38`, Phase B finally done.
///
/// v1 sat catalogued-but-unwired since Day 90 on the strength of AUC 0.8442,
/// which Day 347 showed was RAVDESS-only: on natural speech it reads
/// **0.4780 — chance**. v4 is retrained across five corpora and analysed at
/// the 2048/512 window Dart can now produce, scoring **0.6415 on natural
/// speech** (CI [0.6171, 0.6656]).
///
/// Wiring was blocked on a feature pipeline nobody had built. It turned out
/// to need a window parameter rather than a pyin port — see
/// [AggressiveSpeechFeatures] and DAY352_H_AGGRESSIVE_V4_WIRED.md.
final aggressiveSpeechDetectorProvider =
    FutureProvider<AggressiveSpeechDetector?>((ref) async {
  final detector = await AggressiveSpeechDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

final glassBreakDetectorProvider =
    FutureProvider<GlassBreakDetector?>((ref) async {
  final detector = await GlassBreakDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Live glass-break pipeline: native 16,000 Hz PCM stream -> 2 s mel image
/// -> m_glass_breaking_v3. Null while the detector is loading or failed to
/// load, so a device without the asset simply never fires glass detections.
final glassBreakPipelineProvider = Provider<GlassBreakPipeline?>((ref) {
  final detector = ref.watch(glassBreakDetectorProvider).valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = GlassBreakPipeline(
    detector: detector,
    windows: audio.pcmStream,
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
  // Day 328 — AUC 0.5000 in the m/s² units the pipeline actually feeds. See [kDualInputModelsDisabled].
  if (kDualInputModelsDisabled) return null;

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
  // Day 328 — outputs ~0.019 and never fires at any light value. See [kDualInputModelsDisabled].
  if (kDualInputModelsDisabled) return null;

  final detectorAsync = ref.watch(kConfinementDetectorProvider);
  final detector = detectorAsync.valueOrNull;
  if (detector == null) return null;

  final pipeline = KConfinementFusionPipeline(detector: detector);
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

/// Day 341 — the stream that finally drives [VocalStressDetector].
///
/// Day 337 wired the detector to a provider; nothing fed it. This starts the
/// pipeline on the same PCM stream scream and gunshot already use, so all
/// three analyse the same windows.
///
/// Its results are deliberately **not** subscribed by
/// [liveDetectionEventSubmitterProvider]. Vocal stress is a contributing
/// signal (~0.80 AUC in English, ~0.63 in Mandarin — see
/// `assets/models/DAY338_SPLIT_SENSITIVITY.md`), and submitting it as a
/// standalone detection event would put a weak signal straight into the
/// user's feed. Feeding a fusion is what it is for; `latestResult` is how a
/// fusion reads it.
final vocalStressPipelineProvider =
    Provider<VocalStressPipeline?>((ref) {
  final detector = ref.watch(vocalStressDetectorProvider).valueOrNull;
  if (detector == null) return null;

  final audio = ref.watch(audioChannelProvider);
  final pipeline = VocalStressPipeline(
    detector: detector,
    windows: audio.pcmStream,
  );
  pipeline.start();
  ref.onDispose(pipeline.dispose);
  return pipeline;
});

/// Day 341 — the coordinator that decides when to spend a camera burst.
///
/// Null until [violenceBurstDetectorProvider] resolves, since a coordinator
/// with nothing to infer with would count triggers it cannot act on.
final violenceBurstCoordinatorProvider =
    Provider<ViolenceBurstCoordinator?>((ref) {
  final detector = ref.watch(violenceBurstDetectorProvider).valueOrNull;
  if (detector == null) return null;
  return ViolenceBurstCoordinator.from(
    camera: CameraFrameService(),
    detector: detector,
  );
});

/// Day 337 — vocal stress, wired for the first time.
///
/// `VocalStressDetector` has existed and been gate-verified since Day 325,
/// but **nothing ever constructed it** — `model_registry.dart` loaded the
/// asset at startup and its comment claimed "WIRED", while no provider,
/// pipeline or caller in `lib/` instantiated the class. This provider is
/// what actually makes it run.
///
/// The variant is chosen by device locale, not swapped. Prosodic stress does
/// not transfer across languages — English->Mandarin measures **0.4537** —
/// so shipping only one model would halve the app's coverage rather than
/// upgrade it:
///
/// * `zh*` -> `m5_vocal_stress_v2`, Mandarin, 28 features, 0.7988
/// * everything else -> `m4_vocal_stress_v3_38`, English, 38 features,
///   **0.8321** (against 0.6949 for the same English audio through the
///   28-feature path)
///
/// English is the fallback for an unknown locale because it is both the
/// stronger model and the more likely match.
final vocalStressDetectorProvider =
    FutureProvider<VocalStressDetector?>((ref) async {
  final variant = VocalStressDetector.variantForLocale(
    PlatformDispatcher.instance.locale.languageCode,
  );
  final detector = await VocalStressDetector.tryLoadVariant(variant);
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
});

/// Day 334 — `m3_violence_temporal` + its MobileNetV3Small encoder.
///
/// Deliberately **only loads** the detector. There is no pipeline provider
/// beside it, unlike scream/motion, because a burst is 16 sequential
/// `takePicture()` calls plus 16 encoder passes — far too expensive to run
/// on a timer. This is an on-demand check for when something else has
/// already raised suspicion; the caller drives it with
/// `CameraFrameService.captureBurst()` then
/// [ViolenceBurstDetector.inferBurst].
///
/// Measured end-to-end on the shipped assets against real held-out val
/// clips, with training-matched frame sampling: **AUC 0.9176**, separation
/// +0.5293, and at the 0.5 midpoint 49/70 on Fight against 9/70 on
/// NonFight. The head alone reproduces 0.9126 on the training-time cached
/// features. See `assets/models/DAY334_M3_BURST_WIRING.md`.
final violenceBurstDetectorProvider =
    FutureProvider<ViolenceBurstDetector?>((ref) async {
  final detector = await ViolenceBurstDetector.tryLoad();
  if (detector != null) ref.onDispose(detector.dispose);
  return detector;
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
