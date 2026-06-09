import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted per-model on/off toggles + master AI enable flag.
///
/// Stored in SharedPreferences so settings survive app restarts.
class DetectionSettings {
  const DetectionSettings({
    this.aiEnabled       = true,
    this.screamEnabled   = true,
    this.motionEnabled   = true,
    this.sceneEnabled    = true,
    this.heuristicFallback = true,
  });

  final bool aiEnabled;        // master kill-switch
  final bool screamEnabled;
  final bool motionEnabled;
  final bool sceneEnabled;
  final bool heuristicFallback; // always true for safety; shown for transparency

  DetectionSettings copyWith({
    bool? aiEnabled,
    bool? screamEnabled,
    bool? motionEnabled,
    bool? sceneEnabled,
    bool? heuristicFallback,
  }) {
    return DetectionSettings(
      aiEnabled:         aiEnabled        ?? this.aiEnabled,
      screamEnabled:     screamEnabled    ?? this.screamEnabled,
      motionEnabled:     motionEnabled    ?? this.motionEnabled,
      sceneEnabled:      sceneEnabled     ?? this.sceneEnabled,
      heuristicFallback: heuristicFallback ?? this.heuristicFallback,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DetectionSettings &&
      other.aiEnabled        == aiEnabled &&
      other.screamEnabled    == screamEnabled &&
      other.motionEnabled    == motionEnabled &&
      other.sceneEnabled     == sceneEnabled &&
      other.heuristicFallback == heuristicFallback;

  @override
  int get hashCode => Object.hash(
        aiEnabled, screamEnabled, motionEnabled, sceneEnabled, heuristicFallback);
}

// ─── Keys ──────────────────────────────────────────────────────────────────────
const _kAiEnabled     = 'det_ai_enabled';
const _kScream        = 'det_scream_enabled';
const _kMotion        = 'det_motion_enabled';
const _kScene         = 'det_scene_enabled';

class DetectionSettingsNotifier extends StateNotifier<DetectionSettings> {
  DetectionSettingsNotifier() : super(const DetectionSettings()) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = DetectionSettings(
        aiEnabled:     p.getBool(_kAiEnabled) ?? true,
        screamEnabled: p.getBool(_kScream)    ?? true,
        motionEnabled: p.getBool(_kMotion)    ?? true,
        sceneEnabled:  p.getBool(_kScene)     ?? true,
      );
    } catch (_) {}
  }

  Future<void> setAiEnabled(bool v) async {
    state = state.copyWith(aiEnabled: v);
    _save(_kAiEnabled, v);
  }

  Future<void> setScreamEnabled(bool v) async {
    state = state.copyWith(screamEnabled: v);
    _save(_kScream, v);
  }

  Future<void> setMotionEnabled(bool v) async {
    state = state.copyWith(motionEnabled: v);
    _save(_kMotion, v);
  }

  Future<void> setSceneEnabled(bool v) async {
    state = state.copyWith(sceneEnabled: v);
    _save(_kScene, v);
  }

  Future<void> resetToDefaults() async {
    state = const DetectionSettings();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAiEnabled);
    await p.remove(_kScream);
    await p.remove(_kMotion);
    await p.remove(_kScene);
  }

  Future<void> _save(String key, bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(key, value);
    } catch (_) {}
  }
}

final detectionSettingsProvider =
    StateNotifierProvider<DetectionSettingsNotifier, DetectionSettings>(
  (_) => DetectionSettingsNotifier(),
);
