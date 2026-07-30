import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Day 31 — central catalogue of the four ZapSafe TFLite models.
///
/// Each entry pins the asset path, expected role, and which native trigger
/// it eventually feeds. The actual `.tflite` files on disk today are 1 KB
/// placeholders (see `assets/models/*.tflite`) — calls into
/// `Interpreter.fromAsset` will throw, which is the expected behaviour
/// until backend training drops in Month 3.
///
/// Once a real model file replaces a placeholder, no code change is
/// required — the same `Interpreter.fromAsset(modelDef.assetPath)` call
/// will simply succeed.
@immutable
class ModelDefinition {
  /// Logical id used by the registry — e.g. `'scream'`, `'motion'`.
  final String key;

  /// Human-readable name shown in UIs.
  final String displayName;

  /// Asset path the Flutter loader hits. Must match `pubspec.yaml` assets.
  final String assetPath;

  /// What this model is for. Surface in the Day 31 screen so the catalogue
  /// reads as documentation.
  final String purpose;

  /// When the real `.tflite` file is expected to land (timeline note).
  final String realModelEta;

  /// Expected size of the *real* model in megabytes — for the Day 31 screen
  /// to flag a 1 KB placeholder vs a multi-MB real model.
  final double realSizeMb;

  const ModelDefinition({
    required this.key,
    required this.displayName,
    required this.assetPath,
    required this.purpose,
    required this.realModelEta,
    required this.realSizeMb,
  });
}

/// The four models the ZapSafe DCS pipeline expects. Order matches the
/// dependency graph: scream + motion feed into fusion, scene runs in
/// parallel for context. Same identifiers and asset paths the backend
/// training pipeline ships into.
const List<ModelDefinition> kZapsafeModels = [
  ModelDefinition(
    key: 'scream',
    displayName: 'Scream Classifier (M1)',
    assetPath: 'assets/models/scream_classifier_v1.tflite',
    // Day 257: shipped as m1_scream_v2 — a 128x131 librosa mel spectrogram
    // in, one sigmoid out. The old 13-MFCC description was the placeholder's.
    purpose: '128x131 mel spectrogram → P(scream), single sigmoid',
    realModelEta: 'Shipped Day 257 · AUC 0.9101',
    realSizeMb: 2.75,
  ),
  ModelDefinition(
    key: 'motion',
    displayName: 'Motion Anomaly (M2)',
    assetPath: 'assets/models/motion_anomaly_v1.tflite',
    purpose: 'IMU 6-DOF time-series → normal / unusual / fall',
    realModelEta: 'Month 3 · backend training (UCI-HAR + MobiAct)',
    realSizeMb: 1.8,
  ),
  ModelDefinition(
    key: 'scene',
    displayName: 'Scene Analyzer (M3)',
    assetPath: 'assets/models/scene_analyzer_v1.tflite',
    purpose: 'Camera frame → scene category for context awareness',
    realModelEta: 'Month 4–5 · AWS SageMaker (Places365)',
    realSizeMb: 3.1,
  ),
  ModelDefinition(
    key: 'fusion',
    displayName: 'DCS Fusion (M9)',
    assetPath: 'assets/models/dcs_fusion_v1.tflite',
    purpose: 'Combines M1+M2+M3 scores + context → single DCS score',
    realModelEta: 'Month 7–8 · backend XGBoost (beta-user data)',
    realSizeMb: 0.5,
  ),
  ModelDefinition(
    key: 'aggressive_speech',
    displayName: 'Aggressive Speech (H)',
    assetPath: 'assets/models/h_aggressive_speech_v1.tflite',
    purpose: '38-dim prosodic features → aggressive vs calm speech',
    realModelEta: 'Day 90 · Kaggle trained',
    realSizeMb: 0.024,
    // Phase A (Day 90): catalogue + asset only.
    // Phase B (Day 100): inference wiring — see
    // kaggle_notebooks/h_aggressive_speech_push/DAY90_KAGGLE_TRAIN.md
  ),
];

/// Status of a single model asset on disk.
@immutable
class ModelAssetStatus {
  final ModelDefinition definition;

  /// Bytes the asset bundle returned. 0 if the asset is missing entirely.
  final int sizeBytes;

  /// True when the file looks like a placeholder (small + textual marker).
  /// We don't validate the TFLite header here — we just flag obvious stubs.
  final bool isPlaceholder;

  /// First-line preview (for placeholders only). Real binary models return
  /// non-text bytes which we display as `(binary)`.
  final String previewSnippet;

  const ModelAssetStatus({
    required this.definition,
    required this.sizeBytes,
    required this.isPlaceholder,
    required this.previewSnippet,
  });
}

/// Reads asset metadata for every model in [kZapsafeModels]. Pure I/O —
/// no interpreter is constructed here, so this is cheap and safe to call
/// on every screen build.
class ModelRegistry {
  static const String _placeholderMarker = 'PLACEHOLDER_TFLITE_FILE';

  /// Loads every model's status. Missing assets surface as size 0; the UI
  /// flags them in red.
  Future<List<ModelAssetStatus>> loadAll() async {
    final out = <ModelAssetStatus>[];
    for (final m in kZapsafeModels) {
      out.add(await _statusFor(m));
    }
    return out;
  }

  Future<ModelAssetStatus> _statusFor(ModelDefinition m) async {
    try {
      final bytes = await rootBundle.load(m.assetPath);
      final size = bytes.lengthInBytes;
      // Peek at the first 64 bytes — enough to spot our text-stub marker
      // without dragging in the whole asset.
      final headerLen = size < 64 ? size : 64;
      final headerBytes = bytes.buffer.asUint8List(0, headerLen);
      final headerText = String.fromCharCodes(headerBytes);
      final isPlaceholder = headerText.contains(_placeholderMarker);
      final preview = isPlaceholder
          ? headerText.split('\n').first
          : '(binary · ${size ~/ 1024} KB)';
      return ModelAssetStatus(
        definition: m,
        sizeBytes: size,
        isPlaceholder: isPlaceholder,
        previewSnippet: preview,
      );
    } catch (e) {
      // Asset bundle threw — file isn't shipped or declared. UI shows red.
      if (kDebugMode) {
        debugPrint('[ModelRegistry] failed to load ${m.assetPath}: $e');
      }
      return ModelAssetStatus(
        definition: m,
        sizeBytes: 0,
        isPlaceholder: false,
        previewSnippet: 'MISSING — declare in pubspec.yaml assets',
      );
    }
  }
}
