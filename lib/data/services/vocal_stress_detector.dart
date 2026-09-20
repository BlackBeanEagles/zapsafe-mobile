import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';
import 'vocal_stress_features.dart';

/// Day 325 — `m5_vocal_stress_v2`, the first M5 that actually works.
///
/// ## Five years of M5 failures, and what was wrong
///
/// Measured on real held-out data, same protocol each time:
///
///     v1 (Day 95)                        AUC 0.5855
///     Day 275 (+TESS/SAVEE/ShEMO)        AUC 0.4862   made it worse
///     Day 324 (ESD English -> Mandarin)  AUC 0.4537   below chance
///     this model (trained ON Mandarin)   AUC 0.7988
///
/// Every earlier attempt trained on English/German/Persian and was scored
/// against an APAC task. **Prosodic stress does not transfer across
/// languages** — the Day 324 run proved it directly by producing an
/// excellent English model (val AUC 0.9807) that scored *below chance* on
/// held-out Mandarin. `zapsafeworking/ZAPSAFE_ML_TRAINING_STRATEGY.md`
/// already separates M4 (Vocal Stress EN) from M5 (Vocal Stress APAC); the
/// fix was to stop expecting one model to cover both, not to add more data.
/// Day 275 had already falsified "more data".
///
/// Trained on 3,400 ESD Mandarin clips across 10 speakers, with **3 speakers
/// held out entirely**. That split matters: the same data scores 0.9984 on a
/// random split, because speaker identity leaks that hard. 0.7988 is the
/// honest number and 0.9984 is the one that would have looked like a triumph.
///
/// ## Operating point
///
/// `kDefaultThreshold` is **0.20**, from the measured curve on held-out
/// speakers:
///
/// | threshold | recall | precision |
/// |---|---|---|
/// | 0.50 | 0.333 | 0.769 |
/// | 0.30 | 0.467 | 0.765 |
/// | **0.20** | **0.527** | **0.766** |
///
/// Precision is flat across the range while recall climbs, so there is no
/// reason to sit high. This model is deliberately *not* wired into the alert
/// path: at 0.53 recall it is a DCS fusion input, not a trigger.
///
/// ## Input: 28 features, not 38
///
/// The training script defines 38, but 10 need `librosa.pyin`, an RMS series,
/// or autocorrelation — none of which exist in Dart. Their value was measured
/// before deciding: all-38 scores 0.7986, these 28 score 0.7988, and the 10
/// alone score 0.5620. They carry nothing, so no pyin implementation was
/// written. See [VocalStressFeatures].
///
/// Features are standardised by the constants in
/// `assets/models/m5_vocal_stress_v2_norm.json`. Feeding raw values does not
/// throw and does not change the shape — Day 318 measured
/// `h_aggressive_speech` dropping from AUC 0.844 to 0.52 that way, and its
/// f32 twin collapsing to a constant 1.0.
/// Which trained vocal-stress model to load.
///
/// Day 337 — prosodic stress does **not** transfer across languages
/// (English->Mandarin measured at 0.4537), so there are two models rather
/// than one, and the right one has to be chosen at load time. Replacing one
/// with the other would silently halve the app's coverage.
enum VocalStressVariant {
  /// `m5_vocal_stress_v2` — Mandarin, 28 features, held-out-speaker AUC
  /// 0.7988 (0.850 on the gate's own fixture).
  mandarin28,

  /// `m4_vocal_stress_en_38` — English, the full 38-vector on plain-YIN
  /// pitch, held-out-speaker AUC **0.8321** against 0.6949 for the same
  /// English data through the 28-feature path. Needs [YinPitch] and
  /// [VocalStressFeatures.extendedFeatures], which is why it could not ship
  /// before Day 333.
  english38,
}

class VocalStressDetector implements Interpreter {
  static const String kAsset = 'assets/models/m5_vocal_stress_v2.tflite';
  static const String kNormAsset =
      'assets/models/m5_vocal_stress_v2_norm.json';

  /// See the class doc — precision is flat, so take the recall.
  static const double kDefaultThreshold = 0.20;

  /// `m4_vocal_stress_en_38` — English, 38 features.
  static const String kAssetEn38 =
      'assets/models/m4_vocal_stress_en_38.tflite';
  static const String kNormAssetEn38 =
      'assets/models/m4_vocal_stress_en_38_norm.json';

  /// From the model's own held-out curve: t=0.5 gives recall 0.867 at
  /// precision 0.677, t=0.8 gives 0.690 at 0.793. 0.50 is taken because this
  /// is a *contributing* signal rather than a trigger, and the Mandarin
  /// variant is likewise set for recall.
  static const double kDefaultThresholdEn38 = 0.50;

  VocalStressDetector._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required Float64List normMean,
    required Float64List normStd,
    VocalStressFeatures? features,
  })  : _interpreter = interpreter,
        _mean = normMean,
        _std = normStd,
        _features = features ?? VocalStressFeatures();

  final tfl.Interpreter _interpreter;
  final Float64List _mean;
  final Float64List _std;
  final VocalStressFeatures _features;

  @override
  final String modelLabel;

  final double threshold;

  @override
  int get expectedInputSize => VocalStressFeatures.kFeatureDim;

  @override
  List<String> get classLabels => const ['calm', 'stressed'];

  /// Loads model + normalisation together, or returns null.
  ///
  /// The two are loaded as a pair on purpose: a model without its constants
  /// is worse than no model, because it still returns confident-looking
  /// numbers. If the norm asset is missing or the wrong length this fails
  /// rather than falling back to raw features.
  /// Picks the variant for a language tag such as `en`, `en_US`, `zh`,
  /// `zh-Hans`. Anything that is not clearly Chinese gets the English model,
  /// because it is both the stronger one (0.8321 vs 0.7988) and the safer
  /// default for an unknown locale.
  static VocalStressVariant variantForLocale(String? languageCode) {
    final lc = (languageCode ?? '').toLowerCase();
    if (lc.startsWith('zh') || lc.startsWith('cmn') || lc.startsWith('yue')) {
      return VocalStressVariant.mandarin28;
    }
    return VocalStressVariant.english38;
  }

  /// Loads the model matching [variant], with its own norm file.
  ///
  /// The two variants have **different input contracts** — 28 features
  /// against 38 — so the asset and the norm must move together, and
  /// [inferPcm] dispatches on [featureDim] rather than assuming one.
  static Future<VocalStressDetector?> tryLoadVariant(
    VocalStressVariant variant, {
    double? threshold,
  }) {
    switch (variant) {
      case VocalStressVariant.mandarin28:
        return tryLoad(
          assetPath: kAsset,
          normPath: kNormAsset,
          threshold: threshold ?? kDefaultThreshold,
        );
      case VocalStressVariant.english38:
        return tryLoad(
          assetPath: kAssetEn38,
          normPath: kNormAssetEn38,
          threshold: threshold ?? kDefaultThresholdEn38,
        );
    }
  }

  static Future<VocalStressDetector?> tryLoad({
    String assetPath = kAsset,
    String normPath = kNormAsset,
    String modelLabel = 'm5_vocal_stress_v2',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      final normRaw = await rootBundle.loadString(normPath);
      final norm = jsonDecode(normRaw) as Map<String, dynamic>;
      final mean = (norm['mean'] as List).cast<num>().map((e) => e.toDouble());
      final std = (norm['std'] as List).cast<num>().map((e) => e.toDouble());
      final m = Float64List.fromList(mean.toList());
      final s = Float64List.fromList(std.toList());
      // Day 337 — accept either width, but require the norm file to declare
      // one of them and to agree with the model's own input tensor below.
      // The pair is what matters: a 38-feature model with 28 constants would
      // standardise the wrong columns and produce confident nonsense.
      const dims = [
        VocalStressFeatures.kFeatureDim,
        VocalStressFeatures.kFullFeatureDim,
      ];
      if (m.length != s.length || !dims.contains(m.length)) {
        throw StateError('norm.json has ${m.length}/${s.length} constants, '
            'expected a matching pair of $dims');
      }

      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inShape = interpreter.getInputTensor(0).shape;
      final wantIn = [1, m.length];
      if (!listEquals(inShape, wantIn)) {
        throw StateError('input shape $inShape, expected $wantIn — the model '
            'and its norm.json disagree about the feature width');
      }
      if (interpreter.getOutputTensor(0).shape.fold<int>(1, (a, b) => a * b) !=
          1) {
        throw StateError('expected a single scalar output');
      }

      return VocalStressDetector._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        normMean: m,
        normStd: s,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[VocalStressDetector] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  /// Preferred entry point: raw mono PCM at
  /// [VocalStressFeatures.kSampleRate]. Owns the whole conversion, so the
  /// features cannot drift from what the model was trained on.
  Future<InferenceResult> inferPcm(
    Float64List pcm, {
    required int timestampMs,
  }) {
    // Day 337 — dispatch on the loaded model's own input width rather than
    // assuming 28. The English model takes the full 38-vector, and feeding
    // it the 28-feature subset would be the silent-wrong-answer failure this
    // codebase keeps hitting.
    final raw = _mean.length == VocalStressFeatures.kFullFeatureDim
        ? _features.compose38(pcm)
        : _features.extract(pcm);
    final z = Float32List(_mean.length);
    for (var i = 0; i < z.length; i++) {
      z[i] = ((raw[i] - _mean[i]) / _std[i]).toDouble();
    }
    return infer(z, timestampMs: timestampMs);
  }

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != _mean.length) {
      throw ArgumentError(
        'VocalStressDetector expects ${_mean.length} standardised floats '
        '(this instance loaded the '
        '${_mean.length == VocalStressFeatures.kFullFeatureDim ? "38-feature "
            "English" : "28-feature Mandarin"} model), got '
        '${features.length}. Use inferPcm() if you are holding raw audio.',
      );
    }
    final t0 = DateTime.now();
    final input = features.reshape([1, VocalStressFeatures.kFeatureDim]);
    final output = [Float32List(1)];
    _interpreter.run(input, output);

    final stressed = output[0][0].toDouble().clamp(0.0, 1.0);
    final isStressed = stressed >= threshold;
    return InferenceResult(
      label: isStressed ? 'stressed' : 'calm',
      score: isStressed ? stressed : 1.0 - stressed,
      classScores: {'calm': 1.0 - stressed, 'stressed': stressed},
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {
      // Best-effort — native side may already be torn down.
    }
  }
}
