import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inference_result.dart';
import '../../native/pcm_window.dart';
import 'vocal_stress_detector.dart';
import 'vocal_stress_features.dart';

/// Day 341 — feeds PCM to [VocalStressDetector], which until now had nothing
/// driving it.
///
/// `VocalStressDetector` was gate-verified on Day 325 and wired to a provider
/// on Day 337, but no stream ever reached it: `model_registry.dart` loaded
/// the asset at startup and claimed "WIRED", while nothing in `lib/` fed it a
/// single window. This class closes that gap.
///
/// ## Why it gates on silence and does not queue
///
/// The 38-feature path runs a mel/MFCC pass, an RMS pass, an autocorrelation
/// and a full YIN pitch track over a 3 s clip — materially more work per
/// window than the scream detector's single mel. Two consequences:
///
/// * **Silence is skipped.** Vocal stress on a silent window is meaningless,
///   and the pitch track is the most expensive part of the whole app.
/// * **Windows are dropped, not queued, while busy.** Falling behind on a
///   live audio stream and then reporting stress from ten seconds ago is
///   worse than reporting nothing: the DCS fusion timestamps what it reads.
///
/// Both mirror [ScreamAudioPipeline], which reached the same conclusions for
/// a cheaper model.
///
/// ## What it does not do
///
/// It does **not** submit to the backend. `_submit` in
/// `live_detection_providers.dart` gates on
/// `InferenceResult.confidenceThreshold` (0.7), and vocal stress is a
/// *contributing* signal whose honest expectation is ~0.80 AUC in English
/// and ~0.63 in Mandarin (see `assets/models/DAY338_SPLIT_SENSITIVITY.md`).
/// Wiring it to submit events on its own would put a weak signal in the
/// user's feed; feeding a fusion is what it is for.
class VocalStressPipeline {
  /// Below this RMS the window is treated as silence and skipped.
  ///
  /// Matches `ScreamAudioPipeline.kSilenceRms` deliberately: both read the
  /// same microphone through the same [PcmWindow], so disagreeing about what
  /// counts as silence would mean one model analysing windows the other
  /// discarded.
  static const double kSilenceRms = 0.005;

  final VocalStressDetector detector;
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
  double _maxStress = 0;
  InferenceResult? _latest;

  VocalStressPipeline({
    required this.detector,
    required this.windows,
    this.gateOnSilence = true,
  });

  Stream<InferenceResult> get results => _results.stream;

  /// The most recent inference, for a fusion to read without subscribing.
  InferenceResult? get latestResult => _latest;

  bool get isActive => _sub != null;
  int get windowsIn => _windowsIn;
  int get inferences => _inferences;
  int get droppedSilent => _droppedSilent;
  int get droppedBusy => _droppedBusy;
  int get droppedUnusable => _droppedUnusable;
  int get maxLatencyMs => _maxLatencyMs;
  double get maxStressScore => _maxStress;

  void start() {
    if (_sub != null) return;
    _sub = windows.listen(_onWindow, onError: (Object e, StackTrace st) {
      if (kDebugMode) debugPrint('[VocalStressPipeline] stream error: $e');
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _results.close();
  }

  Future<void> _onWindow(PcmWindow window) async {
    _windowsIn++;

    if (!window.isUsable) {
      _droppedUnusable++;
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
      final pcm =
          window.samples(targetRateHz: VocalStressFeatures.kSampleRate);
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
      // The detector's classLabels are ['calm', 'stressed'], so this key
      // exists. Named explicitly rather than defensively: a `?? 0.0` on a
      // key that does not exist is exactly how DCSScoreWatcher read
      // 'scream' from a safe/danger fusion for months without anything
      // failing (Day 335).
      final stress = result.classScores['stressed'] ?? 0.0;
      if (stress > _maxStress) _maxStress = stress;
      _latest = result;
      if (!_results.isClosed) _results.add(result);
    } catch (e, st) {
      // A single bad window must not tear down the audio pipeline.
      if (kDebugMode) {
        debugPrint('[VocalStressPipeline] inference failed: $e\n$st');
      }
    } finally {
      _busy = false;
    }
  }
}
