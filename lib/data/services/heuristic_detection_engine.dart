import 'interpreter.dart';
import 'heuristic_scream_detector.dart';
import 'heuristic_motion_detector.dart';
import 'heuristic_scene_detector.dart';
import 'phone_capability_detector.dart';

/// Day 44 — routing hub between AI and heuristic detection paths.
///
/// Given a [PhoneCapabilityTier], this class hands back the correct
/// [Interpreter] for each of the three detection modalities (scream, motion,
/// scene). The consumer — [AudioFeatureService], DCS engine, or trigger
/// orchestrator — never needs to know which path is active.
///
/// Routing table:
///   [PhoneCapabilityTier.high]   → TFLite-backed interpreters (passed in)
///   [PhoneCapabilityTier.medium] → TFLite-backed interpreters
///   [PhoneCapabilityTier.low]    → heuristic interpreters (built here)
///
/// Usage:
/// ```dart
/// final engine = HeuristicDetectionEngine(
///   tier: tier,
///   aiScreamInterpreter: myTfliteScreamInterpreter,
///   aiMotionInterpreter: myTfliteMotionInterpreter,
///   aiSceneInterpreter:  myTfliteSceneInterpreter,
/// );
///
/// final screamResult = await engine.scream.infer(audioTensor, timestampMs: t);
/// final motionResult = await engine.motion.infer(motionTensor, timestampMs: t);
/// final sceneResult  = await engine.scene.infer(sceneTensor,  timestampMs: t);
/// ```
///
/// If an AI interpreter is not yet loaded (null), the heuristic fallback is
/// used regardless of tier. This handles the brief window at startup before
/// TFLite models have been loaded from assets.
class HeuristicDetectionEngine {
  HeuristicDetectionEngine({
    required PhoneCapabilityTier tier,
    Interpreter? aiScreamInterpreter,
    Interpreter? aiMotionInterpreter,
    Interpreter? aiSceneInterpreter,
    HeuristicScreamDetector? heuristicScream,
    HeuristicMotionDetector? heuristicMotion,
    HeuristicSceneDetector?  heuristicScene,
  })  : _tier                  = tier,
        _aiScream              = aiScreamInterpreter,
        _aiMotion              = aiMotionInterpreter,
        _aiScene               = aiSceneInterpreter,
        _heuristicScream = heuristicScream ?? const HeuristicScreamDetector(),
        _heuristicMotion = heuristicMotion ?? const HeuristicMotionDetector(),
        _heuristicScene  = heuristicScene  ?? const HeuristicSceneDetector();

  final PhoneCapabilityTier _tier;
  final Interpreter? _aiScream;
  final Interpreter? _aiMotion;
  final Interpreter? _aiScene;
  final HeuristicScreamDetector _heuristicScream;
  final HeuristicMotionDetector _heuristicMotion;
  final HeuristicSceneDetector  _heuristicScene;

  /// Whether this engine is running in AI mode (true) or heuristic mode (false).
  bool get isAiMode => _tier != PhoneCapabilityTier.low;

  /// Current capability tier.
  PhoneCapabilityTier get tier => _tier;

  /// Interpreter for scream/audio detection.
  /// Falls back to heuristic if tier is low OR if the AI interpreter is null.
  Interpreter get scream =>
      (isAiMode && _aiScream != null) ? _aiScream : _heuristicScream;

  /// Interpreter for motion/fall detection.
  Interpreter get motion =>
      (isAiMode && _aiMotion != null) ? _aiMotion : _heuristicMotion;

  /// Interpreter for scene threat detection.
  Interpreter get scene =>
      (isAiMode && _aiScene != null) ? _aiScene : _heuristicScene;

  /// Human-readable mode label for UI / logging.
  String get modeLabel {
    switch (_tier) {
      case PhoneCapabilityTier.high:
        return 'AI (High — <100 ms)';
      case PhoneCapabilityTier.medium:
        return 'AI (Medium — <500 ms)';
      case PhoneCapabilityTier.low:
        return 'Heuristic Fallback';
    }
  }

  /// Disposes AI interpreters if they exist. Heuristic detectors hold no
  /// native resources and are no-ops.
  Future<void> dispose() async {
    await _aiScream?.dispose();
    await _aiMotion?.dispose();
    await _aiScene?.dispose();
  }

  /// Rebuild the engine with a new tier (e.g. after a re-probe).
  HeuristicDetectionEngine withTier(PhoneCapabilityTier newTier) =>
      HeuristicDetectionEngine(
        tier:                newTier,
        aiScreamInterpreter: _aiScream,
        aiMotionInterpreter: _aiMotion,
        aiSceneInterpreter:  _aiScene,
        heuristicScream:     _heuristicScream,
        heuristicMotion:     _heuristicMotion,
        heuristicScene:      _heuristicScene,
      );
}
