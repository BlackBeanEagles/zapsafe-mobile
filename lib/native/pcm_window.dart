import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/services/audio_resampler.dart';

/// Day 258 — one rolling window of raw PCM from
/// `com.zapsafe/audio.pcm`.
///
/// Shipped by `AudioCaptureService.kt` every [AudioCaptureService.MEL_HOP_SAMPLES]
/// (1 s) as a 3-second window, so consecutive windows overlap by 2 s and a
/// scream near a boundary still lands whole inside the next one.
///
/// Two things about this payload are load-bearing:
///
///  * The samples are **raw** — no Hann taper, no VAD gating. `MelSpectrogram`
///    applies its own periodic Hann per STFT frame, so a pre-tapered window
///    would be windowed twice. And gating on VAD would splice together
///    samples that were never adjacent in time.
///  * [sampleRateHz] is whatever `AudioRecord` actually granted, which is not
///    necessarily the 22,050 Hz the model needs. Use [samples], which
///    resamples, rather than decoding [pcmBytes] yourself.
@immutable
class PcmWindow {
  /// Capture time of the *end* of the window (millis since epoch).
  final int timestampMs;

  /// Rate the bytes are actually at. Compare against
  /// `ScreamDetectorV2.kSampleRate` before use.
  final int sampleRateHz;

  /// Little-endian int16 mono PCM.
  final Uint8List pcmBytes;

  const PcmWindow({
    required this.timestampMs,
    required this.sampleRateHz,
    required this.pcmBytes,
  });

  /// Defensive parser — a malformed event must never take down the audio
  /// isolate. A missing or zero `sr` is reported as 0 so [isUsable] rejects
  /// it rather than silently assuming the model's rate.
  factory PcmWindow.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['pcm'];
    return PcmWindow(
      timestampMs: (map['t'] as num?)?.toInt() ?? 0,
      sampleRateHz: (map['sr'] as num?)?.toInt() ?? 0,
      pcmBytes: raw is Uint8List
          ? raw
          : raw is List<int>
              ? Uint8List.fromList(raw)
              : Uint8List(0),
    );
  }

  /// Number of int16 samples in the payload.
  int get sampleCount => pcmBytes.length ~/ 2;

  /// False when the native side sent us something we must not feed a model —
  /// no samples, or samples of unknown rate.
  bool get isUsable => sampleRateHz > 0 && sampleCount > 0;

  /// Decoded, normalised, and resampled to [targetRateHz].
  ///
  /// Returns an empty list rather than throwing when [isUsable] is false, so
  /// callers can drop the window without a try/catch.
  Float64List samples({required int targetRateHz}) {
    if (!isUsable) return Float64List(0);
    final decoded = AudioResampler.pcm16ToDouble(pcmBytes);
    return AudioResampler.resample(decoded, sampleRateHz, targetRateHz);
  }

  /// Root-mean-square of the raw samples, in the normalised `[-1, 1]` domain.
  /// Cheap enough to compute per window and useful as a silence gate before
  /// paying for a mel spectrogram.
  double get rms {
    if (!isUsable) return 0.0;
    final view = ByteData.sublistView(pcmBytes);
    var acc = 0.0;
    final n = sampleCount;
    for (var i = 0; i < n; i++) {
      final s = view.getInt16(i * 2, Endian.little) / 32768.0;
      acc += s * s;
    }
    return n == 0 ? 0.0 : math.sqrt(acc / n);
  }

  @override
  String toString() =>
      'PcmWindow($sampleCount samples @ ${sampleRateHz}Hz, t=$timestampMs)';
}
