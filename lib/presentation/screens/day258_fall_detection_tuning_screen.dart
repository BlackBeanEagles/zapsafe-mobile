/// Day 258 — Fall Detection Sensitivity Tuning
///
/// Section C (Days 241-260): phone IMU-only fall detection settings —
/// Low/Medium/High presets, fine sensitivity slider, mock test simulation,
/// battery impact note, and links to the DCS pipeline (Days 32–33 / 36).
///
/// Tag: 🟢 FRONTEND-ONLY · no watch or Health Kit HR fusion.
///
/// Route: [AppRoutes.fallDetectionTuning] → `/fall-detection-tuning`
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../data/services/fall_detector.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_empty_state.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF97316);
const _kTabs = ['Sensitivity', 'Test', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _FallPreset { low, medium, high }

class _FallTuning {
  const _FallTuning({
    required this.preset,
    required this.sensitivity,
    required this.freefallG,
    required this.impactMs2,
    required this.freefallHoldMs,
    required this.impactWindowMs,
    required this.batteryPctPerHr,
  });

  final _FallPreset? preset;
  final int sensitivity;
  final double freefallG;
  final double impactMs2;
  final int freefallHoldMs;
  final int impactWindowMs;
  final double batteryPctPerHr;

  double get freefallMs2 => freefallG * 9.81;

  String get presetLabel => switch (preset) {
        _FallPreset.low => 'Low',
        _FallPreset.medium => 'Medium',
        _FallPreset.high => 'High',
        null => 'Custom',
      };

  String get batteryLabel =>
      '${batteryPctPerHr.toStringAsFixed(1)}%/hr monitoring';

  Map<String, dynamic> toJson({required bool enabled}) => {
        'endpoint': 'PATCH /api/v1/settings/fall-detection/',
        'preset': preset?.name ?? 'custom',
        'sensitivity': sensitivity,
        'enabled': enabled,
        'source': 'phone_imu_only',
        'watch_hr_fusion': false,
        'health_kit_hr': false,
        'thresholds': {
          'freefall_g': double.parse(freefallG.toStringAsFixed(2)),
          'freefall_m_s2': double.parse(freefallMs2.toStringAsFixed(2)),
          'impact_m_s2': impactMs2,
          'freefall_hold_ms': freefallHoldMs,
          'impact_window_ms': impactWindowMs,
        },
        'battery_estimate_pct_per_hr': batteryPctPerHr,
        'pipeline': 'ImuService → FallDetector → TriggerOrchestrator (Day 39)',
        'dcs_note': 'Fall events are IMU-only · DCS fusion (Day 32–33) handles '
            'audio/scene distress separately',
      };
}

_FallTuning _tuningFromPreset(_FallPreset preset) => switch (preset) {
      _FallPreset.low => const _FallTuning(
          preset: _FallPreset.low,
          sensitivity: 25,
          freefallG: 0.35,
          impactMs2: 28.0,
          freefallHoldMs: 250,
          impactWindowMs: 900,
          batteryPctPerHr: 1.1,
        ),
      _FallPreset.medium => const _FallTuning(
          preset: _FallPreset.medium,
          sensitivity: 50,
          freefallG: 0.30,
          impactMs2: 25.0,
          freefallHoldMs: 200,
          impactWindowMs: 1000,
          batteryPctPerHr: 1.4,
        ),
      _FallPreset.high => const _FallTuning(
          preset: _FallPreset.high,
          sensitivity: 75,
          freefallG: 0.25,
          impactMs2: 22.0,
          freefallHoldMs: 150,
          impactWindowMs: 1100,
          batteryPctPerHr: 1.9,
        ),
    };

_FallTuning _tuningFromSlider(int sensitivity) {
  final t = sensitivity.clamp(0, 100) / 100.0;
  _FallPreset? matched;
  if (sensitivity == 25) {
    matched = _FallPreset.low;
  } else if (sensitivity == 50) {
    matched = _FallPreset.medium;
  } else if (sensitivity == 75) {
    matched = _FallPreset.high;
  }
  return _FallTuning(
    preset: matched,
    sensitivity: sensitivity,
    freefallG: _lerp(0.35, 0.25, t),
    impactMs2: _lerp(28.0, 22.0, t),
    freefallHoldMs: _lerpInt(250, 150, t),
    impactWindowMs: _lerpInt(900, 1100, t),
    batteryPctPerHr: _lerp(1.1, 1.9, t),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

int _lerpInt(int a, int b, double t) =>
    (_lerp(a.toDouble(), b.toDouble(), t)).round();

class _StreamEvent {
  const _StreamEvent({
    required this.at,
    required this.phase,
    required this.detail,
    required this.isFall,
  });

  final DateTime at;
  final String phase;
  final String detail;
  final bool isFall;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d258TabProvider = StateProvider<int>((ref) => 0);
final _d258SensitivityProvider = StateProvider<int>((ref) => 50);
final _d258EnabledProvider = StateProvider<bool>((ref) => true);
final _d258TestingProvider = StateProvider<bool>((ref) => false);
final _d258DetectorStateProvider =
    StateProvider<FallDetectorState>((ref) => FallDetectorState.idle);
final _d258StreamEventsProvider =
    StateProvider<List<_StreamEvent>>((ref) => const []);
final _d258TestCountProvider = StateProvider<int>((ref) => 0);
final _d258LastPeakProvider = StateProvider<double>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day258FallDetectionTuningScreen extends ConsumerWidget {
  const Day258FallDetectionTuningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d258TabProvider);
    final sensitivity = ref.watch(_d258SensitivityProvider);
    final tuning = _tuningFromSlider(sensitivity);
    final enabled = ref.watch(_d258EnabledProvider);
    final testing = ref.watch(_d258TestingProvider);
    final testCount = ref.watch(_d258TestCountProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 258 · Fall Detection'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: (enabled ? _kAccent : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (enabled ? _kAccent : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  enabled ? tuning.presetLabel : 'OFF',
                  style: TextStyle(
                    color: enabled ? _kAccent : ZapColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (testCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.sm),
              child: Center(
                child: Text(
                  '$testCount test${testCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d258TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _SensitivityTab(
                  tuning: tuning,
                  enabled: enabled,
                  onPreset: (p) {
                    final t = _tuningFromPreset(p);
                    ref.read(_d258SensitivityProvider.notifier).state =
                        t.sensitivity;
                    HapticFeedback.selectionClick();
                  },
                  onSlider: (v) =>
                      ref.read(_d258SensitivityProvider.notifier).state = v,
                  onEnabled: (v) =>
                      ref.read(_d258EnabledProvider.notifier).state = v,
                ),
              1 => _TestTab(
                  tuning: tuning,
                  enabled: enabled,
                  testing: testing,
                  onRunTest: () => _runMockFallTest(context, ref, tuning),
                  onClear: () {
                    ref.read(_d258StreamEventsProvider.notifier).state = [];
                    ref.read(_d258DetectorStateProvider.notifier).state =
                        FallDetectorState.idle;
                    ref.read(_d258LastPeakProvider.notifier).state = 0;
                  },
                ),
              _ => _InfoTab(tuning: tuning, enabled: enabled),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runMockFallTest(
    BuildContext context,
    WidgetRef ref,
    _FallTuning tuning,
  ) async {
    if (ref.read(_d258TestingProvider)) return;
    if (!ref.read(_d258EnabledProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable fall detection on the Sensitivity tab first.'),
        ),
      );
      return;
    }

    ref.read(_d258TestingProvider.notifier).state = true;
    ref.read(_d258StreamEventsProvider.notifier).state = [];
    ref.read(_d258DetectorStateProvider.notifier).state =
        FallDetectorState.idle;

    final events = <_StreamEvent>[];
    void push(String phase, String detail, {bool isFall = false}) {
      events.insert(
        0,
        _StreamEvent(
          at: DateTime.now(),
          phase: phase,
          detail: detail,
          isFall: isFall,
        ),
      );
      ref.read(_d258StreamEventsProvider.notifier).state = [...events];
    }

    final detector = FallDetector();
    final baseTs = DateTime.now().millisecondsSinceEpoch;
    var peak = 0.0;

    Future<void> feed(double mag, int offsetMs, String label) async {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      if (!context.mounted) return;
      peak = math.max(peak, mag);
      ref.read(_d258DetectorStateProvider.notifier).state = detector.state;
      push(
        detector.state.name,
        '$label · ${mag.toStringAsFixed(1)} m/s²',
      );
      detector.observe(mag, timestampMs: baseTs + offsetMs);
      ref.read(_d258DetectorStateProvider.notifier).state = detector.state;
    }

    push('idle', 'Test fall started · IMU feature stream (mock)');

    for (var i = 0; i < 8; i++) {
      await feed(2.0, i * 30, 'freefall sample ${i + 1}/8');
    }
    await feed(32.0, 8 * 30, 'impact spike');
    ref.read(_d258LastPeakProvider.notifier).state = peak;

    final triggered = detector.state == FallDetectorState.impactDetected ||
        peak >= tuning.impactMs2;
    if (triggered) {
      push(
        'FALL_DETECTED',
        'Peak ${peak.toStringAsFixed(1)} m/s² · thresholds '
            '${tuning.freefallG.toStringAsFixed(2)}g / '
            '${tuning.impactMs2.toStringAsFixed(0)} m/s²',
        isFall: true,
      );
      ref.read(_d258TestCountProvider.notifier).state =
          ref.read(_d258TestCountProvider) + 1;
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mock fall detected · peak ${peak.toStringAsFixed(1)} m/s² · '
              'would emit FallEvent → TriggerOrchestrator',
            ),
            action: SnackBarAction(
              label: 'Day 36',
              onPressed: () => context.push(AppRoutes.imuService),
            ),
          ),
        );
      }
    } else {
      push('idle', 'Below tuned thresholds — no fall event emitted');
    }

    ref.read(_d258TestingProvider.notifier).state = false;
  }
}

// ── Tab 0: Sensitivity ────────────────────────────────────────────────────────
class _SensitivityTab extends StatelessWidget {
  const _SensitivityTab({
    required this.tuning,
    required this.enabled,
    required this.onPreset,
    required this.onSlider,
    required this.onEnabled,
  });

  final _FallTuning tuning;
  final bool enabled;
  final ValueChanged<_FallPreset> onPreset;
  final ValueChanged<int> onSlider;
  final ValueChanged<bool> onEnabled;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 18/20 · phone IMU-only · '
            'no watch / Health Kit HR',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Phone fall detection',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: const Text(
            'Accelerometer + gyro via ImuService (Day 36) · independent '
            'from DCS audio/scene models.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
          value: enabled,
          activeColor: _kAccent,
          onChanged: onEnabled,
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Preset sensitivity',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        SegmentedButton<_FallPreset>(
          segments: const [
            ButtonSegment(
              value: _FallPreset.low,
              label: Text('Low'),
              icon: Icon(Icons.trending_down_rounded, size: 14),
            ),
            ButtonSegment(
              value: _FallPreset.medium,
              label: Text('Medium'),
              icon: Icon(Icons.tune_rounded, size: 14),
            ),
            ButtonSegment(
              value: _FallPreset.high,
              label: Text('High'),
              icon: Icon(Icons.trending_up_rounded, size: 14),
            ),
          ],
          selected: tuning.preset != null ? {tuning.preset!} : {},
          onSelectionChanged: enabled ? (s) => onPreset(s.first) : null,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Fine tune · ${tuning.sensitivity}',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              tuning.presetLabel,
              style: TextStyle(
                color: _kAccent.withOpacity(0.9),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Slider(
          value: tuning.sensitivity.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '${tuning.sensitivity}',
          activeColor: enabled ? _kAccent : ZapColors.textMuted,
          onChanged: enabled ? (v) => onSlider(v.round()) : null,
        ),
        const SizedBox(height: ZapSpacing.md),
        _ThresholdCard(tuning: tuning, enabled: enabled),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.battery_alert_rounded,
                color: ZapColors.warning.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Battery impact',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      enabled
                          ? 'Continuous IMU sampling at 50 Hz · estimated '
                              '${tuning.batteryLabel} on mid-tier Android.\n'
                              'Higher sensitivity polls motion features more '
                              'aggressively and may increase false-positive '
                              'wake-ups.'
                          : 'Fall detector paused — IMU stream may still run '
                              'for DCS motion slot (Day 32).',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'DCS pipeline (separate channel)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Fall detection uses the phone IMU only. DCS fusion (scream, scene, '
          'motion models) runs on a parallel path — tune DCS sensitivity in '
          'Settings (Day 81) or open the engine screens below.',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.memory_rounded, size: 16),
              label: const Text('Day 32 DCS Engine'),
              onPressed: () => context.push(AppRoutes.dcsEngine),
            ),
            ActionChip(
              avatar: const Icon(Icons.stream_rounded, size: 16),
              label: const Text('Day 33 DCS Stream'),
              onPressed: () => context.push(AppRoutes.dcsStream),
            ),
            ActionChip(
              avatar: const Icon(Icons.sensors_rounded, size: 16),
              label: const Text('Day 36 IMU Service'),
              onPressed: () => context.push(AppRoutes.imuService),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.tuning, required this.enabled});

  final _FallTuning tuning;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? _kAccent : ZapColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tuned thresholds (${tuning.presetLabel})',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          _MetricRow(
            label: 'Freefall hold',
            value: '< ${tuning.freefallG.toStringAsFixed(2)} g '
                '(${tuning.freefallMs2.toStringAsFixed(1)} m/s²) '
                'for ≥ ${tuning.freefallHoldMs} ms',
          ),
          _MetricRow(
            label: 'Impact spike',
            value: '≥ ${tuning.impactMs2.toStringAsFixed(0)} m/s² '
                'within ${tuning.impactWindowMs} ms',
          ),
          const _MetricRow(
            label: 'Reference defaults',
            value: 'Day 36 FallDetector · 0.30 g · 25 m/s² · 200 ms',
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Test ───────────────────────────────────────────────────────────────
class _TestTab extends ConsumerWidget {
  const _TestTab({
    required this.tuning,
    required this.enabled,
    required this.testing,
    required this.onRunTest,
    required this.onClear,
  });

  final _FallTuning tuning;
  final bool enabled;
  final bool testing;
  final VoidCallback onRunTest;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_d258DetectorStateProvider);
    final events = ref.watch(_d258StreamEventsProvider);
    final peak = ref.watch(_d258LastPeakProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'State machine',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              _StateRail(current: state),
              if (peak > 0) ...[
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Last test peak: ${peak.toStringAsFixed(1)} m/s²',
                  style: TextStyle(
                    color: _kAccent.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: testing || !enabled ? null : onRunTest,
          icon: testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label:
              Text(testing ? 'Running mock fall…' : 'Test fall (mock stream)'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: events.isEmpty ? null : onClear,
          icon: const Icon(Icons.clear_all_rounded, size: 16),
          label: const Text('Clear stream log'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Feature stream log',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${events.length} event${events.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        if (events.isEmpty)
          const ZapEmptyInline(
            title: 'Tap Test fall to inject synthetic freefall + impact '
                'samples into a mock IMU feature stream (same sequence as '
                'Day 36).',
          )
        else
          ...events.map((e) => _StreamRow(event: e)),
      ],
    );
  }
}

class _StateRail extends StatelessWidget {
  const _StateRail({required this.current});

  final FallDetectorState current;

  @override
  Widget build(BuildContext context) {
    const steps = [
      FallDetectorState.idle,
      FallDetectorState.possibleFreefall,
      FallDetectorState.awaitingImpact,
      FallDetectorState.impactDetected,
    ];
    const labels = ['Idle', 'Freefall?', 'Await impact', 'Impact'];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: _stepColor(steps[i - 1], current).withOpacity(0.35),
              ),
            ),
          _StateDot(
            label: labels[i],
            active: current == steps[i],
            passed: steps.indexOf(current) > i,
          ),
        ],
      ],
    );
  }

  Color _stepColor(FallDetectorState step, FallDetectorState current) {
    if (current == step) return _kAccent;
    if (steps.indexOf(current) > steps.indexOf(step)) {
      return ZapColors.safe;
    }
    return ZapColors.border;
  }

  List<FallDetectorState> get steps => const [
        FallDetectorState.idle,
        FallDetectorState.possibleFreefall,
        FallDetectorState.awaitingImpact,
        FallDetectorState.impactDetected,
      ];
}

class _StateDot extends StatelessWidget {
  const _StateDot({
    required this.label,
    required this.active,
    required this.passed,
  });

  final String label;
  final bool active;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? _kAccent
        : passed
            ? ZapColors.safe
            : ZapColors.textMuted;
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                active || passed ? color.withOpacity(0.2) : ZapColors.bgSurface,
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: active
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StreamRow extends StatelessWidget {
  const _StreamRow({required this.event});

  final _StreamEvent event;

  @override
  Widget build(BuildContext context) {
    final time = '${event.at.hour.toString().padLeft(2, '0')}:'
        '${event.at.minute.toString().padLeft(2, '0')}:'
        '${event.at.second.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: event.isFall
            ? ZapColors.danger.withOpacity(0.08)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: event.isFall
              ? ZapColors.danger.withOpacity(0.4)
              : ZapColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.phase,
                  style: TextStyle(
                    color: event.isFall ? ZapColors.danger : _kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                Text(
                  event.detail,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.tuning, required this.enabled});

  final _FallTuning tuning;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final payload = tuning.toJson(enabled: enabled);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.phone_android_rounded,
          title: 'Phone IMU only',
          subtitle:
              'Accelerometer + gyroscope on-device · no Apple Watch, Wear OS, '
              'or Health Kit heart-rate fusion on this screen.',
        ),
        const _PolicyRow(
          icon: Icons.graphic_eq_rounded,
          title: 'Separate from DCS',
          subtitle:
              'DCS (Days 32–33) fuses scream/scene/motion audio models · fall '
              'detector is a dedicated IMU state machine (Day 36).',
        ),
        const _PolicyRow(
          icon: Icons.bolt_rounded,
          title: 'Test fall mock',
          subtitle:
              'Synthetic freefall + impact samples feed the feature stream '
              'without moving the device · same injection pattern as Day 36.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fall detection settings copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy settings JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 257 Score Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetScore),
            ),
            ActionChip(
              label: const Text('Day 36 IMU Service'),
              onPressed: () => context.push(AppRoutes.imuService),
            ),
            ActionChip(
              label: const Text('Day 33 DCS Stream'),
              onPressed: () => context.push(AppRoutes.dcsStream),
            ),
            ActionChip(
              label: const Text('Day 32 DCS Engine'),
              onPressed: () => context.push(AppRoutes.dcsEngine),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
