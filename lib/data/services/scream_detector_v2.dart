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

  /// Above this sigmoid output the clip is reported as `scream`. The model
  /// card's 0.9424 / 0.9529 precision / recall are quoted at 0.5.
  static const double kDefaultThreshold = 0.5;

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
    String assetPath = 'assets/models/scream_classifier_v1.tflite',
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
