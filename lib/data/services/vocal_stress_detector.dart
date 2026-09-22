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
/// ## Input: 38 features as of Day 350 — the 28-feature rationale is dead
///
/// The original reasoning was: the training script defines 38, but 10 need
/// `librosa.pyin`, an RMS series or autocorrelation, none of which existed
/// in Dart; and on ESD alone the 10 carried nothing (all-38 0.7986 vs
/// these-28 0.7988, the 10 alone 0.5620). Both halves have since stopped
/// being true.
///
/// **Dart can compute all 38 now.** `yin_pitch.dart` (plain YIN, no HMM)
/// and `VocalStressFeatures.compose38()` were written for the English
/// variant and `kFullFeatureDim` is 38. Nothing needed to be added.
///
/// **And the 10 dropped features turn out to be load-bearing — off ESD.**
/// Day 350 trained Mandarin on ESD + EmotionTalk natural speech both ways:
///
///     28 features   acted 0.6294   natural 0.7716   <- fails the 0.70 floor
///     38 features   acted 0.7873   natural 0.7810   <- holds both
///
/// The 28-feature model cannot do acted and natural at once; the 38-feature
/// one can. Measuring the 10 features *within ESD only* is what made them
/// look worthless -- pitch, shimmer and HNR barely vary across ten actors
/// reading one script, and carry real information the moment the recording
/// situation changes. See [VocalStressFeatures] and
/// `assets/models/DAY350_VOCAL_STRESS_V2.md`.
///
/// Features are standardised by the constants in
/// `assets/models/m5_vocal_stress_v2_38_norm.json`. Feeding raw values does not
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
  /// Mandarin — **38 features as of Day 350**, not 28.
  ///
  /// The name is kept so existing call sites still compile; the asset it
  /// loads is `m5_vocal_stress_v2_38.tflite`, trained on ESD Mandarin +
  /// EmotionTalk natural speech and scoring **acted 0.7873 / natural
  /// 0.7810**.
  ///
  /// History worth keeping, because it is why the old number should not be
  /// quoted: the 28-feature model reported 0.7988, but Day 338 ran that
  /// configuration across six held-out speaker triples and got **mean
  /// 0.6314, sd 0.1100, min 0.5060** — the reported split was the best of
  /// six and on `0005/0007/0010` it was at chance. Day 349 then measured it
  /// at **0.4865 on natural Mandarin**. Both findings point the same way and
  /// the 38-feature retrain addresses both.
  ///
  /// See `assets/models/DAY350_VOCAL_STRESS_V2.md` and
  /// `DAY338_SPLIT_SENSITIVITY.md`.
  mandarin28,

  /// `m4_vocal_stress_en_38` — English, the full 38-vector on plain-YIN
  /// pitch. Needs [YinPitch] and [VocalStressFeatures.extendedFeatures],
  /// which is why it could not ship before Day 333.
  ///
  /// Reported at 0.8321 on one split; across six held-out triples it is
  /// **mean 0.7990, sd 0.0761, min 0.6958** — its reported split was also
  /// its best, but unlike the Mandarin model it never approaches chance.
  /// Expect **~0.80 on an unseen English speaker**.
  ///
  /// The same data through the old 28-feature path averages **0.5925**, so
  /// the extra ten features are worth **+0.207 averaged over splits** —
  /// better evidence than the +0.137 single-split figure that justified
  /// building them.
  english38,
}

/// **DAY 350 — both variants retrained on natural speech. Numbers below.**
///
/// Day 349 measured the shipped pair at chance the moment the recording
/// situation changed (m4 0.8321 acted -> 0.4813 on MELD; m5 0.7988 ->
/// 0.4865 on EmotionTalk). Held-out *speaker* never caught it — m5's own
/// 0.9984-seen vs 0.7988-held-out gap is a properly run control that
/// predicted nothing. **Corpus was the confound, not speaker.**
///
/// Day 350 retrained both on acted + natural, with corpus-balanced sample
/// weights so neither half dominates the loss:
///
///     m4  v1  acted 0.8321   natural 0.4813
///         v2  acted 0.7738   natural 0.6235   (v1's identical MELD rows)
///     m5  v1  acted 0.7988   natural 0.4865
///         v2  acted 0.7873   natural 0.7810
///
/// Both now clear the pre-set bars (natural >= 0.60 with a CI excluding
/// 0.50, acted >= 0.70). m4 trades 0.058 of acted for +0.142 natural; m5
/// gives up almost nothing.
///
/// Two things worth knowing before trusting these:
/// * m5's natural number rests on **4 held-out speakers** of 15 in
///   EmotionTalk, so it is a narrower estimate than m4's, which holds out
///   256 of 1,023 MELD dialogues.
/// * run-to-run variance is about +-0.02 on these small heads; the figures
///   above are the ones belonging to the exported artifacts.
///
/// Still not a live path: `vocalStressPipelineProvider` has no consumers in
/// lib/ and the DCS engine does not read vocal stress, so Riverpod never
/// instantiates it.
///
/// See assets/models/DAY350_VOCAL_STRESS_V2.md and
/// DAY349_PROSODIC_MODELS_FAIL_NATURAL_SPEECH.md.
class VocalStressDetector implements Interpreter {
  /// Day 350 — the Mandarin slot is now the 38-feature model trained on
  /// ESD + EmotionTalk natural speech (acted 0.7873 / natural 0.7810).
  /// The 28-feature v2 it replaces was 0.7988 acted / **0.4865 natural**,
  /// i.e. chance the moment the recording situation changed.
  static const String kAsset = 'assets/models/m5_vocal_stress_v2_38.tflite';
  static const String kNormAsset =
      'assets/models/m5_vocal_stress_v2_38_norm.json';

  /// See the class doc — precision is flat, so take the recall.
  static const double kDefaultThreshold = 0.20;

  /// `m4_vocal_stress_en_38` — English, 38 features.
  /// Day 350 — retrained on ESD + MELD natural speech. v1 was 0.8321
  /// acted / 0.4813 natural; this is 0.7738 acted / 0.6235 natural on
  /// v1's identical MELD rows.
  static const String kAssetEn38 =
      'assets/models/m4_vocal_stress_v2_38.tflite';
  static const String kNormAssetEn38 =
      'assets/models/m4_vocal_stress_v2_38_norm.json';

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
