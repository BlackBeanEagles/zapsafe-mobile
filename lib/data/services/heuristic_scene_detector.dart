import 'dart:typed_data';

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 44 — heuristic scene threat detector for PhoneCapabilityTier.low devices.
///
/// Implements [Interpreter] so it is a drop-in replacement for the TFLite
/// scene_analyzer_v1 model in the DCS pipeline.
///
/// Input layout (8 floats — matches [SceneFeatures.toFloat32Tensor]):
///   [0] meanBrightness     — average pixel luminance, 0–255
///   [1] darkPixelRatio     — fraction of pixels with luminance < 50, 0–1
///   [2] contrastStd        — standard deviation of luminance, 0–128
///   [3] edgeDensity        — fraction of high-gradient pixels, 0–1
///   [4] saturationMean     — mean HSV saturation, 0–1
///   [5] redMean            — mean red channel, 0–255
///   [6] greenMean          — mean green channel, 0–255
///   [7] blueMean           — mean blue channel, 0–255
///
/// Detection logic:
///   A. Dark gate:     meanBrightness < [_darkThreshold]    (very dark scene)
///   B. Coverage gate: darkPixelRatio  > [_darkRatioThreshold] (mostly dark)
///   C. Flat gate:     contrastStd     < [_lowContrastThreshold] AND dark (uniform dark)
///
/// A dark, low-contrast, uniform scene scores high — matches the Violence
/// dataset training signal (night scenes, obscured environments, etc.).
/// A well-lit, colourful scene scores near zero.
class HeuristicSceneDetector implements Interpreter {
  const HeuristicSceneDetector({
    double darkThreshold       = 60.0,
    double darkRatioThreshold  = 0.50,
    double lowContrastThreshold = 35.0,
  })  : _darkThreshold        = darkThreshold,
        _darkRatioThreshold   = darkRatioThreshold,
        _lowContrastThreshold  = lowContrastThreshold;

  final double _darkThreshold;
  final double _darkRatioThreshold;
  final double _lowContrastThreshold;

  @override
  String get modelLabel => 'heuristic-scene-v1';

  @override
  int get expectedInputSize => 8;

  @override
  List<String> get classLabels => const ['safe', 'threat'];

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'HeuristicSceneDetector expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }

    final t0 = DateTime.now();

    final meanBrightness = features[0].toDouble();
    final darkPixelRatio = features[1].toDouble();
    final contrastStd    = features[2].toDouble();

    // Gate A: overall darkness
    final darkGate = meanBrightness < _darkThreshold ? 1.0 : 0.0;

    // Gate B: coverage of dark pixels
    final coverageGate = darkPixelRatio > _darkRatioThreshold ? 1.0 : 0.0;

    // Gate C: low contrast in a dark scene — occlusion/blackout signature
    final flatGate =
        (darkGate > 0 && contrastStd < _lowContrastThreshold) ? 1.0 : 0.0;

    final threatScore =
        (0.40 * darkGate + 0.35 * coverageGate + 0.25 * flatGate)
            .clamp(0.0, 0.95);

    final safeScore = (1.0 - threatScore).clamp(0.0, 1.0);

    final classScores = <String, double>{
      'threat': threatScore,
      'safe':   safeScore,
    };

    final top = classScores.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    return InferenceResult(
      label:       top.key,
      score:       top.value,
      classScores: classScores,
      latencyMs:   DateTime.now().difference(t0).inMilliseconds,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {}

  HeuristicSceneDetector copyWith({
    double? darkThreshold,
    double? darkRatioThreshold,
    double? lowContrastThreshold,
  }) =>
      HeuristicSceneDetector(
        darkThreshold:        darkThreshold        ?? _darkThreshold,
        darkRatioThreshold:   darkRatioThreshold   ?? _darkRatioThreshold,
        lowContrastThreshold: lowContrastThreshold ?? _lowContrastThreshold,
      );
}
