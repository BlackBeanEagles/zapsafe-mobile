import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 262 — `m2_motion_b_retrain.tflite`, a second, independent IMU
/// fall-detection model.
///
/// **Design decision: this is a second, independently-firing detector, not
/// a change to `m2_motion_v2`.** `m2_motion_v2` is already wired, working,
/// and shipping (`DetectorV2`, `motion_detector_v2.dart`); this retrain
/// replaces the previously-dead `m2_motion_b` / `m2_motion_adversarial`
/// checkpoint (bit-exact 0.0 on real UCI-HAR before the Day 261 retrain —
/// `DAY260D_M2_MOTION_B_CHECK.md`), which is a *different* architecture
/// (`medium_cnn1d`, arch "b") trained on a different real data mix
/// (SisFall fall-impact positives vs m2_motion_v2's training set) with a
/// different window length (128 samples vs m2_motion_v2's 100). Fusing the
/// two into one event or silently gating one on the other would risk
/// changing m2_motion_v2's already-verified real-world behaviour for no
/// documented benefit — the simplest, safest thing that ships correctly
/// today is: both run, both can independently fire, both are tagged
/// distinctly (`EventType.MOTION_B` on the backend) so the data can be
/// analysed (and one deprecated, or the two fused into a real ensemble)
/// once there is field evidence for which fires more reliably.
///
/// Input/output shape and dtype were confirmed directly against the real
/// exported file via `interpreter.get_input_details()` /
/// `get_output_details()`, not assumed from
/// `DAY261B_KAGGLE_RUNS.md` (which calls this an "int8 tflite" by file-size
/// convention — the file **is** int8-quantized internally for size, but
/// its input/output tensors are float32 with no quantization params
/// (`quantization: (0.0, 0)`), unlike `mg_gunshot_retrain.tflite`, whose
/// input/output genuinely are int8 tensors requiring explicit
/// quantize/dequantize. That is a real, undocumented discrepancy this
/// wiring session found — see `DAY262_GUNSHOT_MOTIONB_WIRING.md`).
///
/// Preprocessing, from `day261_m2_motion_b_retrain.py`
/// (`IMU_LEN=128, IMU_DIM=6, G_RANGE=8.0`, unchanged from `day107_hardmine_m2.py`):
/// `normalize(w) = clip(w, -8, 8) / 8` — a fixed symmetric clip+scale, not
/// the per-channel mean/std standardisation `m2_motion_v2` uses. Channel
/// order and units (accel xyz + gyro xyz, accel with gravity in the same
/// physical units as the training data) are assumed to match
/// `m2_motion_v2`'s convention (`[acc_x, acc_y, acc_z, gyro_x, gyro_y,
/// gyro_z]`) because both are fed from the same native sensor stream in
/// this app — the retrain script itself is data-source-agnostic about
/// units beyond the `[-8, 8]` clip range.
class MotionDetectorB implements Interpreter {
  static const int kWindow = 128;
  static const int kChannels = 6;
  static const int kInputFloats = kWindow * kChannels; // 768

  /// `day261_m2_motion_b_retrain.py`'s `G_RANGE = 8.0`.
  static const double kGRange = 8.0;

  /// The retrain report's real test-set operating point: precision 0.84,
  /// recall 0.95 (`m2_motion_b_retrain_report.json`).
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final double threshold;

  @override
  final String modelLabel;

  MotionDetectorB._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
  }) : _interpreter = interpreter;

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['normal', 'fall'];

  static Future<MotionDetectorB?> tryLoad({
    String assetPath = 'assets/models/m2_motion_b_retrain.tflite',
    String modelLabel = 'm2_motion_b_retrain',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inTensor = interpreter.getInputTensor(0);
      const wantIn = [1, kWindow, kChannels];
      if (!listEquals(inTensor.shape, wantIn)) {
        throw StateError('input shape ${inTensor.shape}, expected $wantIn');
      }
      if (inTensor.type != tfl.TensorType.float32) {
        throw StateError(
            'input dtype ${inTensor.type}, expected float32 (the real '
            'exported file has float32 I/O despite being called "int8" by '
            'size convention in DAY261B_KAGGLE_RUNS.md)');
      }
      if (interpreter.getOutputTensor(0).shape.fold<int>(1, (a, b) => a * b) !=
          1) {
        throw StateError('expected a single scalar output');
      }
      return MotionDetectorB._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[MotionDetectorB] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  /// `clip(w, -G_RANGE, G_RANGE) / G_RANGE` per channel — the real
  /// normalize() from `day261_m2_motion_b_retrain.py`.
  static Float32List normalise(List<List<double>> samples) {
    if (samples.length != kWindow) {
      throw ArgumentError(
        'MotionDetectorB needs exactly $kWindow samples, got '
        '${samples.length}',
      );
    }
    final out = Float32List(kInputFloats);
    var i = 0;
    for (var t = 0; t < kWindow; t++) {
      final row = samples[t];
      if (row.length != kChannels) {
        throw ArgumentError(
          'sample $t has ${row.length} channels, expected $kChannels '
          '(acc xyz + gyro xyz)',
        );
      }
      for (var c = 0; c < kChannels; c++) {
        final clipped = row[c].clamp(-kGRange, kGRange);
        out[i++] = (clipped / kGRange).toDouble();
      }
    }
    return out;
  }

  Future<InferenceResult> inferRaw(
    List<List<double>> samples, {
    required int timestampMs,
  }) =>
      infer(normalise(samples), timestampMs: timestampMs);

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != kInputFloats) {
      throw ArgumentError(
        'MotionDetectorB expects $kInputFloats floats '
        '($kWindow x $kChannels), got ${features.length}',
      );
    }
    final t0 = DateTime.now();

    final input = features.reshape([1, kWindow, kChannels]);
    final output = [Float32List(1)];
    _interpreter.run(input, output);

    final fall = output[0][0].toDouble().clamp(0.0, 1.0);
    final isFall = fall >= threshold;

    return InferenceResult(
      label: isFall ? 'fall' : 'normal',
      score: isFall ? fall : 1.0 - fall,
      classScores: {'normal': 1.0 - fall, 'fall': fall},
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

/// Collects the raw IMU stream into 128-sample windows for [MotionDetectorB]
/// — the same shape as [MotionWindowBuffer] in `motion_detector_v2.dart`
/// but sized for this model's `IMU_LEN=128` (vs m2_motion_v2's 100), kept
/// as a distinct class so the two window sizes can never be silently mixed
/// up at a call site.
class MotionWindowBufferB {
  final int hop;

  final Queue<List<double>> _buf = Queue<List<double>>();
  int _sinceEmit = 0;

  MotionWindowBufferB({this.hop = 32});

  int get buffered => _buf.length;

  bool get isWarm => _buf.length >= MotionDetectorB.kWindow;

  List<List<double>>? add(List<double> sample) {
    if (sample.length != MotionDetectorB.kChannels) {
      throw ArgumentError(
        'expected ${MotionDetectorB.kChannels} channels, got '
        '${sample.length}',
      );
    }
    _buf.addLast(List<double>.unmodifiable(sample));
    while (_buf.length > MotionDetectorB.kWindow) {
      _buf.removeFirst();
    }
    _sinceEmit++;
    if (_buf.length == MotionDetectorB.kWindow && _sinceEmit >= hop) {
      _sinceEmit = 0;
      return _buf.toList(growable: false);
    }
    return null;
  }

  void clear() {
    _buf.clear();
    _sinceEmit = 0;
  }
}
