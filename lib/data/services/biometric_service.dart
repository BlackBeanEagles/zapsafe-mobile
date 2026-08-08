import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

/// Real, standalone biometric authentication service (LP18).
///
/// Was: `LocalAuthentication()` only ever existed inside a *string
/// literal* shown as a "here's the code we'd write" sample inside
/// day183_biometric_lock_screen.dart's own code-preview UI — a real
/// Day 336/361 P1 finding ("Biometric unlock UI exists but isn't wired
/// to a real auth gate"). Nothing outside that demo string actually
/// called local_auth anywhere in the app.
///
/// This class is the real implementation of that same design (the demo
/// string's own `BiometricService` shape is followed closely, since it
/// was already a reasonable design — just never built), now actually
/// wired into a real gated flow: the Evidence Vault (see
/// day82_evidence_vault_screen.dart's `_PinVerifyFlow`, which now offers
/// "Unlock with biometrics" as a fast-path alongside the PIN, not a
/// replacement for it — LP16's PIN gate still exists and is still the
/// fallback local_auth itself uses when biometrics aren't available).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True if this device supports biometrics AND has at least one
  /// biometric credential enrolled (fingerprint/face). False on
  /// emulators/devices with nothing enrolled — callers should hide the
  /// "unlock with biometrics" affordance entirely in that case rather
  /// than show a button that will always fail.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// List of enrolled biometric types (fingerprint, face, iris, strong,
  /// weak) — used to pick the right icon/label in the UI rather than a
  /// generic one for every platform.
  static Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return const [];
    }
  }

  /// Prompts the OS biometric UI. [reason] is shown to the user inside
  /// that OS-native prompt — must describe the real action being gated.
  ///
  /// Returns false (never throws) for every failure/cancel case except
  /// `lockedOut`/`permanentlyLockedOut`, which throw
  /// [BiometricLockedOutException] so callers can show a real "too many
  /// attempts, use your PIN" message instead of a generic failure.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // device PIN fallback is LP16's own vault PIN, not the OS one
          stickyAuth: true,
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        throw BiometricLockedOutException();
      }
      // notEnrolled, notAvailable, passcodeNotSet, other — treat as a
      // plain "couldn't authenticate", caller falls back to PIN entry.
      return false;
    }
  }
}

/// Thrown by [BiometricService.authenticate] when the OS has locked
/// biometric auth out after too many failed attempts (its own cascade,
/// separate from LP23's vault-PIN wipe cascade).
class BiometricLockedOutException implements Exception {
  @override
  String toString() =>
      'Biometric authentication is temporarily locked — use your PIN instead.';
}
