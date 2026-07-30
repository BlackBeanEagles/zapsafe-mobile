import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inference_result.dart';
import '../../data/services/detection_event_service.dart';
import '../../data/services/motion_audio_pipeline.dart';
import '../../data/services/motion_detector_v2.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../data/services/scream_audio_pipeline.dart';
import '../../data/services/scream_detector_v2.dart';
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
