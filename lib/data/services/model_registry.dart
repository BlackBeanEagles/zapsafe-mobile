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
    assetPath: 'assets/models/m3_violence_temporal_v1.tflite',
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
    // Day 351: scene_analyzer_v1.tflite is DELETED. Day 335 replaced it
    // in the DCS scene slot with m3_violence_temporal via
    // sceneResultOverride, because its labels (indoor/outdoor/transit)
    // contain NO danger class -- being outdoors is not evidence of
    // danger -- and it scored 0.594 on 3 classes. SceneDetectorV2 was
    // never constructed anywhere in lib/; only its constants were used.
    // So the asset was 1.4 MB shipped to every user for nothing, the
    // same dead weight scream_classifier_v3 was removed for on Day 346B.
    // This entry now names what actually serves the slot.
    purpose: 'Camera burst [1,16,576] → P(violence); serves the DCS '
        'scene slot via sceneResultOverride',
    realModelEta: 'Day 335 · m3_violence_temporal · cross-corpus 0.9749',
    realSizeMb: 0.67,
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
    assetPath: 'assets/models/m5_vocal_stress_v3_38.tflite',
    purpose: '38-dim prosodic features -> stressed vs calm speech (Mandarin)',
    realModelEta: 'Day 350 - ESD Mandarin + EmotionTalk natural speech',
    realSizeMb: 0.029,
    // Day 350: the 28-feature v2 was replaced. It reported held-out-
    // SPEAKER AUC 0.7988 and measured 0.4865 -- chance -- on natural
    // Mandarin (EmotionTalk), because held-out speaker is not held-out
    // corpus. Retrained on acted + natural with the FULL 38-dim vector:
    // acted 0.7873 / natural 0.7810. The 28-feature restriction existed
    // because Dart could not compute pitch/shimmer/HNR; yin_pitch.dart and
    // VocalStressFeatures.compose38() removed that limit, and the dropped
    // features turn out to be load-bearing OFF ESD -- the 28-feature
    // retrain cannot hold acted and natural at once (0.6294 / 0.7716).
    // See assets/models/DAY350_VOCAL_STRESS_V2.md.
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
    assetPath: 'assets/models/h_aggressive_v6_38.tflite',
    purpose: '38-dim prosodic features (2048/512 window) → '
        'aggressive vs calm speech',
    realModelEta: 'Day 352 · 5 corpora · natural speech 0.6415',
    realSizeMb: 0.012,
    // Day 352 -- PHASE B IS DONE. This slot is wired:
    // AggressiveSpeechDetector + aggressiveSpeechDetectorProvider.
    //
    // History, because the number on record was misleading for 5 days:
    //   v1  RAVDESS only   acted 0.8442  natural 0.4780  <- CHANCE
    //   v4  5 corpora      acted 0.7611  natural 0.6415  CI [0.6171,0.6656]
    //
    // Day 318 read v1's 0.8442 as "the gap is wiring, not the model". Day
    // 347 measured it on natural speech and found precision equal to the
    // base rate at every threshold -- it had learned acted studio emotion,
    // the same failure scream_classifier_v1 documents about itself.
    //
    // Wiring was estimated at days of native work because v2b needs
    // librosa.pyin at frame 2048/hop 512 and Dart only had plain YIN at
    // 512/256. Day 351 retrained at 512/256 and lost 0.10, concluding the
    // port was unavoidable -- too strong, because that run changed the
    // pitch ALGORITHM and the WINDOW together. Day 352 moved only the
    // window and recovered ~2/3 of the gap, so Phase B became a window
    // parameter in yin_pitch.dart plus AggressiveSpeechFeatures. The
    // residual 0.025 is the pyin HMM, independently measured at 0.011 on
    // m4, and is not worth a Viterbi port.
    //
    // CAVEAT: run-to-run variance on this head is ~0.02, the same order as
    // the acted bar it sits against (0.7611 one run, 0.7464 another, bar
    // 0.75). Do not treat the acted figure as precise.
    //
    // The 38-dim input MUST be z-scored with h_aggressive_v6_38_norm.json,
    // which AggressiveSpeechDetector.tryLoad() loads itself and fails
    // without -- Day 318 measured this family at 0.52 (chance) on raw
    // features, with its f32 twin collapsing to a constant 1.0.
    //
    // NOTE the features are NOT m4/m5's despite both being [1,38]:
    // AggressiveSpeechFeatures analyses at 2048/512, VocalStressFeatures at
    // 512/256. See assets/models/DAY352_H_AGGRESSIVE_V4_WIRED.md.
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
