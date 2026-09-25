import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'aggressive_speech_features.dart';
import 'interpreter.dart';

/// Day 352 — `h_aggressive_v5_38`, finally wired. Phase B, five days late
/// and one wrong estimate later.
///
/// ## History, because the numbers on record are misleading
///
/// This slot sat as "catalogue + asset only" from Day 90. Day 318 measured
/// the original asset at **AUC 0.8442 on RAVDESS** and concluded "the gap is
/// wiring, not the model", which was the reasonable read at the time. Day
/// 347 measured the same asset on natural speech:
///
///     RAVDESS (24 actors, booth, 2 sentences)   0.8442
///     MELD (natural TV dialogue)                0.4780   <- CHANCE
///
/// Precision equalled the base rate at every threshold. The control ruled
/// out "MELD is just hard": models trained on the same features reach 0.683
/// there. It had learned acted studio emotion, the same failure
/// `scream_classifier_v1` documented about itself.
///
/// ## What ships here
///
///     v1   librosa.pyin 2048/512, RAVDESS only   acted 0.8442  natural 0.4780
///     v2b  librosa.pyin 2048/512, 5 corpora      acted 0.8096  natural 0.6661
///     v3   plain YIN     512/256, 5 corpora      acted 0.7063  natural 0.5918
///     v4   plain YIN    2048/512, 5 corpora      acted 0.7464  natural 0.6415
///     v5   same data, same features, new RECIPE   natural 0.6708
///
/// **v5** — identical corpora (CREMA-D + TESS + RAVDESS + SAVEE + MELD,
/// 17,548 clips) and identical 38-dim features. Only the training recipe
/// changed, and the gain came from an unexpected place:
///
///     v4 head     + corpus_weights   0.6513      + class_weight   0.6649
///     regularised + corpus_weights   0.6339      + class_weight   0.6736
///
/// The WEIGHTING dominated, not the architecture. `corpus_weights` scaled
/// every corpus to equal influence, which pushed SAVEE's 360 rows and
/// RAVDESS's 1,056 to the same weight as MELD's 7,961 — and three of the
/// four upweighted corpora are ACTED studio recordings, while the
/// deployment domain is conversational. There is also an interaction:
/// regularisation HURTS under corpus_weights and helps under class_weight,
/// which is why a first attempt that changed only the head came out flat at
/// 0.6410, identical to v4.
///
/// Measured through the shipped .tflite by the gate: **0.671 vs v4's
/// 0.641**. Five seeds spanned 0.6702-0.6761 and the MEDIAN seed was
/// exported, not the best. See DAY358_H_AGGRESSIVE_V5_RECIPE_FIX.md.
///
/// v2b is 0.024 better on natural speech and is **not** what ships, because
/// it needs `librosa.pyin`'s HMM/Viterbi in Dart. Day 351 concluded that
/// port was unavoidable; Day 352 showed that was too strong — moving only
/// the analysis window recovers 68% of the gap. The remaining 0.024 matches
/// the 0.011 that m4 independently measured for the HMM, and is not worth
/// days of native work for a detector at this stage.
///
/// ## The threshold
///
/// **0.23** as of v5 — see [kDefaultThreshold] for why the number moved and
/// what the curve looks like. This is a DCS fusion contributor, not an alert
/// trigger, so recall is preferred over precision. Do not read the old
/// 0.844-era thresholds against it; they were set on a model that reads
/// natural speech at chance, and do not read v4's 0.45 against it either —
/// v5's sigmoid is compressed and the same number means something else.
///
/// ## Features are NOT interchangeable with m4/m5
///
/// [AggressiveSpeechFeatures] analyses at 2048/512;
/// `VocalStressFeatures` at 512/256. Same shape, same slot order, different
/// values — feeding one model the other's vector gives a confident wrong
/// answer. `test/day352_aggressive_speech_features_test.dart` asserts they
/// differ in more than 20 of 38 slots, and pins the Dart path against the
/// Python extractor that trained v4.
class AggressiveSpeechDetector implements Interpreter {
  static const String kAsset = 'assets/models/h_aggressive_v5_38.tflite';
  static const String kNormAsset =
      'assets/models/h_aggressive_v5_38_norm.json';

  /// See the class doc. Fusion contributor, not a trigger.
  /// **0.23**, not 0.45 — the number changed with v5 and had to.
  ///
  /// v5 adds L2 1e-3 and dropout 0.5, which compresses the sigmoid toward
  /// zero. The same numeric threshold therefore means something different:
  /// at 0.45 v5 fires on 15.7% of clips where v4 fired on far more, and at
  /// 0.5 its recall collapses to **0.057** against v4's 0.664. Carrying the
  /// old constant across would have shipped a better-scoring model that
  /// almost never fires — a silent regression an AUC alone cannot show.
  ///
  /// 0.23 reproduces v4's operating point exactly:
  ///
  ///     v4 @ 0.45   recall 0.758   precision 0.280
  ///     v5 @ 0.23   recall 0.758   precision 0.280
  ///
  /// So the upgrade is behaviour-neutral at the operating point while the
  /// ranking improves (AUC 0.671 vs 0.641), which is what benefits any
  /// fusion consuming the raw score rather than the boolean.
  ///
  /// v5 has better precision at every matched recall level measured
  /// (+0.004 to +0.057), so raising this deliberately trades recall for
  /// precision — 0.30 gives recall 0.619 / precision 0.324, and 0.355 gives
  /// 0.50 / 0.368. That is a product decision, not a default.
  /// Full curve: assets/models/DAY358_H_AGGRESSIVE_V5_RECIPE_FIX.md
  static const double kDefaultThreshold = 0.23;

  static const int kInputFloats = AggressiveSpeechFeatures.kFeatureDim;

  AggressiveSpeechDetector._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required Float64List mean,
    required Float64List std,
    AggressiveSpeechFeatures? features,
  })  : _interpreter = interpreter,
        _mean = mean,
        _std = std,
        _features = features ?? AggressiveSpeechFeatures();

  final tfl.Interpreter _interpreter;
  final AggressiveSpeechFeatures _features;
  final Float64List _mean;
  final Float64List _std;
  final double threshold;

  @override
  final String modelLabel;

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['calm', 'aggressive'];

  /// Loads model + norm, returning null on any failure so a device without
  /// them simply never fires.
  ///
  /// The norm is **mandatory and loaded here** rather than left to the
  /// caller. Day 318 measured this family at 0.844 with normalisation and
  /// **0.52 — chance — on raw features**, with its f32 twin collapsing to a
  /// constant 1.0. A missing norm file must therefore fail the load, not
  /// silently produce a working-looking detector.
  static Future<AggressiveSpeechDetector?> tryLoad({
    String assetPath = kAsset,
    String normPath = kNormAsset,
    String modelLabel = 'h_aggressive_v5_38',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      final normRaw = await rootBundle.loadString(normPath);
      final norm = jsonDecode(normRaw) as Map<String, dynamic>;
      final mean = Float64List.fromList(
          (norm['mean'] as List).map((e) => (e as num).toDouble()).toList());
      final std = Float64List.fromList(
          (norm['std'] as List).map((e) => (e as num).toDouble()).toList());
      if (mean.length != kInputFloats || std.length != kInputFloats) {
        throw StateError('norm has ${mean.length}/${std.length} entries, '
            'expected $kInputFloats');
      }

      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inTensor = interpreter.getInputTensor(0);
      final outTensor = interpreter.getOutputTensor(0);
      if (!listEquals(inTensor.shape, const [1, kInputFloats])) {
        throw StateError('input shape ${inTensor.shape}, expected '
            '[1, $kInputFloats]');
      }
      if (outTensor.shape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError('output shape ${outTensor.shape}, expected a scalar');
      }

      return AggressiveSpeechDetector._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        mean: mean,
        std: std,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[AggressiveSpeechDetector] tryLoad failed: $e');
      }
      return null;
    }
  }

  /// Preferred entry point: raw mono PCM at 16 kHz, any length.
  Future<InferenceResult> inferPcm(
    Float64List pcm, {
    required int timestampMs,
  }) {
    final f = _features.compose38(pcm);
    final z = Float32List(kInputFloats);
    for (var i = 0; i < kInputFloats; i++) {
      z[i] = ((f[i] - _mean[i]) / (_std[i] + 1e-8));
    }
    return infer(z, timestampMs: timestampMs);
  }

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != kInputFloats) {
      throw ArgumentError('AggressiveSpeechDetector expects $kInputFloats '
          'standardised floats, got ${features.length}. Use inferPcm() if '
          'you are holding raw audio.');
    }
    final t0 = DateTime.now();
    final input = features.reshape([1, kInputFloats]);
    final output = [Float32List(1)];
    _interpreter.run(input, output);
    final aggressive = output[0][0].toDouble().clamp(0.0, 1.0);

    final isAggressive = aggressive >= threshold;
    return InferenceResult(
      label: isAggressive ? 'aggressive' : 'calm',
      score: isAggressive ? aggressive : 1.0 - aggressive,
      classScores: <String, double>{
        'calm': 1.0 - aggressive,
        'aggressive': aggressive,
      },
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {
      // already closed
    }
  }
}
