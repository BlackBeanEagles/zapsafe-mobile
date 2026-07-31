import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Day 257 — real Sentry crash reporting.
///
/// Until now this was a mock setup screen (`day116_sentry_setup_screen.dart`)
/// describing what wiring Sentry *would* involve. This is the wiring.
///
/// Two deliberate constraints, both because of what this app is:
///
/// **The DSN is never committed.** It comes from
/// `--dart-define=SENTRY_DSN=...` at build time. With no DSN, [init] runs the
/// app untouched and reporting stays off — the same graceful-degradation
/// contract `main.dart` already uses for Firebase, so a missing config never
/// costs a boot.
///
/// **PII is off, and events are scrubbed.** ZapSafe handles live location,
/// SOS events and emergency contacts. A crash reporter is a third party;
/// sending it user data to make debugging easier would be a poor trade for a
/// safety app whose users are often specifically trying not to be findable.
/// `sendDefaultPii` stays false and [_scrub] drops request bodies/headers and
/// redacts anything location- or contact-shaped from breadcrumbs before an
/// event leaves the device.
class CrashReporting {
  CrashReporting._();

  /// Build-time DSN. Empty string (the default) disables reporting entirely.
  static const String dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  /// Environment tag, so production noise is separable from a dev build.
  static const String environment =
      String.fromEnvironment('SENTRY_ENV', defaultValue: kReleaseMode ? 'production' : 'development');

  /// Set once init has actually configured the SDK.
  static bool get isEnabled => _enabled;
  static bool _enabled = false;

  /// Keys whose values must never reach Sentry.
  static const _sensitiveKeys = <String>{
    'latitude', 'longitude', 'lat', 'lng', 'lon', 'coords', 'location',
    'address', 'phone', 'phone_number', 'contact', 'contacts', 'email',
    'token', 'access', 'refresh', 'password', 'otp', 'pin',
  };

  /// Initialise Sentry and run [appRunner] inside it.
  ///
  /// Always calls [appRunner] exactly once, DSN or not — the app must boot
  /// whether or not crash reporting is configured.
  static Future<void> init(Future<void> Function() appRunner) async {
    if (dsn.isEmpty) {
      if (kDebugMode) {
        debugPrint('[boot] SENTRY_DSN not set → crash reporting disabled');
      }
      _enabled = false;
      await appRunner();
      return;
    }

    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.environment = environment;

          // Never attach user identifiers, IP addresses, or request bodies.
          options.sendDefaultPii = false;
          options.attachScreenshot = false; // an SOS screen may show a live map
          options.attachViewHierarchy = false;

          // Sample rather than ship everything: this is a $0-infrastructure
          // project and Sentry's free tier has a monthly event quota. Errors
          // are worth all of it; performance traces are not.
          options.tracesSampleRate = kReleaseMode ? 0.05 : 0.0;

          // `hint` is a named parameter in sentry 7.x, not positional.
          options.beforeSend = (event, {hint}) => _scrub(event);
        },
        appRunner: appRunner,
      );
      _enabled = true;
    } catch (e) {
      // A crash reporter that prevents the app from starting is worse than no
      // crash reporter, so a bad DSN degrades to disabled rather than fatal.
      if (kDebugMode) debugPrint('[boot] Sentry init failed → reporting disabled: $e');
      _enabled = false;
      await appRunner();
    }
  }

  /// Strip anything that could identify or locate a user.
  @visibleForTesting
  static SentryEvent? scrubForTest(SentryEvent event) => _scrub(event);

  /// Rebuilt as an explicit allowlist rather than `copyWith(user: null)`.
  ///
  /// `SentryEvent.copyWith` resolves each argument as `value ?? this.value`,
  /// so passing null *keeps* the original — a scrub written that way silently
  /// does nothing, which a test caught here. An allowlist also fails safe as
  /// the SDK adds fields: anything new is dropped until it is consciously
  /// allowed, instead of shipping by default.
  static SentryEvent? _scrub(SentryEvent event) {
    return SentryEvent(
      eventId: event.eventId,
      timestamp: event.timestamp,
      message: event.message,
      throwable: event.throwable,
      exceptions: event.exceptions,
      threads: event.threads,
      level: event.level,
      logger: event.logger,
      platform: event.platform,
      release: event.release,
      environment: event.environment,
      transaction: event.transaction,
      fingerprint: event.fingerprint,
      sdk: event.sdk,
      type: event.type,
      tags: event.tags,
      contexts: event.contexts,
      extra: _scrubMap(event.extra),
      breadcrumbs: event.breadcrumbs?.map(_scrubBreadcrumb).toList(),
      // Deliberately omitted: user (id/email/ip), request (headers/body).
      // Neither helps fix a crash and both identify the person reporting it.
    );
  }

  static Map<String, dynamic>? _scrubMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return data;
    return {
      for (final e in data.entries)
        e.key: _isSensitive(e.key) ? '[redacted]' : e.value,
    };
  }

  static Breadcrumb _scrubBreadcrumb(Breadcrumb b) {
    final data = b.data;
    if (data == null || data.isEmpty) return b;
    return b.copyWith(data: _scrubMap(data));
  }

  static bool _isSensitive(String key) {
    final k = key.toLowerCase();
    return _sensitiveKeys.any((s) => k == s || k.contains(s));
  }
}
