import 'package:flutter/foundation.dart';

/// Day 34 — stats over a series of latency samples (all in ms).
@immutable
class LatencyStats {
  final int count;
  final int minMs;
  final int p50Ms;
  final int p95Ms;
  final int maxMs;
  final int meanMs;

  const LatencyStats({
    required this.count,
    required this.minMs,
    required this.p50Ms,
    required this.p95Ms,
    required this.maxMs,
    required this.meanMs,
  });

  static const empty = LatencyStats(
    count: 0, minMs: 0, p50Ms: 0, p95Ms: 0, maxMs: 0, meanMs: 0,
  );

  /// Day 34 budget: full DCS cycle ≤ 450 ms on LITE devices (the audio
  /// capture cadence). [meanMs] crossing this means the pipeline is
  /// falling behind real-time on the test hardware.
  static const int budgetMs = 450;

  /// True when [p95Ms] sits inside [budgetMs] — 95% of inferences must
  /// clear the bar, not just the average.
  bool get isWithinBudget => count > 0 && p95Ms <= budgetMs;
}

/// Day 34 — measures wall-clock time of repeated async operations and
/// exposes min / p50 / p95 / max / mean. Pure Dart, isolate-safe (no
/// platform channels), easy to unit-test.
class LatencyProfiler {
  final List<int> _samplesMs = [];

  /// Wraps an async call with a stopwatch and records the result.
  /// Returns whatever [fn] returned so the call site can stay one-liner:
  ///   `final score = await profiler.measure(() => engine.infer(...));`
  Future<T> measure<T>(Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      sw.stop();
      _samplesMs.add(sw.elapsedMilliseconds);
    }
  }

  /// Record an explicit sample. Useful when timing was done elsewhere
  /// (e.g. inside `compute()` and shipped back).
  void record(int latencyMs) {
    if (latencyMs < 0) return;
    _samplesMs.add(latencyMs);
  }

  /// Immutable snapshot of all collected samples in ms.
  List<int> get samplesMs => List.unmodifiable(_samplesMs);

  /// Total samples recorded.
  int get sampleCount => _samplesMs.length;

  /// Computes percentile statistics. Returns [LatencyStats.empty] before
  /// any sample is recorded.
  LatencyStats get stats {
    if (_samplesMs.isEmpty) return LatencyStats.empty;
    final sorted = [..._samplesMs]..sort();
    final n = sorted.length;
    final sum = sorted.fold<int>(0, (a, b) => a + b);
    return LatencyStats(
      count: n,
      minMs:  sorted.first,
      maxMs:  sorted.last,
      // Using ~/ for percentile index; for n=1 every index collapses to 0.
      p50Ms:  sorted[(n - 1) ~/ 2],
      p95Ms:  sorted[((n - 1) * 95) ~/ 100],
      meanMs: sum ~/ n,
    );
  }

  void reset() => _samplesMs.clear();
}
