import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Real, user-configurable storage for the Evidence Vault PIN (LP16).
///
/// Was: `kVaultDevPin = '1234'` in `vault_providers.dart`, a hardcoded
/// literal every install shared — a real P1 finding (Day 336 / Day 361).
/// This replaces it with a per-install, user-chosen PIN, stored the same
/// way [TokenStorage] already stores auth tokens on this app (see
/// `lib/data/services/token_storage.dart` for the identical
/// FlutterSecureStorage/AndroidOptions/IOSOptions pattern this mirrors).
///
/// The PIN itself is never stored — only a salted SHA-256 hash, so a
/// device-storage compromise alone doesn't hand over the plaintext PIN
/// (the vault PIN gate always has to be evaluated in-app either way,
/// so this is a real hardening step, not just theater).
class VaultPinStorage {
  static const _kHash = 'zapsafe_vault_pin_hash';
  static const _kSalt = 'zapsafe_vault_pin_salt';

  static const _opts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  static const _iosOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  VaultPinStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: _opts,
              iOptions: _iosOpts,
            );

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  String _newSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Whether a real user-chosen PIN has ever been set on this device.
  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _kHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets (or overwrites) the vault PIN. [pin] must be exactly 4 digits —
  /// callers (the PIN-setup UI) are responsible for that validation; this
  /// layer just stores whatever it's given.
  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: hash);
  }

  /// Verifies [pin] against the stored hash. Returns false (never throws)
  /// if no PIN has been set yet — callers should check [hasPin] first to
  /// distinguish "wrong PIN" from "no PIN set" in their own UI copy.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  /// Clears the stored PIN — used by the LP23 cascade-wipe flow (5 wrong
  /// attempts) so a wiped vault also forces real PIN re-setup, not just a
  /// file purge with the old PIN still valid.
  Future<void> clearPin() async {
    await _storage.delete(key: _kHash);
    await _storage.delete(key: _kSalt);
  }
}
