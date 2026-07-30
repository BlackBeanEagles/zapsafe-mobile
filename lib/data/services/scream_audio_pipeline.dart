import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../native/pcm_window.dart';
import '../models/inference_result.dart';
import 'scream_detector_v2.dart';

/// Day 258 — joins the native rolling-PCM stream to m1_scream_v2.
///
/// This is the piece that was missing: the model and the mel pipeline were
/// both correct and neither was receiving microphone audio.
///
/// ```text
/// AudioCaptureService.kt          22.05 kHz (or 44.1), raw int16
///   -> com.zapsafe/audio.pcm      rolling 3 s window, 1 s hop
///     -> PcmWindow.samples()      int16 -> double, resample to 22.05 kHz
///       -> MelSpectrogram         librosa-parity 128 x 130 mel, dB, min-max
///         -> ScreamDetectorV2     [1,128,131,1] -> P(scream)
/// ```
///
/// Windows are processed one at a time. A 3-second mel spectrogram is
/// ~1.4 M butterfly operations plus the model call, and the native side
/// emits every second; if a device cannot keep up, the right behaviour is to
/// skip windows rather than build an unbounded queue and drift further and
/// further behind real time. [droppedBusy] counts those skips so the
/// condition is visible instead of silent.
class ScreamAudioPipeline {
  /// Below this RMS the window is silence and not worth a mel spectrogram.
  ///
  /// Expressed in the normalised `[-1, 1]` domain, so it is independent of
  /// bit depth. 0.005 is roughly -46 dBFS — comfortably below speech, above
  /// a quiet room's noise floor.
  static const double kSilenceRms = 0.005;

  final ScreamDetectorV2 detector;
  final Stream<PcmWindow> windows;

  /// Skip the mel + model cost on windows that are essentially silent.
  final bool gateOnSilence;

  StreamSubscription<PcmWindow>? _sub;
  final _results = StreamController<InferenceResult>.broadcast();
  bool _busy = false;

  int _windowsIn = 0;
  int _inferences = 0;
  int _droppedSilent = 0;
  int _droppedBusy = 0;
  int _droppedUnusable = 0;
  int _maxLatencyMs = 0;
  double _maxScream = 0;

  ScreamAudioPipeline({
    required this.detector,
    required this.windows,
    this.gateOnSilence = true,
  });

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _sub != null;

  /// Windows received from the native side.
  int get windowsIn => _windowsIn;

  /// Windows that actually reached the model.
  int get inferences => _inferences;

  /// Skipped as silence by [kSilenceRms].
  int get droppedSilent => _droppedSilent;

  /// Skipped because the previous window was still being processed. A
  /// non-zero value here means the device cannot sustain the 1 s hop.
  int get droppedBusy => _droppedBusy;

  /// Skipped because the payload had no samples or an unknown sample rate.
  int get droppedUnusable => _droppedUnusable;

  int get maxLatencyMs => _maxLatencyMs;

  double get maxScreamScore => _maxScream;

  void start() {
    if (_sub != null) return;
    _sub = windows.listen(_onWindow, onError: (Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[ScreamAudioPipeline] stream error: $e');
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _results.close();
  }

  Future<void> _onWindow(PcmWindow window) async {
    _windowsIn++;

    if (!window.isUsable) {
      _droppedUnusable++;
      if (kDebugMode) {
        debugPrint('[ScreamAudioPipeline] unusable window: $window');
      }
      return;
    }
    if (gateOnSilence && window.rms < kSilenceRms) {
      _droppedSilent++;
      return;
    }
    if (_busy) {
      _droppedBusy++;
      return;
    }

    _busy = true;
    try {
      final pcm = window.samples(targetRateHz: ScreamDetectorV2.kSampleRate);
      if (pcm.isEmpty) {
        _droppedUnusable++;
        return;
      }
      final result = await detector.inferPcm(
        pcm,
        timestampMs: window.timestampMs,
      );
      _inferences++;
      if (result.latencyMs > _maxLatencyMs) _maxLatencyMs = result.latencyMs;
      final scream = result.classScores['scream'] ?? 0.0;
      if (scream > _maxScream) _maxScream = scream;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      // A single bad window must not tear down the audio pipeline.
      if (kDebugMode) {
        debugPrint('[ScreamAudioPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
