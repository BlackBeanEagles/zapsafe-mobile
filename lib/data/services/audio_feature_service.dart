import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inference_result.dart';
import '../../native/audio_features.dart';
import 'interpreter.dart';

/// Day 29 — Flutter-side orchestrator for the feature → inference pipeline.
///
/// Subscribes to a `Stream<AudioFeatures>` (Day 27's feature stream), runs
/// each vector through an injected [Interpreter], and exposes the inference
/// results as a broadcast stream. Maintains lightweight aggregate stats so
/// the Day 29 screen can show "frames processed / triggers fired / max
/// confidence" without re-deriving them in the UI layer.
///
/// The interpreter is injected rather than constructed internally, so:
///   • The Day 29 screen uses an [EnergyStubInterpreter] by default
///   • Tests can pass a [FixedStubInterpreter] or a recording double
///   • Day 31 plugs in the real TFLite interpreter via the same seam
class AudioFeatureService {
  final Interpreter interpreter;
  final Stream<AudioFeatures> _featureStream;

  StreamSubscription<AudioFeatures>? _sub;
  final _resultController = StreamController<InferenceResult>.broadcast();

  // ── Aggregate stats ──────────────────────────────────────────────────────
  int _framesIn = 0;
  int _inferencesOut = 0;
  int _triggersFired = 0;
  double _maxScore = 0;
  Duration _totalLatency = Duration.zero;

  // ── Day 30 · cadence + end-to-end latency tracking ──────────────────────
  int? _previousFrameTimestampMs;
  double _meanIntervalMs = 0;
  int _lastEndToEndLatencyMs = 0;
  int _maxEndToEndLatencyMs = 0;
  static const _emaAlpha = 0.25; // smoothing for the running mean

  AudioFeatureService({
    required this.interpreter,
    required Stream<AudioFeatures> featureStream,
  }) : _featureStream = featureStream;

  /// Broadcast stream of [InferenceResult]. Multiple listeners are safe.
  Stream<InferenceResult> get results => _resultController.stream;

  /// True while the subscription is active.
  bool get isActive => _sub != null;

  // ── Stats ────────────────────────────────────────────────────────────────

  /// Number of feature frames received from the source stream.
  int get framesIn => _framesIn;

  /// Number of inferences completed. Should equal [framesIn] in steady
  /// state — if it's lower, the interpreter is being thrown at faster than
  /// it can keep up (a regression signal worth surfacing).
  int get inferencesOut => _inferencesOut;

  /// Inferences that cleared [InferenceResult.confidenceThreshold].
  int get triggersFired => _triggersFired;

  /// Top score seen since the last [resetStats].
  double get maxScore => _maxScore;

  /// Average inference latency across the run.
  Duration get averageLatency {
    if (_inferencesOut == 0) return Duration.zero;
    return Duration(microseconds:
        _totalLatency.inMicroseconds ~/ _inferencesOut);
  }

  // ── Day 30 · cadence + end-to-end latency exposures ─────────────────────

  /// EMA of the inter-frame gap (ms). Returns 0 before two frames have
  /// arrived. Target: ~450 ms (matches the native capture window).
  double get meanFrameIntervalMs => _meanIntervalMs;

  /// End-to-end latency of the most recent frame (ms), measured from the
  /// native-side capture timestamp to the moment inference completed on
  /// the Dart side.
  int get lastEndToEndLatencyMs => _lastEndToEndLatencyMs;

  /// Worst end-to-end latency seen since [resetStats].
  int get maxEndToEndLatencyMs => _maxEndToEndLatencyMs;

  /// Day 30 budget: capture cadence ~450 ms, inference latency target
  /// < 80 ms ⇒ end-to-end budget = 450 + 80 = 530 ms ceiling. UI surfaces
  /// flag anything above this as a budget regression.
  static const int endToEndBudgetMs = 530;

  /// True when the most recent end-to-end measurement was within budget.
  bool get isWithinE2eBudget =>
      _lastEndToEndLatencyMs > 0 &&
      _lastEndToEndLatencyMs <= endToEndBudgetMs;

  void resetStats() {
    _framesIn = 0;
    _inferencesOut = 0;
    _triggersFired = 0;
    _maxScore = 0;
    _totalLatency = Duration.zero;
    _previousFrameTimestampMs = null;
    _meanIntervalMs = 0;
    _lastEndToEndLatencyMs = 0;
    _maxEndToEndLatencyMs = 0;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Subscribe to the feature stream and start dispatching to the
  /// interpreter. Idempotent — calling twice without a [stop] in between is
  /// a no-op.
  void start() {
    if (_sub != null) return;
    _sub = _featureStream.listen(
      _handleFrame,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) debugPrint('[audio-feature-svc] stream error: $e');
      },
    );
  }

  /// Cancel the subscription. Does not [dispose] — the service can be
  /// restarted with [start].
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Cancel and release. Safe to call multiple times.
  Future<void> dispose() async {
    await stop();
    await _resultController.close();
    await interpreter.dispose();
  }

  // ── Internals ────────────────────────────────────────────────────────────

  Future<void> _handleFrame(AudioFeatures features) async {
    _framesIn++;

    // Day 30 — track frame-to-frame cadence. Uses native capture timestamps
    // so the figure isn't polluted by Dart scheduler jitter.
    final prev = _previousFrameTimestampMs;
    if (prev != null && features.timestampMs > prev) {
      final delta = (features.timestampMs - prev).toDouble();
      _meanIntervalMs = _meanIntervalMs == 0
          ? delta
          : (_emaAlpha * delta + (1 - _emaAlpha) * _meanIntervalMs);
    }
    _previousFrameTimestampMs = features.timestampMs;

    final tensor = features.toFloat32Tensor();

    // Defensive: if the interpreter expects more inputs than the current
    // tensor has, skip this frame instead of crashing the pipeline. This
    // lets us swap models with different input shapes without taking down
    // the audio path.
    if (tensor.length != interpreter.expectedInputSize) {
      if (kDebugMode) {
        debugPrint(
          '[audio-feature-svc] dropped frame · expected '
          '${interpreter.expectedInputSize} inputs, got ${tensor.length}',
        );
      }
      return;
    }

    InferenceResult result;
    try {
      result = await interpreter.infer(tensor, timestampMs: features.timestampMs);
    } catch (e) {
      if (kDebugMode) debugPrint('[audio-feature-svc] inference threw: $e');
      return;
    }

    _inferencesOut++;
    _totalLatency += Duration(milliseconds: result.latencyMs);
    if (result.score > _maxScore) _maxScore = result.score;
    if (result.isConfident) _triggersFired++;

    // Day 30 — end-to-end latency (capture → inference complete).
    // Best-effort: relies on the device clock matching the dart isolate's;
    // both come from `System.currentTimeMillis()` / `Date()` so they agree.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _lastEndToEndLatencyMs = (nowMs - features.timestampMs);
    if (_lastEndToEndLatencyMs < 0) _lastEndToEndLatencyMs = 0;
    if (_lastEndToEndLatencyMs > _maxEndToEndLatencyMs) {
      _maxEndToEndLatencyMs = _lastEndToEndLatencyMs;
    }

    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }
}
