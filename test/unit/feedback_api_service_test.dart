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
  });
}
