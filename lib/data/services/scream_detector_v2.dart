import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';
import 'mel_spectrogram.dart';

/// Day 257 — the real m1_scream_v2 model, wired to the librosa-parity
/// mel pipeline.
///
/// This replaces the 15-float MFCC path for the scream slot. The two are
/// not variations on a theme; they are different models with different
/// inputs:
///
/// | | old scream slot | m1_scream_v2 |
/// |---|---|---|
/// | Input | `[1, 15]` MFCC+ZCR+centroid | `[1, 128, 131, 1]` mel spectrogram |
/// | Output | 3-class softmax | `[1, 1]` sigmoid |
/// | Sample rate | 16 kHz | **22.05 kHz** |
/// | Window | 450 ms | **3 s** |
///
/// Because [Interpreter.infer] takes a flat `Float32List`, this class
/// accepts the *flattened* mel ([kInputFloats] floats, row-major
/// `[mel band][frame]`) on that path — but callers holding raw audio should
/// use [inferPcm], which owns the whole conversion and is the only way to
/// be sure the features match what the model was trained on.
///
/// Preprocessing is specified in `assets/models/PREPROCESSING_SPEC.md` and
/// verified against librosa golden values by
/// `test/mel_spectrogram_test.dart`. That parity test is what makes this
/// wiring trustworthy: a mel pipeline that is close but not equal yields a
/// tensor of exactly the right shape and range that the model scores
/// wrongly, which is indistinguishable from a working detector at runtime.
class ScreamDetectorV2 implements Interpreter {
  /// Model input sample rate. Audio captured at any other rate must be
  /// resampled *before* it reaches [inferPcm].
  static const int kSampleRate = 22050;

  /// Exactly 3 s at [kSampleRate]. Shorter clips are zero-padded, longer
  /// ones truncated — matching `m1_train_v2.py`.
  static const int kSamples = 66150;

  static const int kMelBands = 128;

  /// The exported model wants 131 frames; librosa yields 130 for a 3 s clip.
  /// See the spec doc — the last frame is zero-padded and the measured
  /// impact is at most 0.0195.
  static const int kFrames = 131;

  static const int kInputFloats = kMelBands * kFrames; // 16,768

  /// Above this sigmoid output the clip is reported as `scream`.
  ///
  /// **0.20, not 0.5, and that is deliberate.**
  ///
  /// Day 346 — re-measured on the shipped **v5** model over the FSD50K eval
  /// set: 1,764 clips, **287 real positives**. The table this block used to
  /// carry (recall 0.778, precision 0.614) came from a 135-clip AudioSet
  /// fixture with only 45 positives, which Day 345 retired — on real data
  /// v3 never achieved those numbers:
  ///
  /// | t | v5 recall | v5 precision |
  /// |---|---|---|
  /// | 0.40 | 0.784 | 0.356 |
  /// | 0.30 | 0.822 | 0.324 |
  /// | 0.25 | 0.836 | 0.302 |
  /// | **0.20** | **0.843** | **0.282** |
  /// | 0.15 | 0.857 | 0.268 |
  ///
  /// v3 at this same threshold, measured the same way, was **recall 0.711,
  /// precision 0.304**. So v5 at 0.20 buys **+0.132 recall for −0.022
  /// precision** — a missed scream is the expensive error for a safety app.
  ///
  /// 0.30 was the alternative and would have *dominated* v3 on both axes
  /// (0.822 / 0.324). It was not taken: the extra 0.021 recall is worth more
  /// here than the 0.042 precision.
  ///
  /// These precisions look low against the old table because the eval set is
  /// adversarial by design — 287 positives against 1,477 negatives that are
  /// speech, chatter, laughter and singing. It is a worst-case number, not a
  /// field estimate, and it is not comparable to the 0.614 above.
  ///
  /// This detector carries the **largest DCS fusion weight (0.5)**, so the
  /// change propagates: an uncorroborated scream at 0.9 contributes 0.45,
  /// which is exactly `ViolenceBurstCoordinator.kTriggerThreshold`. More
  /// screams crossing threshold therefore means more camera bursts, bounded
  /// by that class's 90 s cooldown.
  ///
  /// **Day 346 — this now loads `scream_classifier_v5.tflite`.**
  ///
  /// AUC across versions. The first three rows are the OLD 135-clip AudioSet
  /// fixture (45 positives, CI ~±0.05); the last two are the FSD50K eval set
  /// (287 positives, CI ~±0.018). **The two columns are not comparable** —
  /// that is the whole point of Day 345:
  ///
  ///     v1 (Day 31)   0.616   |
  ///     v2 (Day 322)  0.759   |  135-clip AudioSet fixture
  ///     v3 (Day 324)  0.823   |
  ///     ----------------------+------------------------------
  ///     v3 re-measured        |  0.7675   FSD50K eval
  ///     v5 (this one)         |  0.8284   FSD50K eval
  ///
  /// v3's "0.823" and its real 0.7675 are the same model measured two ways.
  /// v5 gained +0.0609, 95% CI [+0.0394, +0.0816], from two changes: crying
  /// dropped from the positive set (it is not scored as a scream), and
  /// Cheering/Crowd/Applause added as hard negatives. See
  /// assets/models/DAY346_SCREAM_V5_DEFINITION_AND_DATA.md.
  ///
  /// v1's model card claimed precision 0.9424 / recall 0.9529. Those were
  /// in-domain memorisation on a held-out split of its own training
  /// distribution, which was dominated by acted RAVDESS/CREMA-D **speech**.
  /// On real AudioSet screaming it fired on 5.6% of clips, and on RAVDESS
  /// *neutral* speech just as often — it had learned acted studio emotion,
  /// not screaming. At this threshold v3 catches 0.667 where v1 caught
  /// 0.067 at its own.
  ///
  /// What fixed it was the training distribution, twice over. A scream is
  /// not speech, it is a non-speech vocalisation: v2 swapped in 1,991 real
  /// ASVP-ESD non-speech distress vocalisations and demoted acted speech to
  /// a negative. v3 then added 714 VocalAffectBench screams **and ~4,500
  /// same-domain hard negatives** — laughter, cough, sneeze, sigh, sniff,
  /// throat-clearing, yawn. That second half is what moved precision: a
  /// cough and a scream are both sharp non-speech vocalisations, and
  /// nothing before had ever taught the model the difference. At equal
  /// recall (0.667) precision went 0.386 -> 0.524.
  ///
  /// **Still not a solved problem.** v5 catches 0.843 of real screams and
  /// roughly seven alerts in ten are false on an adversarial eval set. It is
  /// a materially better detector than v3, not one to advertise.
  ///
  /// The binding constraint has changed. Through v3 it was *measurement* —
  /// 33 real held-out screams, so 0.82 could not be told from 0.78. Day 345
  /// fixed that with 287 positives (CI ~±0.018), which is what made v5's
  /// +0.0609 provable rather than plausible.
  ///
  /// What binds now is **precision against crowd noise**. The gain here came
  /// from adding Cheering/Crowd/Applause as negatives, and that is also where
  /// the remaining false alerts concentrate. See
  /// `assets/models/DAY346_SCREAM_V5_DEFINITION_AND_DATA.md` and
  /// `DAY324_SCREAM_V3.md` for the earlier history.
  static const double kDefaultThreshold = 0.20;

  final tfl.Interpreter _interpreter;
  final MelSpectrogram _mel;
  final double threshold;

  @override
  final String modelLabel;

  ScreamDetectorV2._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    MelSpectrogram? mel,
  })  : _interpreter = interpreter,
        _mel = mel ??
            MelSpectrogram(
              sampleRate: kSampleRate,
              nFft: 2048,
              hopLength: 512,
              nMels: kMelBands,
            );

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['normal', 'scream'];

  /// Loads the model, returning null on any failure so callers can fall back
  /// to [HeuristicScreamDetector].
  ///
  /// The shape check is not ceremony. The same asset path previously held a
  /// 658-byte placeholder, and before that a 15-float MFCC model; loading
  /// either of those and feeding it a mel spectrogram would produce numbers
  /// rather than an error.
  static Future<ScreamDetectorV2?> tryLoad({
    String assetPath = 'assets/models/scream_classifier_v5.tflite',
    String modelLabel = 'm1_scream_v2',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inShape = interpreter.getInputTensor(0).shape;
      final outShape = interpreter.getOutputTensor(0).shape;

      const wantIn = [1, kMelBands, kFrames, 1];
      if (!listEquals(inShape, wantIn)) {
        throw StateError('input shape $inShape, expected $wantIn');
      }
      if (outShape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError('output shape $outShape, expected a single scalar');
      }

      return ScreamDetectorV2._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
      );
    } catch (e) {
      // Missing asset, placeholder file, wrong model in the slot, or a host
      // VM with no native TFLite library.
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[ScreamDetectorV2] tryLoad failed for $assetPath → $e');
      }
      return null;
    }
  }

  /// Preferred entry point: raw mono PCM at [kSampleRate], any length.
  Future<InferenceResult> inferPcm(
    Float64List pcm, {
    required int timestampMs,
  }) =>
      infer(melInputFromPcm(pcm), timestampMs: timestampMs);

  /// Full preprocessing: fit to 3 s, mel spectrogram, dB, per-clip min-max,
  /// pad to [kFrames], flatten row-major.
  ///
  /// Exposed separately so tests can assert on the tensor without a native
  /// interpreter, and so the feature extraction can be profiled on its own.
  Float32List melInputFromPcm(Float64List pcm) {
    final clip = _fitSamples(pcm);
    final mel = MelSpectrogram.fitFrames(_mel.compute(clip), kFrames);

    final out = Float32List(kInputFloats);
    var i = 0;
    for (var m = 0; m < kMelBands; m++) {
      final row = mel[m];
      for (var t = 0; t < kFrames; t++) {
        out[i++] = row[t];
      }
    }
    return out;
  }

  /// Pad with zeros or truncate to exactly [kSamples].
  static Float64List _fitSamples(Float64List pcm) {
    if (pcm.length == kSamples) return pcm;
    final out = Float64List(kSamples);
    out.setRange(0, pcm.length < kSamples ? pcm.length : kSamples,
        pcm.length < kSamples ? pcm : pcm.sublist(0, kSamples));
    return out;
  }

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != kInputFloats) {
      throw ArgumentError(
        'ScreamDetectorV2 expects $kInputFloats floats '
        '($kMelBands x $kFrames mel), got ${features.length}. '
        'Use inferPcm() if you are holding raw audio.',
      );
    }
    final t0 = DateTime.now();

    final input = features.reshape([1, kMelBands, kFrames, 1]);
    final output = [Float32List(1)];
    _interpreter.run(input, output);

    // Single sigmoid unit: P(scream). Clamped because a quantised head can
    // return a hair outside [0, 1].
    final scream = output[0][0].toDouble().clamp(0.0, 1.0);
    final classScores = <String, double>{
      'normal': 1.0 - scream,
      'scream': scream,
    };
    final isScream = scream >= threshold;

    return InferenceResult(
      label: isScream ? 'scream' : 'normal',
      score: isScream ? scream : 1.0 - scream,
      classScores: classScores,
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
