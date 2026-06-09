import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';

/// Thin wrapper around the four auth endpoints.
///
/// Pure transport — no caching, no state. State (the JWT pair, the cached
/// user) lives in [TokenStorage] and is wired together by the providers.
///
/// Every method throws a typed [ApiError] on failure. Dio's internal
/// [DioException] is unwrapped here so callers never have to know about
/// the transport library — they just `try { ... } on ApiError catch (e)`.
class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Dio get _dio => _api.dio;

  /// `POST /auth/register/` — sends an OTP to the supplied phone.
  ///
  /// Throws [ApiError] for any backend failure (rate limit, SMS down, ...).
  Future<OtpRequestResponse> requestOtp(String phone) async {
    return _call(() async {
      final body = OtpRequest(phone: phone).toJson();
      final res = await _dio.post(ApiConfig.requestOtp, data: body);
      return OtpRequestResponse.fromJson(_asMap(res));
    });
  }

  /// `POST /auth/verify-otp/` — exchanges (phone, otp) for the JWT pair.
  Future<AuthTokens> verifyOtp({required String phone, required String otp}) async {
    return _call(() async {
      final body = VerifyOtpRequest(phone: phone, otp: otp).toJson();
      final res = await _dio.post(ApiConfig.verifyOtp, data: body);
      return AuthTokens.fromJson(_asMap(res));
    });
  }

  /// `POST /api/v1/auth/token/refresh/` — used by [ApiClient]'s auto-refresh
  /// flow when an access token expires (401).
  Future<RefreshResponse> refresh(String refreshToken) async {
    return _call(() async {
      final body = RefreshRequest(refresh: refreshToken).toJson();
      final res = await _dio.post(ApiConfig.refreshToken, data: body);
      return RefreshResponse.fromJson(_asMap(res));
    });
  }

  /// `POST /api/v1/auth/logout/` — blacklists the refresh token server-side.
  /// Requires authentication; the access token is attached by the interceptor.
  Future<void> logout(String refreshToken) async {
    return _call(() async {
      final body = LogoutRequest(refresh: refreshToken).toJson();
      await _dio.post(ApiConfig.logout, data: body);
    });
  }

  /// Health check — pings the docs route to confirm we can reach the server.
  /// Used by the Day 6 screen to give the user a green/red indicator before
  /// they bother typing a phone number.
  ///
  /// Never throws — returns `false` on any error (timeout, refused, 5xx).
  Future<bool> ping() async {
    try {
      final res = await _dio.get(
        '/docs/',
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          followRedirects: true,
        ),
      );
      return (res.statusCode ?? 0) < 500;
    } catch (_) {
      return false;
    }
  }

  // ─── Internals ────────────────────────────────────────────────────────

  /// Wraps any Dio call and re-throws as a typed [ApiError].
  ///
  /// The error interceptor attaches an [ApiError] to the [DioException.error]
  /// field, but Dio's own machinery still throws [DioException]. Without this
  /// helper, callers writing `on ApiError catch (e)` would silently miss every
  /// network failure — a nasty bug that hid the real error messages from users.
  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ApiError) throw inner;
      // Last-ditch fallback — should never trigger because the error
      // interceptor always attaches an ApiError, but defensive code.
      throw ApiError(
        message: e.message ?? 'Network error.',
        code: 'UNKNOWN',
        statusCode: e.response?.statusCode,
      );
    } on ApiError {
      rethrow;
    }
  }

  Map<String, dynamic> _asMap(Response res) {
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw ApiError(
      message: 'Unexpected response shape from server.',
      code: 'BAD_RESPONSE',
      statusCode: res.statusCode,
    );
  }
}
