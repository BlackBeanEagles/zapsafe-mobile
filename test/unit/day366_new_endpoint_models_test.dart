// Day 366 — client models for the three endpoints built the same day.
//
// Each of these carries fields the server deliberately reports as UNKNOWN
// rather than guessing. The failure mode being guarded against is a parser
// that quietly turns "unknown" into a plausible default: a live SOS showing
// 0 minutes, a location at 0,0 (a real place in the Gulf of Guinea), or a
// missing alert flag defaulting to "off".

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/account_service.dart';
import 'package:zapsafe_mobile/data/services/referral_api_service.dart';
import 'package:zapsafe_mobile/data/services/sos_service.dart';

void main() {
  group('SosHistoryEntry', () {
    test('a live event keeps duration as null, not 0', () {
      final e = SosHistoryEntry.fromJson(<String, dynamic>{
        'id': 'a',
        'reference': 'SOS-A',
        'outcome': 'active',
        'triggered_at': '2026-09-01T10:00:00Z',
        'duration_minutes': null,
      });
      expect(e.durationMinutes, isNull);
      expect(e.isLive, isTrue);
    });

    test('missing coordinates stay null rather than becoming 0,0', () {
      final e = SosHistoryEntry.fromJson(<String, dynamic>{
        'id': 'b',
        'outcome': 'resolved',
        'lat': null,
        'lng': null,
      });
      expect(e.lat, isNull);
      expect(e.lng, isNull);
    });

    test('police_ref stays null — the server has no such field', () {
      final e = SosHistoryEntry.fromJson(<String, dynamic>{'id': 'c'});
      expect(e.policeRef, isNull);
    });

    test('parses the populated case', () {
      final e = SosHistoryEntry.fromJson(<String, dynamic>{
        'id': 'd',
        'reference': 'SOS-D',
        'outcome': 'resolved',
        'status': 'resolved',
        'trigger_type': 'manual_button',
        'triggered_at': '2026-09-01T10:00:00Z',
        'resolved_at': '2026-09-01T10:30:00Z',
        'lat': 19.07,
        'lng': 72.87,
        'evidence_count': 2,
        'contacts_notified': 3,
        'duration_minutes': 30,
        'duress_used': true,
      });
      expect(e.durationMinutes, 30);
      expect(e.contactsNotified, 3);
      expect(e.evidenceCount, 2);
      expect(e.lat, closeTo(19.07, 1e-9));
      expect(e.duressUsed, isTrue);
      expect(e.isLive, isFalse);
    });
  });

  group('SosHistoryPage', () {
    test('count is the total, not the page length', () {
      final p = SosHistoryPage.fromJson(<String, dynamic>{
        'count': 40,
        'results': [
          <String, dynamic>{'id': 'x'},
        ],
      });
      expect(p.count, 40);
      expect(p.results.length, 1);
    });

    test('an empty body is an empty page, not a crash', () {
      final p = SosHistoryPage.fromJson(const <String, dynamic>{});
      expect(p.count, 0);
      expect(p.results, isEmpty);
    });
  });

  group('ReferralRewards', () {
    test('pending entries are recognised and carry 0 points', () {
      final r = ReferralRewards.fromJson(<String, dynamic>{
        'total_bonus': 10,
        'protection_score_before': 60,
        'protection_score_after': 70,
        'entries': [
          <String, dynamic>{
            'id': '1',
            'title': '...1234 completed onboarding',
            'points': 10,
            'date': '2026-09-01',
            'type': 'referralBonus',
          },
          <String, dynamic>{
            'id': '2',
            'title': '...5678 joined — onboarding not finished',
            'points': 0,
            'date': '2026-09-02',
            'type': 'referralPending',
          },
        ],
      });
      expect(r.totalBonus, 10);
      expect(r.entries.where((e) => e.isPending).length, 1);
      expect(r.entries.firstWhere((e) => e.isPending).points, 0);
    });
  });

  group('SessionConfig / SecurityAlerts', () {
    test('session config parses the server value', () {
      final c = SessionConfig.fromJson(
          <String, dynamic>{'session_expiry_days': 7});
      expect(c.sessionExpiryDays, 7);
    });

    test('a missing alert flag is ON, not off', () {
      // The shipped defaults are all-on. A partial response must not quietly
      // turn a security alert off — that is the dangerous direction.
      final a = SecurityAlerts.fromJson(const <String, dynamic>{});
      expect(a.newDeviceAlert, isTrue);
      expect(a.failedAttemptsAlert, isTrue);
      expect(a.geoAnomalyAlert, isTrue);
      expect(a.failedAttemptsThreshold, 3);
    });

    test('an explicit false is respected', () {
      final a = SecurityAlerts.fromJson(<String, dynamic>{
        'new_device_alert': false,
        'failed_attempts_alert': true,
        'geo_anomaly_alert': false,
        'failed_attempts_threshold': 5,
      });
      expect(a.newDeviceAlert, isFalse);
      expect(a.geoAnomalyAlert, isFalse);
      expect(a.failedAttemptsThreshold, 5);
    });
  });
}
