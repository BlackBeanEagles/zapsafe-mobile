import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/push_service.dart';

void main() {
  group('PushCategoryMeta.wireName', () {
    test('round-trips through fromWire for every category', () {
      for (final cat in PushCategory.values) {
        if (cat == PushCategory.unknown) continue;
        final wire = cat.wireName;
        final back = PushCategoryMeta.fromWire(wire);
        expect(back, equals(cat), reason: 'roundtrip for $cat');
      }
    });

    test('unknown wire strings collapse to PushCategory.unknown', () {
      expect(PushCategoryMeta.fromWire(null), PushCategory.unknown);
      expect(PushCategoryMeta.fromWire(''), PushCategory.unknown);
      expect(PushCategoryMeta.fromWire('NOT_A_REAL_CAT'), PushCategory.unknown);
    });

    test('every category has a non-empty label and priority', () {
      for (final cat in PushCategory.values) {
        expect(cat.label, isNotEmpty, reason: '$cat label');
        expect(cat.priority, isNotEmpty, reason: '$cat priority');
      }
    });

    test('SOS_ALERT is the only CRITICAL priority', () {
      final critical = PushCategory.values
          .where((c) => c.priority == 'CRITICAL')
          .toList();
      expect(critical, [PushCategory.sosAlert]);
    });
  });

  group('PushPayload', () {
    test('default values produce a usable object', () {
      const payload = PushPayload(
        category: PushCategory.contactAck,
        title: 'Amma',
        body: 'Acknowledged',
      );
      expect(payload.category, PushCategory.contactAck);
      expect(payload.title, 'Amma');
      expect(payload.body, 'Acknowledged');
      expect(payload.data, isEmpty);
      expect(payload.messageId, isNull);
    });
  });
}
