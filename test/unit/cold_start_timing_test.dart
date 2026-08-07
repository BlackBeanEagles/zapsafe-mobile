// Day 326 — ColdStartTimings instrumentation tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/core/monitoring/cold_start_timing.dart';

void main() {
  setUp(() => ColdStartTimings.instance.resetForTest());
  tearDown(() => ColdStartTimings.instance.resetForTest());

  test('marks before start() are no-ops', () {
    ColdStartTimings.instance.mark('too_early');
    expect(ColdStartTimings.instance.marks, isEmpty);
  });

  test('start() records process_start as the first mark', () {
    ColdStartTimings.instance.start();
    expect(ColdStartTimings.instance.marks, hasLength(1));
    expect(ColdStartTimings.instance.marks.first.label, 'process_start');
  });

  test('start() is idempotent — a second call does not add a mark', () {
    ColdStartTimings.instance.start();
    ColdStartTimings.instance.start();
    expect(ColdStartTimings.instance.marks, hasLength(1));
  });

  test('mark() appends in order after start()', () {
    ColdStartTimings.instance.start();
    ColdStartTimings.instance.mark('a');
    ColdStartTimings.instance.mark('b');
    expect(ColdStartTimings.instance.marks.map((m) => m.label),
        ['process_start', 'a', 'b']);
  });

  test('markOnce() only records the first call for a given label', () {
    ColdStartTimings.instance.start();
    ColdStartTimings.instance.markOnce('first_frame');
    ColdStartTimings.instance.markOnce('first_frame');
    ColdStartTimings.instance.markOnce('first_frame');
    expect(
        ColdStartTimings.instance.marks.where((m) => m.label == 'first_frame'),
        hasLength(1));
  });

  test('deltaMs computes ms between two marks', () async {
    ColdStartTimings.instance.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    ColdStartTimings.instance.mark('later');
    final delta = ColdStartTimings.instance.deltaMs('process_start', 'later');
    expect(delta, isNotNull);
    expect(delta! >= 0, isTrue);
  });

  test('deltaMs returns null when a label is missing', () {
    ColdStartTimings.instance.start();
    expect(ColdStartTimings.instance.deltaMs('process_start', 'nonexistent'), isNull);
  });

  test('totalMs() returns the last mark elapsed when no label given', () {
    ColdStartTimings.instance.start();
    ColdStartTimings.instance.mark('a');
    ColdStartTimings.instance.mark('b');
    expect(ColdStartTimings.instance.totalMs(), ColdStartTimings.instance.marks.last.elapsedMs);
  });

  test('totalMs(label) returns that mark\'s elapsed, or null if absent', () {
    ColdStartTimings.instance.start();
    ColdStartTimings.instance.mark('a');
    expect(ColdStartTimings.instance.totalMs('a'), isNotNull);
    expect(ColdStartTimings.instance.totalMs('missing'), isNull);
  });
}
