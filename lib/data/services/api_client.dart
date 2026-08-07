import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_config.dart';
import '../../core/utils/jwt_utils.dart';
import '../models/auth_models.dart';

/// Returns the current access token, or null when logged out.
typedef AccessTokenProvider = Future<String?> Function();

/// Called by the [AuthInterceptor] when a 401 lands. The callback should
/// attempt to refresh the access token and return the new value, or `null`
/// if refresh failed (which forces a re-login).
typedef TokenRefresher = Future<String?> Function();

/// Day 305 — returns the app's current active language code (e.g. 'en',
/// 'hi'), sourced from EasyLocalization's `context.locale` via a Riverpod
/// bridge provider. Returning null/empty falls back to 'en'.
typedef LanguageCodeProvider = String? Function();

/// Day 305 — one captured outgoing request, for the Accept-Language QA
/// screen to display without needing a live backend response. Populated by
/// [_AcceptLanguageInterceptor] on every request, success or failure.
class AcceptLanguageLogEntry {
  const AcceptLanguageLogEntry({
    required this.method,
    required this.path,
    required this.languageHeader,
    required this.at,
  });

  final String method;
  final String path;
  final String languageHeader;
  final DateTime at;
}

/// Day 305 — ring buffer of the last 30 requests' Accept-Language headers.
/// A plain static list (not a provider) so it survives regardless of
/// which widget tree constructed the [ApiClient] — the QA screen reads it
/// directly.
class AcceptLanguageAuditLog {
  AcceptLanguageAuditLog._();
  static final List<AcceptLanguageLogEntry> entries = [];

  static void record(AcceptLanguageLogEntry entry) {
    entries.insert(0, entry);
    if (entries.length > 30) entries.removeLast();
  }
}

/// Thin wrapper around [Dio] that wires our auth, logging, and error
/// translation in one place. Every Day 7+ service should ride on this.
class ApiClient {
  final Dio dio;

  ApiClient._(this.dio);

  /// Build the singleton Dio instance with all interceptors attached.
  factory ApiClient.build({
    AccessTokenProvider? tokenProvider,
    TokenRefresher? refresher,
    LanguageCodeProvider? languageProvider,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
        },
        // The backend uses its own error envelope; never throw on non-2xx.
        // We translate to [ApiError] in the error interceptor instead.
        validateStatus: (status) => status != null && status > 0,
      ),
    );

    // Day 305 — centralised Accept-Language on EVERY request (auth'd and
    // public alike, so OTP verify carries it too), before the auth
    // interceptor so the header is present even on unauthenticated calls.
    dio.interceptors.add(_AcceptLanguageInterceptor(languageProvider));

    dio.interceptors.add(_AuthInterceptor(
      dio: dio,
      tokenProvider: tokenProvider,
      refresher: refresher,
    ));

    dio.interceptors.add(_ErrorInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(_LoggingInterceptor());
    }

    return ApiClient._(dio);
  }
}

// ─── Accept-Language interceptor (Day 305) ───────────────────────────────
//
// Sets `Accept-Language: <code>` on every outgoing request from the app's
// real active locale (EasyLocalization, bridged in via [languageProvider]).
// Backend `AcceptLanguageMiddleware` (Day 103, confirmed live in
// `zapsafe_backend/zapsafe_backend/settings.py` MIDDLEWARE) reads this to
// activate Django translations and localize error-code messages.

class _AcceptLanguageInterceptor extends Interceptor {
  _AcceptLanguageInterceptor(this.languageProvider);
  final LanguageCodeProvider? languageProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final code = languageProvider?.call();
    final header = (code == null || code.isEmpty) ? 'en' : code;
    options.headers['Accept-Language'] = header;

    AcceptLanguageAuditLog.record(AcceptLanguageLogEntry(
      method: options.method,
      path: options.path,
      languageHeader: header,
      at: DateTime.now(),
    ));

    handler.next(options);
  }
}

// ─── Auth interceptor ────────────────────────────────────────────────────
//
// 1. On request: attaches `Authorization: Bearer <access>` when a token exists.
// 2. On 401:    pauses the failing request, asks [refresher] for a fresh
//                access token, then retries the original request once.
//                If refresh fails, the 401 is rethrown for the UI to handle.

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  final AccessTokenProvider? tokenProvider;
  final TokenRefresher? refresher;

  /// Endpoints that should never carry an Authorization header — auth itself
  /// and OTP request are obviously unauthenticated.
  static const _publicPaths = {
    ApiConfig.requestOtp,
    ApiConfig.verifyOtp,
    ApiConfig.refreshToken,
  };

  /// Guards against infinite refresh loops if /refresh itself returns 401.
  bool _refreshing = false;

  _AuthInterceptor({
    required this.dio,
    required this.tokenProvider,
    required this.refresher,
  });

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (tokenProvider == null || _isPublicPath(options.path)) {
      return handler.next(options);
    }

    String? token = await tokenProvider!();

    // ── Proactive expiry check ────────────────────────────────────────────
    // If the access token is expired or will expire within 30 seconds,
    // refresh it NOW before attaching it to the request. This avoids a
    // round-trip failure (request → 401 → refresh → retry) at the cost of
    // a slightly longer first request when the token is stale.
    if (token != null &&
        token.isNotEmpty &&
        !_refreshing &&
        refresher != null &&
        JwtUtils.isExpiredOrExpiringSoon(token)) {
      developer.log(
        'Access token expiring soon — proactive refresh',
        name: 'ApiClient',
      );
      final fresh = await _proactiveRefresh();
      if (fresh != null) token = fresh;
    }

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// Attempt a token refresh outside the 401-response path.
  /// Returns the new access token, or null if the refresh fails.
  Future<String?> _proactiveRefresh() async {
    _refreshing = true;
    try {
      return await refresher!();
    } catch (_) {
      return null;
    } finally {
      _refreshing = false;
    }
  }

  @override
  Future<void> onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    // Treat 401 here too — Dio's behaviour with validateStatus=>true means
    // 401s arrive as responses, not errors.
    if (response.statusCode == 401 &&
        !_isPublicPath(response.requestOptions.path) &&
        !_refreshing &&
        refresher != null) {
      final retried = await _tryRefreshAndRetry(response.requestOptions);
      if (retried != null) {
        return handler.resolve(retried);
      }
    }
    handler.next(response);
  }

  Future<Response?> _tryRefreshAndRetry(RequestOptions original) async {
    _refreshing = true;
    try {
      final newAccess = await refresher!();
      if (newAccess == null || newAccess.isEmpty) return null;

      // Retry once with the new token.
      final retryOpts = Options(
        method: original.method,
        headers: {
          ...original.headers,
          'Authorization': 'Bearer $newAccess',
        },
        contentType: original.contentType,
        responseType: original.responseType,
      );
      return await dio.request<dynamic>(
        original.path,
        data: original.data,
        queryParameters: original.queryParameters,
        options: retryOpts,
      );
    } catch (_) {
      return null;
    } finally {
      _refreshing = false;
    }
  }

  bool _isPublicPath(String path) {
    for (final p in _publicPaths) {
      if (path.endsWith(p) || path == p) return true;
    }
    return false;
  }
}

// ─── Error interceptor ───────────────────────────────────────────────────
//
// Turns Dio's various failure modes into a single, typed [ApiError] that the
// UI knows how to render. Also handles backend's `{ "error": "...", "code": "..." }`
// envelope.

class _ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return handler.next(response);
    }
    // Non-2xx response — translate to ApiError.
    final err = _fromResponse(response);
    handler.reject(DioException(
      requestOptions: response.requestOptions,
      response: response,
      error: err,
    ));
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // If we already attached an ApiError upstream, just pass through.
    if (err.error is ApiError) {
      return handler.next(err);
    }
    err = err.copyWith(error: _fromDio(err));
    handler.next(err);
  }

  ApiError _fromResponse(Response r) {
    final data = r.data;
    String message = 'Request failed (HTTP ${r.statusCode}).';
    String? code;
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      message = (m['error'] ?? m['detail'] ?? m['message'] ?? message).toString();
      code = m['code'] as String?;
    }
    return ApiError(message: message, code: code, statusCode: r.statusCode);
  }

  ApiError _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError(
          message: 'The server took too long to respond. Check your connection.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return const ApiError(
          message: 'Cannot reach server. Is the backend running and reachable?',
          code: 'NETWORK',
        );
      case DioExceptionType.cancel:
        return const ApiError(message: 'Request cancelled.', code: 'CANCELLED');
      case DioExceptionType.badCertificate:
        return const ApiError(
          message: 'Server certificate could not be verified.',
          code: 'BAD_CERT',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response!);
      case DioExceptionType.unknown:
        return ApiError(
          message: e.message ?? 'Unknown network error.',
          code: 'UNKNOWN',
        );
    }
  }
}

// ─── Logging interceptor (debug only) ────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(
      '→ ${options.method} ${options.uri}',
      name: 'ApiClient',
    );
    if (options.data != null) {
      developer.log('  body: ${_sanitize(options.data)}', name: 'ApiClient');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      name: 'ApiClient',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '✗ ${err.requestOptions.uri} → ${err.error}',
      name: 'ApiClient',
      error: err,
    );
    handler.next(err);
  }

  /// Strip sensitive fields from logs (OTPs, tokens, PINs).
  Object? _sanitize(dynamic data) {
    if (data is Map) {
      final clone = Map<String, dynamic>.from(data.cast<String, dynamic>());
      for (final k in ['otp', 'pin', 'password', 'refresh', 'access']) {
        if (clone.containsKey(k)) clone[k] = '••••';
      }
      return clone;
    }
    return data;
  }
}
