/// Day 39 — PIN matching policy.
///
/// The real PIN storage flow lands during onboarding (Day 41+ — secure
/// storage / Keystore-backed). For the Day 39 wiring this class is a
/// pure constant table:
///
///   • REAL PIN   = `1234` → cancel countdown and return to MONITORING
///   • DURESS PIN = `9999` → return to MONITORING in the UI, but set the
///     LP3 `silentlyEscalating` flag so backend dispatch continues
///
/// The Day 39 screen shows both PINs to the user so the wiring demo is
/// self-contained. Production builds will inject a different
/// implementation via DI (the screen will read PINs from secure storage
/// + compare via constant-time digest).
class PinPolicy {
  /// Demo PIN — accepts the real cancel path.
  static const String demoRealPin   = '1234';

  /// Demo PIN — accepts the duress cancel path (LP3).
  static const String demoDuressPin = '9999';

  /// True when [pin] is the configured "real cancel" PIN.
  bool isRealPin(String pin) => pin == demoRealPin;

  /// True when [pin] is the configured "duress cancel" PIN.
  /// Duress is recognised but the user never sees an explicit hint —
  /// matching the LP3 contract that the attacker can't distinguish
  /// duress from real cancel just by looking.
  bool isDuressPin(String pin) => pin == demoDuressPin;

  /// Classify a PIN. Returns null when neither matches.
  PinMatch? classify(String pin) {
    if (isRealPin(pin))   return PinMatch.real;
    if (isDuressPin(pin)) return PinMatch.duress;
    return null;
  }
}

/// Day 39 — outcome of a [PinPolicy.classify] call.
enum PinMatch {
  real,
  duress;

  String get label => switch (this) {
        PinMatch.real   => 'REAL_PIN',
        PinMatch.duress => 'DURESS_PIN',
      };
}
