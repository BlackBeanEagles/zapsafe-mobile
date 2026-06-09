import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../models/inference_result.dart';
import 'interpreter.dart';

/// Day 31 — real `tflite_flutter`-backed interpreter.
///
/// Wraps `tflite_flutter`'s native FFI bindings. Constructed via the static
/// [tryLoad] factory which:
///
///   1. Attempts `tfl.Interpreter.fromAsset(assetPath)`
///   2. On success, validates input shape matches [expectedInputSize]
///   3. On any failure (missing model, malformed bytes, dim mismatch, host
///      VM with no native lib) returns null so callers can fall back to
///      [EnergyStubInterpreter].
///
/// The fallback contract is the whole point of the seam — Day 31 ships
/// placeholder `.tflite` files that intentionally fail to load. When
/// backend training drops the real binaries into `assets/models/` in
/// Month 3, the exact same code path starts succeeding without any
/// caller-side change.
class TfliteInterpreter implements Interpreter {
  final tfl.Interpreter _interpreter;

  @override
  final String modelLabel;

  @override
  final int expectedInputSize;

  @override
  final List<String> classLabels;

  TfliteInterpreter._({
    required tfl.Interpreter interpreter,
    required this.modelLabel,
    required this.expectedInputSize,
    required this.classLabels,
  }) : _interpreter = interpreter;

  /// Attempt to construct a real interpreter from a TFLite asset.
  /// Returns null on any failure — caller falls back to the stub.
  static Future<TfliteInterpreter?> tryLoad({
    required String assetPath,
    required String modelLabel,
    int expectedInputSize = 15,
    List<String> classLabels = const ['normal', 'shout', 'scream'],
  }) async {
    try {
      final interpreter = await tfl.Interpreter.fromAsset(assetPath);
      // Sanity-check the input tensor shape. Real ZapSafe Model 1 takes a
      // [1, 15] tensor; the placeholder file won't get this far because
      // `fromAsset` throws first on the invalid header.
      final shape = interpreter.getInputTensor(0).shape;
      final declaredInputs =
          shape.isEmpty ? 0 : shape.reduce((a, b) => a * b);
      if (declaredInputs != expectedInputSize) {
        interpreter.close();
        if (kDebugMode) {
          debugPrint('[TfliteInterpreter] shape mismatch '
              '($declaredInputs vs $expectedInputSize) for $assetPath');
        }
        return null;
      }
      return TfliteInterpreter._(
        interpreter: interpreter,
        modelLabel: modelLabel,
        expectedInputSize: expectedInputSize,
        classLabels: classLabels,
      );
    } catch (e) {
      // Either the asset is missing, the file is the Day 31 placeholder
      // (invalid TFLite header), or the host VM lacks the native FFI lib.
      if (kDebugMode) {
        debugPrint(
          '[TfliteInterpreter] tryLoad failed for $assetPath → $e',
        );
      }
      return null;
    }
  }

  @override
  Future<InferenceResult> infer(
    Float32List features, {
    required int timestampMs,
  }) async {
    final t0 = DateTime.now();
    if (features.length != expectedInputSize) {
      throw ArgumentError(
        'TfliteInterpreter expects $expectedInputSize floats, '
        'got ${features.length}',
      );
    }

    // Shape: input [1, expectedInputSize], output [1, N classes].
    final inputTensor = features.reshape([1, expectedInputSize]);
    final outputBuffer = List<List<double>>.filled(
      1,
      List<double>.filled(classLabels.length, 0),
    );

    _interpreter.run(inputTensor, outputBuffer);

    // Softmax-friendly: output is already normalised by the trained head,
    // so we treat the highest as the top class without re-softmaxing.
    final scores = outputBuffer[0];
    var topIdx = 0;
    var topScore = scores.isEmpty ? 0.0 : scores[0];
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > topScore) {
        topScore = scores[i];
        topIdx = i;
      }
    }

    final classScores = <String, double>{
      for (var i = 0; i < scores.length && i < classLabels.length; i++)
        classLabels[i]: scores[i],
    };
    final elapsed = DateTime.now().difference(t0).inMilliseconds;

    return InferenceResult(
      label: classLabels[topIdx],
      score: topScore,
      classScores: classScores,
      latencyMs: elapsed,
      timestampMs: timestampMs,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      _interpreter.close();
    } catch (_) {
      // Best-effort — native side may already be torn down.
    }
  }
}
