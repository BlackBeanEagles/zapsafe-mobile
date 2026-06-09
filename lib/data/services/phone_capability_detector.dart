import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'interpreter.dart';

/// Three tiers that drive the AI-vs-heuristic routing decision.
enum PhoneCapabilityTier {
  /// Modern GPU (2023+). AI models run <100 ms.
  high,

  /// Mid-range (2020-2022). AI models run 100-500 ms — still usable.
  medium,

  /// Older device (pre-2020). AI too slow; use heuristic fallback.
  low,
}

/// Result of a single capability probe run.
class CapabilityProbeResult {
  const CapabilityProbeResult({
    required this.tier,
    required this.inferenceMs,
    required this.shouldUseAi,
  });

  final PhoneCapabilityTier tier;
  final double inferenceMs;
  final bool shouldUseAi;

  // If inference completes in under 1 s → AI path is viable.
  static const double _aiThresholdMs = 1000.0;

  static PhoneCapabilityTier tierFor(double ms) {
    if (ms < 100) return PhoneCapabilityTier.high;
    if (ms < 500) return PhoneCapabilityTier.medium;
    return PhoneCapabilityTier.low;
  }

  static bool aiViable(double ms) => ms < _aiThresholdMs;

  String get tierLabel {
    switch (tier) {
      case PhoneCapabilityTier.high:
        return 'High — AI models (<100 ms)';
      case PhoneCapabilityTier.medium:
        return 'Medium — AI models (<500 ms)';
      case PhoneCapabilityTier.low:
        return 'Low — Heuristic fallback';
    }
  }

  @override
  String toString() =>
      'CapabilityProbeResult(tier=${tier.name}, '
      'inferenceMs=${inferenceMs.toStringAsFixed(1)}, '
      'shouldUseAi=$shouldUseAi)';
}

/// Detects whether this device can run on-device AI models or needs the
/// heuristic fallback path.
///
/// Algorithm:
///   1. Run [_warmups] discard passes (JIT / cache warm-up).
///   2. Time [_samples] measured passes on a tiny stub interpreter.
///   3. Take the median elapsed time.
///   4. Map median → [PhoneCapabilityTier].
///   5. Cache result in SharedPreferences to avoid re-probing on every start.
///
/// The cached tier is read by [DetectionSettingsScreen] and the DCS engine
/// to choose AI vs heuristic on every inference cycle.
class PhoneCapabilityDetector {
  PhoneCapabilityDetector({Interpreter? interpreter})
      : _interpreter = interpreter ?? EnergyStubInterpreter();

  final Interpreter _interpreter;

  static const String _prefKeyTier = 'phone_capability_tier';
  static const String _prefKeyMs   = 'phone_capability_ms';
  static const int    _warmups     = 3;
  static const int    _samples     = 5;

  // Dummy 15-float tensor — mirrors AudioFeatures.toFloat32Tensor() layout.
  static final Float32List _dummy = Float32List(15);

  /// Run the probe (or return cached result).
  ///
  /// Pass [forceReprobe] = true to ignore the cache and re-measure, e.g.
  /// after an OS update or when the user taps "Re-test" in settings.
  Future<CapabilityProbeResult> detect({bool forceReprobe = false}) async {
    if (!forceReprobe) {
      final cached = await _loadCached();
      if (cached != null) return cached;
    }
    final result = await _runProbe();
    await _persist(result);
    return result;
  }

  /// Read the stored tier without re-probing. Returns null if never probed.
  static Future<PhoneCapabilityTier?> cachedTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name  = prefs.getString(_prefKeyTier);
      if (name == null) return null;
      return PhoneCapabilityTier.values.firstWhere(
        (t) => t.name == name,
        orElse: () => PhoneCapabilityTier.low,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<CapabilityProbeResult> _runProbe() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var i = 0; i < _warmups; i++) {
      try {
        await _interpreter.infer(_dummy, timestampMs: now);
      } catch (_) {}
    }

    final samples = <double>[];
    for (var i = 0; i < _samples; i++) {
      final sw = Stopwatch()..start();
      try {
        await _interpreter.infer(_dummy, timestampMs: now);
      } catch (_) {}
      sw.stop();
      samples.add(sw.elapsedMicroseconds / 1000.0);
    }

    samples.sort();
    final medianMs = samples[samples.length ~/ 2];

    return CapabilityProbeResult(
      tier:        CapabilityProbeResult.tierFor(medianMs),
      inferenceMs: medianMs,
      shouldUseAi: CapabilityProbeResult.aiViable(medianMs),
    );
  }

  Future<CapabilityProbeResult?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name  = prefs.getString(_prefKeyTier);
      final ms    = prefs.getDouble(_prefKeyMs);
      if (name == null || ms == null) return null;
      final tier = PhoneCapabilityTier.values.firstWhere(
        (t) => t.name == name,
        orElse: () => PhoneCapabilityTier.low,
      );
      return CapabilityProbeResult(
        tier:        tier,
        inferenceMs: ms,
        shouldUseAi: CapabilityProbeResult.aiViable(ms),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(CapabilityProbeResult r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyTier, r.tier.name);
      await prefs.setDouble(_prefKeyMs,   r.inferenceMs);
    } catch (_) {}
  }
}
