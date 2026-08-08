import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/services/audio_feature_service.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';

/// Recording double — captures every infer() call so tests can assert
/// against the exact sequence the service handed to the interpreter.
class _RecordingInterpreter implements Interpreter {
  final List<({Float32List tensor, int timestampMs})> calls = [];
  final InferenceResult Function(Float32List, int) build;

  bool disposed = false;
  _RecordingInterpreter(this.build);

  @override
  String get modelLabel => 'recording';

  @override
  int get expectedInputSize => 15;

  @override
  List<String> get classLabels => const ['normal', 'shout', 'scream'];

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    calls.add((tensor: features, timestampMs: timestampMs));
    return build(features, timestampMs);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// Builds a synthetic AudioFeatures (15 floats: 13 MFCC + ZCR + centroid).
AudioFeatures _frame({
  int ts = 0,
  double centroid = 1500,
  double zcr = 0.1,
}) {
  return AudioFeatures(
    timestampMs: ts,
    mfcc: const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    zcr: zcr,
    spectralCentroidHz: centroid,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioFeatureService · dispatch', () {
    test('feeds every feature frame to the interpreter', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1));
      controller.add(_frame(ts: 2));
      controller.add(_frame(ts: 3));
      await controller.close();
      // Flush async listeners.
      await Future.delayed(Duration.zero);

      expect(rec.calls.length, 3);
      expect(rec.calls.map((c) => c.timestampMs).toList(), [1, 2, 3]);
      expect(svc.framesIn, 3);
      expect(svc.inferencesOut, 3);
      await svc.dispose();
    });

    test('triggers fire when result clears confidence threshold', () async {
      final controller = StreamController<AudioFeatures>();
      var n = 0;
      final rec = _RecordingInterpreter((tensor, ts) {
        // First call returns 0.5, second 0.8, third 0.9.
        n++;
        final scores = [0.5, 0.8, 0.9];
        final s = scores[n - 1];
        return InferenceResult(
          label: 'scream',
          score: s,
          classScores: {'scream': s},
          latencyMs: 1,
          timestampMs: ts,
        );
      });
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1));
      controller.add(_frame(ts: 2));
      controller.add(_frame(ts: 3));
      await controller.close();
      await Future.delayed(Duration.zero);

      expect(svc.framesIn, 3);
      expect(svc.triggersFired, 2,
          reason: '0.8 and 0.9 are >= 0.7, 0.5 is not');
      expect(svc.maxScore, closeTo(0.9, 1e-9));
      await svc.dispose();
    });

    test('drops frame when tensor shape mismatches expected input size',
        () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      // expectedInputSize = 15. Build a frame with empty mfcc → dimension = 2.
      const undersized = AudioFeatures(
        timestampMs: 1,
        mfcc: [],
        zcr: 0,
        spectralCentroidHz: 0,
      );
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(undersized);
      await controller.close();
      await Future.delayed(Duration.zero);

      expect(rec.calls, isEmpty,
          reason: 'service should never have called the interpreter');
      expect(svc.framesIn, 1);
      expect(svc.inferencesOut, 0);
      await svc.dispose();
    });

    test('survives interpreter exception and keeps processing', () async {
      final controller = StreamController<AudioFeatures>();
      var n = 0;
      final rec = _RecordingInterpreter((tensor, ts) {
        n++;
        if (n == 1) throw 'kaboom';
        return InferenceResult(
          label: 'normal',
          score: 0.1,
          classScores: const {'normal': 0.1},
          latencyMs: 1,
          timestampMs: ts,
        );
      });
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1));
      controller.add(_frame(ts: 2));
      await controller.close();
      await Future.delayed(Duration.zero);

      // Both frames were dispatched to the interpreter (call count = 2),
      // but only the second produced an inference result.
      expect(rec.calls.length, 2);
      expect(svc.framesIn, 2);
      expect(svc.inferencesOut, 1);
      await svc.dispose();
    });

    test('Day 30 · cadence EMA settles toward the source interval', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      // Feed three frames 450 ms apart by timestamp.
      controller.add(_frame(ts: 1000));
      controller.add(_frame(ts: 1450));
      controller.add(_frame(ts: 1900));
      await controller.close();
      await Future.delayed(Duration.zero);
      // Two deltas (450, 450) → EMA = 450.
      expect(svc.meanFrameIntervalMs, closeTo(450, 1e-6));
      await svc.dispose();
    });

    test('Day 30 · cadence EMA is 0 before two frames arrive', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1000));
      await controller.close();
      await Future.delayed(Duration.zero);
      expect(svc.meanFrameIntervalMs, 0);
      await svc.dispose();
    });

    test('Day 30 · end-to-end latency populated after first inference',
        () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      // Use a recent timestamp so the e2e latency comes out as a small
      // positive number rather than a huge one from epoch.
      final now = DateTime.now().millisecondsSinceEpoch;
      controller.add(_frame(ts: now));
      await controller.close();
      await Future.delayed(Duration.zero);
      // Last e2e should be small (microseconds in test, rounded to ms).
      expect(svc.lastEndToEndLatencyMs, lessThan(500));
      expect(svc.maxEndToEndLatencyMs >= svc.lastEndToEndLatencyMs, isTrue);
      await svc.dispose();
    });

    test('Day 30 · endToEndBudgetMs == 530', () {
      expect(AudioFeatureService.endToEndBudgetMs, 530);
    });

    test('Day 30 · resetStats clears cadence + e2e', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0,
            classScores: const {},
            latencyMs: 0,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1000));
      controller.add(_frame(ts: 1450));
      await controller.close();
      await Future.delayed(Duration.zero);
      expect(svc.meanFrameIntervalMs > 0, isTrue);
      svc.resetStats();
      expect(svc.meanFrameIntervalMs, 0);
      expect(svc.lastEndToEndLatencyMs, 0);
      expect(svc.maxEndToEndLatencyMs, 0);
      await svc.dispose();
    });

    test('resetStats clears every counter', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'scream',
            score: 0.8,
            classScores: const {'scream': 0.8},
            latencyMs: 5,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      controller.add(_frame(ts: 1));
      controller.add(_frame(ts: 2));
      await controller.close();
      await Future.delayed(Duration.zero);

      expect(svc.framesIn, 2);
      expect(svc.triggersFired, 2);
      svc.resetStats();
      expect(svc.framesIn, 0);
      expect(svc.inferencesOut, 0);
      expect(svc.triggersFired, 0);
      expect(svc.maxScore, 0);
      await svc.dispose();
    });

    test('start is idempotent — calling twice does not double-subscribe',
        () async {
      final controller = StreamController<AudioFeatures>.broadcast();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0.1,
            classScores: const {'normal': 0.1},
            latencyMs: 1,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      svc.start(); // no-op
      controller.add(_frame(ts: 1));
      await Future.delayed(Duration.zero);
      // Only one call despite two start() invocations.
      expect(rec.calls.length, 1);
      await svc.dispose();
      await controller.close();
    });

    test('dispose disposes the interpreter', () async {
      final controller = StreamController<AudioFeatures>();
      final rec = _RecordingInterpreter((tensor, ts) => InferenceResult(
            label: 'normal',
            score: 0,
            classScores: const {},
            latencyMs: 0,
            timestampMs: ts,
          ));
      final svc = AudioFeatureService(
        interpreter: rec,
        featureStream: controller.stream,
      );
      svc.start();
      await svc.dispose();
      expect(rec.disposed, isTrue);
      await controller.close();
    });
  });

  group('InferenceResult', () {
    test('isConfident respects the static threshold (0.7)', () {
      const below = InferenceResult(
        label: 'scream', score: 0.69, classScores: {},
        latencyMs: 0, timestampMs: 0,
      );
      const at = InferenceResult(
        label: 'scream', score: 0.7, classScores: {},
        latencyMs: 0, timestampMs: 0,
      );
      const above = InferenceResult(
        label: 'scream', score: 0.71, classScores: {},
        latencyMs: 0, timestampMs: 0,
      );
      expect(below.isConfident, isFalse);
      expect(at.isConfident, isTrue);
      expect(above.isConfident, isTrue);
    });

    test('severity tiers map correctly to score bands', () {
      InferenceResult r(double s) => InferenceResult(
            label: 'x', score: s, classScores: const {},
            latencyMs: 0, timestampMs: 0,
          );
      expect(r(0.1).severity, InferenceSeverity.none);
      expect(r(0.4).severity, InferenceSeverity.low);
      expect(r(0.7).severity, InferenceSeverity.medium);
      expect(r(0.85).severity, InferenceSeverity.high);
      expect(r(1.0).severity, InferenceSeverity.high);
    });
  });

  group('EnergyStubInterpreter', () {
    test('returns valid softmax distribution', () async {
      final i = EnergyStubInterpreter();
      final result = await i.infer(
        Float32List.fromList(List.filled(15, 0.0)),
        timestampMs: 100,
      );
      // Class scores sum to 1.0 (softmax invariant).
      final sum = result.classScores.values.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-6));
      expect(result.timestampMs, 100);
      expect(i.classLabels, ['normal', 'shout', 'scream']);
    });

    test('higher-energy inputs push the scream score higher', () async {
      final i = EnergyStubInterpreter();
      final lowEnergy = Float32List(15);  // all zeros — quiet
      final highEnergy = Float32List(15);
      highEnergy[0] = 0.0;    // mfcc[0] high
      highEnergy[13] = 0.5;   // ZCR high
      highEnergy[14] = 4000;  // centroid high
      final a = await i.infer(lowEnergy, timestampMs: 1);
      final b = await i.infer(highEnergy, timestampMs: 2);
      expect((b.classScores['scream'] ?? 0) >
          (a.classScores['scream'] ?? 0), isTrue);
    });

    test('rejects undersized tensors with ArgumentError', () async {
      final i = EnergyStubInterpreter();
      await expectLater(
        i.infer(Float32List(5), timestampMs: 0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
