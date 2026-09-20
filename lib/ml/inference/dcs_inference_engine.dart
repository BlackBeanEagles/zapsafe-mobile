import 'package:flutter/foundation.dart';

import '../../data/models/dcs_score.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/interpreter.dart';
import '../../data/services/model_registry.dart';
import '../../data/services/scream_detector_v2.dart';
import '../../data/services/tflite_interpreter.dart';
import '../../native/audio_features.dart';

/// Day 32 — composite engine that runs all four ZapSafe interpreters in
/// one pass.
///
/// Architecture mirrors the Day 31 fallback contract: each slot is loaded
/// independently via [TfliteInterpreter.tryLoad], and any slot that fails
/// (placeholder bytes today, missing asset, mis-sized input tensor) drops
/// to its stub equivalent. The composite is always usable — there's never
/// a partial-failure mode where the pipeline halts.
///
/// Slot configuration (matches `kZapsafeModels`):
///   • M1 scream:  expectedInputSize = 15 (Day 27 feature vector)
///   • M2 motion:  expectedInputSize = 6  (Day 32 `MotionFeatures`)
///   • M3 scene:   expectedInputSize = 8  (placeholder, real Month 4–5)
///   • M9 fusion:  expectedInputSize = 3  (the three per-model scores)
///
/// Fusion math: today the fusion stub is a [LinearStubInterpreter] with
/// weights `[0.5, 0.3, 0.2]` (audio · motion · scene). When the real
/// XGBoost model lands (backend Month 7–8) the weights become irrelevant —
/// `TfliteInterpreter.tryLoad` succeeds and routes through native code.
class DCSInferenceEngine {
  final Interpreter scream;
  final Interpreter motion;
  final Interpreter scene;
  final Interpreter fusion;

  /// True when the corresponding slot loaded a real `.tflite` model rather
  /// than the stub. Lets the UI render a per-slot REAL / STUB chip.
  final bool screamIsReal;
  final bool motionIsReal;
  final bool sceneIsReal;
  final bool fusionIsReal;

  /// Tracks counts since construction — useful for the Day 32 screen
  /// "stress" mode.
  int _runs = 0;
  int get runs => _runs;

  DCSInferenceEngine._({
    required this.scream,
    required this.motion,
    required this.scene,
    required this.fusion,
    required this.screamIsReal,
    required this.motionIsReal,
    required this.sceneIsReal,
    required this.fusionIsReal,
  });

  /// Day 34 — build an engine from caller-supplied interpreters. Used by
  /// the worker isolate to construct a fresh stub-only engine without
  /// re-running the asset-bundle probe (which works inside an isolate
  /// but adds startup cost we don't need for stubs).
  ///
  /// Every slot is treated as a stub since real-TFLite interpreters
  /// can't cross isolate boundaries — see `IsolatedDcsRunner`.
  factory DCSInferenceEngine.fromInterpreters({
    required Interpreter scream,
    required Interpreter motion,
    required Interpreter scene,
    required Interpreter fusion,
  }) {
    return DCSInferenceEngine._(
      scream: scream,
      motion: motion,
      scene: scene,
      fusion: fusion,
      screamIsReal: false,
      motionIsReal: false,
      sceneIsReal:  false,
      fusionIsReal: false,
    );
  }

  /// Loads all four interpreters in parallel. Always returns an engine —
  /// failed slots fall back to stubs so the rest of the app can compose
  /// against this safely.
  static Future<DCSInferenceEngine> create() async {
    // Build the per-slot stubs eagerly — used as fallbacks.
    final screamStub = EnergyStubInterpreter();
    const motionStub = FixedStubInterpreter(
      modelLabel: 'stub-motion',
      expectedInputSize: 6,
      classLabels: ['normal', 'unusual', 'fall'],
      label: 'normal',
      score: 0.15,
    );
    const sceneStub = FixedStubInterpreter(
      modelLabel: 'stub-scene',
      expectedInputSize: 8,
      classLabels: ['indoor', 'outdoor', 'transit'],
      label: 'indoor',
      score: 0.25,
    );
    final fusionStub = LinearStubInterpreter(
      modelLabel: 'stub-fusion',
      weights: const [0.5, 0.3, 0.2],
      classLabels: const ['safe', 'danger'],
    );

    // Attempt real loads in parallel.
    final results = await Future.wait<Interpreter?>([
      // Day 257: m1_scream_v2 takes a [1,128,131,1] mel spectrogram, not the
      // 15-float MFCC vector. See ScreamDetectorV2.
      ScreamDetectorV2.tryLoad(assetPath: kZapsafeModels[0].assetPath),
      TfliteInterpreter.tryLoad(
        assetPath: kZapsafeModels[1].assetPath,
        modelLabel: 'motion_fall_v2 · tflite',
        expectedInputSize: 6,
        classLabels: const ['normal', 'unusual', 'fall'],
      ),
      TfliteInterpreter.tryLoad(
        assetPath: kZapsafeModels[2].assetPath,
        modelLabel: 'scene_analyzer_v1 · tflite',
        expectedInputSize: 8,
        classLabels: const ['indoor', 'outdoor', 'transit'],
      ),
      TfliteInterpreter.tryLoad(
        assetPath: kZapsafeModels[3].assetPath,
        modelLabel: 'dcs_fusion_v1 · tflite',
        expectedInputSize: 3,
        classLabels: const ['safe', 'danger'],
      ),
    ]);

    final scream = results[0] ?? screamStub;
    final motion = results[1] ?? motionStub;
    final scene  = results[2] ?? sceneStub;
    final fusion = results[3] ?? fusionStub;

    return DCSInferenceEngine._(
      scream: scream,
      motion: motion,
      scene: scene,
      fusion: fusion,
      screamIsReal: results[0] != null,
      motionIsReal: results[1] != null,
      sceneIsReal:  results[2] != null,
      fusionIsReal: results[3] != null,
    );
  }

  /// Day 335 — how old an M3 burst may be and still count toward the fused
  /// score.
  ///
  /// The scene slot is unlike the other two. Audio and motion produce a
  /// result every window; an M3 burst is 16 `takePicture()` calls plus 16
  /// encoder passes, so it runs rarely and on demand. Without a bound, one
  /// violence reading would keep inflating the DCS score for as long as the
  /// app stayed up, and a stale burst is exactly the kind of evidence that
  /// should not be escalating on.
  ///
  /// 30 s is chosen to outlive the burst itself (~2.4 s of capture plus
  /// inference) by enough to cover the audio windows immediately around it,
  /// without letting a reading persist into an unrelated situation.
  ///
  /// Enforced **here** rather than at the call site on purpose: a caller
  /// forgetting the check would silently reintroduce the problem, and this
  /// engine drives SOS escalation.
  static const int kSceneMaxAgeMs = 30000;

  /// Runs one full DCS pass. The audio frame is required; motion + scene
  /// are optional — missing inputs fall back to "at rest" defaults so the
  /// fusion model still gets a 3-element vector.
  /// Runs one full DCS pass.
  ///
  /// Day 327 — [motionResultOverride] exists because this engine's own
  /// motion slot never worked. It declares `expectedInputSize: 6` and calls
  /// `infer` with a 6-float [MotionFeatures] snapshot, but every real motion
  /// model has been windowed: `motion_anomaly_v1` was `[1,100,6]` = 600
  /// floats and `motion_fall_v2` is `[1,100,3]` = 300. `TfliteInterpreter
  /// .tryLoad` returns null on that mismatch and the engine substitutes
  /// [FixedStubInterpreter], whose `classScores` is `{label: score}` —
  /// `{'normal': 0.15}`. [_dangerScore] then looks for `fall`/`unusual`,
  /// finds neither, and returns **0**.
  ///
  /// So the fused score was `0.5 × scream + 0.3 × 0 + 0.2 × 0`, capped at
  /// **0.50**, while [DCSScoreWatcher.alertThreshold] is **0.75**. The DCS
  /// escalation path was mathematically unreachable — `onDCSThresholdExceeded`
  /// could never fire. See `assets/models/DAY326_DCS_FUSION_NEVER_FUSED.md`.
  ///
  /// Passing the real result from [MotionAudioPipeline] — which already runs
  /// the windowed model on the same sensor stream — fixes that without a
  /// second inference. With motion contributing, the reachable maximum
  /// becomes `0.5 + 0.3 = 0.80`, so the 0.75 alert threshold now requires
  /// **two independent modalities to agree**, which is what a fusion is for.
  Future<DCSScore> infer({
    required AudioFeatures audio,
    MotionFeatures? motion,
    Float32List? sceneFeatures,
    InferenceResult? motionResultOverride,
    InferenceResult? sceneResultOverride,
  }) async {
    _runs++;
    final timestampMs = audio.timestampMs;

    // 1. Audio (always present)
    final audioResult = await scream.infer(
      audio.toFloat32Tensor(),
      timestampMs: timestampMs,
    );

    // 2. Motion (synthesise "at rest" if absent so the fusion vector is
    //    always 3-wide)
    // Prefer a real windowed result when the caller has one. Only fall
    // back to this engine's own 6-float slot when it does not, which keeps
    // existing callers and the Month-2 integration runner working.
    final InferenceResult motionResult;
    if (motionResultOverride != null) {
      motionResult = motionResultOverride;
    } else {
      final motionTensor =
          (motion ?? MotionFeatures.atRest(timestampMs: timestampMs))
              .toFloat32Tensor();
      motionResult = await this.motion.infer(
            motionTensor,
            timestampMs: timestampMs,
          );
    }

    // 3. Scene — Day 335 wires `m3_violence_temporal` in here.
    //
    // Prefer a real burst result when the caller has a FRESH one. The
    // engine's own scene slot declares `expectedInputSize: 8` while
    // `scene_analyzer_v1` wants 150,528, so it has always stubbed out and
    // contributed exactly 0; M3 is the first thing this slot has ever
    // actually carried.
    //
    // A burst older than [kSceneMaxAgeMs] is discarded rather than used,
    // and the stub's 0 stands in — see that constant for why.
    final InferenceResult sceneResult;
    if (sceneResultOverride != null &&
        (timestampMs - sceneResultOverride.timestampMs).abs() <=
            kSceneMaxAgeMs) {
      sceneResult = sceneResultOverride;
    } else {
      if (sceneResultOverride != null && kDebugMode) {
        debugPrint('[DCSInferenceEngine] scene burst discarded: '
            '${(timestampMs - sceneResultOverride.timestampMs).abs()}ms old '
            '> ${kSceneMaxAgeMs}ms');
      }
      final sceneTensor = sceneFeatures ?? Float32List(8);
      sceneResult = await scene.infer(
        sceneTensor,
        timestampMs: timestampMs,
      );
    }

    // 4. Fusion takes per-modality DANGER probabilities (not top-class
    //    confidences). `audioResult.score` for a confident-normal reading
    //    is ~0.5, identical in magnitude to a confident-scream — useless
    //    as a fusion input. We instead extract the scream / fall /
    //    unusual class probabilities explicitly. When the real fusion
    //    .tflite ships, it'll be trained on this same 3-scalar shape.
    final fusionInput = Float32List(3)
      ..[0] = _dangerScore(audioResult, danger: const ['scream', 'shout'])
      ..[1] = _dangerScore(motionResult, danger: const ['fall', 'unusual'])
      // Day 335: 'violence' replaces 'outdoor'. `scene_analyzer_v1`'s
      // labels are indoor/outdoor/transit, none of which is a danger class
      // — being outdoors is not evidence of danger, and treating it as such
      // would have let a confident 'outdoor' reading push the fused score
      // up for no reason. That slot stubbed to 0 in practice, so nothing
      // regresses by dropping it; M3's 'violence' is the first real danger
      // probability this input has ever carried.
      ..[2] = _dangerScore(sceneResult, danger: const ['violence']);
    final fusionResult = await fusion.infer(
      fusionInput,
      timestampMs: timestampMs,
    );

    return DCSScore(
      timestampMs: timestampMs,
      audio: audioResult,
      motion: motionResult,
      scene: sceneResult,
      fusion: fusionResult,
    );
  }

  /// Pick the highest probability across the supplied "danger" labels.
  /// Falls back to 0 when none of the danger classes are present (stub
  /// case) — the fusion model treats that slot as neutral.
  ///
  /// Logs in debug mode when no danger label is found, so label mismatches
  /// surface immediately after swapping in a real model.
  double _dangerScore(InferenceResult r,
      {required List<String> danger}) {
    double best = 0;
    var found = false;
    for (final label in danger) {
      final v = r.classScores[label];
      if (v != null) {
        found = true;
        if (v > best) best = v;
      }
    }
    if (!found && kDebugMode) {
      debugPrint('[DCSInferenceEngine] _dangerScore: none of $danger '
          'found in classScores ${r.classScores.keys.toList()} '
          '(model=${r.label}) — returning 0');
    }
    return best;
  }

  /// Returns a snapshot of which slots are real vs stub. Day 32 screen
  /// renders this as a 4-row chip table.
  List<({String slot, String label, bool real})> get slotStatuses => [
        (slot: 'M1 scream', label: scream.modelLabel, real: screamIsReal),
        (slot: 'M2 motion', label: motion.modelLabel, real: motionIsReal),
        (slot: 'M3 scene',  label: scene.modelLabel,  real: sceneIsReal),
        (slot: 'M9 fusion', label: fusion.modelLabel, real: fusionIsReal),
      ];

  /// Disposes every slot. Safe to call multiple times — each interpreter's
  /// dispose is idempotent.
  Future<void> dispose() async {
    await Future.wait([
      scream.dispose(),
      motion.dispose(),
      scene.dispose(),
      fusion.dispose(),
    ]);
    if (kDebugMode) debugPrint('[DCSInferenceEngine] disposed');
  }
}
