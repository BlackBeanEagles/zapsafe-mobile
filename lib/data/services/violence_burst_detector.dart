
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';

/// Day 334 — `m3_violence_temporal` (held-out AUC **0.9124**), wired as a
/// two-stage burst detector.
///
/// ## Why two models
///
/// The temporal head does not take pixels. Its input is `[1, 16, 576]` — a
/// sequence of **16 MobileNetV3Small embeddings**. So a frame burst has to be
/// run through the encoder first:
///
/// ```
/// 16 frames -> [1,224,224,3] each -> encoder -> [1,576] each
///           -> stack to [1,16,576] -> temporal head -> [1,1]
/// ```
///
/// This is why the model sat trained-but-unwired: `assets/models/` shipped no
/// encoder, so the head had nothing to consume. Both are float16 —
/// `mobilenetv3small_encoder_float16.tflite` (1.85 MB) and
/// `m3_violence_temporal_v1.tflite` (685 KB).
///
/// ## The input-scaling hazard, which is the reason this class exists at all
///
/// **This encoder takes raw `[0, 255]` pixel values. Do not divide by 255.**
///
/// `MobileNetV3Small` carries its own `Rescaling(scale: 1/127.5, offset:
/// -1.0)` as its first layer, and `tf.keras.applications.mobilenet_v3
/// .preprocess_input` is a verified pass-through (checked against the real
/// library: input `[0,255]` comes back `[0,255]`, `np.allclose` true). The
/// encoder was exported with that rescaling baked in, so scaling beforehand
/// would apply it twice and hand the temporal head embeddings drawn from a
/// distribution it has never seen.
///
/// This app now contains **two MobileNetV3-based models with opposite input
/// conventions**, both fed from the same `CameraFrameService` byte source:
///
/// | model | expects | why |
/// |---|---|---|
/// | `scene_analyzer_v1` ([SceneDetectorV2]) | `pixel / 255.0` | trained end-to-end on `/255`-scaled input despite `include_preprocessing=True`, so its weights are self-consistent with that range |
/// | this encoder | **raw `0-255`** | rescaling is a layer inside the exported graph |
///
/// Confusing them produces well-formed, confident-looking, wrong output with
/// nothing thrown — the failure shape this codebase has hit repeatedly. The
/// separate entry points [packFrameRaw] and [SceneDetectorV2.normalise] exist
/// so the two conventions cannot be reached by the same call, and
/// `day334_violence_burst_test.dart` pins the distinction.
///
/// See `assets/models/DAY332_M7_M3_PYIN.md` and
/// `assets/models/DAY334_M3_BURST_WIRING.md`.
class ViolenceBurstDetector {
  static const int kFrames = 16;
  static const int kImgSize = 224;
  static const int kChannels = 3;
  static const int kEmbedding = 576;

  /// Bytes in one frame: `224 * 224 * 3` = 150,528.
  static const int kFrameBytes = kImgSize * kImgSize * kChannels;

  /// Day 337 — calibrated on the full 670-clip held-out val set, raised from
  /// the 0.5 sigmoid midpoint.
  ///
  /// | t | recall | precision | false-positive rate |
  /// |---|---|---|---|
  /// | 0.90 | 0.373 | 0.956 | 0.019 |
  /// | **0.80** | **0.538** | **0.935** | **0.040** |
  /// | 0.70 | 0.613 | 0.910 | 0.065 |
  /// | 0.50 | 0.743 | 0.862 | 0.127 |
  ///
  /// 0.5 fired on **12.7%** of non-violent clips. At 0.80 that is **4.0%** —
  /// a third as many — for recall 0.743 -> 0.538.
  ///
  /// Precision is the right thing to buy here, for two reasons. This is a
  /// **corroborating** signal: a burst is only captured once something else
  /// has already raised suspicion, so a miss costs a confirmation the app
  /// was not relying on, while a false positive puts a "violence" event in
  /// the user's feed and the backend. And escalation now actually fires
  /// (Day 335), so a wrong label is no longer harmless.
  ///
  /// Note this threshold does **not** gate the DCS contribution — the fusion
  /// reads the raw `violence` probability, deliberately, so a borderline
  /// burst contributes proportionally rather than all-or-nothing. What this
  /// controls is the reported label, and therefore what gets submitted.
  ///
  /// Still not calibrated on real *device* footage; these are held-out
  /// dataset clips.
  static const double kDefaultThreshold = 0.80;

  final tfl.Interpreter _encoder;
  final tfl.Interpreter _temporal;
  final double threshold;

  ViolenceBurstDetector._({
    required tfl.Interpreter encoder,
    required tfl.Interpreter temporal,
    required this.threshold,
  })  : _encoder = encoder,
        _temporal = temporal;

  /// Loads both stages, verifying every tensor shape.
  ///
  /// Returns null on any failure rather than throwing, and closes whichever
  /// interpreter did load — a half-open pair would leak a native handle.
  /// Loading them as a **pair** is deliberate: either stage alone is useless,
  /// and a detector that silently ran with one missing would be worse than
  /// one that reports itself unavailable.
  static Future<ViolenceBurstDetector?> tryLoad({
    String encoderAsset = 'assets/models/mobilenetv3small_encoder_float16.tflite',
    String temporalAsset = 'assets/models/m3_violence_temporal_v1.tflite',
    double threshold = kDefaultThreshold,
  }) async {
    tfl.Interpreter? encoder;
    tfl.Interpreter? temporal;
    try {
      encoder = await tfl.Interpreter.fromAsset(encoderAsset);
      const wantEncIn = [1, kImgSize, kImgSize, kChannels];
      const wantEncOut = [1, kEmbedding];
      if (!listEquals(encoder.getInputTensor(0).shape, wantEncIn)) {
        throw StateError('encoder input ${encoder.getInputTensor(0).shape}, '
            'expected $wantEncIn');
      }
      if (!listEquals(encoder.getOutputTensor(0).shape, wantEncOut)) {
        throw StateError('encoder output ${encoder.getOutputTensor(0).shape}, '
            'expected $wantEncOut');
      }

      temporal = await tfl.Interpreter.fromAsset(temporalAsset);
      const wantTempIn = [1, kFrames, kEmbedding];
      const wantTempOut = [1, 1];
      if (!listEquals(temporal.getInputTensor(0).shape, wantTempIn)) {
        throw StateError('temporal input ${temporal.getInputTensor(0).shape}, '
            'expected $wantTempIn');
      }
      if (!listEquals(temporal.getOutputTensor(0).shape, wantTempOut)) {
        throw StateError('temporal output ${temporal.getOutputTensor(0).shape},'
            ' expected $wantTempOut');
      }

      return ViolenceBurstDetector._(
        encoder: encoder,
        temporal: temporal,
        threshold: threshold,
      );
    } catch (e) {
      try {
        encoder?.close();
      } catch (_) {}
      try {
        temporal?.close();
      } catch (_) {}
      if (kDebugMode) {
        debugPrint('[ViolenceBurstDetector] tryLoad failed -> $e');
      }
      return null;
    }
  }

  /// Packs one `224*224*3` RGB byte frame into the encoder's float32 layout,
  /// **unscaled**.
  ///
  /// The `.toDouble()` here is a type conversion, not a normalisation. See
  /// the class doc: dividing by 255 would double-apply the encoder's internal
  /// `Rescaling` layer.
  static Float32List packFrameRaw(List<int> rgbBytes) {
    if (rgbBytes.length != kFrameBytes) {
      throw ArgumentError(
        'ViolenceBurstDetector needs exactly $kFrameBytes bytes per frame '
        '($kImgSize x $kImgSize x $kChannels RGB), got ${rgbBytes.length}',
      );
    }
    final out = Float32List(kFrameBytes);
    for (var i = 0; i < kFrameBytes; i++) {
      out[i] = rgbBytes[i].toDouble();
    }
    return out;
  }

  /// Runs one frame through the encoder, returning its 576-dim embedding.
  Float32List encodeFrame(List<int> rgbBytes) {
    final input = packFrameRaw(rgbBytes)
        .reshape([1, kImgSize, kImgSize, kChannels]);
    final output = [Float32List(kEmbedding)];
    _encoder.run(input, output);
    return output[0];
  }

  /// Full two-stage pass over a burst of exactly [kFrames] frames.
  ///
  /// [frames] must be in **capture order** — the head is temporal, so
  /// shuffling them is not a no-op the way it would be for a frame-level
  /// classifier.
  Future<InferenceResult> inferBurst(
    List<List<int>> frames, {
    required int timestampMs,
  }) async {
    if (frames.length != kFrames) {
      throw ArgumentError(
        'ViolenceBurstDetector expects exactly $kFrames frames in capture '
        'order, got ${frames.length}',
      );
    }
    final t0 = DateTime.now();

    final seq = List.generate(
      kFrames,
      (i) => encodeFrame(frames[i]),
      growable: false,
    );

    final input = [seq];
    final output = [Float32List(1)];
    _temporal.run(input, output);

    // Single sigmoid unit: P(violence).
    final violence = output[0][0].toDouble();
    final isViolent = violence >= threshold;

    return InferenceResult(
      label: isViolent ? 'violence' : 'no_violence',
      // Mirrors the other detectors in this app: `score` is confidence in the
      // reported label, not the raw positive-class probability.
      score: isViolent ? violence : 1.0 - violence,
      classScores: {
        'violence': violence,
        'no_violence': 1.0 - violence,
      },
      latencyMs: DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  Future<void> dispose() async {
    try {
      _encoder.close();
    } catch (_) {}
    try {
      _temporal.close();
    } catch (_) {}
  }
}
