// Day 327 — memory leak audit seed data tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/domain/diagnostics/memory_leak_audit.dart';

void main() {
  test('seedMemoryLeakAudit returns 5 categories, all clean', () {
    final audit = seedMemoryLeakAudit();
    expect(audit, hasLength(5));
    expect(audit.every((r) => r.verdict == LeakAuditVerdict.clean), isTrue);
  });

  test('every row has a non-empty category, scope, method, and finding', () {
    for (final r in seedMemoryLeakAudit()) {
      expect(r.category, isNotEmpty);
      expect(r.filesChecked, isNotEmpty);
      expect(r.method, isNotEmpty);
      expect(r.finding, isNotEmpty);
    }
  });
}
