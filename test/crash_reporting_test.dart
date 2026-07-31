import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:zapsafe_mobile/core/monitoring/crash_reporting.dart';

/// Day 257 — the scrubbing is the part worth testing.
///
/// ZapSafe handles live location, SOS events and emergency contacts. Sentry
/// is a third party. If a crash report carries coordinates or a phone number,
/// that is a privacy failure that ships silently and looks like nothing is
/// wrong — exactly the class of bug a test should catch rather than a review.
void main() {
  group('CrashReporting.scrub', () {
    test('drops the user object entirely', () {
      final event = SentryEvent(
        user: SentryUser(id: 'user-123', email: 'a@b.com', ipAddress: '1.2.3.4'),
      );
      expect(CrashReporting.scrubForTest(event)?.user, isNull);
    });

    test('drops request data (bodies and headers can carry tokens)', () {
      final event = SentryEvent(
        request: SentryRequest(
          url: 'https://zapsafe.app/api/v1/sos/trigger/',
          headers: const {'Authorization': 'Bearer secret-token'},
        ),
      );
      expect(CrashReporting.scrubForTest(event)?.request, isNull);
    });

    test('redacts location values in breadcrumbs', () {
      final event = SentryEvent(breadcrumbs: [
        Breadcrumb(message: 'gps', data: const {
          'latitude': 12.9716,
          'longitude': 77.5946,
          'accuracy': 5.0,
        }),
      ]);
      final data = CrashReporting.scrubForTest(event)!.breadcrumbs!.first.data!;
      expect(data['latitude'], '[redacted]');
      expect(data['longitude'], '[redacted]');
      // Non-identifying diagnostics must survive, or the reports are useless.
      expect(data['accuracy'], 5.0);
    });

    test('redacts contact and credential values in breadcrumbs', () {
      final event = SentryEvent(breadcrumbs: [
        Breadcrumb(message: 'sos', data: const {
          'contact_phone': '+919876543210',
          'access_token': 'eyJhbGciOi',
          'event_id': 'abc-123',
        }),
      ]);
      final data = CrashReporting.scrubForTest(event)!.breadcrumbs!.first.data!;
      expect(data['contact_phone'], '[redacted]');
      expect(data['access_token'], '[redacted]');
      expect(data['event_id'], 'abc-123');
    });

    test('leaves breadcrumbs without data untouched', () {
      final event = SentryEvent(breadcrumbs: [Breadcrumb(message: 'app resumed')]);
      expect(CrashReporting.scrubForTest(event)!.breadcrumbs!.first.message, 'app resumed');
    });
  });

  group('CrashReporting config', () {
    test('is disabled when no DSN is compiled in', () {
      // No --dart-define under `flutter test`, so this documents the default:
      // reporting off, app still boots.
      expect(CrashReporting.dsn, isEmpty);
      expect(CrashReporting.isEnabled, isFalse);
    });

    test('init still runs the app when the DSN is absent', () async {
      var ran = false;
      await CrashReporting.init(() async => ran = true);
      expect(ran, isTrue, reason: 'a missing DSN must never stop the app booting');
    });
  });
}
