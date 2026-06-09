import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Day 44 — 8-float scene-feature vector for the heuristic scene fallback.
///
/// Layout (matches [HeuristicSceneDetector.expectedInputSize] = 8):
///   [0] meanBrightness     — average pixel luminance, 0–255
///   [1] darkPixelRatio     — fraction of pixels with luminance < 50, 0–1
///   [2] contrastStd        — standard deviation of luminance, 0–128
///   [3] edgeDensity        — fraction of high-gradient pixels (Sobel proxy), 0–1
///   [4] saturationMean     — mean HSV saturation, 0–1
///   [5] redMean            — mean red channel, 0–255
///   [6] greenMean          — mean green channel, 0–255
///   [7] blueMean           — mean blue channel, 0–255
///
/// These can be computed on a 48×48 thumbnail without GPU, typically < 5 ms.
/// The real MobileNetV2 path uses the full 224×224 frame; this fallback avoids
/// it for PhoneCapabilityTier.low devices.
@immutable
class SceneFeatures {
  final int timestampMs;
  final double meanBrightness;
  final double darkPixelRatio;
  final double contrastStd;
  final double edgeDensity;
  final double saturationMean;
  final double redMean;
  final double greenMean;
  final double blueMean;

  const SceneFeatures({
    required this.timestampMs,
    required this.meanBrightness,
    required this.darkPixelRatio,
    required this.contrastStd,
    required this.edgeDensity,
    required this.saturationMean,
    required this.redMean,
    required this.greenMean,
    required this.blueMean,
  });

  /// Well-lit indoor scene — safe environment.
  factory SceneFeatures.wellLit({int? timestampMs}) => SceneFeatures(
        timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        meanBrightness: 160.0,
        darkPixelRatio: 0.05,
        contrastStd: 30.0,
        edgeDensity: 0.12,
        saturationMean: 0.35,
        redMean: 155.0,
        greenMean: 165.0,
        blueMean: 160.0,
      );

  /// Low-light / nighttime scene — potential threat environment.
  factory SceneFeatures.dark({int? timestampMs}) => SceneFeatures(
        timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        meanBrightness: 28.0,
        darkPixelRatio: 0.78,
        contrastStd: 18.0,
        edgeDensity: 0.04,
        saturationMean: 0.08,
        redMean: 25.0,
        greenMean: 28.0,
        blueMean: 32.0,
      );

  /// Pack into the Float32 layout [HeuristicSceneDetector] expects.
  Float32List toFloat32Tensor() {
    return Float32List.fromList([
      meanBrightness,
      darkPixelRatio,
      contrastStd,
      edgeDensity,
      saturationMean,
      redMean,
      greenMean,
      blueMean,
    ]);
  }

  int get dimension => 8;
}
