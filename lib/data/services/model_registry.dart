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
    assetPath: 'assets/models/scream_classifier_v5.tflite',
    // Day 257: shipped as m1_scream_v2 — a 128x131 librosa mel spectrogram
    // in, one sigmoid out. The old 13-MFCC description was the placeholder's.
    purpose: '128x131 mel spectrogram → P(scream), single sigmoid',
    realModelEta: 'Shipped Day 346 · AUC 0.8284 (FSD50K eval, 287 pos)',
    realSizeMb: 2.75,
  ),
  ModelDefinition(
    key: 'motion',
    displayName: 'Motion Anomaly (M2)',
    assetPath: 'assets/models/motion_fall_v2.tflite',
    purpose: 'IMU 6-DOF time-series → normal / unusual / fall',
    realModelEta: 'Month 3 · backend training (UCI-HAR + MobiAct)',
    realSizeMb: 1.8,
  ),
  ModelDefinition(
    key: 'scene',
    displayName: 'Scene Analyzer (M3)',
    assetPath: 'assets/models/scene_analyzer_v1.tflite',
    // Day 315: real m3_ucf_crime_retrain_v3, trained on odins0n/ucf-crime-
    // dataset (real surveillance footage, Normal vs 13 crime categories) —
    // replaces the old placeholder note referencing AWS SageMaker/Places365,
    // which was never how this model was actually trained (real training
    // was Kaggle, see assets/models/DAY289_M3_UCF_CRIME_PUSH.md and
    // DAY293's iteration-3 result, the real best of 6 tried). Real 3-class
    // test accuracy 0.5944 — better-labeled data than before, still
    // mediocre, disclosed honestly rather than rounded up. Wired via
    // SceneDetectorV2 (lib/data/services/scene_detector_v2.dart); no real
    // camera-frame capture pipeline exists yet to feed it — see that
    // file's class doc.
    purpose: 'Camera frame [1,224,224,3] → SAFE/NEUTRAL/RISKY (softmax)',
    realModelEta: 'Shipped Day 315 · UCF-Crime · test acc 0.5944',
    realSizeMb: 1.34,
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
    key: 'vocal_stress',
    displayName: 'Vocal Stress APAC (M5)',
    assetPath: 'assets/models/m5_vocal_stress_v2.tflite',
    purpose: '28-dim prosodic features -> stressed vs calm speech (Mandarin)',
    realModelEta: 'Day 325 - trained locally on ESD Mandarin',
    realSizeMb: 0.031,
    // Day 337 CORRECTION: this said "WIRED and verified". It was not wired.
    // VocalStressDetector existed and was gate-verified, but nothing
    // constructed it — no provider, no pipeline, no caller anywhere in lib/.
    // The asset was loaded by this registry at startup and then never used.
    // vocalStressDetectorProvider now instantiates it.
    //
    // Verified: VocalStressFeatures builds the input with librosa-parity
    // MFCC (test/vocal_stress_features_test.dart pins it to <1e-6 against
    // real librosa).
    //
    // Held-out-SPEAKER AUC 0.7988 (3 of 10 Mandarin speakers held out
    // entirely). The same data scores 0.9984 on a random split, so the
    // speaker-wise number is the only honest one.
    //
    // Earlier M5s scored 0.5855 / 0.4862 / 0.4537 because they all trained
    // on English and were scored on APAC. Prosodic stress does not transfer
    // across languages. See vocal_stress_detector.dart.
    //
    // Threshold 0.20, not 0.5: precision is flat (~0.77) across the range
    // while recall climbs, so there is no reason to sit high. At 0.53 recall
    // this is a DCS fusion input, NOT an alert trigger.
  ),
  ModelDefinition(
    key: 'aggressive_speech',
    displayName: 'Aggressive Speech (H)',
    assetPath: 'assets/models/h_aggressive_speech_v1.tflite',
    purpose: '38-dim prosodic features → aggressive vs calm speech',
    realModelEta: 'Day 90 · Kaggle trained',
    realSizeMb: 0.024,
    // Phase A (Day 90): catalogue + asset only.
    // Phase B (inference wiring) is STILL NOT DONE — no Dart code loads or
    // runs this model.
    //
    // ** DO NOT START PHASE B ON THE 0.844. READ THIS FIRST. **
    //
    // Day 318 verified the asset scores AUC 0.844 on real RAVDESS and that
    // its int8 export is as accurate as the f32 twin. Both still hold, and
    // Day 318's conclusion — "the gap is wiring, not the model" — was the
    // reasonable read at the time. Day 347 measured it on a SECOND corpus
    // and that conclusion did not survive:
    //
    //     RAVDESS (acted, studio booth)   AUC 0.8442
    //     MELD (natural TV dialogue)      AUC 0.4780   -> CHANCE
    //                                     CI [0.4516, 0.5037]
    //
    // Precision equals the base rate (0.227) at every threshold. The
    // control rules out "MELD is just hard": classifiers trained on the
    // SAME 38 features reach 0.683 on MELD, so the features carry signal
    // there and this model specifically fails to transfer.
    //
    // All 160 of the RAVDESS clips are 24 actors in a booth reading two
    // fixed sentences — the same distribution that had
    // `scream_classifier_v1` claiming 0.9529 while, in its own words,
    // having "learned acted studio emotion, not screaming".
    //
    // Phase B is expensive: the native layer emits 15 per-frame scalars and
    // the day90 extractor needs pyin f0 mean/std/jitter, RMS shimmer + HNR
    // and spectral rolloff, none of which exist in Dart today. Spending
    // that on a detector that reads natural speech at chance is the point
    // of this warning. A retrain on natural speech comes first, aimed at
    // ~0.68, not 0.84. See assets/models/DAY347_H_AGGRESSIVE_CROSS_CORPUS.md.
    //
    // Whoever does Phase B: the 38-dim input MUST be z-scored with
    // assets/models/h_aggressive_speech_v1_norm.json (shipped Day 318).
    // Feeding raw features drops this model to AUC 0.52 — chance — and the
    // f32 twin collapses to a constant 1.0. That is a silent wrong-answer
    // failure, not a crash.
    //
    // Real blocker: the native side (lib/native/audio_features.dart) emits
    // only 15 per-frame scalars (13 MFCC + ZCR + spectral centroid). The
    // day90 extractor needs f0 mean/std/jitter via pyin pitch tracking,
    // RMS-derived shimmer + HNR, and spectral rolloff — none of which exist
    // in Dart or in the native layer today. See
    // assets/models/DAY318_H_AGGRESSIVE_VERIFIED.md.
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
