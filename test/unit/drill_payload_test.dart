import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/push_service.dart';

/// Day 18 unit tests — pure logic around the drill payload contract.
/// We don't initialise PushService (it touches platform channels); we just
/// verify the constants and the shape of payloads callers can build.

void main() {
  group('Drill payload contract', () {
    test('drillTitlePrefix is the literal "[DRILL] "', () {
      expect(PushService.drillTitlePrefix, '[DRILL] ');
    });

    test('drillFlagKey is "drill" — backend uses this to short-circuit', () {
      expect(PushService.drillFlagKey, 'drill');
    });

    test('drill payloads reuse the SOS category', () {
      // Drill mode is supposed to reuse the SOS template byte-for-byte except
      // the title prefix and the data flag. Constructing one manually verifies
      // the contract from the caller's perspective.
      final payload = PushPayload(
        messageId: 'drill_123',
        category: PushCategory.sosAlert,
        title: '${PushService.drillTitlePrefix}SOS Triggered',
        body: '${PushService.drillTitlePrefix}Practice run.',
        data: const {PushService.drillFlagKey: 'true'},
      );
      expect(payload.category, PushCategory.sosAlert);
      expect(payload.title, startsWith('[DRILL] '));
      expect(payload.body, startsWith('[DRILL] '));
      expect(payload.data[PushService.drillFlagKey], 'true');
    });

    test('drill payloads route to /sos-active just like real SOS', () {
      // The category determines routing — same code path for drill vs real.
      expect(PushCategory.sosAlert.destinationRoute, '/sos-active');
    });

    test('SOS (and therefore drill) is NOT suppressed by quiet hours', () {
      expect(PushCategory.sosAlert.suppressibleInQuietHours, isFalse);
    });
  });

  group('Action button identifiers', () {
    test('responding action ID is stable across platforms', () {
      expect(PushService.actionResponding, 'ZAPSAFE_RESPONDING');
    });

    test('call-112 action ID is stable across platforms', () {
      expect(PushService.actionCall112, 'ZAPSAFE_CALL_112');
    });
  });
}
