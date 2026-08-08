import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/core/utils/jwt_utils.dart';

// ─── Helper ──────────────────────────────────────────────────────────────────
//
// Builds a syntactically valid JWT with a fake signature. We never verify
// signatures on the client — we only read the `exp` claim — so a fake sig
// is fine for tests.

String _makeJwt({required int expEpochSeconds, Map<String, dynamic>? extra}) {
  String b64url(String json) {
    final bytes = utf8.encode(json);
    return base64Url.encode(bytes).replaceAll('=', ''); // strip padding
  }

  final header = b64url('{"alg":"HS256","typ":"JWT"}');
  final claims = <String, dynamic>{'exp': expEpochSeconds, 'user_id': 'u-test'};
  if (extra != null) claims.addAll(extra);
  final payload = b64url(jsonEncode(claims));
  return '$header.$payload.fakesignature';
}

int _nowSeconds() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('JwtUtils.decodePayload', () {
    test('decodes a valid JWT payload', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 900);
      final payload = JwtUtils.decodePayload(token);
      expect(payload, isNotNull);
      expect(payload!['user_id'], equals('u-test'));
      expect(payload['exp'], isA<int>());
    });

    test('returns null for empty string', () {
      expect(JwtUtils.decodePayload(''), isNull);
    });

    test('returns null for token with only 2 segments', () {
      expect(JwtUtils.decodePayload('header.payload'), isNull);
    });

    test('returns null for token with 4 segments', () {
      expect(JwtUtils.decodePayload('a.b.c.d'), isNull);
    });

    test('returns null for non-base64 payload', () {
      expect(JwtUtils.decodePayload('header.!!!invalid!!!.sig'), isNull);
    });

    test('returns null for payload that is not a JSON object', () {
      // base64url of a JSON array "[1,2,3]"
      final arrayPayload = base64Url.encode(utf8.encode('[1,2,3]')).replaceAll('=', '');
      expect(JwtUtils.decodePayload('h.$arrayPayload.s'), isNull);
    });
  });

  group('JwtUtils.expiry', () {
    test('returns correct DateTime for future token', () {
      final futureEpoch = _nowSeconds() + 900; // 15 min from now
      final token = _makeJwt(expEpochSeconds: futureEpoch);
      final exp = JwtUtils.expiry(token);
      expect(exp, isNotNull);
      expect(
        exp!.millisecondsSinceEpoch ~/ 1000,
        equals(futureEpoch),
      );
    });

    test('returns correct DateTime for past token', () {
      final pastEpoch = _nowSeconds() - 3600; // 1 hr ago
      final token = _makeJwt(expEpochSeconds: pastEpoch);
      final exp = JwtUtils.expiry(token);
      expect(exp, isNotNull);
      expect(exp!.isBefore(DateTime.now().toUtc()), isTrue);
    });

    test('returns null when no exp claim', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '');
      final payload = base64Url.encode(utf8.encode('{"user_id":"x"}')).replaceAll('=', '');
      expect(JwtUtils.expiry('$header.$payload.sig'), isNull);
    });

    test('returns null for malformed token', () {
      expect(JwtUtils.expiry('not.a.jwt.at.all'), isNull);
    });
  });

  group('JwtUtils.isExpired', () {
    test('returns false for a token expiring in the future', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 900);
      expect(JwtUtils.isExpired(token), isFalse);
    });

    test('returns true for a token that expired in the past', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() - 1);
      expect(JwtUtils.isExpired(token), isTrue);
    });

    test('returns true for a malformed token (fail-safe)', () {
      expect(JwtUtils.isExpired('garbage'), isTrue);
    });

    test('returns true for empty string (fail-safe)', () {
      expect(JwtUtils.isExpired(''), isTrue);
    });
  });

  group('JwtUtils.isExpiredOrExpiringSoon', () {
    test('returns false when token expires well beyond the buffer', () {
      // Expires in 10 minutes — well past the 30s default buffer.
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 600);
      expect(JwtUtils.isExpiredOrExpiringSoon(token), isFalse);
    });

    test('returns true when token expires within the default 30s buffer', () {
      // Expires in 15 seconds — inside the 30s buffer.
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 15);
      expect(JwtUtils.isExpiredOrExpiringSoon(token), isTrue);
    });

    test('returns true for already-expired token', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() - 60);
      expect(JwtUtils.isExpiredOrExpiringSoon(token), isTrue);
    });

    test('respects custom buffer', () {
      // Expires in 5 minutes (300s). With a 10-minute (600s) buffer, it's "soon".
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 300);
      expect(
        JwtUtils.isExpiredOrExpiringSoon(token, buffer: const Duration(minutes: 10)),
        isTrue,
      );
      // With a 1-minute (60s) buffer, 5 minutes is not soon.
      expect(
        JwtUtils.isExpiredOrExpiringSoon(token, buffer: const Duration(minutes: 1)),
        isFalse,
      );
    });

    test('returns true for malformed token (fail-safe)', () {
      expect(JwtUtils.isExpiredOrExpiringSoon('bad'), isTrue);
    });
  });

  group('JwtUtils.secondsRemaining', () {
    test('returns positive value for future token', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() + 900);
      final remaining = JwtUtils.secondsRemaining(token);
      expect(remaining, isNotNull);
      // Allow a 2-second window for test execution time.
      expect(remaining, greaterThan(897));
      expect(remaining, lessThanOrEqualTo(900));
    });

    test('returns negative value for expired token', () {
      final token = _makeJwt(expEpochSeconds: _nowSeconds() - 300);
      final remaining = JwtUtils.secondsRemaining(token);
      expect(remaining, isNotNull);
      expect(remaining!, isNegative);
    });

    test('returns null for malformed token', () {
      expect(JwtUtils.secondsRemaining('nope'), isNull);
    });
  });
}
