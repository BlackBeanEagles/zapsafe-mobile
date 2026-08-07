/// Day 247 — Hearing Impaired — Haptic Patterns
///
/// Section C (Days 241-260): custom vibration patterns for SOS vs drill vs
/// journey check-in; visual waveform preview; play-test with HapticFeedback.
///
/// Tag: 🟢 FRONTEND-ONLY · pairs with Day 246 visual alerts · Day 97 haptics.
///
/// Route: [AppRoutes.hapticPatterns] → `/haptic-patterns`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/accessibility_providers.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFA855F7);
const _kTabs = ['Patterns', 'Test', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// ── Models ────────────────────────────────────────────────────────────────────
enum _HapticKind { heavy, medium, light, vibrate, pause }

class _HapticStep {
  const _HapticStep(this.kind, {this.durationMs = 0});

  final _HapticKind kind;
  final int durationMs;
}

class _HapticPatternDef {
  const _HapticPatternDef({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.steps,
    required this.useCase,
  });

  final String id;
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<_HapticStep> steps;
  final String useCase;

  List<_HapticKind> get pulseKinds =>
      steps.where((s) => s.kind != _HapticKind.pause).map((s) => s.kind).toList();
}

const _kPatternDefs = [
  _HapticPatternDef(
    id: 'sos',
    label: 'SOS Active',
    subtitle: 'Triple heavy + vibrate — emergency unmistakable',
    color: ZapColors.danger,
    icon: Icons.emergency_rounded,
    useCase: 'SOS_ACTIVE · alert pending expiry',
    steps: [
      _HapticStep(_HapticKind.heavy),
      _HapticStep(_HapticKind.pause, durationMs: 160),
      _HapticStep(_HapticKind.heavy),
      _HapticStep(_HapticKind.pause, durationMs: 160),
      _HapticStep(_HapticKind.vibrate),
      _HapticStep(_HapticKind.pause, durationMs: 220),
      _HapticStep(_HapticKind.heavy),
      _HapticStep(_HapticKind.pause, durationMs: 160),
      _HapticStep(_HapticKind.vibrate),
    ],
  ),
  _HapticPatternDef(
    id: 'drill',
    label: 'Safety drill',
    subtitle: 'Medium-light-medium — practice without panic',
    color: ZapColors.warning,
    icon: Icons.fitness_center_rounded,
    useCase: 'DRILL_MODE · scheduled practice reminders',
    steps: [
      _HapticStep(_HapticKind.medium),
      _HapticStep(_HapticKind.pause, durationMs: 120),
      _HapticStep(_HapticKind.light),
      _HapticStep(_HapticKind.pause, durationMs: 120),
      _HapticStep(_HapticKind.medium),
      _HapticStep(_HapticKind.pause, durationMs: 280),
      _HapticStep(_HapticKind.light),
    ],
  ),
  _HapticPatternDef(
    id: 'journey',
    label: 'Journey check-in',
    subtitle: 'Double light tap — gentle nudge',
    color: _kAccent,
    icon: Icons.route_rounded,
    useCase: 'JOURNEY_MODE · check-in reminder (Day 241)',
    steps: [
      _HapticStep(_HapticKind.light),
      _HapticStep(_HapticKind.pause, durationMs: 90),
      _HapticStep(_HapticKind.light),
    ],
  ),
];

_HapticPatternDef _patternById(String id) {
  return _kPatternDefs.firstWhere(
    (p) => p.id == id,
    orElse: () => _kPatternDefs.first,
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d247TabProvider = StateProvider<int>((ref) => 0);
final _d247SelectedPatternProvider = StateProvider<String>((ref) => 'sos');
final _d247PlayingProvider = StateProvider<bool>((ref) => false);
final _d247ActiveStepProvider = StateProvider<int>((ref) => -1);
final _d247PlayCountProvider = StateProvider<int>((ref) => 0);
final _d247EnabledPatternsProvider = StateProvider<Set<String>>(
  (ref) => {'sos', 'drill', 'journey'},
);

// ── Haptic playback helper ────────────────────────────────────────────────────
Future<void> _runHapticSteps(
  List<_HapticStep> steps, {
  required void Function(int stepIndex) onStep,
  required bool Function() shouldContinue,
}) async {
  for (var i = 0; i < steps.length; i++) {
    if (!shouldContinue()) break;
    onStep(i);
    final step = steps[i];
    switch (step.kind) {
      case _HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case _HapticKind.medium:
        HapticFeedback.mediumImpact();
      case _HapticKind.light:
        HapticFeedback.lightImpact();
      case _HapticKind.vibrate:
        HapticFeedback.vibrate();
      case _HapticKind.pause:
        break;
    }
    if (step.durationMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: step.durationMs));
    }
  }
  onStep(-1);
}

String _kindLabel(_HapticKind kind) => switch (kind) {
      _HapticKind.heavy => 'Heavy',
      _HapticKind.medium => 'Medium',
      _HapticKind.light => 'Light',
      _HapticKind.vibrate => 'Vibrate',
      _HapticKind.pause => 'Pause',
    };

double _kindBarHeight(_HapticKind kind) => switch (kind) {
      _HapticKind.heavy => 1.0,
      _HapticKind.medium => 0.72,
      _HapticKind.light => 0.45,
      _HapticKind.vibrate => 0.88,
      _HapticKind.pause => 0.12,
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day247HapticPatternsScreen extends ConsumerStatefulWidget {
  const Day247HapticPatternsScreen({super.key});

  @override
  ConsumerState<Day247HapticPatternsScreen> createState() =>
      _Day247HapticPatternsScreenState();
}

class _Day247HapticPatternsScreenState
    extends ConsumerState<Day247HapticPatternsScreen> {
  bool _playSession = true;

  Future<void> _playPattern(String patternId) async {
    final a11y = ref.read(accessibilityProvider);
    if (!a11y.hapticFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Haptics disabled in Day 97 Accessibility settings.'),
        ),
      );
      return;
    }

    final enabled = ref.read(_d247EnabledPatternsProvider);
    if (!enabled.contains(patternId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable this pattern on the Patterns tab.')),
      );
      return;
    }

    if (ref.read(_d247PlayingProvider)) return;

    ref.read(_d247PlayingProvider.notifier).state = true;
    ref.read(_d247SelectedPatternProvider.notifier).state = patternId;
    ref.read(_d247PlayCountProvider.notifier).state =
        ref.read(_d247PlayCountProvider) + 1;
    _playSession = true;

    final pattern = _patternById(patternId);
    await _runHapticSteps(
      pattern.steps,
      onStep: (i) {
        if (mounted) {
          ref.read(_d247ActiveStepProvider.notifier).state = i;
        }
      },
      shouldContinue: () => _playSession && mounted,
    );

    if (mounted) {
      ref.read(_d247PlayingProvider.notifier).state = false;
      ref.read(_d247ActiveStepProvider.notifier).state = -1;
    }
  }

  void _stopPlayback() {
    _playSession = false;
    ref.read(_d247PlayingProvider.notifier).state = false;
    ref.read(_d247ActiveStepProvider.notifier).state = -1;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d247TabProvider);
    final playing = ref.watch(_d247PlayingProvider);
    final selected = ref.watch(_d247SelectedPatternProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 247 · Haptic Patterns'),
        actions: [
          if (playing)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _kAccent.withOpacity(0.45)),
                  ),
                  child: const Text(
                    'PLAYING',
                    style: TextStyle(
                      color: _kAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
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
            onSelect: (i) => ref.read(_d247TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PatternsTab(onPlay: _playPattern),
              1 => _TestTab(
                  onPlay: _playPattern,
                  onStop: _stopPlayback,
                ),
              _ => _InfoTab(selectedId: selected),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Patterns ───────────────────────────────────────────────────────────
class _PatternsTab extends ConsumerWidget {
  const _PatternsTab({required this.onPlay});

  final Future<void> Function(String id) onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(_d247EnabledPatternsProvider);
    final playing = ref.watch(_d247PlayingProvider);
    final activeStep = ref.watch(_d247ActiveStepProvider);
    final selected = ref.watch(_d247SelectedPatternProvider);

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
            '🟢 FRONTEND-ONLY · Section C Day 7/20 · SOS · drill · journey check-in',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kPatternDefs.map((p) {
          final isEnabled = enabled.contains(p.id);
          final isSelected = selected == p.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Container(
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected && playing
                      ? p.color
                      : isEnabled
                          ? p.color.withOpacity(0.35)
                          : ZapColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: isEnabled,
                    onChanged: playing
                        ? null
                        : (v) {
                            final next = Set<String>.from(enabled);
                            if (v) {
                              next.add(p.id);
                            } else {
                              next.remove(p.id);
                            }
                            ref
                                .read(_d247EnabledPatternsProvider.notifier)
                                .state = next;
                          },
                    secondary: Icon(p.icon, color: p.color),
                    title: Text(
                      p.label,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      p.subtitle,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    activeColor: p.color,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _Waveform(
                      pattern: p,
                      activeStep: isSelected ? activeStep : -1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.useCase,
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed:
                              (isEnabled && !playing) ? () => onPlay(p.id) : null,
                          icon: Icon(Icons.play_arrow_rounded, color: p.color),
                          label: Text(
                            'Preview',
                            style: TextStyle(color: p.color, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.accessibilitySettings),
          icon: const Icon(Icons.accessibility_new_rounded, size: 18),
          label: const Text('Day 97 · Haptic feedback toggle'),
        ),
      ],
    );
  }
}

// ── Tab 1: Test ───────────────────────────────────────────────────────────────
class _TestTab extends ConsumerWidget {
  const _TestTab({
    required this.onPlay,
    required this.onStop,
  });

  final Future<void> Function(String id) onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d247SelectedPatternProvider);
    final playing = ref.watch(_d247PlayingProvider);
    final activeStep = ref.watch(_d247ActiveStepProvider);
    final playCount = ref.watch(_d247PlayCountProvider);
    final pattern = _patternById(selected);
    final a11y = ref.watch(accessibilityProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Select pattern',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kPatternDefs.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: selected == p.id
                  ? p.color.withOpacity(0.12)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: playing
                    ? null
                    : () =>
                        ref.read(_d247SelectedPatternProvider.notifier).state =
                            p.id,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected == p.id ? p.color : ZapColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected == p.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected == p.id ? p.color : ZapColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.label,
                          style: TextStyle(
                            color: selected == p.id
                                ? ZapColors.textPrimary
                                : ZapColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pattern.color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(Icons.vibration_rounded, size: 48, color: pattern.color),
              const SizedBox(height: 12),
              Text(
                pattern.label,
                style: TextStyle(
                  color: pattern.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              _Waveform(pattern: pattern, activeStep: activeStep, height: 72),
              const SizedBox(height: ZapSpacing.md),
              if (activeStep >= 0 && activeStep < pattern.steps.length)
                Text(
                  'Step ${activeStep + 1}: '
                  '${_kindLabel(pattern.steps[activeStep].kind)}',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                )
              else
                Text(
                  '${pattern.pulseKinds.length} pulses · '
                  '${pattern.steps.where((s) => s.kind == _HapticKind.pause).fold<int>(0, (a, s) => a + s.durationMs)}ms pauses',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: (!playing && a11y.hapticFeedback)
                    ? () => onPlay(selected)
                    : null,
                icon: const Icon(Icons.play_circle_rounded),
                label: const Text('Play pattern'),
                style: FilledButton.styleFrom(
                  backgroundColor: pattern.color,
                  disabledBackgroundColor:
                      ZapColors.textMuted.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: playing ? onStop : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Stop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Tests run: $playCount · '
          'Haptics ${a11y.hapticFeedback ? 'ON' : 'OFF (Day 97)'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Each pattern is distinct so hearing-impaired users can tell SOS '
            'apart from drills and journey check-ins by feel alone.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(_d247EnabledPatternsProvider);
    final playCount = ref.watch(_d247PlayCountProvider);
    final a11y = ref.watch(accessibilityProvider);

    final payload = {
      'feature': 'haptic_patterns',
      'version': '1.0.0',
      'section': 'C',
      'day': 247,
      'haptic_feedback_enabled': a11y.hapticFeedback,
      'enabled_patterns': enabled.toList(),
      'patterns': _kPatternDefs
          .map(
            (p) => {
              'id': p.id,
              'label': p.label,
              'use_case': p.useCase,
              'steps': p.steps
                  .map(
                    (s) => {
                      'kind': s.kind.name,
                      if (s.durationMs > 0) 'duration_ms': s.durationMs,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'play_test_count': playCount,
      'visual_alerts_route': AppRoutes.hearingImpairedVisual,
      'journey_mode_route': AppRoutes.journeyModeV2,
    };

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
            '🟢 FRONTEND-ONLY · Tactile alert channel · complements Day 246 visual flash',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Pattern map',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'SOS Active',
          subtitle:
              'Heavy-heavy-vibrate-heavy-vibrate — longest, strongest pattern.',
        ),
        const _PolicyRow(
          icon: Icons.fitness_center_rounded,
          title: 'Safety drill',
          subtitle: 'Medium-light-medium-light — shorter, calmer cadence.',
        ),
        const _PolicyRow(
          icon: Icons.route_rounded,
          title: 'Journey check-in',
          subtitle: 'Double light tap — gentle reminder (Day 241 check-in).',
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
            borderRadius: BorderRadius.circular(8),
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
              const SnackBar(content: Text('Haptic patterns JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy patterns JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 250 Group Journey'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
            ActionChip(
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 246 Visual Alerts'),
              onPressed: () => context.push(AppRoutes.hearingImpairedVisual),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Waveform widget ───────────────────────────────────────────────────────────
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.pattern,
    required this.activeStep,
    this.height = 48,
  });

  final _HapticPatternDef pattern;
  final int activeStep;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(pattern.steps.length, (i) {
          final step = pattern.steps[i];
          final active = i == activeStep;
          final h = height * _kindBarHeight(step.kind);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: h.clamp(4, height),
                decoration: BoxDecoration(
                  color: step.kind == _HapticKind.pause
                      ? ZapColors.textMuted.withOpacity(active ? 0.35 : 0.15)
                      : pattern.color.withOpacity(active ? 1 : 0.45),
                  borderRadius: BorderRadius.circular(3),
                  border: active
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 20),
          const SizedBox(width: 10),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
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
