// Day 325 — model_version_service.dart pure-logic tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/model_registry.dart';
import 'package:zapsafe_mobile/data/services/model_version_service.dart';

void main() {
  group('localVersionFor', () {
    test('extracts the _vN suffix from real asset paths', () {
      for (final def in kZapsafeModels.take(4)) {
        final v = localVersionFor(def);
        expect(v, matches(RegExp(r'^v\d+$')),
            reason: '${def.assetPath} should yield a vN version string');
      }
    });

    test('scream classifier resolves to v1', () {
      final scream = kZapsafeModels.firstWhere((m) => m.key == 'scream');
      expect(localVersionFor(scream), 'v1');
    });
  });

  group('kLocalToBackendModelType', () {
    test('maps all 4 core slots, fusion -> dcs explicitly', () {
      expect(kLocalToBackendModelType['scream'], 'scream');
      expect(kLocalToBackendModelType['motion'], 'motion');
      expect(kLocalToBackendModelType['scene'], 'scene');
      expect(kLocalToBackendModelType['fusion'], 'dcs');
    });

    test('does not map the extended (non-core) catalogue entries', () {
      expect(kLocalToBackendModelType.containsKey('aggressive_speech'), isFalse);
    });
  });

  group('ModelVersionCheckResponse.fromJson', () {
    test('parses a realistic backend payload', () {
      final resp = ModelVersionCheckResponse.fromJson({
        'checked_at': '2026-05-27T12:00:00Z',
        'all_up_to_date': false,
        'results': [
          {
            'model_type': 'scream',
            'client_version': 'v1',
            'server_version': 'v2',
            'update_available': true,
          },
          {
            'model_type': 'motion',
            'client_version': 'v1',
            'server_version': 'v1',
            'update_available': false,
          },
        ],
      });
      expect(resp.allUpToDate, isFalse);
      expect(resp.results, hasLength(2));
      expect(resp.results.first.updateAvailable, isTrue);
      expect(resp.results.last.updateAvailable, isFalse);
    });

    test('empty results parses cleanly', () {
      final resp = ModelVersionCheckResponse.fromJson({
        'checked_at': '2026-05-27T12:00:00Z',
        'all_up_to_date': true,
        'results': <dynamic>[],
      });
      expect(resp.results, isEmpty);
      expect(resp.allUpToDate, isTrue);
    });
  });
}
