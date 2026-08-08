import 'package:flutter/foundation.dart';

import '../../data/models/dcs_score.dart';
import '../../data/models/motion_features.dart';
import '../../data/services/interpreter.dart';
import '../../native/audio_features.dart';
import 'dcs_inference_engine.dart';

/// Day 34 — input to the isolated runner.
///
/// Designed to be sendable across isolate boundaries (Flutter's
/// `compute()` uses the standard message-codec, which accepts immutable
/// classes of primitive fields). Both [AudioFeatures] and
/// [MotionFeatures] are immutable + primitive-only.
@immutable
class IsolatedInferenceInput {
  final AudioFeatures audio;
  final MotionFeatures motion;
  const IsolatedInferenceInput({required this.audio, required this.motion});
}

/// Day 34 — runs the DCS inference cycle on a worker isolate so the UI
/// thread (and the audio capture thread, on Android) never blocks on
/// math-heavy work.
///
/// Pattern: per-call `compute()`. Each call spawns a fresh worker
/// isolate, constructs a stub engine (cheap — pure Dart), runs inference,
/// and returns the [DCSScore]. The worker tears down after.
///
/// **Known limitation (real TFLite, not stubs)**:
/// `tflite_flutter`'s `Interpreter` wraps native FFI pointers and cannot
/// cross isolate boundaries. Today the runner ALWAYS uses the pure-Dart
/// stub engines — even when the main isolate has a real
/// `TfliteInterpreter` loaded. When the real `.tflite` files land in
/// Month 3 we'll upgrade this to a long-lived worker isolate that owns
/// its own `Interpreter` (one-time spawn + persistent `SendPort` rather
/// than the current per-call spawn). For now, every isolated inference
/// is a stub inference.
class IsolatedDcsRunner {
  /// Run one inference on a worker isolate. Always falls back to stubs.
  /// Latency includes isolate-spawn overhead (~1-3 ms on a real device).
  Future<DCSScore> infer(IsolatedInferenceInput input) {
    return compute(_runInferenceInIsolate, input);
  }
}

/// Top-level so `compute()` can find it. Constructs a fresh stub engine
/// inside the worker isolate, runs one inference, returns the score.
///
/// Worker isolates can't see the main isolate's [DCSInferenceEngine]
/// instance, so we build a parallel set of pure-Dart interpreters here.
Future<DCSScore> _runInferenceInIsolate(IsolatedInferenceInput input) async {
  final engine = DCSInferenceEngine.fromInterpreters(
    scream: EnergyStubInterpreter(),
    motion: const FixedStubInterpreter(
      modelLabel: 'iso-stub-motion',
      expectedInputSize: 6,
      classLabels: ['normal', 'unusual', 'fall'],
      label: 'normal',
      score: 0.15,
    ),
    scene: const FixedStubInterpreter(
      modelLabel: 'iso-stub-scene',
      expectedInputSize: 8,
      classLabels: ['indoor', 'outdoor', 'transit'],
      label: 'indoor',
      score: 0.25,
    ),
    fusion: LinearStubInterpreter(
      modelLabel: 'iso-stub-fusion',
      weights: const [0.5, 0.3, 0.2],
    ),
  );
  final result = await engine.infer(
    audio: input.audio,
    motion: input.motion,
  );
  await engine.dispose();
  return result;
}
