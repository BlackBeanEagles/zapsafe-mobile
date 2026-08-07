/// Day 94 — Silence-after-distress meta-rule (Track P).
///
/// IF scream/struggle in last 60s AND near-silence on mic AND no IMU motion
/// for ~30s → escalate SOS as possible unconscious victim.
///
/// Not a separate TFLite model — fusion rule for DCS / M9 path.
library;

/// Inputs wired from M1 scream slot, audio RMS, and M2 motion magnitude.
class SilenceAfterDistressInput {
  const SilenceAfterDistressInput({
    required this.now,
    this.lastScreamAt,
    required this.audioRmsDb,
    required this.motionMagnitude,
    this.motionStillSince,
  });

  final DateTime now;
  final DateTime? lastScreamAt;
  final double audioRmsDb;
  final double motionMagnitude;

  /// When sustained low motion began (for 30s still window).
  final DateTime? motionStillSince;
}

class SilenceAfterDistressResult {
  const SilenceAfterDistressResult({
    required this.shouldEscalate,
    required this.possibleUnconscious,
    required this.cause,
  });

  final bool shouldEscalate;
  final bool possibleUnconscious;
  final String cause;
}

class SilenceAfterDistressRule {
  const SilenceAfterDistressRule({
    this.screamWindowSec = 60,
    this.silenceDbThreshold = 20.0,
    this.stillMotionThreshold = 0.15,
    this.stillDurationSec = 30,
  });

  final int screamWindowSec;
  final double silenceDbThreshold;
  final double stillMotionThreshold;
  final int stillDurationSec;

  static const defaultCause =
      'CRITICAL: Possible unconscious victim — scream then silence + still';

  SilenceAfterDistressResult evaluate(SilenceAfterDistressInput input) {
    final screamAt = input.lastScreamAt;
    if (screamAt == null) {
      return const SilenceAfterDistressResult(
        shouldEscalate: false,
        possibleUnconscious: false,
        cause: '',
      );
    }

    final sinceScream = input.now.difference(screamAt).inSeconds;
    if (sinceScream > screamWindowSec || sinceScream < 0) {
      return const SilenceAfterDistressResult(
        shouldEscalate: false,
        possibleUnconscious: false,
        cause: '',
      );
    }

    final silent = input.audioRmsDb < silenceDbThreshold;
    final motionLow = input.motionMagnitude < stillMotionThreshold;

    if (!silent || !motionLow) {
      return const SilenceAfterDistressResult(
        shouldEscalate: false,
        possibleUnconscious: false,
        cause: '',
      );
    }

    final stillSince = input.motionStillSince;
    if (stillSince != null) {
      final stillSec = input.now.difference(stillSince).inSeconds;
      if (stillSec < stillDurationSec) {
        return const SilenceAfterDistressResult(
          shouldEscalate: false,
          possibleUnconscious: false,
          cause: '',
        );
      }
    }

    return const SilenceAfterDistressResult(
      shouldEscalate: true,
      possibleUnconscious: true,
      cause: defaultCause,
    );
  }
}
