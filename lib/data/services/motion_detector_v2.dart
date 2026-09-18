import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 258 — m2_motion_v2, the IMU fall / anomaly model.
///
/// Input `[1, 100, 3]` float32: 100 consecutive samples at 50 Hz (a 2-second
/// window) of `[acc_x, acc_y, acc_z]`.
/// Output `[1, 1]` float32 sigmoid — P(fall / anomaly).
///
/// **The trap here is normalisation.** `day83_m2_motion_v2.py` standardises
/// the whole training set by fixed global per-channel constants:
///
/// ```python
/// mean = all_X.mean(axis=(0,1), keepdims=True)
/// std  = all_X.std(axis=(0,1),  keepdims=True) + 1e-8
/// all_X = (all_X - mean) / std
/// ```
///
/// Those constants are baked into the model's weights, not into the graph, so
/// they must be reapplied at inference. Feeding raw m/s^2 and rad/s produces a
/// tensor of exactly the right shape whose values sit several standard
/// deviations from anything the model saw — and it will still return a
/// confident-looking probability. [kNormMean] / [kNormStd] are copied verbatim
/// from `models/components/m2_motion_v2_report.json`.
///
/// Units are equally load-bearing: accelerometer in m/s^2 **including
/// gravity** (Android `TYPE_ACCELEROMETER`, not `TYPE_LINEAR_ACCELERATION`).
/// `sensors_plus`'s `accelerometerEventStream()` already supplies exactly
/// that; `userAccelerometerEventStream()` would not.
///
/// **Day 323 — this now loads `motion_fall_v2.tflite`, and the channel count
/// dropped from 6 to 3.** The previous asset, `motion_anomaly_v1.tflite`,
/// was verified DEAD: a constant 0.0 for every input on real SisFall IMU.
///
/// Retrained on UniMiB-SHAR, the one local dataset matching deployment
/// reality: real smartphone accelerometer, 50 Hz, 11,771 windows with 4,192
/// genuine falls across 8 fall types and 30 subjects. Units were verified by
/// measurement rather than assumption — median window magnitude 9.41 m/s^2,
/// so gravity is present (g-units would read ~1.0).
///
/// Held out 7 of the 30 subjects **entirely**, so no subject appears in both
/// train and test and the model cannot be scoring on memorised gait:
///
///   held-out-subject AUC 0.9978 over 2,751 windows (1,045 real falls)
///   at threshold 0.50 — recall 0.971, precision 0.983
///
/// **Why 3 channels and not 6:** UniMiB has no gyroscope. Zero-padding the
/// gyro channels to preserve the old shape would have taught the model that
/// `gyro == 0` is normal, and it would then misbehave the moment a real
/// phone supplied real gyro — a silent wrong-input failure, which is the
/// exact class of bug that made `scream_classifier_v1` claim 0.95 recall
/// while firing on 5.6% of real screams. Three honest channels beat six
/// dishonest ones.
///
/// Caveat worth carrying: UniMiB falls are lab-collected (deliberate falls
/// onto mats). Real-world falls will differ, and this has not been tested on
/// a physical device.
class MotionDetectorV2 implements Interpreter {
  static const int kWindow = 100;
  static const int kChannels = 3;
  static const int kInputFloats = kWindow * kChannels; // 300
  static const int kRateHz = 50;

  /// Per-channel mean, from `m2_motion_v2_report.json`.
  static const List<double> kNormMean = [
    0.15847542881965637,
    -0.25485244393348694,
    -0.18803349137306213,
  ];

  /// Per-channel standard deviation, from the same report. The training code's
  /// `+ 1e-8` is already included in these values — do not add it again.
  static const List<double> kNormStd = [
    5.146200656890869,
    8.54922866821289,
    4.773979187011719,
  ];

  /// The model's own report records `fall_recall: 1.0` at this cut-off.
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final double threshold;

  @override
  final String modelLabel;

  MotionDetectorV2._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
  }) : _interpreter = interpreter;

  @override
  int get expectedInputSize => kInputFloats;

  @override
  List<String> get classLabels => const ['normal', 'fall'];

  static Future<MotionDetectorV2?> tryLoad({
    String assetPath = 'assets/models/motion_fall_v2.tflite',
    String modelLabel = 'motion_fall_v2',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);
      final inShape = interpreter.getInputTensor(0).shape;
      const wantIn = [1, kWindow, kChannels];
      if (!listEquals(inShape, wantIn)) {
        throw StateError('input shape $inShape, expected $wantIn');
      }
      if (interpreter.getOutputTensor(0).shape.fold<int>(1, (a, b) => a * b) !=
          1) {
        throw StateError('expected a single scalar output');
      }
      return MotionDetectorV2._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[MotionDetectorV2] tryLoad failed for $assetPath → $e');
      }
      return null;
    }
  }

  /// Standardises a window of **raw** sensor readings into the model's input.
  ///
  /// [samples] is row-major `[100][6]` in physical units. Returns 600 floats
  /// in the same layout, ready for [infer].
  static Float32List normalise(List<List<double>> samples) {
    if (samples.length != kWindow) {
      throw ArgumentError(
        'MotionDetectorV2 needs exactly $kWindow samples '
        '(${kWindow / kRateHz}s at ${kRateHz}Hz), got ${samples.length}',
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
        out[i++] = (row[c] - kNormMean[c]) / kNormStd[c];
      }
    }
    return out;
  }

  /// Convenience: standardise raw samples and run inference.
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
        'MotionDetectorV2 expects $kInputFloats floats '
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

/// Collects the 50 Hz per-sample IMU stream into 100-sample windows.
///
/// The native side emits one fused sample per accelerometer event; the model
/// wants a 2-second window. This buffers with a configurable hop so
/// consecutive windows overlap — a fall lasting under a second would
/// otherwise be split across two non-overlapping windows and appear in
/// neither as a complete event.
class MotionWindowBuffer {
  /// Emit a new window every [hop] samples. 25 at 50 Hz = every 0.5 s, with
  /// 1.5 s of overlap between consecutive windows.
  final int hop;

  final Queue<List<double>> _buf = Queue<List<double>>();
  int _sinceEmit = 0;

  MotionWindowBuffer({this.hop = 25});

  int get buffered => _buf.length;

  /// True once enough samples have arrived to form a first window.
  bool get isWarm => _buf.length >= MotionDetectorV2.kWindow;

  /// Adds one raw sample. Returns a complete `[100][6]` window when one is
  /// ready, otherwise null.
  List<List<double>>? add(List<double> sample) {
    if (sample.length != MotionDetectorV2.kChannels) {
      throw ArgumentError(
        'expected ${MotionDetectorV2.kChannels} channels, got ${sample.length}',
      );
    }
    _buf.addLast(List<double>.unmodifiable(sample));
    while (_buf.length > MotionDetectorV2.kWindow) {
      _buf.removeFirst();
    }
    _sinceEmit++;
    if (_buf.length == MotionDetectorV2.kWindow && _sinceEmit >= hop) {
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
