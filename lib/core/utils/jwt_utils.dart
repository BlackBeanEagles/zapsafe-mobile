import 'dart:convert';

/// Lightweight JWT payload decoder — no external package needed.
///
/// A JWT is three base64url-encoded segments joined by dots:
///   header.payload.signature
///
/// We only need the payload (segment 1) to read the `exp` claim.
/// We never verify the signature here — that is the backend's job.
/// The client only needs expiry to decide *when* to refresh proactively.
class JwtUtils {
  JwtUtils._();

  /// Decode the payload of a JWT and return it as a map.
  /// Returns `null` if the token is malformed or cannot be decoded.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // base64url → base64: replace - with + and _ with /
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');

      // Pad to a multiple of 4.
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }

      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Extract the expiry as a [DateTime], or `null` if the token is
  /// malformed or has no `exp` claim.
  static DateTime? expiry(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp == null) return null;
    final seconds = exp is int ? exp : int.tryParse(exp.toString());
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// Returns `true` if the token has already expired or will expire within
  /// [buffer] from now.  A 30-second buffer avoids using a token that expires
  /// between the client check and the server receiving the request.
  static bool isExpiredOrExpiringSoon(
    String token, {
    Duration buffer = const Duration(seconds: 30),
  }) {
    final exp = expiry(token);
    if (exp == null) return true; // treat malformed tokens as expired
    return DateTime.now().toUtc().isAfter(exp.subtract(buffer));
  }

  /// Returns `true` only if the token is already past its expiry time.
  static bool isExpired(String token) {
    final exp = expiry(token);
    if (exp == null) return true;
    return DateTime.now().toUtc().isAfter(exp);
  }

  /// Seconds remaining until the token expires.  Negative means already
  /// expired.  Returns `null` for malformed tokens.
  static int? secondsRemaining(String token) {
    final exp = expiry(token);
    if (exp == null) return null;
    return exp.difference(DateTime.now().toUtc()).inSeconds;
  }
}
