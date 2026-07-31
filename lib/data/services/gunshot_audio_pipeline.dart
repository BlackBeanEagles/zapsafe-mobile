import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../native/pcm_window.dart';
import '../models/inference_result.dart';
import 'gunshot_detector.dart';

/// Day 262 — joins the native rolling-PCM stream to `mg_gunshot_retrain`.
///
/// Mirrors `ScreamAudioPipeline`'s shape exactly (same native window
/// source), but resamples to [GunshotDetectorV2.kSampleRate] (16 kHz, not
/// m1's 22.05 kHz) and runs a structurally different preprocessing pipeline
/// — see `gunshot_detector.dart`'s class doc for the full diff.
class GunshotAudioPipeline {
  /// Same silence gate as `ScreamAudioPipeline` — a gunshot's transient is
  /// loud; a window this quiet is not worth a mel spectrogram + model call.
  static const double kSilenceRms = 0.005;

  final GunshotDetectorV2 detector;
  final Stream<PcmWindow> windows;
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
  double _maxGunshot = 0;

  GunshotAudioPipeline({
    required this.detector,
    required this.windows,
    this.gateOnSilence = true,
  });

  Stream<InferenceResult> get results => _results.stream;

  bool get isActive => _sub != null;

  int get windowsIn => _windowsIn;
  int get inferences => _inferences;
  int get droppedSilent => _droppedSilent;
  int get droppedBusy => _droppedBusy;
  int get droppedUnusable => _droppedUnusable;
  int get maxLatencyMs => _maxLatencyMs;
  double get maxGunshotScore => _maxGunshot;

  void start() {
    if (_sub != null) return;
    _sub = windows.listen(_onWindow, onError: (Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[GunshotAudioPipeline] stream error: $e');
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
        debugPrint('[GunshotAudioPipeline] unusable window: $window');
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
      final pcm = window.samples(targetRateHz: GunshotDetectorV2.kSampleRate);
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
      final gunshot = result.classScores['gunshot'] ?? 0.0;
      if (gunshot > _maxGunshot) _maxGunshot = gunshot;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GunshotAudioPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
