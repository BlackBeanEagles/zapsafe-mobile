import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 315 — m3_ucf_crime_retrain_v3, the real UCF-Crime-trained scene
/// classifier, wired in to replace the old scene_analyzer_v1 placeholder
/// (trained on Intel Image Classification + Places365 — generic scene
/// photography with no real safe/unsafe label of any kind).
///
/// Real provenance (see `assets/models/m3_scene_analyzer_v3_report.json`,
/// copied verbatim from the real Kaggle training run's own output —
/// `kaggle_notebooks/day293_m3_iteration3/day293_m3_ucf_crime_v3.py`):
/// trained on `odins0n/ucf-crime-dataset` (real surveillance-camera
/// footage, `NormalVideos` vs 13 real crime-anomaly categories — found via
/// a real Kaggle catalog search, `assets/models/DAY288_KAGGLE_SEARCH_
/// BLOCKED4.md`), a materially better label match than the old model's
/// generic scene photography. Backbone: MobileNetV3Small,
/// `include_preprocessing=True`, fine-tuned (15 unfrozen layers).
///
/// **Real accuracy, disclosed plainly — this is a mediocre, not a
/// strong, detector:** 3-class test accuracy 0.5944 (chance is 0.333),
/// safe_f1 0.72, neutral_f1 0.34, risky_f1 0.53, risky_recall 0.50 (it
/// misses about half of real "risky" test frames). This was the best of
/// 6 real training iterations tried (Days 289/291/293/301/305/308 —
/// iteration 3, this one, is the actual best; later iterations 4-6 tried
/// more data/a bigger backbone and did NOT beat it — see
/// `assets/models/DAY301_M3_ITERATION4.md` and
/// `assets/models/DAY308_M3_BALANCED_SAMPLING.md` for what was tried and
/// why it didn't help). Real, better-labeled data than before; still not
/// a model to gate a safety decision on alone — exactly why DCS fusion
/// (M9) combines it with M1/M2 rather than acting on M3 in isolation.
///
/// Input `[1, 224, 224, 3]` float32 — RGB, row-major, pixel values scaled
/// to **`[0.0, 1.0]`** (`pixel / 255.0`, confirmed from the training
/// script's own dataset pipeline — `include_preprocessing=True` on the
/// MobileNetV3 base normally expects raw `[0, 255]` internally, but this
/// model was actually trained end-to-end on `/255.0`-scaled input, so its
/// learned weights are self-consistent with THAT range; feeding raw
/// `[0, 255]` here would be real, silent, high-confidence-looking
/// misinference, the same class of bug this codebase's own
/// `MotionDetectorV2` docs warn about for M2's normalisation constants).
/// Output `[1, 3]` float32 — already softmax (`Dense(3, activation=
/// 'softmax')` is the model's real final layer, confirmed from the
/// training script), class order `[safe, neutral, risky]`.
///
/// **Day 316 update**: the camera-capture gap this class's doc used to
/// describe as unstarted is now closed — see
/// `lib/data/services/camera_frame_service.dart` (real capture +
/// preprocess) and `lib/data/services/scene_capture_scheduler.dart` (the
/// real AppState-driven cadence loop that calls this class with real
/// frames). [SceneFeatures] (the older 8-float heuristic input) is
/// untouched and still synthetic-preset-only — it belongs to
/// [HeuristicSceneDetector], a different code path entirely, not this
/// class.
class SceneDetectorV2 implements Interpreter {
  static const int kImgSize = 224;
  static const int kChannels = 3;
  static const int kInputFloats = kImgSize * kImgSize * kChannels; // 150,528

  final tfl.Interpreter _interpreter;

  @override
  final String modelLabel;

  SceneDetectorV2._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
  }) : _interpreter = interpreter;

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['safe', 'neutral', 'risky'];

  static Future<SceneDetectorV2?> tryLoad({
    String assetPath = 'assets/models/scene_analyzer_v1.tflite',
    String modelLabel = 'm3_ucf_crime_retrain_v3',
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inShape = interpreter.getInputTensor(0).shape;
      const wantIn = [1, kImgSize, kImgSize, kChannels];
      if (!listEquals(inShape, wantIn)) {
        throw StateError('input shape $inShape, expected $wantIn');
      }
      final outShape = interpreter.getOutputTensor(0).shape;
      const wantOut = [1, 3];
      if (!listEquals(outShape, wantOut)) {
        throw StateError('output shape $outShape, expected $wantOut');
      }
      return SceneDetectorV2._(interpreter: interpreter, modelLabel: modelLabel);
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[SceneDetectorV2] tryLoad failed for $assetPath → $e');
      }
      return null;
    }
  }

  /// Packs a raw `[224][224][3]` RGB frame (each channel `0-255`) into the
  /// `[0.0, 1.0]`-scaled float32 layout this model actually expects. See
  /// the class doc for why `/255.0`, not raw `0-255`, is the real
  /// requirement here despite `include_preprocessing=True` on the base.
  ///
  /// [rgbBytes] must be exactly `224 * 224 * 3` bytes, row-major, RGB
  /// (not BGR/RGBA) — the same layout `tf.io.decode_png(..., channels: 3)`
  /// produces, which is what the model was trained on.
  static Float32List normalise(List<int> rgbBytes) {
    if (rgbBytes.length != kInputFloats) {
      throw ArgumentError(
        'SceneDetectorV2 needs exactly $kInputFloats bytes '
        '($kImgSize x $kImgSize x $kChannels RGB), got ${rgbBytes.length}',
      );
    }
    final out = Float32List(kInputFloats);
    for (var i = 0; i < kInputFloats; i++) {
      out[i] = rgbBytes[i] / 255.0;
    }
    return out;
  }

  /// Convenience: normalise a raw RGB frame and run inference.
  Future<InferenceResult> inferRaw(
    List<int> rgbBytes, {
    required int timestampMs,
  }) =>
      infer(normalise(rgbBytes), timestampMs: timestampMs);

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != kInputFloats) {
      throw ArgumentError(
        'SceneDetectorV2 expects $kInputFloats floats '
        '($kImgSize x $kImgSize x $kChannels), got ${features.length}',
      );
    }
    final t0 = DateTime.now();

    final input = features.reshape([1, kImgSize, kImgSize, kChannels]);
    final output = [Float32List(3)];
    _interpreter.run(input, output);

    // Already softmax (Dense(3, activation='softmax') is the model's real
    // final layer) — no manual softmax needed here.
    final scores = output[0];
    final classScores = {
      'safe': scores[0].toDouble(),
      'neutral': scores[1].toDouble(),
      'risky': scores[2].toDouble(),
    };
    final top = classScores.entries.reduce((a, b) => a.value > b.value ? a : b);

    return InferenceResult(
      label: top.key,
      score: top.value,
      classScores: classScores,
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {}
  }
}
