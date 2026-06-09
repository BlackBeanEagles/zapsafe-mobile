import 'dart:async';

import 'package:flutter/foundation.dart';

/// Status of a single integration-test phase.
enum PhaseStatus {
  /// Not yet executed.
  pending,

  /// Currently in flight.
  running,

  /// Passed cleanly.
  pass,

  /// Hard failure — a real bug.
  fail,

  /// Failure that is expected at this point in the project (e.g. backend
  /// route lands in a later week). Rendered yellow rather than red.
  expectedFail,
}

/// Result emitted by a single phase.
@immutable
class PhaseResult {
  final String key;
  final String name;
  final PhaseStatus status;

  /// One-liner explaining the outcome — error class, status code, value etc.
  final String detail;

  /// Wall-clock time the phase took.
  final Duration duration;

  const PhaseResult({
    required this.key,
    required this.name,
    required this.status,
    required this.detail,
    this.duration = Duration.zero,
  });

  PhaseResult copyWith({PhaseStatus? status, String? detail, Duration? duration}) =>
      PhaseResult(
        key: key,
        name: name,
        status: status ?? this.status,
        detail: detail ?? this.detail,
        duration: duration ?? this.duration,
      );

  bool get isTerminal =>
      status == PhaseStatus.pass ||
      status == PhaseStatus.fail ||
      status == PhaseStatus.expectedFail;
}

/// Per-phase "what to do" closure. Returns the desired terminal [PhaseResult];
/// throwing inside translates to [PhaseStatus.fail] with the exception's text.
typedef PhaseRunner = Future<PhaseResult> Function();

/// A registered phase — pairs human-readable metadata with the runner closure.
@immutable
class IntegrationPhase {
  final String key;
  final String name;
  final String description;

  /// When set, a thrown exception inside [runner] is recorded as
  /// [PhaseStatus.expectedFail] instead of [PhaseStatus.fail], and the text
  /// is appended to the detail. Used for phases that legitimately can't pass
  /// until a backend dependency lands.
  final String? expectedFailReason;

  final PhaseRunner runner;

  const IntegrationPhase({
    required this.key,
    required this.name,
    required this.description,
    required this.runner,
    this.expectedFailReason,
  });
}

/// Runs a list of integration phases in declared order. Each phase emits its
/// own running + terminal status to the returned stream — UIs subscribe to
/// stream a live progress display.
///
/// The runner does **not** short-circuit on failure — every phase runs so the
/// final result table is complete. Hard failures and expected failures are
/// distinguished by the phase's [IntegrationPhase.expectedFailReason] field.
/// Day 25 — generic alias. Kept named `runMonth1Integration` for the
/// original Day 19 caller; new callers should use this synonym.
Stream<PhaseResult> runIntegrationPhases(List<IntegrationPhase> phases) =>
    runMonth1Integration(phases);

Stream<PhaseResult> runMonth1Integration(List<IntegrationPhase> phases) async* {
  for (final phase in phases) {
    // Emit "running" so UIs can render a spinner.
    yield PhaseResult(
      key: phase.key,
      name: phase.name,
      status: PhaseStatus.running,
      detail: 'Running…',
    );

    final sw = Stopwatch()..start();
    try {
      final res = await phase.runner();
      sw.stop();
      yield res.copyWith(duration: sw.elapsed);
    } catch (e, _) {
      sw.stop();
      final status = phase.expectedFailReason != null
          ? PhaseStatus.expectedFail
          : PhaseStatus.fail;
      final suffix = phase.expectedFailReason != null
          ? ' · ${phase.expectedFailReason}'
          : '';
      yield PhaseResult(
        key: phase.key,
        name: phase.name,
        status: status,
        detail: '$e$suffix',
        duration: sw.elapsed,
      );
    }
  }
}

/// Aggregate counts for a finished run.
@immutable
class IntegrationSummary {
  final int total;
  final int pass;
  final int fail;
  final int expectedFail;

  const IntegrationSummary({
    required this.total,
    required this.pass,
    required this.fail,
    required this.expectedFail,
  });

  /// True only when every phase passed or was an expected failure.
  bool get isGreen => fail == 0 && pass + expectedFail == total;

  factory IntegrationSummary.from(Iterable<PhaseResult> results) {
    var pass = 0, fail = 0, exp = 0;
    var total = 0;
    for (final r in results) {
      if (!r.isTerminal) continue;
      total++;
      switch (r.status) {
        case PhaseStatus.pass:         pass++; break;
        case PhaseStatus.fail:         fail++; break;
        case PhaseStatus.expectedFail: exp++; break;
        case PhaseStatus.pending:
        case PhaseStatus.running:
          break;
      }
    }
    return IntegrationSummary(
      total: total,
      pass: pass,
      fail: fail,
      expectedFail: exp,
    );
  }
}
