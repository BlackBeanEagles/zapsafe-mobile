import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/models/quiet_hours.dart';
import 'package:zapsafe_mobile/data/services/push_service.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 5, 19, hour, minute);

void main() {
  group('QuietHoursConfig.covers', () {
    test('defaults span 10pm → 7am, wrapping midnight', () {
      const cfg = QuietHoursConfig.defaults;
      expect(cfg.covers(_at(22, 0)), isTrue);    // start
      expect(cfg.covers(_at(23, 30)), isTrue);
      expect(cfg.covers(_at(0, 0)), isTrue);     // midnight
      expect(cfg.covers(_at(3, 0)), isTrue);
      expect(cfg.covers(_at(6, 59)), isTrue);    // last covered minute
      expect(cfg.covers(_at(7, 0)), isFalse);    // exclusive end
      expect(cfg.covers(_at(12, 0)), isFalse);
      expect(cfg.covers(_at(21, 59)), isFalse);
    });

    test('same-day window (no wrap) — 13:00 → 17:00', () {
      const cfg = QuietHoursConfig(startHour: 13, endHour: 17);
      expect(cfg.covers(_at(12, 59)), isFalse);
      expect(cfg.covers(_at(13, 0)), isTrue);
      expect(cfg.covers(_at(16, 59)), isTrue);
      expect(cfg.covers(_at(17, 0)), isFalse);
    });

    test('disabled config never covers', () {
      const cfg = QuietHoursConfig(enabled: false);
      expect(cfg.covers(_at(2, 0)), isFalse);
      expect(cfg.covers(_at(23, 0)), isFalse);
    });

    test('start == end → empty window', () {
      const cfg = QuietHoursConfig(startHour: 12, endHour: 12);
      expect(cfg.covers(_at(11, 59)), isFalse);
      expect(cfg.covers(_at(12, 0)), isFalse);
      expect(cfg.covers(_at(12, 30)), isFalse);
    });
  });

  group('QuietHoursConfig.prettyRange', () {
    test('renders am/pm bounds correctly', () {
      expect(const QuietHoursConfig(startHour: 22, endHour: 7).prettyRange,
          '10pm → 7am');
      expect(const QuietHoursConfig(startHour: 0, endHour: 12).prettyRange,
          '12am → 12pm');
      expect(const QuietHoursConfig(startHour: 12, endHour: 13).prettyRange,
          '12pm → 1pm');
    });
  });

  group('QuietHoursConfig.copyWith', () {
    test('overwrites only the specified field', () {
      const base = QuietHoursConfig.defaults;
      final cfg = base.copyWith(enabled: false);
      expect(cfg.enabled, isFalse);
      expect(cfg.startHour, base.startHour);
      expect(cfg.endHour, base.endHour);
    });
  });

  group('PushCategoryMeta.destinationRoute', () {
    test('SOS / Ack / Battery all route to /sos-active', () {
      expect(PushCategory.sosAlert.destinationRoute, '/sos-active');
      expect(PushCategory.contactAck.destinationRoute, '/sos-active');
      expect(PushCategory.batteryWarning.destinationRoute, '/sos-active');
    });

    test('CHECK_IN_REMINDER routes to /dashboard', () {
      expect(PushCategory.checkInReminder.destinationRoute, '/dashboard');
    });

    test('unknown routes to /', () {
      expect(PushCategory.unknown.destinationRoute, '/');
    });
  });

  group('PushCategoryMeta.suppressibleInQuietHours', () {
    test('only CHECK_IN_REMINDER is suppressible', () {
      expect(PushCategory.sosAlert.suppressibleInQuietHours, isFalse);
      expect(PushCategory.contactAck.suppressibleInQuietHours, isFalse);
      expect(PushCategory.batteryWarning.suppressibleInQuietHours, isFalse);
      expect(PushCategory.checkInReminder.suppressibleInQuietHours, isTrue);
      expect(PushCategory.unknown.suppressibleInQuietHours, isFalse);
    });
  });
}
