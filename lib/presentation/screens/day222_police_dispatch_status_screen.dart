/// Day 222 — Police Dispatch Status Flow
///
/// Section B (Days 221-240): during/after SOS, shows police dispatch timeline
/// Received → Dispatched → Officer en route → Arrived with reference number.
///
/// Tag: 🟡 MOCK-NOW — mock auto-advance every 8s; GET dispatch by sos_id.
///
/// Route: [AppRoutes.policeDispatchStatus] → `/police-dispatch-status`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum DispatchStepId { received, dispatched, enRoute, arrived }

extension DispatchStepIdX on DispatchStepId {
  String get apiKey => switch (this) {
        DispatchStepId.received => 'received',
        DispatchStepId.dispatched => 'dispatched',
        DispatchStepId.enRoute => 'en_route',
        DispatchStepId.arrived => 'arrived',
      };

  String get status => apiKey;

  int get index => DispatchStepId.values.indexOf(this);
}

class DispatchStepSpec {
  final DispatchStepId id;
  final String title;
  final String subtitle;
  final IconData icon;

  const DispatchStepSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _kReferenceNumber = 'MP-2026-88421';
const _kSosId = 'sos_a8f3c21e-8842';
const _kDepartment = 'Mumbai Police Cyber Cell';
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kSteps = [
  DispatchStepSpec(
    id: DispatchStepId.received,
    title: 'Received',
    subtitle: 'Cyber Cell acknowledged your SOS alert',
    icon: Icons.inbox_rounded,
  ),
  DispatchStepSpec(
    id: DispatchStepId.dispatched,
    title: 'Dispatched',
    subtitle: 'Unit MP-442 assigned · officer Singh',
    icon: Icons.local_shipping_rounded,
  ),
  DispatchStepSpec(
    id: DispatchStepId.enRoute,
    title: 'Officer en route',
    subtitle: 'GPS tracking active · ETA updating',
    icon: Icons.directions_car_filled_rounded,
  ),
  DispatchStepSpec(
    id: DispatchStepId.arrived,
    title: 'Arrived',
    subtitle: 'Officers on scene · stay visible if safe',
    icon: Icons.place_rounded,
  ),
];

class DispatchTimelineEntry {
  final String step;
  final DateTime at;

  const DispatchTimelineEntry({required this.step, required this.at});

  Map<String, dynamic> toJson() => {
        'step': step,
        'at': at.toUtc().toIso8601String(),
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d222TabProvider = StateProvider<int>((ref) => 0);
final _d222CurrentStepProvider =
    StateProvider<DispatchStepId>((ref) => DispatchStepId.received);
final _d222AutoAdvanceProvider = StateProvider<bool>((ref) => true);
final _d222DemoRunningProvider = StateProvider<bool>((ref) => false);
final _d222TimelineProvider =
    StateProvider<List<DispatchTimelineEntry>>((ref) => []);
final _d222EtaProvider = StateProvider<int>((ref) => 12);
final _d222TimerProvider = StateProvider<Timer?>((ref) => null);

const _kTabs = ['Live Dispatch', 'Controls', 'API Contract'];
const _kAutoAdvanceSeconds = 8;

DispatchStepId? _nextStep(DispatchStepId current) {
  final i = current.index;
  if (i >= DispatchStepId.values.length - 1) return null;
  return DispatchStepId.values[i + 1];
}

int _etaForStep(DispatchStepId step) => switch (step) {
      DispatchStepId.received => 12,
      DispatchStepId.dispatched => 10,
      DispatchStepId.enRoute => 12,
      DispatchStepId.arrived => 0,
    };

void _cancelTimer(WidgetRef ref) {
  ref.read(_d222TimerProvider.notifier).state?.cancel();
  ref.read(_d222TimerProvider.notifier).state = null;
}

void _appendTimeline(WidgetRef ref, DispatchStepId step) {
  ref.read(_d222TimelineProvider.notifier).update((entries) {
    if (entries.any((e) => e.step == step.apiKey)) return entries;
    return [
      ...entries,
      DispatchTimelineEntry(step: step.apiKey, at: DateTime.now())
    ];
  });
}

void _scheduleAutoAdvance(WidgetRef ref) {
  _cancelTimer(ref);
  if (!ref.read(_d222AutoAdvanceProvider)) return;
  if (!ref.read(_d222DemoRunningProvider)) return;
  if (ref.read(_d222CurrentStepProvider) == DispatchStepId.arrived) return;

  final timer = Timer(const Duration(seconds: _kAutoAdvanceSeconds), () {
    _advanceStep(ref);
    _scheduleAutoAdvance(ref);
  });
  ref.read(_d222TimerProvider.notifier).state = timer;
}

void _advanceStep(WidgetRef ref) {
  final current = ref.read(_d222CurrentStepProvider);
  final next = _nextStep(current);
  if (next == null) return;
  ref.read(_d222CurrentStepProvider.notifier).state = next;
  ref.read(_d222EtaProvider.notifier).state = _etaForStep(next);
  _appendTimeline(ref, next);
  if (ref.read(_d222DemoRunningProvider) &&
      ref.read(_d222AutoAdvanceProvider)) {
    _scheduleAutoAdvance(ref);
  }
}

void _startDemo(WidgetRef ref) {
  _cancelTimer(ref);
  ref.read(_d222CurrentStepProvider.notifier).state = DispatchStepId.received;
  ref.read(_d222EtaProvider.notifier).state =
      _etaForStep(DispatchStepId.received);
  ref.read(_d222TimelineProvider.notifier).state = [
    DispatchTimelineEntry(
      step: DispatchStepId.received.apiKey,
      at: DateTime.now(),
    ),
  ];
  ref.read(_d222DemoRunningProvider.notifier).state = true;
  _scheduleAutoAdvance(ref);
}

void _resetDemo(WidgetRef ref) {
  _cancelTimer(ref);
  ref.read(_d222DemoRunningProvider.notifier).state = false;
  ref.read(_d222CurrentStepProvider.notifier).state = DispatchStepId.received;
  ref.read(_d222EtaProvider.notifier).state = 12;
  ref.read(_d222TimelineProvider.notifier).state = [];
}

void _jumpToStep(WidgetRef ref, DispatchStepId step) {
  ref.read(_d222CurrentStepProvider.notifier).state = step;
  ref.read(_d222EtaProvider.notifier).state = _etaForStep(step);
  ref.read(_d222DemoRunningProvider.notifier).state = true;
  final timeline = <DispatchTimelineEntry>[];
  for (final s in DispatchStepId.values) {
    if (s.index <= step.index) {
      timeline.add(DispatchTimelineEntry(step: s.apiKey, at: DateTime.now()));
    }
  }
  ref.read(_d222TimelineProvider.notifier).state = timeline;
  _scheduleAutoAdvance(ref);
}

Map<String, dynamic> _buildApiResponse(
  DispatchStepId step,
  List<DispatchTimelineEntry> timeline,
  int eta,
) {
  return {
    'reference_number': _kReferenceNumber,
    'status': step.status,
    'timeline': timeline.map((e) => e.toJson()).toList(),
    'eta_minutes': eta,
    'department_name': _kDepartment,
    'sos_id': _kSosId,
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day222PoliceDispatchStatusScreen extends ConsumerStatefulWidget {
  const Day222PoliceDispatchStatusScreen({super.key});

  @override
  ConsumerState<Day222PoliceDispatchStatusScreen> createState() =>
      _Day222PoliceDispatchStatusScreenState();
}

class _Day222PoliceDispatchStatusScreenState
    extends ConsumerState<Day222PoliceDispatchStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startDemo(ref);
    });
  }

  @override
  void dispose() {
    ref.read(_d222TimerProvider.notifier).state?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d222TabProvider);
    final step = ref.watch(_d222CurrentStepProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 222 · Police Dispatch'),
        actions: [
          Semantics(
            label: 'Copy reference number $_kReferenceNumber',
            button: true,
            child: IconButton(
              tooltip: 'Copy reference #',
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: _kReferenceNumber),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied $_kReferenceNumber')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: _StatusChip(step: step),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d222TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LiveDispatchTab(),
              1 => const _ControlsTab(),
              _ => const _ApiContractTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Dispatch ──────────────────────────────────────────────────────
class _LiveDispatchTab extends ConsumerWidget {
  const _LiveDispatchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(_d222CurrentStepProvider);
    final eta = ref.watch(_d222EtaProvider);
    final running = ref.watch(_d222DemoRunningProvider);
    final auto = ref.watch(_d222AutoAdvanceProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section B Day 2/20 · Linked from SOS Active / Post-Incident',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.sos_rounded, size: 16),
              label: const Text('SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
            ),
            ActionChip(
              avatar: const Icon(Icons.local_police_rounded, size: 16),
              label: const Text('Day 221 Police'),
              onPressed: () => context.push(AppRoutes.policeDashboard),
            ),
            ActionChip(
              avatar: const Icon(Icons.web_rounded, size: 16),
              label: const Text('Day 223 WebLink'),
              onPressed: () => context.push(AppRoutes.policeWeblinkPreview),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ZapColors.info.withOpacity(0.12),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reference number',
                style: TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      _kReferenceNumber,
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Copy reference number',
                    button: true,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: _kReferenceNumber),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reference # copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              const Text(
                _kDepartment,
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'SOS ID: $_kSosId',
                style: TextStyle(
                  color: ZapColors.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
              if (step != DispatchStepId.arrived && eta > 0) ...[
                const SizedBox(height: ZapSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: ZapColors.warning, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ETA $eta min',
                      style: const TextStyle(
                        color: ZapColors.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
              if (step == DispatchStepId.arrived) ...[
                const SizedBox(height: ZapSpacing.md),
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: ZapColors.safe, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Officers on scene',
                      style: TextStyle(
                        color: ZapColors.safe,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Row(
          children: [
            const Text(
              'Dispatch timeline',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (running && auto && step != DispatchStepId.arrived)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ZapColors.info.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Auto ${_kAutoAdvanceSeconds}s',
                    style: TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...List.generate(_kSteps.length, (i) {
          final spec = _kSteps[i];
          final state = _stepVisualState(spec.id, step);
          return _TimelineStepTile(
            spec: spec,
            state: state,
            isLast: i == _kSteps.length - 1,
          );
        }),
        if (!running) ...[
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () => _startDemo(ref),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start dispatch demo'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.info,
            ),
          ),
        ],
      ],
    );
  }
}

enum _StepVisualState { upcoming, active, complete }

_StepVisualState _stepVisualState(DispatchStepId id, DispatchStepId current) {
  if (id.index < current.index) return _StepVisualState.complete;
  if (id.index == current.index) return _StepVisualState.active;
  return _StepVisualState.upcoming;
}

class _TimelineStepTile extends StatelessWidget {
  final DispatchStepSpec spec;
  final _StepVisualState state;
  final bool isLast;

  const _TimelineStepTile({
    required this.spec,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepVisualState.complete => ZapColors.safe,
      _StepVisualState.active => ZapColors.info,
      _StepVisualState.upcoming => ZapColors.textMuted,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 420),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(
                      state == _StepVisualState.upcoming ? 0.08 : 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.6),
                    width: state == _StepVisualState.active ? 2.5 : 1,
                  ),
                  boxShadow: state == _StepVisualState.active
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  state == _StepVisualState.complete
                      ? Icons.check_rounded
                      : spec.icon,
                  color: color,
                  size: 18,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
                    color: state == _StepVisualState.complete
                        ? ZapColors.safe.withOpacity(0.5)
                        : ZapColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : ZapSpacing.lg),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                opacity: state == _StepVisualState.upcoming ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: TextStyle(
                        color: state == _StepVisualState.upcoming
                            ? ZapColors.textSecondary
                            : ZapColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      spec.subtitle,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    if (state == _StepVisualState.active) ...[
                      const SizedBox(height: ZapSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ZapColors.info.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: ZapColors.info,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Controls ───────────────────────────────────────────────────────────
class _ControlsTab extends ConsumerWidget {
  const _ControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(_d222CurrentStepProvider);
    final auto = ref.watch(_d222AutoAdvanceProvider);
    final timeline = ref.watch(_d222TimelineProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SwitchListTile(
          title: const Text(
            'Auto-advance every 8s',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: const Text(
            'Mock demo — advances Received → Dispatched → En route → Arrived',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
          value: auto,
          activeColor: ZapColors.info,
          onChanged: (v) {
            ref.read(_d222AutoAdvanceProvider.notifier).state = v;
            if (v && ref.read(_d222DemoRunningProvider)) {
              _scheduleAutoAdvance(ref);
            } else {
              _cancelTimer(ref);
            }
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Jump to step',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kSteps.map((s) {
            final selected = step == s.id;
            return FilterChip(
              label: Text(s.title),
              selected: selected,
              onSelected: (_) => _jumpToStep(ref, s.id),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () => _advanceStep(ref),
          icon: const Icon(Icons.skip_next_rounded),
          label: const Text('Advance one step'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.info,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _startDemo(ref),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Restart demo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.textPrimary,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _resetDemo(ref),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            foregroundColor: ZapColors.danger,
            side: const BorderSide(color: ZapColors.danger),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        const Text(
          'Timeline JSON (mock GET response)',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontWeight: FontWeight.w600,
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
            _kJsonEncoder.convert(
              _buildApiResponse(step, timeline, ref.watch(_d222EtaProvider)),
            ),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: API Contract ───────────────────────────────────────────────────────
class _ApiContractTab extends ConsumerWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(_d222CurrentStepProvider);
    final timeline = ref.watch(_d222TimelineProvider);
    final eta = ref.watch(_d222EtaProvider);
    final liveJson = _kJsonEncoder.convert(
      _buildApiResponse(step, timeline, eta),
    );

    const sampleJson = '''{
  "reference_number": "MP-2026-88421",
  "status": "en_route",
  "timeline": [
    { "step": "received", "at": "2026-06-15T10:00:00Z" },
    { "step": "dispatched", "at": "2026-06-15T10:00:08Z" },
    { "step": "en_route", "at": "2026-06-15T10:00:16Z" }
  ],
  "eta_minutes": 12,
  "department_name": "Mumbai Police Cyber Cell",
  "sos_id": "sos_a8f3c21e-8842"
}''';

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
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZapColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GET',
                      style: TextStyle(
                        color: ZapColors.info,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  const Expanded(
                    child: Text(
                      '/api/v1/police/dispatch/{sos_id}/',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Poll during SOS Active when police integration is connected (Day 221).',
                style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Spec sample (en_route)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            sampleJson,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Live mock state',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.25)),
          ),
          child: SelectableText(
            liveJson,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              const ClipboardData(
                text: 'GET /api/v1/police/dispatch/{sos_id}/\n$sampleJson',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('API contract copied')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy contract'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 75),
            backgroundColor: ZapColors.bgElevated,
            foregroundColor: ZapColors.textPrimary,
          ),
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
            'Tomorrow: Day 224 — Referral invite a friend.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final DispatchStepId step;

  const _StatusChip({required this.step});

  @override
  Widget build(BuildContext context) {
    final spec = _kSteps[step.index];
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.info.withOpacity(0.4)),
      ),
      child: Text(
        spec.title,
        style: const TextStyle(
          color: ZapColors.info,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.info : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
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
