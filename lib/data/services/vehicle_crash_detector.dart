import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'gunshot_detector.dart';
import 'mel_spectrogram.dart';

/// Day 271 — `i_vehicle_crash.tflite`, ZapSafe's second two-input
/// (audio + IMU fusion) model, following `DAY265_CROWD_PANIC_WIRING.md`'s
/// pattern for `s_crowd_panic`.
///
/// ## Backstory: this model was nearly retired by mistake
///
/// `DAY267_REMAINING_MODELS_TRIAGE.md` found this model had been mistested
/// by an earlier harness that only fed the `audio_mel` input, leaving
/// `imu_window` as allocator garbage — the same bug class already found and
/// fixed for `k_confinement` and `s_crowd_panic`. With both real inputs
/// supplied (real ESC-50 crash-proxy audio + real UCI-HAR IMU run through
/// the model's own `inject_crash_spike()`), the real AUC is 0.9622 (fp32) /
/// 0.8733 (int8) — a genuinely strong result. This class is the follow-up
/// wiring for that reconciled model.
///
/// ## Real tensor signature — confirmed directly, not assumed from docs
///
/// Verified this session via `interpreter.get_input_details()` /
/// `get_output_details()` against the real staged file at
/// `day108_int4_m9_push/day108_kaggle_output/saved/int4_m9/
/// day108-int4-m9-kaggle-20260703-v5-production/tflite_staging/
/// i_vehicle_crash.tflite` (the canonical staging copy per
/// `DAY267_REMAINING_MODELS_TRIAGE.md`'s "Where files were moved" section —
/// there are dozens of stale duplicate copies scattered under
/// `day108_int4_m9_push/`'s various `_pull_*`/`_bench_work`/`prior_snapshot`
/// working directories; this is the one the Day 260+ triage scripts treat
/// as canonical):
///
/// ```
/// IN  serving_default_audio_mel:0 [1 64 64 3] int8  (scale=0.003921568859368563, zero=-128)
/// IN  serving_default_imu_window:0 [1 128 6]  int8  (scale=0.003922347445040941, zero=47)
/// OUT StatefulPartitionedCall_1:0  [1 1]      int8  (scale=0.00390625, zero=-128)
/// ```
///
/// **Unlike `s_crowd_panic` (float32, no quantization), this model is a
/// genuine int8-quantized model** — same tensor-dtype situation as
/// `mg_gunshot_retrain`, not `MotionDetectorB`'s "int8 by file size but
/// float32 tensors" trap. Both inputs and the output require real
/// quantize/dequantize using the scale/zero_point read from the loaded
/// model, not hardcoded here.
///
/// ## Preprocessing, from `day91_i_vehicle_crash.py`
///
/// **Audio side** (`audio_to_melspec`): `SR=16000`, `DURATION=2.0s`
/// (32,000 samples), default librosa `n_fft=2048`/`hop_length=512`,
/// `n_mels=64`, `fmax=8000`, `librosa.power_to_db(mel, ref=np.max)`,
/// **then a per-clip min-max rescale to `[0,1]`** (unlike `s_crowd_panic`'s
/// global mean/std — this model uses the *same* per-clip min-max
/// normalization as `MelSpectrogram.compute()`'s default, `normalize:
/// true`). A real 2.0s/16kHz clip yields **63 mel frames**
/// (`1 + 32000 // 512`), then **`np.resize(mel_norm, (64, 64))`** — the
/// same wrap/tile (not image-resize) trap `GunshotDetectorV2` already
/// solved, reused here via [GunshotDetectorV2.wrapResizeSquare] rather than
/// reimplemented. Because the real frame count (63) is only 1 short of the
/// 64x64 target, the wrap here repeats just the model's first mel column
/// once at the very end of the flattened image — a much smaller wrap than
/// `mg_gunshot`'s `[128,94]->[128,128]` case, but the same mechanism,
/// confirmed against real `numpy.resize` output
/// (`test/fixtures/np_resize_vehicle_crash_golden.json`). The normalized
/// image is then stacked into 3 identical channels
/// (`np.stack([img, img, img], axis=-1)`), same as `mg_gunshot`.
///
/// **IMU side**: raw `[128, 6]` window (acc xyz + gyro xyz).
/// `day91_i_vehicle_crash.py`'s `normalize_imu(w) = clip(w, -8, 8) / 8`
/// (`G_RANGE = 8.0`) is **bit-for-bit the same formula** as
/// `MotionDetectorB.normalise` — confirmed by reading both scripts, not
/// assumed from the matching window length alone. `inject_crash_spike()`
/// (the function used to build real IMU crash positives for the AUC 0.87/
/// 0.96 evidence) also ends by calling this same `normalize_imu`. Because
/// the formula and window length (128 samples, 6 channels, same accel-xyz+
/// gyro-xyz channel order convention this app already uses) are identical
/// to `MotionDetectorB`'s, this class reuses [MotionWindowBufferB] for IMU
/// windowing rather than introducing a third windowing implementation —
/// verified, not assumed.
class VehicleCrashDetector {
  static const int kSampleRate = 16000;
  static const int kAudioSamples = 32000; // 2.0s @ 16kHz
  static const int kMelBands = 64;
  static const int kImgSize = 64;
  static const int kChannels = 3;
  static const double kFmax = 8000.0;
  static const int kImuWindow = 128;
  static const int kImuChannels = 6;
  static const double kGRange = 8.0;

  static const int kMelInputFloats = kImgSize * kImgSize * kChannels; // 12,288
  static const int kImuInputFloats = kImuWindow * kImuChannels; // 768

  /// No published operating point beyond the raw sigmoid midpoint — same
  /// posture as `CrowdPanicDetector.kDefaultThreshold`. The real evidence
  /// (`DAY267_REMAINING_MODELS_TRIAGE.md`: AUC 0.8733 int8 on real matched
  /// ESC-50 crash-proxy audio + real UCI-HAR crash-injected IMU) supports
  /// this being a usable detector, but no field-tuned threshold exists yet.
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final MelSpectrogram _mel;
  final double threshold;

  final int _imuInputIndex;
  final int _melInputIndex;

  final double _melInScale;
  final int _melInZeroPoint;
  final double _imuInScale;
  final int _imuInZeroPoint;
  final double _outScale;
  final int _outZeroPoint;

  final String modelLabel;

  VehicleCrashDetector._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required int imuInputIndex,
    required int melInputIndex,
    required double melInScale,
    required int melInZeroPoint,
    required double imuInScale,
    required int imuInZeroPoint,
    required double outScale,
    required int outZeroPoint,
  })  : _interpreter = interpreter,
        _imuInputIndex = imuInputIndex,
        _melInputIndex = melInputIndex,
        _melInScale = melInScale,
        _melInZeroPoint = melInZeroPoint,
        _imuInScale = imuInScale,
        _imuInZeroPoint = imuInZeroPoint,
        _outScale = outScale,
        _outZeroPoint = outZeroPoint,
        _mel = MelSpectrogram(
          sampleRate: kSampleRate,
          nFft: 2048,
          hopLength: 512,
          nMels: kMelBands,
          fmax: kFmax,
        );

  List<String> get classLabels => const ['no_crash', 'crash'];

  /// Loads the model, verifying both input tensors by name (`imu`/`mel`
  /// or `audio` substring match on `interpreter.getInputTensors()[i].name`,
  /// not assumed index order — same approach as `CrowdPanicDetector`) and
  /// reading the real per-tensor int8 quantization params from the loaded
  /// interpreter, not hardcoded. Returns null on any failure so callers can
  /// simply not run vehicle-crash detection on this device/build.
  static Future<VehicleCrashDetector?> tryLoad({
    String assetPath = 'assets/models/i_vehicle_crash.tflite',
    String modelLabel = 'i_vehicle_crash',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);

      final inputTensors = interpreter.getInputTensors();
      if (inputTensors.length != 2) {
        throw StateError(
            'expected 2 inputs (imu_window, audio_mel), got ${inputTensors.length}');
      }
      int? imuIdx, melIdx;
      for (var i = 0; i < inputTensors.length; i++) {
        final name = inputTensors[i].name.toLowerCase();
        if (name.contains('imu')) imuIdx = i;
        if (name.contains('mel') || name.contains('audio')) melIdx = i;
      }
      if (imuIdx == null || melIdx == null) {
        throw StateError(
            'could not identify imu/mel inputs by name: '
            '${inputTensors.map((t) => t.name).toList()}');
      }

      const wantImu = [1, kImuWindow, kImuChannels];
      const wantMel = [1, kImgSize, kImgSize, kChannels];
      if (!listEquals(inputTensors[imuIdx].shape, wantImu)) {
        throw StateError(
            'imu input shape ${inputTensors[imuIdx].shape}, expected $wantImu');
      }
      if (!listEquals(inputTensors[melIdx].shape, wantMel)) {
        throw StateError(
            'mel input shape ${inputTensors[melIdx].shape}, expected $wantMel');
      }
      if (inputTensors[imuIdx].type != tfl.TensorType.int8 ||
          inputTensors[melIdx].type != tfl.TensorType.int8) {
        throw StateError('expected int8 imu/mel inputs, got '
            '${inputTensors[imuIdx].type}/${inputTensors[melIdx].type} '
            '(real exported file is int8-quantized, unlike s_crowd_panic)');
      }

      final outTensor = interpreter.getOutputTensor(0);
      if (outTensor.shape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError(
            'output shape ${outTensor.shape}, expected a single scalar');
      }

      final melParams = inputTensors[melIdx].params;
      final imuParams = inputTensors[imuIdx].params;
      final outParams = outTensor.params;

      return VehicleCrashDetector._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        imuInputIndex: imuIdx,
        melInputIndex: melIdx,
        melInScale: melParams.scale,
        melInZeroPoint: melParams.zeroPoint,
        imuInScale: imuParams.scale,
        imuInZeroPoint: imuParams.zeroPoint,
        outScale: outParams.scale,
        outZeroPoint: outParams.zeroPoint,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[VehicleCrashDetector] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  /// Full preprocessing: 2.0s PCM at [kSampleRate] -> mel spectrogram
  /// (fmax=8000) -> dB -> per-clip min-max `[0,1]` ->
  /// `np.resize`-style wrap to 64x64 -> stacked into 3 identical channels
  /// -> flattened row-major `[h][w][c]`, still float in `[0,1]`.
  /// Quantization to int8 happens in [inferFused]/[infer].
  Float32List melFeaturesFromPcm(Float64List pcm) {
    final clip = _fitSamples(pcm, kAudioSamples);
    final mel = _mel.compute(clip); // per-clip min-max [0,1], [64][63] real shape
    final img = GunshotDetectorV2.wrapResizeSquare(mel, kImgSize);

    final out = Float32List(kMelInputFloats);
    var i = 0;
    for (var h = 0; h < kImgSize; h++) {
      final row = img[h];
      for (var w = 0; w < kImgSize; w++) {
        final v = row[w];
        out[i++] = v;
        out[i++] = v;
        out[i++] = v;
      }
    }
    return out;
  }

  /// Raw `[128][6]` IMU window -> `clip(w, -8, 8) / 8`, bit-for-bit
  /// `day91_i_vehicle_crash.py::normalize_imu`, identical to
  /// [MotionDetectorB.normalise]'s formula.
  Float32List imuFeaturesFromWindow(List<List<double>> samples) {
    if (samples.length != kImuWindow) {
      throw ArgumentError(
          'VehicleCrashDetector needs exactly $kImuWindow IMU samples, got '
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
        final clipped = row[c].clamp(-kGRange, kGRange);
        out[i++] = (clipped / kGRange).toDouble();
      }
    }
    return out;
  }

  /// Runs a single fused inference from raw audio PCM + a raw IMU window.
  Future<InferenceResult> inferFused({
    required Float64List pcm,
    required List<List<double>> imuWindow,
    required int timestampMs,
  }) async {
    final melFeatures = melFeaturesFromPcm(pcm);
    final imuFeatures = imuFeaturesFromWindow(imuWindow);
    return infer(
      melFeatures: melFeatures,
      imuFeatures: imuFeatures,
      timestampMs: timestampMs,
    );
  }

  int _quantizeMel(double v) =>
      ((v / _melInScale).round() + _melInZeroPoint).clamp(-128, 127);
  int _quantizeImu(double v) =>
      ((v / _imuInScale).round() + _imuInZeroPoint).clamp(-128, 127);
  double _dequantizeOut(int q) => (q - _outZeroPoint) * _outScale;

  /// Runs inference given already-preprocessed feature tensors (test
  /// entrypoint, and used internally by [inferFused]). Quantizes both
  /// inputs to int8 using the real scale/zero_point read from the loaded
  /// model, and dequantizes the int8 output the same way.
  Future<InferenceResult> infer({
    required Float32List melFeatures,
    required Float32List imuFeatures,
    required int timestampMs,
  }) async {
    if (melFeatures.length != kMelInputFloats) {
      throw ArgumentError(
          'expected $kMelInputFloats mel floats, got ${melFeatures.length}');
    }
    if (imuFeatures.length != kImuInputFloats) {
      throw ArgumentError('expected $kImuInputFloats imu floats, got '
          '${imuFeatures.length}');
    }
    final t0 = DateTime.now();

    final melQ = Int8List(kMelInputFloats);
    for (var i = 0; i < kMelInputFloats; i++) {
      melQ[i] = _quantizeMel(melFeatures[i]);
    }
    final imuQ = Int8List(kImuInputFloats);
    for (var i = 0; i < kImuInputFloats; i++) {
      imuQ[i] = _quantizeImu(imuFeatures[i]);
    }

    final melInput = melQ.reshape([1, kImgSize, kImgSize, kChannels]);
    final imuInput = imuQ.reshape([1, kImuWindow, kImuChannels]);

    final inputs = List<Object>.filled(2, imuInput);
    inputs[_imuInputIndex] = imuInput;
    inputs[_melInputIndex] = melInput;

    final output = Int8List(1);
    _interpreter.runForMultipleInputs(inputs, {0: [output]});

    final crash = _dequantizeOut(output[0]).clamp(0.0, 1.0);
    final isCrash = crash >= threshold;

    return InferenceResult(
      label: isCrash ? 'crash' : 'no_crash',
      score: isCrash ? crash : 1.0 - crash,
      classScores: {'no_crash': 1.0 - crash, 'crash': crash},
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  static Float64List _fitSamples(Float64List pcm, int target) {
    if (pcm.length == target) return pcm;
    final out = Float64List(target);
    out.setRange(0, pcm.length < target ? pcm.length : target,
        pcm.length < target ? pcm : pcm.sublist(0, target));
    return out;
  }

  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {}
  }
}
