/// Day 49 — Audio Pipeline unit tests.
///
/// Validates the data models and service logic that power the audio pipeline
/// validation screen:
///   - AudioFeatures construction, tensor layout, field values
///   - AudioFeatureService stats (framesIn, triggersFired, maxScore, averageLatency)
///   - HeuristicScreamDetector used as the pipeline interpreter
///   - InferenceResult confidence / severity thresholds
///   - Confidence history logic (rolling window behaviour)
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/inference_result.dart';
import 'package:zapsafe_mobile/data/services/audio_feature_service.dart';
import 'package:zapsafe_mobile/data/services/heuristic_scream_detector.dart';
import 'package:zapsafe_mobile/data/services/interpreter.dart';
import 'package:zapsafe_mobile/native/audio_features.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

AudioFeatures _screamAudioFeatures() => AudioFeatures(
      timestampMs: 1000,
      mfcc: List.generate(13, (i) => i == 0 ? -5.0 : 0.0),
      zcr: 0.35,
      spectralCentroidHz: 4000.0,
    );

AudioFeatures _silentAudioFeatures() => AudioFeatures(
      timestampMs: 2000,
      mfcc: List.generate(13, (i) => i == 0 ? -80.0 : 0.0),
      zcr: 0.01,
      spectralCentroidHz: 200.0,
    );

/// Creates an [AudioFeatureService] backed by a single-event stream.
AudioFeatureService _serviceWith(List<AudioFeatures> frames,
    {Interpreter? interpreter}) {
  final ctrl = StreamController<AudioFeatures>();
  final svc = AudioFeatureService(
    interpreter: interpreter ?? const HeuristicScreamDetector(),
    featureStream: ctrl.stream,
  );
  svc.start();
  for (final f in frames) {
    ctrl.add(f);
  }
  ctrl.close();
  return svc;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── 1. AudioFeatures model ─────────────────────────────────────────────
  group('AudioFeatures model', () {
    test('fields are preserved', () {
      final f = _screamAudioFeatures();
      expect(f.mfcc.length, equals(13));
      expect(f.mfcc[0], equals(-5.0));
      expect(f.zcr, equals(0.35));
      expect(f.spectralCentroidHz, equals(4000.0));
      expect(f.timestampMs, equals(1000));
    });

    test('toFloat32Tensor has 15 elements (13 MFCC + ZCR + centroid)', () {
      final tensor = _screamAudioFeatures().toFloat32Tensor();
      expect(tensor.length, equals(15));
      expect(tensor, isA<Float32List>());
    });

    test('tensor layout: [0..12]=MFCC, [13]=ZCR, [14]=centroid', () {
      final f = _screamAudioFeatures();
      final t = f.toFloat32Tensor();
      expect(t[0],  closeTo(f.mfcc[0], 0.001));
      expect(t[12], closeTo(f.mfcc[12], 0.001));
      expect(t[13], closeTo(f.zcr, 0.001));
      expect(t[14], closeTo(f.spectralCentroidHz, 0.001));
    });

    test('silent features have low mfcc[0] and low ZCR', () {
      final f = _silentAudioFeatures();
      expect(f.mfcc[0], lessThan(-20.0));
      expect(f.zcr, lessThan(0.05));
    });
  });

  // ── 2. HeuristicScreamDetector via tensor ─────────────────────────────
  group('HeuristicScreamDetector via AudioFeatures tensor', () {
    const detector = HeuristicScreamDetector();

    test('scream features tensor → score > 0.5', () async {
      final tensor = _screamAudioFeatures().toFloat32Tensor();
      final result = await detector.infer(tensor, timestampMs: 1000);
      expect(result.score, greaterThan(0.5));
    });

    test('silent features tensor → scream classScore < 0.1', () async {
      final tensor = _silentAudioFeatures().toFloat32Tensor();
      final result = await detector.infer(tensor, timestampMs: 2000);
      expect(result.classScores['scream'] ?? 0.0, lessThan(0.1));
    });

    test('expectedInputSize matches tensor length', () {
      final tensorLen = _screamAudioFeatures().toFloat32Tensor().length;
      expect(detector.expectedInputSize, equals(tensorLen));
    });
  });

  // ── 3. AudioFeatureService stats ──────────────────────────────────────
  group('AudioFeatureService stats', () {
    test('framesIn increments per frame', () async {
      final svc = _serviceWith([
        _screamAudioFeatures(),
        _silentAudioFeatures(),
      ]);
      // Let the async stream drain
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(svc.framesIn, equals(2));
      svc.dispose();
    });

    test('triggersFired counts confident results', () async {
      // Scream features should fire the trigger (score ≥ 0.7)
      final svc = _serviceWith([
        _screamAudioFeatures(),
        _screamAudioFeatures(),
        _silentAudioFeatures(),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(svc.triggersFired, greaterThanOrEqualTo(1));
      svc.dispose();
    });

    test('maxScore is max of all seen scores', () async {
      final svc = _serviceWith([_screamAudioFeatures()]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(svc.maxScore, greaterThan(0.0));
      expect(svc.maxScore, lessThanOrEqualTo(1.0));
      svc.dispose();
    });

    test('averageLatency is non-negative after frames', () async {
      final svc = _serviceWith([
        _screamAudioFeatures(),
        _silentAudioFeatures(),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(svc.averageLatency.inMilliseconds, greaterThanOrEqualTo(0));
      svc.dispose();
    });

    test('isActive true after start, false after dispose', () async {
      final ctrl = StreamController<AudioFeatures>();
      final svc = AudioFeatureService(
        interpreter: const HeuristicScreamDetector(),
        featureStream: ctrl.stream,
      );
      svc.start();
      expect(svc.isActive, isTrue);
      svc.dispose();
      await ctrl.close();
      expect(svc.isActive, isFalse);
    });

    test('inferencesOut equals framesIn in steady state', () async {
      final svc = _serviceWith([
        _screamAudioFeatures(),
        _silentAudioFeatures(),
        _screamAudioFeatures(),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(svc.inferencesOut, equals(svc.framesIn));
      svc.dispose();
    });
  });

  // ── 4. Confidence history window logic ────────────────────────────────
  group('Confidence history window', () {
    test('history stays at most historyLen items', () {
      const historyLen = 20;
      final history = <double>[];
      for (var i = 0; i < 30; i++) {
        history.add(i / 30.0);
        if (history.length > historyLen) history.removeAt(0);
      }
      expect(history.length, equals(historyLen));
    });

    test('most recent value is last in list', () {
      const historyLen = 5;
      final history = <double>[];
      for (var i = 0; i < historyLen; i++) {
        history.add(i.toDouble());
        if (history.length > historyLen) history.removeAt(0);
      }
      expect(history.last, equals((historyLen - 1).toDouble()));
    });

    test('clamp keeps history values in [0,1]', () {
      final rawScores = [0.0, 0.5, 1.0, 1.5, -0.1];
      final clamped = rawScores.map((v) => v.clamp(0.0, 1.0)).toList();
      for (final v in clamped) {
        expect(v, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  // ── 5. InferenceResult thresholds used by screen ──────────────────────
  group('InferenceResult thresholds', () {
    InferenceResult r(double score) => InferenceResult(
          label: 'scream',
          score: score,
          classScores: {'scream': score, 'normal': 1 - score},
          latencyMs: 1,
          timestampMs: 0,
        );

    test('score 0.70 → isConfident=true, trigger fires', () {
      expect(r(0.70).isConfident, isTrue);
    });

    test('score 0.69 → isConfident=false, no trigger', () {
      expect(r(0.69).isConfident, isFalse);
    });

    test('severity high ≥ 0.85', () {
      expect(r(0.85).severity, InferenceSeverity.high);
    });

    test('severity medium 0.70–0.84', () {
      expect(r(0.72).severity, InferenceSeverity.medium);
    });

    test('severity low 0.40–0.69', () {
      expect(r(0.50).severity, InferenceSeverity.low);
    });

    test('severity none < 0.40', () {
      expect(r(0.30).severity, InferenceSeverity.none);
    });
  });
}
