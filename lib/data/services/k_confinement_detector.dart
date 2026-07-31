import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';

/// Day 273 — wires `k_confinement_decorrelated.tflite` (Day 272's
/// decorrelated retrain, see `DAY272_K_CONFINEMENT_DECORRELATED_RETRAIN.md`),
/// following `DAY271_VEHICLE_CRASH_WIRING.md`'s two-input fusion pattern.
///
/// ## Why this retrain, not the originally-shipped-staging model
///
/// The originally-staged `k_confinement` model gated almost entirely on its
/// `light` input due to a training-data confound (every "confined" positive
/// hardcoded `light=0.0`, every negative used `light>=0.15`) — Day 260/269
/// found it collapsed to a constant ~0 output at any realistic lit light
/// value, with zero motion-discrimination. The Day 272 retrain decorrelates
/// light from label on the same real IMU sources (PAMAP2, MotionSense) and
/// is a real, verified fix: AUC 0.9959, and at a fixed realistic lit light
/// value (0.7) the output std across real IMU windows goes from 0.0000
/// (collapsed) to 0.4775, with a real +0.2811 high-vs-low-motion mean-output
/// gap. Full detail in `DAY272_K_CONFINEMENT_DECORRELATED_RETRAIN.md`.
///
/// ## Real tensor signature — confirmed directly this session, not assumed
///
/// Verified via `interpreter.get_input_details()`/`get_output_details()`
/// against the real file at
/// `kaggle_notebooks/day272_k_confinement_decorrelated_push/kaggle_output/
/// k_confinement_decorrelated.tflite` (59,240 bytes):
///
/// ```
/// IN  serving_default_imu:0   [1 128 6]  float32
/// IN  serving_default_light:0 [1 32  1]  float32
/// OUT StatefulPartitionedCall_1:0 [1 1]  float32
/// ```
///
/// **Both tensors are float32** — unlike `i_vehicle_crash`'s genuine int8
/// export, this retrain's `.tflite` (despite the training report citing an
/// "int8 size: 57.9 KB" figure for a *separate* quantized artifact not
/// present in `kaggle_output/`) is float32 end-to-end. No quantize/
/// dequantize is needed; this class runs float32 in and out directly,
/// confirmed against the loaded interpreter's tensor dtypes at load time
/// (not assumed from the report).
///
/// ## Preprocessing, from `day272_k_confinement_decorrelated.py`
///
/// **IMU side**: raw `[128, 6]` window (acc xyz + gyro xyz), z-score
/// normalized per channel: `(x - imu_mean) / imu_std`, using the real
/// per-channel `imu_mean`/`imu_std` (6 values each) from
/// `k_confinement_decorrelated_norm.json` — **not** the `clip(-8,8)/8`
/// formula `MotionDetectorB`/`VehicleCrashDetector` use; this model's own
/// training script normalizes differently, confirmed by reading
/// `build_dataset()`'s `X_imu = (X_imu - imu_mean) / imu_std` directly.
/// `MotionWindowBufferB` is still reused for raw 128-sample/6-channel
/// windowing (same window length/channel convention as every other IMU
/// model in this app), but the normalization step is this class's own.
///
/// **Light side**: `make_light(val) = np.full(32, val)` — a single scalar
/// broadcast across all 32 timesteps, reshaped to `[1, 32, 1]`, with **no
/// normalization** (raw value in the model's trained range, roughly
/// `0.0`-`0.9`). See `KConfinementFusionPipeline` for where this value
/// currently comes from — **this is the one piece of this wiring that is
/// NOT backed by a real sensor reading yet** (see that file's doc comment).
class KConfinementDetector {
  static const int kImuWindow = 128;
  static const int kImuChannels = 6;
  static const int kLightLen = 32;

  static const int kImuInputFloats = kImuWindow * kImuChannels; // 768

  /// No published/field-tuned operating point — same posture as
  /// `VehicleCrashDetector.kDefaultThreshold` and `CrowdPanicDetector`'s.
  /// The real evidence (Day 272: AUC 0.9959, real dynamic range restored at
  /// a realistic lit light value) supports this being usable, but this is
  /// the raw sigmoid midpoint, not a field-calibrated threshold.
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final double threshold;
  final List<double> _imuMean;
  final List<double> _imuStd;

  final int _imuInputIndex;
  final int _lightInputIndex;

  final String modelLabel;

  KConfinementDetector._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required int imuInputIndex,
    required int lightInputIndex,
    required List<double> imuMean,
    required List<double> imuStd,
  })  : _interpreter = interpreter,
        _imuInputIndex = imuInputIndex,
        _lightInputIndex = lightInputIndex,
        _imuMean = imuMean,
        _imuStd = imuStd;

  List<String> get classLabels => const ['not_confined', 'confined'];

  /// Real per-channel z-score params from
  /// `k_confinement_decorrelated_norm.json` (Day 272's real training run).
  /// Hardcoded here (mirroring how `MotionDetectorB`/other detectors embed
  /// their own norm constants) rather than loaded from a bundled JSON asset,
  /// since the six values are small and stable per-model constants.
  static const List<double> kImuMean = [
    18.82670783996582,
    -1.5446271896362305,
    3.4640188217163086,
    -0.2883187234401703,
    0.15556541085243225,
    3.3361189365386963,
  ];
  static const List<double> kImuStd = [
    33.07301712036133,
    15.915735244750977,
    6.720554828643799,
    2.901996374130249,
    1.4621796607971191,
    5.33461332321167,
  ];

  /// Loads the model, verifying both input tensors by name (`imu`/`light`
  /// substring match on `interpreter.getInputTensors()[i].name`, not
  /// assumed index order) and confirming shapes/dtype against the real
  /// loaded interpreter. Returns null on any failure so callers simply
  /// don't run confinement detection on this device/build.
  static Future<KConfinementDetector?> tryLoad({
    String assetPath = 'assets/models/k_confinement_decorrelated.tflite',
    String modelLabel = 'k_confinement_decorrelated',
    double threshold = kDefaultThreshold,
    List<double> imuMean = kImuMean,
    List<double> imuStd = kImuStd,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);

      final inputTensors = interpreter.getInputTensors();
      if (inputTensors.length != 2) {
        throw StateError(
            'expected 2 inputs (imu, light), got ${inputTensors.length}');
      }
      int? imuIdx, lightIdx;
      for (var i = 0; i < inputTensors.length; i++) {
        final name = inputTensors[i].name.toLowerCase();
        if (name.contains('imu')) imuIdx = i;
        if (name.contains('light')) lightIdx = i;
      }
      if (imuIdx == null || lightIdx == null) {
        throw StateError('could not identify imu/light inputs by name: '
            '${inputTensors.map((t) => t.name).toList()}');
      }

      const wantImu = [1, kImuWindow, kImuChannels];
      const wantLight = [1, kLightLen, 1];
      if (!listEquals(inputTensors[imuIdx].shape, wantImu)) {
        throw StateError(
            'imu input shape ${inputTensors[imuIdx].shape}, expected $wantImu');
      }
      if (!listEquals(inputTensors[lightIdx].shape, wantLight)) {
        throw StateError('light input shape ${inputTensors[lightIdx].shape}, '
            'expected $wantLight');
      }
      if (inputTensors[imuIdx].type != tfl.TensorType.float32 ||
          inputTensors[lightIdx].type != tfl.TensorType.float32) {
        throw StateError('expected float32 imu/light inputs, got '
            '${inputTensors[imuIdx].type}/${inputTensors[lightIdx].type} '
            '(real exported file is float32, unlike i_vehicle_crash)');
      }

      final outTensor = interpreter.getOutputTensor(0);
      if (outTensor.shape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError(
            'output shape ${outTensor.shape}, expected a single scalar');
      }
      if (outTensor.type != tfl.TensorType.float32) {
        throw StateError('expected float32 output, got ${outTensor.type}');
      }

      return KConfinementDetector._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        imuInputIndex: imuIdx,
        lightInputIndex: lightIdx,
        imuMean: imuMean,
        imuStd: imuStd,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[KConfinementDetector] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  /// Raw `[128][6]` IMU window -> `(x - imu_mean) / imu_std` per channel,
  /// bit-for-bit `day272_k_confinement_decorrelated.py`'s
  /// `X_imu = (X_imu - imu_mean) / imu_std`.
  Float32List imuFeaturesFromWindow(List<List<double>> samples) {
    if (samples.length != kImuWindow) {
      throw ArgumentError(
          'KConfinementDetector needs exactly $kImuWindow IMU samples, got '
          '${samples.length}');
    }
    final out = Float32List(kImuInputFloats);
    var i = 0;
    for (var t = 0; t < kImuWindow; t++) {
      final row = samples[t];
      if (row.length != kImuChannels) {
        throw ArgumentError(
            'sample $t has ${row.length} channels, expected $kImuChannels');
      }
      for (var c = 0; c < kImuChannels; c++) {
        out[i++] = ((row[c] - _imuMean[c]) / _imuStd[c]).toDouble();
      }
    }
    return out;
  }

  /// `make_light(val) = np.full(32, val)` — a single scalar broadcast
  /// across all 32 timesteps, no normalization.
  Float32List lightFeaturesFromScalar(double lightValue) {
    final out = Float32List(kLightLen);
    for (var i = 0; i < kLightLen; i++) {
      out[i] = lightValue.toDouble();
    }
    return out;
  }

  /// Runs a single fused inference from a raw IMU window + a light scalar.
  /// See `KConfinementFusionPipeline` for the honest caveat on where
  /// [lightValue] currently comes from (not yet a real sensor reading).
  Future<InferenceResult> inferFused({
    required List<List<double>> imuWindow,
    required double lightValue,
    required int timestampMs,
  }) async {
    final imuFeatures = imuFeaturesFromWindow(imuWindow);
    final lightFeatures = lightFeaturesFromScalar(lightValue);
    return infer(
      imuFeatures: imuFeatures,
      lightFeatures: lightFeatures,
      timestampMs: timestampMs,
    );
  }

  /// Runs inference given already-preprocessed feature tensors (test
  /// entrypoint, and used internally by [inferFused]). Float32 in, float32
  /// out — no quantize/dequantize needed for this model.
  Future<InferenceResult> infer({
    required Float32List imuFeatures,
    required Float32List lightFeatures,
    required int timestampMs,
  }) async {
    if (imuFeatures.length != kImuInputFloats) {
      throw ArgumentError('expected $kImuInputFloats imu floats, got '
          '${imuFeatures.length}');
    }
    if (lightFeatures.length != kLightLen) {
      throw ArgumentError(
          'expected $kLightLen light floats, got ${lightFeatures.length}');
    }
    final t0 = DateTime.now();

    final imuInput = imuFeatures.reshape([1, kImuWindow, kImuChannels]);
    final lightInput = lightFeatures.reshape([1, kLightLen, 1]);

    final inputs = List<Object>.filled(2, imuInput);
    inputs[_imuInputIndex] = imuInput;
    inputs[_lightInputIndex] = lightInput;

    final output = Float32List(1);
    _interpreter.runForMultipleInputs(inputs, {0: [output]});

    final confined = output[0].clamp(0.0, 1.0);
    final isConfined = confined >= threshold;

    return InferenceResult(
      label: isConfined ? 'confined' : 'not_confined',
      score: isConfined ? confined : 1.0 - confined,
      classScores: {
        'not_confined': 1.0 - confined,
        'confined': confined,
      },
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {}
  }
}
