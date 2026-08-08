import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/ml/inference/latency_profiler.dart';

void main() {
  group('LatencyProfiler · empty state', () {
    test('stats default to LatencyStats.empty when no samples recorded', () {
      final p = LatencyProfiler();
      expect(p.sampleCount, 0);
      expect(p.stats.count, 0);
      expect(p.stats.minMs, 0);
      expect(p.stats.maxMs, 0);
      expect(p.stats.meanMs, 0);
      expect(p.stats.isWithinBudget, isFalse,
          reason: 'an empty profiler does not assert anything about budget');
    });
  });

  group('LatencyProfiler · record / stats', () {
    test('single sample → all stats equal that sample', () {
      final p = LatencyProfiler()..record(42);
      final s = p.stats;
      expect(s.count, 1);
      expect(s.minMs, 42);
      expect(s.maxMs, 42);
      expect(s.p50Ms, 42);
      expect(s.p95Ms, 42);
      expect(s.meanMs, 42);
    });

    test('computes percentiles on a sorted distribution', () {
      // 10 samples: 1, 2, 3, …, 10
      final p = LatencyProfiler();
      for (var i = 1; i <= 10; i++) {
        p.record(i);
      }
      final s = p.stats;
      expect(s.count, 10);
      expect(s.minMs, 1);
      expect(s.maxMs, 10);
      // For a 10-sample list [1..10], indices 0..9:
      //   p50 = sorted[(9 ~/ 2)] = sorted[4] = 5
      //   p95 = sorted[((9 * 95) ~/ 100)] = sorted[8] = 9
      expect(s.p50Ms, 5);
      expect(s.p95Ms, 9);
      expect(s.meanMs, 5);
    });

    test('rejects negative samples', () {
      final p = LatencyProfiler()..record(-5)..record(10);
      expect(p.sampleCount, 1);
      expect(p.stats.minMs, 10);
    });

    test('order of insertion does not affect percentiles', () {
      final a = LatencyProfiler()..record(3)..record(1)..record(2);
      final b = LatencyProfiler()..record(1)..record(2)..record(3);
      expect(a.stats.minMs, b.stats.minMs);
      expect(a.stats.maxMs, b.stats.maxMs);
      expect(a.stats.p50Ms, b.stats.p50Ms);
      expect(a.stats.meanMs, b.stats.meanMs);
    });

    test('reset clears all samples', () {
      final p = LatencyProfiler()..record(1)..record(2)..record(3);
      expect(p.sampleCount, 3);
      p.reset();
      expect(p.sampleCount, 0);
      expect(p.stats.count, 0);
    });

    test('samplesMs is an unmodifiable view', () {
      final p = LatencyProfiler()..record(1)..record(2);
      final view = p.samplesMs;
      expect(() => view.add(99), throwsA(isA<UnsupportedError>()));
    });
  });

  group('LatencyProfiler · measure() wraps async work', () {
    test('returns the inner result + records elapsed time', () async {
      final p = LatencyProfiler();
      final result = await p.measure<int>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return 7;
      });
      expect(result, 7);
      expect(p.sampleCount, 1);
      expect(p.samplesMs.first, greaterThanOrEqualTo(0),
          reason: 'stopwatch is monotonic, samples are non-negative');
    });

    test('records the sample even when the inner function throws', () async {
      final p = LatencyProfiler();
      await expectLater(
        p.measure<int>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1));
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(p.sampleCount, 1,
          reason: 'try/finally records the sample on the failure path too');
    });
  });

  group('LatencyStats · budget gate', () {
    test('budgetMs is 450 — matches the DCS capture cadence', () {
      expect(LatencyStats.budgetMs, 450);
    });

    test('isWithinBudget requires p95 ≤ budget', () {
      const within = LatencyStats(
          count: 5, minMs: 1, p50Ms: 10, p95Ms: 449, maxMs: 500, meanMs: 12);
      const over = LatencyStats(
          count: 5, minMs: 1, p50Ms: 10, p95Ms: 451, maxMs: 500, meanMs: 12);
      expect(within.isWithinBudget, isTrue);
      expect(over.isWithinBudget, isFalse);
    });

    test('isWithinBudget is false when count == 0 (no samples → no claim)', () {
      const empty = LatencyStats.empty;
      expect(empty.isWithinBudget, isFalse);
    });
  });
}
