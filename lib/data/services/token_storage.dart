import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/utils/jwt_utils.dart';
import '../models/auth_models.dart';

/// Secure key-value store for the JWT pair + cached user profile.
///
/// Uses [FlutterSecureStorage], which delegates to:
///   - Android: EncryptedSharedPreferences (AES, AndroidKeystore-backed key)
///   - iOS:     Keychain (kSecAttrAccessibleAfterFirstUnlock)
///
/// Keys are namespaced under `zapsafe_*` so we don't clash with any other
/// app in the keychain or with future ZapSafe storage (vault keys, PINs etc).
class TokenStorage {
  static const _kAccess = 'zapsafe_access_token';
  static const _kRefresh = 'zapsafe_refresh_token';
  static const _kUser = 'zapsafe_user';

  /// Configured for max compatibility — encrypted on both platforms, survives
  /// reboots so we don't force re-login every cold start.
  static const _opts = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  static const _iosOpts = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: _opts,
              iOptions: _iosOpts,
            );

  // ─── Reads ────────────────────────────────────────────────────────────

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<User?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return User.fromJson(map);
    } catch (_) {
      // Corrupt cached profile — wipe so next login can rewrite cleanly.
      await _storage.delete(key: _kUser);
      return null;
    }
  }

  /// Quick "are we logged in" check — does not validate the token, just
  /// confirms one exists. Real expiry handling happens in [ApiClient] via
  /// the proactive + 401-reactive refresh interceptors.
  Future<bool> hasSession() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty;
  }

  /// Returns true if the stored access token is already expired.
  /// Used by the cold-start hydrator to decide whether to refresh before
  /// showing the dashboard (avoids the first API call failing with 401).
  Future<bool> isAccessTokenExpired() async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) return true;
    return JwtUtils.isExpired(token);
  }

  /// Seconds until the access token expires. Negative = already expired.
  /// Returns null if no token is stored or it is malformed.
  Future<int?> accessTokenSecondsRemaining() async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) return null;
    return JwtUtils.secondsRemaining(token);
  }

  /// Returns the access token expiry as a [DateTime], or null.
  Future<DateTime?> accessTokenExpiry() async {
    final token = await readAccessToken();
    if (token == null || token.isEmpty) return null;
    return JwtUtils.expiry(token);
  }

  // ─── Writes ───────────────────────────────────────────────────────────

  /// Persist the JWT pair returned from `verify-otp/`.
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: tokens.access),
      _storage.write(key: _kRefresh, value: tokens.refresh),
      _storage.write(key: _kUser, value: jsonEncode(tokens.user.toJson())),
    ]);
  }

  /// Update only the access token after a refresh.
  Future<void> saveAccessToken(String access) =>
      _storage.write(key: _kAccess, value: access);

  /// Update both tokens after a refresh that rotated the refresh token.
  Future<void> saveAccessAndRefresh(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: _kAccess, value: access),
      _storage.write(key: _kRefresh, value: refresh),
    ]);
  }

  /// Replace the cached user profile (e.g. after `/users/me/` refresh).
  Future<void> saveUser(User user) =>
      _storage.write(key: _kUser, value: jsonEncode(user.toJson()));

  // ─── Clear ────────────────────────────────────────────────────────────

  /// Logout — wipe everything we put in.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kUser),
    ]);
  }
}
