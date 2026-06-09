import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dcs_score.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/motion_features.dart';
import '../../data/models/trigger_event.dart';
import '../../data/services/audio_feature_service.dart';
import '../../data/services/interpreter.dart';
import '../../data/services/model_bundle_service.dart';
import '../../data/services/model_registry.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../data/services/tflite_interpreter.dart';
import '../../ml/inference/dcs_inference_engine.dart';
import '../../ml/inference/dcs_score_watcher.dart';
import '../../ml/inference/isolated_dcs_runner.dart';
import 'imu_providers.dart';
import 'platform_channel_providers.dart';

/// Day 29 — the synchronous [Interpreter] in force right now.
///
/// Defaults to [EnergyStubInterpreter]. The Day 31 [activeInterpreterProvider]
/// FutureProvider attempts to upgrade this to a real TFLite interpreter on
/// app start — when the upgrade resolves, it overrides the same id.
final interpreterProvider = Provider<Interpreter>((ref) {
  final svc = EnergyStubInterpreter();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Day 31 — pluggable real-model loader.
///
/// Attempts `TfliteInterpreter.tryLoad()` against the scream classifier asset.
/// If it succeeds (real `.tflite` shipped), returns it; otherwise returns
/// null so the screen can keep using the stub provider. Currently a 1 KB
/// placeholder ships in `assets/models/scream_classifier_v1.tflite`, so
/// today this provider resolves to null on every device — by design.
///
/// When backend Month 3 drops the real ~1.2 MB binary into the same asset
/// path, the next app launch will resolve a real interpreter here with
/// no code change required.
final realInterpreterProvider =
    FutureProvider<Interpreter?>((ref) async {
  // Match the Day 27 feature layout: 13 MFCC + ZCR + spectral centroid = 15.
  return TfliteInterpreter.tryLoad(
    assetPath: kZapsafeModels.first.assetPath,
    modelLabel: 'scream_classifier_v1 · tflite',
    expectedInputSize: 15,
    classLabels: const ['normal', 'shout', 'scream'],
  );
});

/// Day 31 — singleton ModelRegistry.
final modelRegistryProvider =
    Provider<ModelRegistry>((_) => ModelRegistry());

/// All model assets + their statuses on disk. Day 31 screen reads this.
final modelAssetStatusesProvider =
    FutureProvider<List<ModelAssetStatus>>((ref) async {
  return ref.watch(modelRegistryProvider).loadAll();
});

/// Day 45 — singleton ModelBundleService.
final modelBundleServiceProvider =
    Provider<ModelBundleService>((_) => ModelBundleService());

/// Day 45 — loads all detection models and returns the active engine.
///
/// Reads [PhoneCapabilityTier] from cache so the routing decision (AI vs
/// heuristic) is based on this phone's measured inference speed.
final detectionEngineProvider =
    FutureProvider<ModelBundleResult>((ref) async {
  final svc  = ref.watch(modelBundleServiceProvider);
  final tier = await PhoneCapabilityDetector.cachedTier() ??
      PhoneCapabilityTier.low;
  final result = await svc.load(tier: tier);
  ref.onDispose(result.engine.dispose);
  return result;
});

/// Day 32 — composite DCS inference engine. Loads all 4 interpreters in
/// parallel; missing or placeholder models fall back to stubs slot-by-slot.
final dcsEngineProvider = FutureProvider<DCSInferenceEngine>((ref) async {
  final engine = await DCSInferenceEngine.create();
  ref.onDispose(engine.dispose);
  return engine;
});

// ─── Day 33 · DCS stream + score watcher ────────────────────────────────────

/// Singleton score watcher. Mutates internal vote-counter state, so one
/// instance per process — UI and the auto-trigger pipeline share it.
final dcsScoreWatcherProvider = Provider<DCSScoreWatcher>((ref) {
  return DCSScoreWatcher();
});

/// Day 33 — streams a [DCSScore] per voiced audio window, by feeding the
/// Day 27 feature stream into the Day 32 inference engine. Motion is
/// synthesised as `MotionFeatures.atRest` until the real IMU service
/// lands (Week 8 / Day 36+).
///
/// Returns a broadcast stream so the score-watcher and any debug UI can
/// subscribe simultaneously.
final dcsStreamProvider = StreamProvider<DCSScore>((ref) async* {
  final engineAsync = ref.watch(dcsEngineProvider);
  final engine = engineAsync.valueOrNull;
  if (engine == null) return;

  // Day 36 — read the most recent IMU snapshot if the service has one;
  // otherwise fall back to the at-rest default. This keeps the audio
  // path unblocked even when sensors aren't subscribed yet.
  final imu = ref.watch(imuServiceProvider);

  final featureStream = ref.watch(audioChannelProvider).featureStream;
  await for (final audio in featureStream) {
    yield await engine.infer(
      audio: audio,
      motion: imu.latestFeatures ??
          MotionFeatures.atRest(timestampMs: audio.timestampMs),
    );
  }
});

// ─── Day 34 · isolated runner ───────────────────────────────────────────────

final isolatedDcsRunnerProvider =
    Provider<IsolatedDcsRunner>((_) => IsolatedDcsRunner());

/// Day 33 — stream of trigger events from the score watcher.
///
/// Subscribed to by the Day 33 screen and, eventually, by the auto-SOS
/// dispatch path in `AppStateNotifier` (Day 39).
final triggerEventStreamProvider =
    StreamProvider<TriggerEvent>((ref) async* {
  final watcher = ref.watch(dcsScoreWatcherProvider);
  ref.watch(dcsStreamProvider); // keep subscription alive (side-effect only)

  // We can't pipe an AsyncValue directly through Stream — pull values out
  // explicitly and re-run the watcher on each new DCSScore.
  await for (final score in _asScoreStream(ref)) {
    final event = watcher.observe(score);
    if (event != null) yield event;
  }
});

/// Internal helper — re-emits successful [dcsStreamProvider] values as a
/// plain `Stream<DCSScore>`.
Stream<DCSScore> _asScoreStream(Ref ref) async* {
  final controller = StreamController<DCSScore>.broadcast();
  final sub = ref.listen<AsyncValue<DCSScore>>(dcsStreamProvider, (_, next) {
    next.whenData((score) {
      if (!controller.isClosed) controller.add(score);
    });
  });
  ref.onDispose(() {
    sub.close();
    controller.close();
  });
  yield* controller.stream;
}

/// Singleton [AudioFeatureService] bound to the platform feature stream
/// and the [interpreterProvider]. Resolves lazily.
final audioFeatureServiceProvider = Provider<AudioFeatureService>((ref) {
  final interpreter = ref.watch(interpreterProvider);
  final stream = ref.watch(audioChannelProvider).featureStream;
  final svc = AudioFeatureService(
    interpreter: interpreter,
    featureStream: stream,
  );
  ref.onDispose(svc.dispose);
  return svc;
});

/// Broadcast stream of inference results. Day 29 screen watches this for
/// per-result UI updates.
final inferenceResultStreamProvider =
    StreamProvider<InferenceResult>((ref) {
  return ref.watch(audioFeatureServiceProvider).results;
});

/// Day 52 — runs the [PhoneCapabilityDetector] probe (or returns cached result).
/// Re-run by calling [ref.invalidate] on this provider after
/// [PhoneCapabilityDetector.detect] with `forceReprobe: true`.
final phoneCapabilityProvider =
    FutureProvider<CapabilityProbeResult>((ref) async {
  return PhoneCapabilityDetector().detect();
});
