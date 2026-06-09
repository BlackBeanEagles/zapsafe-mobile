/// ZapSafe Auth Data Models
///
/// Plain Dart classes that mirror the backend payloads exactly. Hand-rolled
/// (no codegen) because the auth contract is small and stable, and avoiding
/// build_runner keeps Day 6 simple.
///
/// Backend reference: `auth_app/views.py` + `auth_app/serializers.py`.
library;

// ─── User ─────────────────────────────────────────────────────────────

/// Returned inside the `verify-otp` response. Mirrors the `user` block:
/// ```json
/// {
///   "id": "<uuid>",
///   "phone": "+919876543210",
///   "full_name": "...",
///   "device_tier": "premium" | "mid_tier" | "lite",
///   "is_onboarded": true
/// }
/// ```
class User {
  final String id;
  final String phone;
  final String? fullName;
  final String? deviceTier;
  final bool isOnboarded;

  const User({
    required this.id,
    required this.phone,
    this.fullName,
    this.deviceTier,
    this.isOnboarded = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String,
        fullName: json['full_name'] as String?,
        deviceTier: json['device_tier'] as String?,
        isOnboarded: (json['is_onboarded'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'full_name': fullName,
        'device_tier': deviceTier,
        'is_onboarded': isOnboarded,
      };

  User copyWith({
    String? id,
    String? phone,
    String? fullName,
    String? deviceTier,
    bool? isOnboarded,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      deviceTier: deviceTier ?? this.deviceTier,
      isOnboarded: isOnboarded ?? this.isOnboarded,
    );
  }
}

// ─── OTP Request ──────────────────────────────────────────────────────

/// Body for `POST /auth/register/`.
class OtpRequest {
  /// E.164 format — e.g. `+919876543210`. The backend rejects anything else.
  final String phone;

  const OtpRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

/// Response from `POST /auth/register/` on success.
class OtpRequestResponse {
  /// Echo of the normalized phone the server stored against the OTP.
  final String phone;

  /// Seconds until the OTP expires. Used to seed the resend timer.
  final int expiresIn;

  /// Success message from server (e.g. "OTP sent successfully.").
  final String message;

  const OtpRequestResponse({
    required this.phone,
    required this.expiresIn,
    required this.message,
  });

  factory OtpRequestResponse.fromJson(Map<String, dynamic> json) =>
      OtpRequestResponse(
        phone: json['phone'] as String,
        expiresIn: json['expires_in'] as int,
        message: (json['message'] as String?) ?? 'OTP sent.',
      );
}

// ─── OTP Verify ───────────────────────────────────────────────────────

/// Body for `POST /auth/verify-otp/`.
class VerifyOtpRequest {
  final String phone;

  /// 6-digit numeric code.
  final String otp;

  const VerifyOtpRequest({required this.phone, required this.otp});

  Map<String, dynamic> toJson() => {'phone': phone, 'otp': otp};
}

/// Response from `POST /auth/verify-otp/` on success.
///
/// Contains the JWT pair (access 15 min, refresh 30 days) plus the user.
class AuthTokens {
  final String access;
  final String refresh;
  final User user;
  final bool isNewUser;

  const AuthTokens({
    required this.access,
    required this.refresh,
    required this.user,
    this.isNewUser = false,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        access: json['access'] as String,
        refresh: json['refresh'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        isNewUser: (json['is_new_user'] as bool?) ?? false,
      );

  AuthTokens copyWith({String? access, String? refresh, User? user, bool? isNewUser}) {
    return AuthTokens(
      access: access ?? this.access,
      refresh: refresh ?? this.refresh,
      user: user ?? this.user,
      isNewUser: isNewUser ?? this.isNewUser,
    );
  }
}

// ─── Logout ───────────────────────────────────────────────────────────

/// Body for `POST /api/v1/auth/logout/`.
class LogoutRequest {
  final String refresh;
  const LogoutRequest({required this.refresh});
  Map<String, dynamic> toJson() => {'refresh': refresh};
}

// ─── Refresh ──────────────────────────────────────────────────────────

/// Body for `POST /api/v1/auth/token/refresh/`.
class RefreshRequest {
  final String refresh;
  const RefreshRequest({required this.refresh});
  Map<String, dynamic> toJson() => {'refresh': refresh};
}

/// Response from `POST /api/v1/auth/token/refresh/`.
class RefreshResponse {
  final String access;

  /// SimpleJWT returns a new refresh if rotation is enabled. Optional.
  final String? refresh;

  const RefreshResponse({required this.access, this.refresh});

  factory RefreshResponse.fromJson(Map<String, dynamic> json) => RefreshResponse(
        access: json['access'] as String,
        refresh: json['refresh'] as String?,
      );
}

// ─── API Errors ───────────────────────────────────────────────────────

/// Backend's standard error shape: `{ "error": "...", "code": "..." }`.
class ApiError implements Exception {
  /// Human-readable error message from the server (or our wrapper).
  final String message;

  /// Backend error code: VALIDATION_ERROR, RATE_LIMITED, OTP_INVALID,
  /// SMS_FAILED, TOKEN_INVALID, TOKEN_USER_MISMATCH, MISSING_TOKEN, etc.
  /// `null` if we couldn't parse a code.
  final String? code;

  /// HTTP status, if available.
  final int? statusCode;

  const ApiError({
    required this.message,
    this.code,
    this.statusCode,
  });

  bool get isRateLimited => code == 'RATE_LIMITED' || statusCode == 429;
  bool get isOtpInvalid => code == 'OTP_INVALID';
  bool get isValidation => code == 'VALIDATION_ERROR';
  bool get isUnauthorized => statusCode == 401;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() => 'ApiError($statusCode/$code): $message';
}
