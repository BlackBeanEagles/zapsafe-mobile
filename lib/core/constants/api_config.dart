import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// API configuration — pick the right base URL for the current environment.
///
/// The Android emulator runs in its own VM and cannot reach the host machine's
/// `localhost`. It uses the special alias `10.0.2.2` instead. The iOS simulator
/// shares the host's network so `localhost` works there.
///
/// In production this defaults to https://zapsafe.app (Oracle Cloud), and
/// `https://` is mandatory. Override with --dart-define=ZAPSAFE_API_URL=...
/// for staging builds.
class ApiConfig {
  ApiConfig._();

  /// Dev backend URL — depends on platform.
  ///   Android emulator → http://10.0.2.2:8000
  ///   iOS simulator    → http://localhost:8000
  ///   Web              → http://localhost:8000
  ///   Real device      → http://<your-lan-ip>:8000  (override `_lanIp` below)
  ///
  /// Set the env var `ZAPSAFE_API_URL` at build time to override entirely:
  /// `flutter run --dart-define=ZAPSAFE_API_URL=https://staging.zapsafe.app`
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('ZAPSAFE_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // Release builds default to the deployed backend so a missing
    // --dart-define doesn't silently ship pointing at localhost.
    if (kReleaseMode) return 'https://zapsafe.app';

    if (kIsWeb) return 'http://localhost:8000';

    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (Platform.isIOS) return 'http://localhost:8000';

    // Windows/macOS/Linux desktop — assume backend on same host.
    return 'http://localhost:8000';
  }

  // ─── Endpoint paths ────────────────────────────────────────────────────
  // Centralized so the call sites are not littered with magic strings.
  // All paths intentionally include trailing slashes (Django APPEND_SLASH).

  // Auth (no /api/v1 prefix — per backend spec)
  static const requestOtp = '/auth/register/';
  static const verifyOtp = '/auth/verify-otp/';
  // Day 257 — Google/Apple sign-in. Returns the same JWT pair shape as
  // verifyOtp, so session handling downstream is identical.
  static const googleVerify = '/auth/google-verify/';

  // Auth (versioned)
  static const refreshToken = '/api/v1/auth/token/refresh/';
  static const logout = '/api/v1/auth/logout/';

  // Users
  static const me = '/api/v1/users/me/';

  // Contacts
  static const contacts = '/api/v1/contacts/';

  // SOS
  static const sosTrigger = '/api/v1/sos/trigger/';
  static const sosActive  = '/api/v1/sos/active/';
  static const sosDashboard = '/api/v1/sos/dashboard/';

  /// POST /api/v1/sos/<uuid>/cancel/
  static String sosCancelFor(String sosId) => '/api/v1/sos/$sosId/cancel/';

  /// POST /api/v1/sos/<uuid>/location/
  static String sosLocationFor(String sosId) => '/api/v1/sos/$sosId/location/';

  // GPS
  static const gpsPing = '/api/v1/gps/ping/';

  // Evidence
  static const evidence = '/api/v1/evidence/';

  // ML / Compatibility matrix — Day 53 (public endpoint, no auth required)
  static const compatibilityMatrix = '/api/v1/ml/compatibility-matrix/';

  // ML / Device capability report — Day 54 (authenticated POST + GET)
  static const deviceCapability = '/api/v1/ml/device-capability/';

  // ML / Detection event log — Day 55 (authenticated POST + GET)
  static const detectionEvents = '/api/v1/ml/detection-events/';

  // ML / Model download tracker — Day 56 (authenticated POST + GET)
  static const modelDownloads = '/api/v1/ml/model-downloads/';

  // ML / Analytics — Day 57 (authenticated GET)
  static const mlAnalytics = '/api/v1/ml/analytics/';

  // Safe Zones — Day 58 (authenticated CRUD)
  static const safeZones = '/api/v1/safe-zones/';

  // Protection Score — Day 59 (authenticated GET)
  static const protectionScore        = '/api/v1/protection-score/';
  static const protectionScoreHistory = '/api/v1/protection-score/history/';

  // Drill Mode — Day 60 (authenticated POST + GET)
  static const drillStart   = '/api/v1/drill/start/';
  static const drillHistory = '/api/v1/drill/history/';

  // Inference Log — Day 61 (authenticated POST + GET)
  static const inferenceLogs      = '/api/v1/ml/inference-logs/';
  static const inferenceLogsStats = '/api/v1/ml/inference-logs/stats/';

  // Incident Report — Day 62 (authenticated POST + GET + PATCH)
  static const incidents = '/api/v1/incidents/';

  // Alert Thresholds — Day 63 (authenticated CRUD)
  static const alertThresholds = '/api/v1/alert-thresholds/';

  // Escalation Policies — Day 64 (authenticated CRUD + activate)
  static const escalationPolicies = '/api/v1/escalation-policies/';

  // Check-in Timers — Day 65 (authenticated POST + GET + actions)
  static const checkIns = '/api/v1/check-ins/';

  // SOS Message Templates — Day 66 (authenticated CRUD + activate)
  static const sosTemplates = '/api/v1/sos-templates/';

  // Notification Category Preferences — Day 67 (authenticated GET + PATCH per category)
  static const notificationPrefs = '/api/v1/notification-prefs/';

  // User Activity Audit Log — Day 68 (authenticated POST + GET list + GET summary)
  static const auditLog        = '/api/v1/audit-log/';
  static const auditLogSummary = '/api/v1/audit-log/summary/';

  // Data Export — Day 69 (authenticated POST + GET list + GET detail + GET download)
  static const dataExport = '/api/v1/data-export/';

  // Privacy & Consent — Day 70 (authenticated GET/PATCH settings + POST/GET/DELETE deletion request)
  static const privacy            = '/api/v1/privacy/';
  static const privacyDeletion    = '/api/v1/privacy/deletion-request/';

  // Analytics — Day 81-85 backend, wired Day 302 (authenticated GET; device-health also POST)
  static const analyticsSosSummary          = '/api/v1/analytics/sos-summary/';
  static const analyticsDetections          = '/api/v1/analytics/detections/';
  static const analyticsContactResponseRate = '/api/v1/analytics/contacts/response-rate/';
  static const analyticsDeviceHealth        = '/api/v1/analytics/device-health/';

  // Subscription (Razorpay) — Day 91-100 backend, wired Day 303 (authenticated)
  static const subscriptionCreate = '/api/v1/subscription/create/';
  static const subscriptionStatus = '/api/v1/subscription/status/';
  static const subscriptionCancel = '/api/v1/subscription/cancel/';

  // SOS delivery status (MSG91 cascade) — Day 101 backend, wired Day 304 (authenticated)
  /// GET /api/v1/sos/<uuid>/delivery-status/
  static String sosDeliveryStatusFor(String sosId) =>
      '/api/v1/sos/$sosId/delivery-status/';

  // ─── Development Auth ──────────────────────────────────────────────────
  /// Development token for emulator testing (Django token from backend test user).
  /// In production, this is obtained from OTP verification flow.
  static const String devToken = 'dev-test-token-12345abcde';

  // ─── Timeouts ──────────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);
}
