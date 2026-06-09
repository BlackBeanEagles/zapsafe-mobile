import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Day 27 — one voiced-window's acoustic feature vector.
///
/// Shipped from the Kotlin/Swift native side over the
/// `com.zapsafe/audio.features` EventChannel. Day 31's TFLite scream
/// classifier takes [mfcc] + [zcr] + [spectralCentroidHz] as its input
/// layer (15 scalars: 13 + 1 + 1).
@immutable
class AudioFeatures {
  /// Wall-clock millis when the native side computed these features.
  final int timestampMs;

  /// 13 mel-frequency cepstral coefficients. The first one (`mfcc[0]`)
  /// is the log-energy term — kept rather than discarded so downstream
  /// models can use it as a coarse loudness gate.
  final List<double> mfcc;

  /// Zero-crossing rate over the raw PCM frame, normalised to `[0, 1]`.
  /// Whispered speech ≈ 0.05–0.10 · screams ≈ 0.20+ · fricatives top out.
  final double zcr;

  /// Spectral centroid in Hz — broadband brightness. Shouts and screams
  /// push this above ~2 kHz; conversational speech sits around 800-1500.
  final double spectralCentroidHz;

  const AudioFeatures({
    required this.timestampMs,
    required this.mfcc,
    required this.zcr,
    required this.spectralCentroidHz,
  });

  /// Defensive parser. Missing fields default to zero / empty so a
  /// malformed event from the native side never crashes the isolate.
  factory AudioFeatures.fromMap(Map<dynamic, dynamic> map) {
    final rawMfcc = map['mfcc'];
    final mfcc = <double>[];
    if (rawMfcc is List) {
      for (final v in rawMfcc) {
        // Defensive: anything that isn't a num becomes 0 (covers null,
        // String, bool, … — `as num?` would throw on non-num values).
        mfcc.add(v is num ? v.toDouble() : 0.0);
      }
    }
    return AudioFeatures(
      timestampMs:        (map['t'] as num?)?.toInt() ?? 0,
      mfcc:               List.unmodifiable(mfcc),
      zcr:                (map['zcr']      as num?)?.toDouble() ?? 0.0,
      spectralCentroidHz: (map['centroid'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// All scalars flattened into a `Float32List` — ready to hand to a
  /// TFLite interpreter without extra copies.
  Float32List toFloat32Tensor() {
    final out = Float32List(mfcc.length + 2);
    for (var i = 0; i < mfcc.length; i++) {
      out[i] = mfcc[i];
    }
    out[mfcc.length]     = zcr;
    out[mfcc.length + 1] = spectralCentroidHz;
    return out;
  }

  /// Number of scalars in this feature vector. Used by tests and by UI
  /// surfaces that want to display dimensions without hard-coding 15.
  int get dimension => mfcc.length + 2;
}
