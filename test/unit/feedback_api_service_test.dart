// Day 366 — the Day 114 feedback form now POSTs for real, so the category
// wire values are a contract with the backend rather than display strings.
//
// This exists because two of the five categories do NOT round-trip through
// `.name`: `falseAlarm` must go out as `false_alarm` and `uxIssue` as `ux`.
// A naive `.name` would have been accepted for crash/performance/general and
// rejected for exactly those two — feedback "sometimes going missing" rather
// than an error anyone would notice.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/api_client.dart';
import 'package:zapsafe_mobile/data/services/feedback_api_service.dart';

/// `FeedbackCategory.choices` in zapsafe_backend/feedback/models.py.
/// If the backend adds a category, this list and the Dart enum both have to
/// grow — that is what the coverage test below is for.
const _backendChoices = <String>{
  'crash',
  'false_alarm',
  'ux',
  'performance',
  'general',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedbackCategory wire values', () {
    test('every category maps to a value the backend accepts', () {
      for (final c in FeedbackCategory.values) {
        expect(
          _backendChoices,
          contains(c.wire),
          reason: '${c.name} sends "${c.wire}", which is not a backend choice '
              '— POST /api/v1/feedback/submit would return VALIDATION_ERROR',
        );
      }
    });

    test('every backend choice is reachable from the app', () {
      final wires = FeedbackCategory.values.map((c) => c.wire).toSet();
      expect(
        wires,
        equals(_backendChoices),
        reason: 'a category the backend accepts has no way to be submitted, '
            'or the app can submit one the backend will reject',
      );
    });

    test('the two that differ from .name are mapped, not derived', () {
      // The whole reason this enum carries an explicit string.
      expect(FeedbackCategory.falseAlarm.wire, 'false_alarm');
      expect(FeedbackCategory.uxIssue.wire, 'ux');
      // Specifically NOT "ux_issue" — the backend choice is "ux".
      expect(FeedbackCategory.uxIssue.wire, isNot('ux_issue'));
      // And confirm .name really would have been wrong for both, so this test
      // fails loudly if someone "simplifies" the enum back to .name.
      expect(FeedbackCategory.falseAlarm.wire,
          isNot(FeedbackCategory.falseAlarm.name));
      expect(
          FeedbackCategory.uxIssue.wire, isNot(FeedbackCategory.uxIssue.name));
    });

    test('the three that do match .name still match', () {
      expect(FeedbackCategory.crash.wire, 'crash');
      expect(FeedbackCategory.performance.wire, 'performance');
      expect(FeedbackCategory.general.wire, 'general');
    });

    test('no two categories share a wire value', () {
      final wires = FeedbackCategory.values.map((c) => c.wire).toList();
      expect(wires.toSet().length, wires.length,
          reason: 'a duplicate wire value silently merges two categories');
    });
  });

  group('FeedbackReceipt', () {
    test('parses the backend 201 body', () {
      final r = FeedbackReceipt.fromJson(
          <String, dynamic>{'id': 'FB-123', 'status': 'received'});
      expect(r.id, 'FB-123');
      expect(r.status, 'received');
    });

    test('survives a body missing fields rather than throwing', () {
      // A 201 means the report was stored. Throwing here would tell the tester
      // it failed and invite a duplicate report.
      final r = FeedbackReceipt.fromJson(<String, dynamic>{});
      expect(r.id, '');
      expect(r.status, '');
    });
  });

  group('local validation fails fast', () {
    // A real ApiClient is safe here: Dio's adapter creates the pinned HTTP
    // client lazily on the first request, and these guards throw before a
    // request is ever built. If a guard were removed, the test would attempt a
    // real call and fail loudly rather than pass on a mock.
    final service = FeedbackApiService(ApiClient.build());

    test('rejects a rating outside 1-5 as a validation error', () async {
      await expectLater(
        service.submit(
          rating: 0,
          category: FeedbackCategory.general,
          message: 'hi',
          appVersion: '1.0.0+1',
        ),
        throwsA(isA<FeedbackSubmitException>()
            .having((e) => e.isValidation, 'isValidation', true)),
      );
      await expectLater(
        service.submit(
          rating: 6,
          category: FeedbackCategory.general,
          message: 'hi',
          appVersion: '1.0.0+1',
        ),
        throwsA(isA<FeedbackSubmitException>()),
      );
    });

    test('rejects a blank message', () async {
      await expectLater(
        service.submit(
          rating: 5,
          category: FeedbackCategory.general,
          message: '   \n  ',
          appVersion: '1.0.0+1',
        ),
        throwsA(isA<FeedbackSubmitException>()
            .having((e) => e.isValidation, 'isValidation', true)),
      );
    });

    // Day 115. The screen hardcoded sos_id "sos_mock_001" behind a mock, so
    // the payload it would have sent was never once exercised — the backend
    // field is a UUIDField and that string could not be accepted.
    test('false-positive rejects the old hardcoded mock id', () async {
      await expectLater(
        service.reportFalsePositive(
            sosId: 'sos_mock_001', isFalseAlarm: true),
        throwsA(isA<FeedbackSubmitException>()
            .having((e) => e.isValidation, 'isValidation', true)
            .having((e) => e.message, 'names the id', contains('sos_mock_001'))),
      );
    });

    test('false-positive rejects an empty id with a different message',
        () async {
      await expectLater(
        service.reportFalsePositive(sosId: '   ', isFalseAlarm: false),
        throwsA(isA<FeedbackSubmitException>()
            .having((e) => e.message, 'says no id', contains('No SOS id'))),
      );
    });
  });

  group('isUuid', () {
    test('accepts the canonical 8-4-4-4-12 form, either case', () {
      expect(FeedbackApiService.isUuid('3f1b9c2e-7a41-4c8b-9d02-5e6f7a8b9c0d'),
          isTrue);
      expect(FeedbackApiService.isUuid('3F1B9C2E-7A41-4C8B-9D02-5E6F7A8B9C0D'),
          isTrue);
      // The zeroed id the live-wire screens default to must be well-formed,
      // or the screens could never reach the backend to be told it is unknown.
      expect(FeedbackApiService.isUuid('00000000-0000-0000-0000-000000000000'),
          isTrue);
    });

    test('rejects the shapes that actually showed up', () {
      expect(FeedbackApiService.isUuid('sos_mock_001'), isFalse);
      expect(FeedbackApiService.isUuid(''), isFalse);
      // Hyphens in the wrong places, right length.
      expect(FeedbackApiService.isUuid('3f1b9c2e7a41-4c8b-9d02-5e6f7a8b9c0d'),
          isFalse);
      // Right shape, non-hex.
      expect(FeedbackApiService.isUuid('zzzzzzzz-7a41-4c8b-9d02-5e6f7a8b9c0d'),
          isFalse);
      // Trailing junk — anchors matter, or a pasted URL would pass.
      expect(
          FeedbackApiService.isUuid(
              '3f1b9c2e-7a41-4c8b-9d02-5e6f7a8b9c0d/ack/'),
          isFalse);
    });
  });
}
