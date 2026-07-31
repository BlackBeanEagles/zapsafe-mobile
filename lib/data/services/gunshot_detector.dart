import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';
import 'mel_spectrogram.dart';

/// Day 262 — `mg_gunshot_retrain.tflite`, wired to a librosa-parity mel
/// pipeline that is structurally different from m1_scream_v2's.
///
/// This is a *new* detection family, not a variant of the scream model.
/// Confirmed directly against the real exported file
/// (`interpreter.get_input_details()` /
/// `day261_mg_gunshot_retrain.py::audio_to_melspec`), not assumed from the
/// docs:
///
/// | | m1_scream_v2 | mg_gunshot_retrain |
/// |---|---|---|
/// | Sample rate | 22,050 Hz | **16,000 Hz** |
/// | Window | 3 s (66,150 samples) | 3 s (**48,000** samples) |
/// | Mel fmax | Nyquist (11,025 Hz) | **8,000 Hz** (explicit `fmax` kwarg) |
/// | Frames | 131 (librosa yields 130, zero-padded by 1) | **128x128 "image"** |
/// | Post-mel shape step | pad/trim frame axis | **`np.resize(mel_norm, (128, 128))`** |
/// | Channels | 1 | **3** (mel image duplicated into all 3, `np.stack`) |
/// | Input tensor | `[1, 128, 131, 1]` float32 | **`[1, 128, 128, 3]` int8** |
/// | Output tensor | `[1, 1]` float32 sigmoid | **`[1, 1]` int8** (dequantized here) |
///
/// The `np.resize` step is the trap. It is **not** an image resize —
/// `np.resize` on an array smaller than the target flattens the source in
/// C (row-major) order and *tiles/wraps* it to fill the requested shape,
/// re-using early elements again once the source is exhausted. A real 3 s
/// clip at these settings produces a `[128, 94]` mel (94 < 128 frames), so
/// every output row after the first ~94 columns repeats earlier data. An
/// implementation that reaches for a standard bilinear/nearest image resize
/// here — the "obviously correct" reading of "resize a spectrogram to an
/// image" — produces a tensor of exactly the right shape that the model
/// scores on features it never saw in training. See
/// `test/gunshot_detector_test.dart` and
/// `test/fixtures/np_resize_wrap_golden.json`, generated directly from
/// `numpy.resize` (not reimplemented independently), for the parity check.
class GunshotDetectorV2 implements Interpreter {
  /// Model input sample rate — confirmed from `day261_mg_gunshot_retrain.py`
  /// `SR = 16000`, NOT the 22,050 Hz used by m1_scream_v2.
  static const int kSampleRate = 16000;

  /// 3.0 s at [kSampleRate] (`DURATION = 3.0` in the training script).
  static const int kSamples = 48000;

  static const int kMelBands = 128;
  static const int kImgSize = 128;
  static const int kChannels = 3;
  static const double kFmax = 8000.0;

  /// Flattened `[H][W][C]` row-major float count fed to [infer], *before*
  /// int8 quantization (quantization happens inside [infer]).
  static const int kInputFloats = kImgSize * kImgSize * kChannels; // 49,152

  /// The retrain report's operating point: recall 0.9958 at the model's
  /// default sigmoid cut, precision 0.5065 (`mg_gunshot_retrain_report.json`,
  /// `DAY261B_KAGGLE_RUNS.md`). Recall-heavy by design — a missed real
  /// gunshot is worse than a false positive for a safety app.
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final MelSpectrogram _mel;
  final double threshold;

  final double _inScale;
  final int _inZeroPoint;
  final double _outScale;
  final int _outZeroPoint;

  @override
  final String modelLabel;

  GunshotDetectorV2._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required double inScale,
    required int inZeroPoint,
    required double outScale,
    required int outZeroPoint,
    MelSpectrogram? mel,
  })  : _interpreter = interpreter,
        _inScale = inScale,
        _inZeroPoint = inZeroPoint,
        _outScale = outScale,
        _outZeroPoint = outZeroPoint,
        _mel = mel ??
            MelSpectrogram(
              sampleRate: kSampleRate,
              nFft: 2048,
              hopLength: 512,
              nMels: kMelBands,
              fmax: kFmax,
            );

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['normal', 'gunshot'];

  /// Loads the model, returning null on any failure so callers can fall
  /// back to a heuristic or simply not fire gunshot detections on this
  /// device.
  ///
  /// Reads the real per-tensor quantization params from the loaded
  /// interpreter rather than hardcoding them — the exported int8 file is
  /// the source of truth, not this doc comment.
  static Future<GunshotDetectorV2?> tryLoad({
    String assetPath = 'assets/models/mg_gunshot_retrain.tflite',
    String modelLabel = 'mg_gunshot_retrain',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inTensor = interpreter.getInputTensor(0);
      final outTensor = interpreter.getOutputTensor(0);

      const wantIn = [1, kImgSize, kImgSize, kChannels];
      if (!listEquals(inTensor.shape, wantIn)) {
        throw StateError('input shape ${inTensor.shape}, expected $wantIn');
      }
      if (outTensor.shape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError(
            'output shape ${outTensor.shape}, expected a single scalar');
      }
      if (inTensor.type != tfl.TensorType.int8) {
        throw StateError(
            'input dtype ${inTensor.type}, expected int8 (real exported '
            'file is int8-quantized — see mg_gunshot_retrain_report.json)');
      }

      final inParams = inTensor.params;
      final outParams = outTensor.params;

      return GunshotDetectorV2._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        inScale: inParams.scale,
        inZeroPoint: inParams.zeroPoint,
        outScale: outParams.scale,
        outZeroPoint: outParams.zeroPoint,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[GunshotDetectorV2] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  /// Preferred entry point: raw mono PCM at [kSampleRate], any length.
  Future<InferenceResult> inferPcm(
    Float64List pcm, {
    required int timestampMs,
  }) =>
      infer(melImageFromPcm(pcm), timestampMs: timestampMs);

  /// Full preprocessing: fit to 3 s, mel spectrogram (fmax=8000), dB,
  /// per-clip min-max, `np.resize`-style wrap to 128x128, stacked into 3
  /// identical channels, flattened row-major `[h][w][c]`.
  ///
  /// Returned values are still float in `[0, 1]` — quantization to int8
  /// happens in [infer], using the real scale/zero-point read from the
  /// loaded model, not hardcoded here.
  Float32List melImageFromPcm(Float64List pcm) {
    final clip = _fitSamples(pcm);
    final mel = _mel.compute(clip); // [128][~94] for a real 3s/16kHz clip
    final img = wrapResizeSquare(mel, kImgSize);

    final out = Float32List(kInputFloats);
    var i = 0;
    for (var h = 0; h < kImgSize; h++) {
      final row = img[h];
      for (var w = 0; w < kImgSize; w++) {
        final v = row[w];
        // 3 identical channels — np.stack([img, img, img], axis=-1).
        out[i++] = v;
        out[i++] = v;
        out[i++] = v;
      }
    }
    return out;
  }

  /// `np.resize(mel_norm, (size, size))` — flattens [mel] row-major and
  /// tiles/wraps it to fill a `size x size` array. **Not** an image resize:
  /// there is no interpolation, and once the source is exhausted the output
  /// repeats earlier rows/columns from the start. See the class doc and
  /// `test/fixtures/np_resize_wrap_golden.json` (generated by real
  /// `numpy.resize`, not reimplemented independently).
  ///
  /// Day 271 — no longer test-only: reused directly by `VehicleCrashDetector`
  /// (`vehicle_crash_detector.dart`), which has the same np.resize wrap/tile
  /// step in its own preprocessing (`day91_i_vehicle_crash.py`'s
  /// `audio_to_melspec`). Kept as one shared implementation rather than a
  /// third copy-paste, since both are bit-for-bit the same numpy operation.
  static List<Float64List> wrapResizeSquare(
      List<Float64List> mel, int size) {
    final srcRows = mel.length;
    final srcCols = srcRows == 0 ? 0 : mel[0].length;
    final total = srcRows * srcCols;
    final out = List<Float64List>.generate(size, (_) => Float64List(size));
    if (total == 0) return out;

    var flatIdx = 0;
    for (var h = 0; h < size; h++) {
      final row = out[h];
      for (var w = 0; w < size; w++) {
        final srcIdx = flatIdx % total;
        final srcR = srcIdx ~/ srcCols;
        final srcC = srcIdx % srcCols;
        row[w] = mel[srcR][srcC];
        flatIdx++;
      }
    }
    return out;
  }

  /// Pad with zeros or truncate to exactly [kSamples]. Deterministic (start
  /// of clip), unlike the training script's random crop for over-length
  /// clips — random cropping is a training-time augmentation, not part of
  /// the model's learned input distribution.
  static Float64List _fitSamples(Float64List pcm) {
    if (pcm.length == kSamples) return pcm;
    final out = Float64List(kSamples);
    out.setRange(0, pcm.length < kSamples ? pcm.length : kSamples,
        pcm.length < kSamples ? pcm : pcm.sublist(0, kSamples));
    return out;
  }

  int _quantize(double value) {
    final q = (value / _inScale).round() + _inZeroPoint;
    return q.clamp(-128, 127);
  }

  double _dequantize(int q) => (q - _outZeroPoint) * _outScale;

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != kInputFloats) {
      throw ArgumentError(
        'GunshotDetectorV2 expects $kInputFloats floats '
        '($kImgSize x $kImgSize x $kChannels image), got ${features.length}. '
        'Use inferPcm() if you are holding raw audio.',
      );
    }
    final t0 = DateTime.now();

    final quantized = Int8List(kInputFloats);
    for (var i = 0; i < kInputFloats; i++) {
      quantized[i] = _quantize(features[i]);
    }

    final input = quantized.reshape([1, kImgSize, kImgSize, kChannels]);
    final output = [Int8List(1)];
    _interpreter.run(input, output);

    final gunshot = _dequantize(output[0][0]).clamp(0.0, 1.0);
    final classScores = <String, double>{
      'normal': 1.0 - gunshot,
      'gunshot': gunshot,
    };
    final isGunshot = gunshot >= threshold;

    return InferenceResult(
      label: isGunshot ? 'gunshot' : 'normal',
      score: isGunshot ? gunshot : 1.0 - gunshot,
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
