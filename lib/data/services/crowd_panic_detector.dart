import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'mel_spectrogram.dart';

/// Day 264/265 — `s_crowd_panic.tflite`, ZapSafe's first two-input
/// (audio + IMU fusion) model.
///
/// Confirmed directly against the real retrained file
/// (`interpreter.get_input_details()`/`get_output_details()`, pulled from
/// `hridyajain/zapsafe-day264-s-crowd-panic` kernel v2 —
/// `DAY264_S_CROWD_PANIC_MOBIACT.md`), not assumed from any doc:
///
/// - `serving_default_imu:0` — `[1, 128, 6]` float32, no quantization.
/// - `serving_default_mel:0` — `[1, 64, 64, 1]` float32, no quantization.
///   **Not** the same mel shape as m1_scream_v2 (`[1,128,131,1]`) or
///   mg_gunshot (`[1,128,128,3]`, int8) — this model's own thing.
/// - Output — `[1, 1]` float32.
///
/// Preprocessing, from `day95_s_crowd_panic.py` (the fixed Day 264 version):
///
/// Audio side (`audio_to_mel`): `SR=16000`, `DURATION=2.0s` (32,000
/// samples), `n_fft=2048`, `hop_length=512`, `n_mels=64`, `fmax=8000`,
/// `librosa.power_to_db(mel, ref=np.max)` — **no per-clip min-max
/// rescale** (unlike m1/mg_gunshot's `MelSpectrogram.compute()` default),
/// pad/crop to exactly 64x64 frames. Final scaling is a **global**
/// `(mel - mel_mean) / mel_std` using the constants baked into
/// `s_crowd_panic_norm.json` at export time (`mel_mean=-16.599...`,
/// `mel_std=17.935...`), not a per-clip normalisation — see
/// `MelSpectrogram.compute(..., normalize: false)`.
///
/// IMU side: raw `[128, 6]` window (acc xyz + gyro xyz, same convention and
/// window length as `MotionDetectorB`/`m2_motion_b_retrain` — reuses
/// `MotionWindowBufferB` for windowing), normalised with a **global
/// per-channel** `(imu - imu_mean[c]) / imu_std[c]` using the 6-element
/// `imu_mean`/`imu_std` arrays from `s_crowd_panic_norm.json` — a third,
/// distinct normalisation convention from both `m2_motion_v2`'s per-channel
/// standardisation (computed live) and `MotionDetectorB`'s fixed
/// `clip(-8,8)/8` scale.
///
/// The mel_mean/mel_std/imu_mean/imu_std constants are **not** hardcoded
/// here — they are read from `s_crowd_panic_norm.json`, bundled as an asset
/// and loaded alongside the model, so a future retrain that changes these
/// constants doesn't require a code change to this file.
class CrowdPanicDetector {
  static const int kSampleRate = 16000;
  static const int kAudioSamples = 32000; // 2.0s @ 16kHz
  static const int kMelH = 64;
  static const int kMelW = 64;
  static const int kImuWindow = 128;
  static const int kImuChannels = 6;

  /// No published operating point yet for this first-pass fusion retrain
  /// (AUC 0.8744 on the training split, 0.68 on the real matched-pair
  /// direction-check set — `DAY264_S_CROWD_PANIC_MOBIACT.md`). 0.5 is the
  /// model's own raw sigmoid midpoint, kept as the default until field data
  /// justifies tuning it, same posture as the other Day 26x retrains.
  static const double kDefaultThreshold = 0.5;

  final tfl.Interpreter _interpreter;
  final MelSpectrogram _mel;
  final double threshold;

  final double melMean;
  final double melStd;
  final List<double> imuMean;
  final List<double> imuStd;

  final int _imuInputIndex;
  final int _melInputIndex;

  final String modelLabel;

  CrowdPanicDetector._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.threshold,
    required this.melMean,
    required this.melStd,
    required this.imuMean,
    required this.imuStd,
    required int imuInputIndex,
    required int melInputIndex,
  })  : _interpreter = interpreter,
        _imuInputIndex = imuInputIndex,
        _melInputIndex = melInputIndex,
        _mel = MelSpectrogram(
          sampleRate: kSampleRate,
          nFft: 2048,
          hopLength: 512,
          nMels: kMelH,
          fmax: 8000.0,
        );

  List<String> get classLabels => const ['calm', 'panic'];

  /// Loads the model + its norm constants, returning null on any failure
  /// (missing asset, unexpected shape/dtype, malformed norm json) so callers
  /// can simply not run crowd-panic detection on this device/build rather
  /// than crash or silently score garbage.
  static Future<CrowdPanicDetector?> tryLoad({
    String assetPath = 'assets/models/s_crowd_panic.tflite',
    String normAssetPath = 'assets/models/s_crowd_panic_norm.json',
    String modelLabel = 's_crowd_panic',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? interpreter;
    try {
      interpreter = await tfl.Interpreter.fromAsset(assetPath);

      final inputTensors = interpreter.getInputTensors();
      if (inputTensors.length != 2) {
        throw StateError(
            'expected 2 inputs (imu, mel), got ${inputTensors.length}');
      }
      int? imuIdx, melIdx;
      for (var i = 0; i < inputTensors.length; i++) {
        final name = inputTensors[i].name.toLowerCase();
        if (name.contains('imu')) imuIdx = i;
        if (name.contains('mel')) melIdx = i;
      }
      if (imuIdx == null || melIdx == null) {
        throw StateError(
            'could not identify imu/mel inputs by name: '
            '${inputTensors.map((t) => t.name).toList()}');
      }

      const wantImu = [1, kImuWindow, kImuChannels];
      const wantMel = [1, kMelH, kMelW, 1];
      if (!listEquals(inputTensors[imuIdx].shape, wantImu)) {
        throw StateError(
            'imu input shape ${inputTensors[imuIdx].shape}, expected $wantImu');
      }
      if (!listEquals(inputTensors[melIdx].shape, wantMel)) {
        throw StateError(
            'mel input shape ${inputTensors[melIdx].shape}, expected $wantMel');
      }
      if (inputTensors[imuIdx].type != tfl.TensorType.float32 ||
          inputTensors[melIdx].type != tfl.TensorType.float32) {
        throw StateError('expected float32 imu/mel inputs, got '
            '${inputTensors[imuIdx].type}/${inputTensors[melIdx].type}');
      }

      final outTensor = interpreter.getOutputTensor(0);
      if (outTensor.shape.fold<int>(1, (a, b) => a * b) != 1) {
        throw StateError(
            'output shape ${outTensor.shape}, expected a single scalar');
      }

      final normJson = await _loadNormJson(normAssetPath);
      final melMean = (normJson['mel_mean'] as num).toDouble();
      final melStd = (normJson['mel_std'] as num).toDouble();
      final imuMean = (normJson['imu_mean'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final imuStd = (normJson['imu_std'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      if (imuMean.length != kImuChannels || imuStd.length != kImuChannels) {
        throw StateError('imu_mean/imu_std length mismatch in norm json');
      }

      return CrowdPanicDetector._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        threshold: threshold,
        melMean: melMean,
        melStd: melStd,
        imuMean: imuMean,
        imuStd: imuStd,
        imuInputIndex: imuIdx,
        melInputIndex: melIdx,
      );
    } catch (e) {
      try {
        interpreter?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[CrowdPanicDetector] tryLoad failed for $assetPath -> $e');
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>> _loadNormJson(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Full preprocessing: 2.0s PCM at [kSampleRate] -> raw (un-normalised
  /// per-clip) mel dB via `MelSpectrogram.compute(normalize: false)` ->
  /// global `(x - mel_mean) / mel_std`.
  Float32List melFeaturesFromPcm(Float64List pcm) {
    final clip = _fitSamples(pcm, kAudioSamples);
    final rawMel = _mel.compute(clip, normalize: false); // [64][~63]
    final fitted = MelSpectrogram.fitFrames(rawMel, kMelW); // [64][64]

    final out = Float32List(kMelH * kMelW);
    var i = 0;
    for (var h = 0; h < kMelH; h++) {
      final row = fitted[h];
      for (var w = 0; w < kMelW; w++) {
        out[i++] = ((row[w] - melMean) / melStd);
      }
    }
    return out;
  }

  /// Raw `[128][6]` IMU window -> global per-channel `(x - imu_mean[c]) /
  /// imu_std[c]`.
  Float32List imuFeaturesFromWindow(List<List<double>> samples) {
    if (samples.length != kImuWindow) {
      throw ArgumentError(
          'CrowdPanicDetector needs exactly $kImuWindow IMU samples, got '
          '${samples.length}');
    }
    final out = Float32List(kImuWindow * kImuChannels);
    var i = 0;
    for (var t = 0; t < kImuWindow; t++) {
      final row = samples[t];
      if (row.length != kImuChannels) {
        throw ArgumentError(
            'sample $t has ${row.length} channels, expected $kImuChannels');
      }
      for (var c = 0; c < kImuChannels; c++) {
        out[i++] = (row[c] - imuMean[c]) / imuStd[c];
      }
    }
    return out;
  }

  /// Runs a single fused inference from raw audio PCM + a raw IMU window.
  /// Both sides are preprocessed here so callers never touch tensor layout.
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

  /// Runs inference given already-preprocessed feature tensors (test
  /// entrypoint, and used internally by [inferFused]).
  Future<InferenceResult> infer({
    required Float32List melFeatures,
    required Float32List imuFeatures,
    required int timestampMs,
  }) async {
    if (melFeatures.length != kMelH * kMelW) {
      throw ArgumentError(
          'expected ${kMelH * kMelW} mel floats, got ${melFeatures.length}');
    }
    if (imuFeatures.length != kImuWindow * kImuChannels) {
      throw ArgumentError('expected ${kImuWindow * kImuChannels} imu '
          'floats, got ${imuFeatures.length}');
    }
    final t0 = DateTime.now();

    final imuInput = imuFeatures.reshape([1, kImuWindow, kImuChannels]);
    final melInput = melFeatures.reshape([1, kMelH, kMelW, 1]);

    final inputs = List<Object>.filled(2, imuInput);
    inputs[_imuInputIndex] = imuInput;
    inputs[_melInputIndex] = melInput;

    final output = Float32List(1);
    _interpreter.runForMultipleInputs(inputs, {0: [output]});

    final panic = output[0].toDouble().clamp(0.0, 1.0);
    final isPanic = panic >= threshold;

    return InferenceResult(
      label: isPanic ? 'panic' : 'calm',
      score: isPanic ? panic : 1.0 - panic,
      classScores: {'calm': 1.0 - panic, 'panic': panic},
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
