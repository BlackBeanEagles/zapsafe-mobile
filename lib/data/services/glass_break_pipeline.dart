import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../native/pcm_window.dart';
import '../models/inference_result.dart';
import 'glass_break_detector.dart';

/// Day 346 — joins the native rolling-PCM stream to `m_glass_breaking_v4`.
///
/// Mirrors `GunshotAudioPipeline` exactly in shape, including the silence
/// gate, the single-flight `_busy` guard and the drop counters. The two
/// differ only in the detector they call and therefore in the window length
/// each one asks the native layer to resample (glass wants 2 s at 16 kHz,
/// gunshot 3 s) — `PcmWindow.samples(targetRateHz:)` handles the rate and
/// [GlassBreakDetector] fits the length.
///
/// The silence gate is [kSilenceRms] = 0.005, the same value
/// `ScreamAudioPipeline` and `GunshotAudioPipeline` use. Breaking glass is a
/// loud transient, so a window below this is not worth a mel spectrogram and
/// a model call. It is written as its own constant rather than imported so
/// that retuning one detector's gate cannot silently retune another's.
class GlassBreakPipeline {
  static const double kSilenceRms = 0.005;

  final GlassBreakDetector detector;
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
  double _maxGlass = 0;

  GlassBreakPipeline({
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
  double get maxGlassScore => _maxGlass;

  void start() {
    if (_sub != null) return;
    _sub = windows.listen(_onWindow, onError: (Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[GlassBreakPipeline] stream error: $e');
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
        debugPrint('[GlassBreakPipeline] unusable window: $window');
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
      final pcm = window.samples(targetRateHz: GlassBreakDetector.kSampleRate);
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
      // Read the class key explicitly. Copying this pipeline from gunshot's
      // and leaving `classScores['gunshot']` in place would read null, coerce
      // to 0.0, and silently report that glass never fires -- the same bug
      // Day 343 found in `dcs_score_watcher.dart`.
      final glass = result.classScores['glass_break'] ?? 0.0;
      if (glass > _maxGlass) _maxGlass = glass;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[GlassBreakPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
