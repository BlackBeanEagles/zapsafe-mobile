import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'heuristic_detection_engine.dart';
import 'heuristic_motion_detector.dart';
import 'heuristic_scene_detector.dart';
import 'heuristic_scream_detector.dart';
import 'interpreter.dart';
import 'motion_detector_v2.dart';
import 'phone_capability_detector.dart';
import 'scream_detector_v2.dart';

/// Day 45 — how each model slot resolved during bundle loading.
enum ModelLoadStatus {
  /// File is the 1 KB placeholder written before training.
  placeholder,

  /// Real TFLite file loaded and shape-checked successfully.
  realLoaded,

  /// Real TFLite file present but interpreter construction failed
  /// (shape mismatch, corrupted bytes, etc.).
  realLoadFailed,

  /// Model is an image-based CNN (e.g. MobileNetV2). Its input tensor is a
  /// 224×224×3 frame — incompatible with the Float32 feature pipeline on the
  /// mobile side. Heuristic fallback is used until a pipeline adapter lands.
  skippedImageModel,
}

/// Load result for a single model slot.
@immutable
class ModelSlotResult {
  final String key;           // 'scream' | 'motion' | 'scene'
  final String displayName;
  final String assetPath;
  final ModelLoadStatus status;
  final int sizeBytes;
  final Interpreter activeInterpreter;

  const ModelSlotResult({
    required this.key,
    required this.displayName,
    required this.assetPath,
    required this.status,
    required this.sizeBytes,
    required this.activeInterpreter,
  });

  bool get usesAi => status == ModelLoadStatus.realLoaded;

  String get statusLabel {
    switch (status) {
      case ModelLoadStatus.realLoaded:
        return 'TFLite loaded';
      case ModelLoadStatus.placeholder:
        return 'Placeholder — heuristic';
      case ModelLoadStatus.realLoadFailed:
        return 'Load failed — heuristic';
      case ModelLoadStatus.skippedImageModel:
        return 'Image model — heuristic';
    }
  }

  String get sizeMbLabel {
    if (sizeBytes == 0) return 'missing';
    if (sizeBytes < 10000) return '$sizeBytes B (placeholder)';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Result of a complete [ModelBundleService.load] call.
@immutable
class ModelBundleResult {
  final List<ModelSlotResult> slots;
  final HeuristicDetectionEngine engine;
  final int totalModelBytes;

  const ModelBundleResult({
    required this.slots,
    required this.engine,
    required this.totalModelBytes,
  });

  int get loadedAiCount => slots.where((s) => s.usesAi).length;
  int get heuristicCount => slots.where((s) => !s.usesAi).length;

  String get totalSizeLabel {
    final mb = totalModelBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
}

/// Day 45 — loads all three ZapSafe detection model slots and builds a
/// [HeuristicDetectionEngine] wired with whatever TFLite models successfully
/// loaded.
///
/// Loading strategy per slot:
///
///   scream_classifier_v1 (15-float audio features)
///     → Try `TfliteInterpreter.tryLoad(expectedInputSize: 15)`
///     → Day 45: placeholder (658 B) → resolves to heuristic
///
///   motion_anomaly_v1 (561-float UCI HAR features)
///     → Real 194 KB model present. Try `tryLoad(expectedInputSize: 561)`.
///     → Shape mismatch: mobile pipeline produces 6-DOF features (6 floats),
///       not 561 pre-extracted stats. Falls through to heuristic until a
///       feature-alignment adapter is built (Day 57+).
///
///   scene_analyzer_v1 (MobileNetV2image model — [1,224,224,3] input)
///     → Skipped: incompatible with Float32List feature pipeline.
///     → Uses [HeuristicSceneDetector] until a camera-frame adapter lands.
///
/// When a real scream model ships (HuggingFace Day 71+) or a UCI-HAR feature
/// bridge is added, this service picks it up automatically — no code change.
class ModelBundleService {
  static const int _placeholderSizeThreshold = 2000; // bytes

  static const String _screamAsset = 'assets/models/scream_classifier_v1.tflite';
  static const String _motionAsset = 'assets/models/motion_anomaly_v1.tflite';
  static const String _sceneAsset  = 'assets/models/scene_analyzer_v1.tflite';

  /// Run the full bundle load. Pass a [PhoneCapabilityTier] so the engine
  /// knows whether to prefer AI or heuristic when both are available.
  Future<ModelBundleResult> load({
    PhoneCapabilityTier tier = PhoneCapabilityTier.low,
  }) async {
    final screamSlot = await _loadScream();
    final motionSlot = await _loadMotion();
    final sceneSlot  = await _loadScene();

    final slots = [screamSlot, motionSlot, sceneSlot];

    final engine = HeuristicDetectionEngine(
      tier: tier,
      aiScreamInterpreter: screamSlot.usesAi ? screamSlot.activeInterpreter : null,
      aiMotionInterpreter: motionSlot.usesAi ? motionSlot.activeInterpreter : null,
      aiSceneInterpreter:  sceneSlot.usesAi  ? sceneSlot.activeInterpreter  : null,
    );

    final totalBytes =
        screamSlot.sizeBytes + motionSlot.sizeBytes + sceneSlot.sizeBytes;

    return ModelBundleResult(slots: slots, engine: engine, totalModelBytes: totalBytes);
  }

  // ── Scream slot ────────────────────────────────────────────────────────────

  Future<ModelSlotResult> _loadScream() async {
    final size = await _assetSize(_screamAsset);
    if (size < _placeholderSizeThreshold) {
      return ModelSlotResult(
        key: 'scream',
        displayName: 'Scream Classifier v1',
        assetPath: _screamAsset,
        status: ModelLoadStatus.placeholder,
        sizeBytes: size,
        activeInterpreter: const HeuristicScreamDetector(),
      );
    }
    // Day 257: the shipped asset is m1_scream_v2 — a [1,128,131,1] mel
    // spectrogram model, not the 15-float MFCC model this slot originally
    // assumed. Asking TfliteInterpreter for expectedInputSize: 15 fails the
    // shape check and silently drops back to the heuristic, which is what
    // was happening before this path existed.
    final interp = await ScreamDetectorV2.tryLoad(assetPath: _screamAsset);
    if (interp != null) {
      return ModelSlotResult(
        key: 'scream',
        displayName: 'Scream Classifier v2 (mel)',
        assetPath: _screamAsset,
        status: ModelLoadStatus.realLoaded,
        sizeBytes: size,
        activeInterpreter: interp,
      );
    }
    return ModelSlotResult(
      key: 'scream',
      displayName: 'Scream Classifier v1',
      assetPath: _screamAsset,
      status: ModelLoadStatus.realLoadFailed,
      sizeBytes: size,
      activeInterpreter: const HeuristicScreamDetector(),
    );
  }

  // ── Motion slot ────────────────────────────────────────────────────────────

  Future<ModelSlotResult> _loadMotion() async {
    final size = await _assetSize(_motionAsset);
    if (size < _placeholderSizeThreshold) {
      return ModelSlotResult(
        key: 'motion',
        displayName: 'Motion Anomaly v1',
        assetPath: _motionAsset,
        status: ModelLoadStatus.placeholder,
        sizeBytes: size,
        activeInterpreter: const HeuristicMotionDetector(),
      );
    }
    // Day 258: the "561-float UCI HAR" note that used to live here was wrong.
    // The shipped asset is m2_motion_v2 and its input tensor is [1, 100, 6] —
    // 100 raw IMU samples at 50 Hz, not 561 pre-extracted statistics. Asking
    // TfliteInterpreter for 561 floats failed the shape check every time, so
    // a working model sat in the bundle unused behind the heuristic.
    //
    // Verified against real UCI-HAR data: a walking window scores 0.004 and
    // the same window with an injected fall scores 0.98. See
    // test/motion_detector_v2_test.dart.
    final interp = await MotionDetectorV2.tryLoad(assetPath: _motionAsset);
    if (interp != null) {
      return ModelSlotResult(
        key: 'motion',
        displayName: 'Motion Anomaly v2 (IMU)',
        assetPath: _motionAsset,
        status: ModelLoadStatus.realLoaded,
        sizeBytes: size,
        activeInterpreter: interp,
      );
    }
    return ModelSlotResult(
      key: 'motion',
      displayName: 'Motion Anomaly v2 (IMU)',
      assetPath: _motionAsset,
      status: ModelLoadStatus.realLoadFailed,
      sizeBytes: size,
      activeInterpreter: const HeuristicMotionDetector(),
    );
  }

  // ── Scene slot ─────────────────────────────────────────────────────────────

  Future<ModelSlotResult> _loadScene() async {
    final size = await _assetSize(_sceneAsset);
    if (size < _placeholderSizeThreshold) {
      return ModelSlotResult(
        key: 'scene',
        displayName: 'Scene Analyzer v1',
        assetPath: _sceneAsset,
        status: ModelLoadStatus.placeholder,
        sizeBytes: size,
        activeInterpreter: const HeuristicSceneDetector(),
      );
    }
    // MobileNetV2 image model — input shape [1, 224, 224, 3]. Incompatible
    // with the Float32List feature pipeline. Skip TFLite load.
    return ModelSlotResult(
      key: 'scene',
      displayName: 'Scene Analyzer v1',
      assetPath: _sceneAsset,
      status: ModelLoadStatus.skippedImageModel,
      sizeBytes: size,
      activeInterpreter: const HeuristicSceneDetector(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<int> _assetSize(String path) async {
    try {
      final bytes = await rootBundle.load(path);
      return bytes.lengthInBytes;
    } catch (_) {
      return 0;
    }
  }
}
