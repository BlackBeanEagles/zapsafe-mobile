/// Day 213 — Animation Polish Pass
///
/// Section A (Days 201-220): tune SOS breathe, mode badge color morph,
/// protection score ring fill, and page transitions with speed slider +
/// reduced-motion respect and before/after comparisons.
///
/// Tag: 🟣 POLISH — animation tuning demo, no new backend.
///
/// Route: [AppRoutes.animationPolish] → `/animation-polish`
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/mode_status_card.dart';
import '../widgets/protection_score_ring.dart';
import '../widgets/sos_long_press_ring_button.dart';

// ── Animation helpers ─────────────────────────────────────────────────────────
const _kPageTransitionPolishedMs = 320;
const _kPageTransitionLegacyMs = 150;
const _kScoreFillPolishedMs = 1000;
const _kScoreFillLegacyMs = 180;
const _kModeMorphPolishedMs = 420;

Duration _scaledDuration({
  required int baseMs,
  required double speed,
  required bool reduceMotion,
}) {
  if (reduceMotion) return Duration.zero;
  final ms = (baseMs / speed).round().clamp(0, 5000);
  return Duration(milliseconds: ms);
}

Curve _curveFor({required bool polished, required bool reduceMotion}) {
  if (reduceMotion) return Curves.linear;
  return polished ? Curves.easeOutCubic : Curves.linear;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d213TabProvider = StateProvider<int>((ref) => 0);
final _d213SpeedProvider = StateProvider<double>((ref) => 1.0);
final _d213ReduceMotionProvider = StateProvider<bool>((ref) => false);
final _d213ModeProvider =
    StateProvider<SafetyDashboardMode>((ref) => SafetyDashboardMode.monitoring);
final _d213ScoreProvider = StateProvider<int>((ref) => 45);
final _d213PageIndexProvider = StateProvider<int>((ref) => 0);
final _d213ReplayTickProvider = StateProvider<int>((ref) => 0);

const _kTabs = ['Live Preview', 'Controls', 'Spec'];

const _kModes = SafetyDashboardMode.values;

const _kScoreSteps = [18, 45, 72, 88, 95];

const _kPageLabels = ['Dashboard', 'Contacts', 'Vault'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day213AnimationPolishScreen extends ConsumerWidget {
  const Day213AnimationPolishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d213TabProvider);
    final systemReduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 213 · Animation Polish'),
      ),
      body: Column(
        children: [
          if (systemReduceMotion)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md,
                vertical: ZapSpacing.sm,
              ),
              color: ZapColors.warning.withOpacity(0.15),
              child: const Text(
                'System reduce-motion is ON — previews honor Duration.zero.',
                style: TextStyle(color: ZapColors.warning, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d213TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LivePreviewTab(),
              1 => const _ControlsTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Preview ───────────────────────────────────────────────────────
class _LivePreviewTab extends ConsumerWidget {
  const _LivePreviewTab();

  void _replay(WidgetRef ref) {
    ref.read(_d213ReplayTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(_d213SpeedProvider);
    final reduceMotion = ref.watch(_d213ReduceMotionProvider) ||
        MediaQuery.of(context).disableAnimations;
    final mode = ref.watch(_d213ModeProvider);
    final score = ref.watch(_d213ScoreProvider);
    final pageIndex = ref.watch(_d213PageIndexProvider);
    final replayTick = ref.watch(_d213ReplayTickProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF06B6D4).withOpacity(0.35),
            ),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 13/20 · easeOutCubic · 200–400ms · reduced motion',
            style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              label: 'Speed ${speed.toStringAsFixed(1)}×',
              color: ZapColors.info,
            ),
            _InfoChip(
              label: reduceMotion ? 'Reduce motion ON' : 'Reduce motion OFF',
              color: reduceMotion ? ZapColors.warning : ZapColors.safe,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        _CompareSection(
          title: '1 · SOS idle breathe',
          subtitle: 'Subtle scale pulse when SOS is idle (not holding)',
          onReplay: () => _replay(ref),
          beforeLabel: 'Before · static',
          afterLabel: 'After · breathe 900ms',
          before: _SosBreatheDemo(
            key: ValueKey('sos-before-$replayTick'),
            polished: false,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
          after: _SosBreatheDemo(
            key: ValueKey('sos-after-$replayTick'),
            polished: true,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
        ),
        _CompareSection(
          title: '2 · Mode badge color morph',
          subtitle: 'MONITORING → ELEVATED → CRITICAL transitions',
          onReplay: () {
            ref.read(_d213ModeProvider.notifier).state =
                SafetyDashboardMode.monitoring;
            Future<void>.delayed(const Duration(milliseconds: 50), () {
              ref.read(_d213ModeProvider.notifier).state =
                  SafetyDashboardMode.elevated;
              Future<void>.delayed(const Duration(milliseconds: 700), () {
                ref.read(_d213ModeProvider.notifier).state =
                    SafetyDashboardMode.critical;
              });
            });
          },
          beforeLabel: 'Before · snap',
          afterLabel: 'After · 420ms morph',
          before: _ModeMorphBadge(
            mode: mode,
            polished: false,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
          after: _ModeMorphBadge(
            mode: mode,
            polished: true,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
        ),
        _CompareSection(
          title: '3 · Protection score ring',
          subtitle: '1s counter tick with easeOutCubic fill',
          onReplay: () {
            final i = _kScoreSteps.indexOf(score);
            final next = _kScoreSteps[(i + 1) % _kScoreSteps.length];
            ref.read(_d213ScoreProvider.notifier).state = next;
          },
          beforeLabel: 'Before · linear ${ _kScoreFillLegacyMs}ms',
          afterLabel: 'After · ${_kScoreFillPolishedMs}ms tick',
          before: _ScoreRingDemo(
            key: ValueKey('score-before-$score-$replayTick'),
            score: score,
            polished: false,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
          after: _ScoreRingDemo(
            key: ValueKey('score-after-$score-$replayTick'),
            score: score,
            polished: true,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
        ),
        _CompareSection(
          title: '4 · Page transitions',
          subtitle: 'Mock route push: linear 150ms vs easeOutCubic 320ms',
          onReplay: () {
            ref.read(_d213PageIndexProvider.notifier).state =
                (pageIndex + 1) % _kPageLabels.length;
          },
          beforeLabel: 'Before · linear',
          afterLabel: 'After · easeOutCubic',
          before: _PageTransitionDemo(
            key: ValueKey('page-before-$pageIndex-$replayTick'),
            pageIndex: pageIndex,
            polished: false,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
          after: _PageTransitionDemo(
            key: ValueKey('page-after-$pageIndex-$replayTick'),
            pageIndex: pageIndex,
            polished: true,
            speed: speed,
            reduceMotion: reduceMotion,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Center(
          child: SosLongPressRingButton(
            size: 64,
            reduceMotion: reduceMotion,
            hapticsEnabled: false,
            onTriggered: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Production widget (Day 203) — hold ring uses same speed tokens',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Hold-to-trigger SOS ring (Day 203 widget) respects reduce-motion.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Tab 1: Controls ───────────────────────────────────────────────────────────
class _ControlsTab extends ConsumerWidget {
  const _ControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(_d213SpeedProvider);
    final reduceMotion = ref.watch(_d213ReduceMotionProvider);
    final mode = ref.watch(_d213ModeProvider);
    final score = ref.watch(_d213ScoreProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Global animation controls',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Speed ${speed.toStringAsFixed(1)}×',
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        Slider(
          value: speed,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${speed.toStringAsFixed(1)}×',
          activeColor: const Color(0xFF06B6D4),
          onChanged: (v) => ref.read(_d213SpeedProvider.notifier).state = v,
        ),
        const Text(
          '0.5× slower · 1.0× default · 2.0× faster',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          value: reduceMotion,
          onChanged: (v) =>
              ref.read(_d213ReduceMotionProvider.notifier).state = v,
          activeColor: ZapColors.warning,
          title: const Text(
            'Reduce motion',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: const Text(
            'All demos jump to final state (matches Day 97 a11y setting)',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Demo triggers',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_kModes.length, (i) {
            final m = _kModes[i];
            final selected = mode == m;
            return FilterChip(
              label: Text(m.label),
              selected: selected,
              onSelected: (_) =>
                  ref.read(_d213ModeProvider.notifier).state = m,
              selectedColor: m.accent.withOpacity(0.25),
              checkmarkColor: m.accent,
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kScoreSteps.map((s) {
            return ActionChip(
              label: Text('Score $s'),
              onPressed: () =>
                  ref.read(_d213ScoreProvider.notifier).state = s,
              backgroundColor: ZapColors.bgElevated,
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Reset all animation demos',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              ref.read(_d213SpeedProvider.notifier).state = 1.0;
              ref.read(_d213ReduceMotionProvider.notifier).state = false;
              ref.read(_d213ModeProvider.notifier).state =
                  SafetyDashboardMode.monitoring;
              ref.read(_d213ScoreProvider.notifier).state = 45;
              ref.read(_d213PageIndexProvider.notifier).state = 0;
              ref.read(_d213ReplayTickProvider.notifier).state++;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Animation demos reset')),
              );
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            label: const Text('Reset all'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ModeStatusCard(
          data: ModeStatusData(
            mode: mode,
            batteryPercent: 82,
            lastDcsScore: 0.12,
            protectionScore: score,
          ),
          expanded: true,
          reduceMotion: reduceMotion,
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const tokens = [
      ('SOS breathe', '900ms · scale 1.0→1.06 · reverse · idle only'),
      ('Mode morph', '420ms · easeOutCubic · border + fill opacity'),
      ('Score ring', '1000ms · easeOutCubic · counter tick + arc sweep'),
      ('Page push', '320ms · easeOutCubic · slide from right 12%'),
      ('Legacy baseline', '150–180ms · linear · instant color snap'),
    ];

    const adopt = [
      ('Day 203 SOS ring', 'hold progress already easeOut — add idle breathe'),
      ('Day 204 ModeStatusCard', '420ms morph + critical pulse (done)'),
      ('Day 59 Protection Score', 'ProtectionScoreRing duration + curve'),
      ('Day 145 Cold Start', 'first-frame page fade 300ms easeOutCubic'),
      ('Day 97 Accessibility', 'reduce-motion + speed segment wiring'),
      ('GoRouter transitions', 'CustomTransitionPage easeOutCubic 320ms'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Animation polish pass (Day 213)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Token targets',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...tokens.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    t.$1,
                    style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    t.$2,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Screens to adopt',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...adopt.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ZapColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${a.$1}\n',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: a.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy animation duration helper',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'Duration zapAnimMs(int baseMs, double speed, bool reduceMotion) {\n'
                      '  if (reduceMotion) return Duration.zero;\n'
                      '  return Duration(milliseconds: (baseMs / speed).round());\n'
                      '}\n'
                      'const kCurvePolished = Curves.easeOutCubic;',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Animation helper copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy duration helper'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 215 — Font scale 200% regression (textScaleFactor 1.0→2.0).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ── Compare layout ────────────────────────────────────────────────────────────
class _CompareSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String beforeLabel;
  final String afterLabel;
  final Widget before;
  final Widget after;
  final VoidCallback onReplay;

  const _CompareSection({
    required this.title,
    required this.subtitle,
    required this.beforeLabel,
    required this.afterLabel,
    required this.before,
    required this.after,
    required this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.lg),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: 'Replay $title animation',
                button: true,
                child: IconButton(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay_rounded),
                  color: const Color(0xFF06B6D4),
                  tooltip: 'Replay',
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ComparePane(label: beforeLabel, child: before),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: _ComparePane(label: afterLabel, child: after),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparePane extends StatelessWidget {
  final String label;
  final Widget child;

  const _ComparePane({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ZapColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Demo 1: SOS breathe ───────────────────────────────────────────────────────
class _SosBreatheDemo extends StatefulWidget {
  final bool polished;
  final double speed;
  final bool reduceMotion;

  const _SosBreatheDemo({
    super.key,
    required this.polished,
    required this.speed,
    required this.reduceMotion,
  });

  @override
  State<_SosBreatheDemo> createState() => _SosBreatheDemoState();
}

class _SosBreatheDemoState extends State<_SosBreatheDemo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _scaledDuration(
        baseMs: 900,
        speed: widget.speed,
        reduceMotion: widget.reduceMotion,
      ),
    );
    if (widget.polished && !widget.reduceMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _SosBreatheDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _scaledDuration(
      baseMs: 900,
      speed: widget.speed,
      reduceMotion: widget.reduceMotion,
    );
    if (widget.polished && !widget.reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    final breathe = widget.polished && !widget.reduceMotion
        ? 1.0 + _controller.value * 0.06
        : 1.0;
    final glow = widget.polished && !widget.reduceMotion
        ? 0.15 + _controller.value * 0.25
        : 0.15;

    return Transform.scale(
      scale: breathe,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ZapColors.danger,
          boxShadow: [
            BoxShadow(
              color: ZapColors.danger.withOpacity(glow),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

// ── Demo 2: Mode morph badge ──────────────────────────────────────────────────
class _ModeMorphBadge extends StatelessWidget {
  final SafetyDashboardMode mode;
  final bool polished;
  final double speed;
  final bool reduceMotion;

  const _ModeMorphBadge({
    required this.mode,
    required this.polished,
    required this.speed,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.accent;
    final duration = polished
        ? _scaledDuration(
            baseMs: _kModeMorphPolishedMs,
            speed: speed,
            reduceMotion: reduceMotion,
          )
        : Duration.zero;

    return AnimatedContainer(
      duration: duration,
      curve: _curveFor(polished: polished, reduceMotion: reduceMotion),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            mode.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Demo 3: Score ring ────────────────────────────────────────────────────────
class _ScoreRingDemo extends StatelessWidget {
  final int score;
  final bool polished;
  final double speed;
  final bool reduceMotion;

  const _ScoreRingDemo({
    super.key,
    required this.score,
    required this.polished,
    required this.speed,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return ProtectionScoreRing(
        score: score,
        size: 100,
        duration: Duration.zero,
        label: 'SCORE',
      );
    }

    final duration = _scaledDuration(
      baseMs: polished ? _kScoreFillPolishedMs : _kScoreFillLegacyMs,
      speed: speed,
      reduceMotion: false,
    );

    return _AnimatedScoreRing(
      score: score,
      duration: duration,
      curve: _curveFor(polished: polished, reduceMotion: false),
      size: 100,
    );
  }
}

class _AnimatedScoreRing extends StatefulWidget {
  final int score;
  final Duration duration;
  final Curve curve;
  final double size;

  const _AnimatedScoreRing({
    required this.score,
    required this.duration,
    required this.curve,
    required this.size,
  });

  @override
  State<_AnimatedScoreRing> createState() => _AnimatedScoreRingState();
}

class _AnimatedScoreRingState extends State<_AnimatedScoreRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.score;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: _from.toDouble(),
      end: widget.score.toDouble(),
    ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
    _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _AnimatedScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score != oldWidget.score ||
        widget.duration != oldWidget.duration ||
        widget.curve != oldWidget.curve) {
      _ctrl.duration = widget.duration;
      _anim = Tween<double>(
        begin: _from.toDouble(),
        end: widget.score.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
      _ctrl
        ..reset()
        ..forward();
      _from = widget.score;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value.round();
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _MiniRingPainter(
              progress: _anim.value / 100,
              color: _colorForScore(_anim.value),
            ),
            child: Center(
              child: Text(
                v.toString(),
                style: ZapTypography.displayLarge.copyWith(
                  color: _colorForScore(_anim.value),
                  fontSize: widget.size * 0.28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _colorForScore(double score) {
  if (score >= 80) return ZapColors.safe;
  if (score >= 50) return ZapColors.info;
  if (score >= 20) return ZapColors.warning;
  return ZapColors.danger;
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MiniRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.08;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = ZapColors.bgSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Demo 4: Page transition ───────────────────────────────────────────────────
class _PageTransitionDemo extends StatefulWidget {
  final int pageIndex;
  final bool polished;
  final double speed;
  final bool reduceMotion;

  const _PageTransitionDemo({
    super.key,
    required this.pageIndex,
    required this.polished,
    required this.speed,
    required this.reduceMotion,
  });

  @override
  State<_PageTransitionDemo> createState() => _PageTransitionDemoState();
}

class _PageTransitionDemoState extends State<_PageTransitionDemo> {
  int _displayIndex = 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _displayIndex = widget.pageIndex;
  }

  @override
  void didUpdateWidget(covariant _PageTransitionDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageIndex != oldWidget.pageIndex) {
      _forward = widget.pageIndex > oldWidget.pageIndex ||
          (oldWidget.pageIndex == _kPageLabels.length - 1 &&
              widget.pageIndex == 0);
      setState(() => _displayIndex = widget.pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseMs =
        widget.polished ? _kPageTransitionPolishedMs : _kPageTransitionLegacyMs;
    final duration = _scaledDuration(
      baseMs: baseMs,
      speed: widget.speed,
      reduceMotion: widget.reduceMotion,
    );
    final curve = _curveFor(
      polished: widget.polished,
      reduceMotion: widget.reduceMotion,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: curve,
          switchOutCurve: curve,
          transitionBuilder: (child, animation) {
            if (widget.reduceMotion) return child;
            final offset = Tween<Offset>(
              begin: Offset(_forward ? 0.12 : -0.12, 0),
              end: Offset.zero,
            ).animate(animation);
            return SlideTransition(
              position: offset,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _MockPage(
            key: ValueKey(_displayIndex),
            label: _kPageLabels[_displayIndex],
            color: _pageColor(_displayIndex),
          ),
        ),
      ),
    );
  }
}

Color _pageColor(int index) => switch (index) {
      0 => ZapColors.safe,
      1 => ZapColors.info,
      _ => const Color(0xFF8B5CF6),
    };

class _MockPage extends StatelessWidget {
  final String label;
  final Color color;

  const _MockPage({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: 80,
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
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
                        color: selected
                            ? const Color(0xFF06B6D4)
                            : Colors.transparent,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
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
