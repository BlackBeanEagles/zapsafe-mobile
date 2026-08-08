/// Day 203 — SOS Long-Press Ring Animation
///
/// Section A (Days 201-220): clockwise gray→red ring during 2s hold,
/// intensifying haptics, early-release "Cancelled" flash.
///
/// Tag: 🟣 POLISH — ships reusable [SosLongPressRingButton] widget.
///
/// Route: [AppRoutes.sosLongPressRing] → `/sos-long-press-ring`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/sos_long_press_ring_button.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d203TabProvider = StateProvider<int>((ref) => 0);
final _d203HapticsProvider = StateProvider<bool>((ref) => true);
final _d203ReduceMotionProvider = StateProvider<bool>((ref) => false);
final _d203EnabledProvider = StateProvider<bool>((ref) => true);
final _d203SizeProvider = StateProvider<double>((ref) => 80);
final _d203PhaseProvider = StateProvider<SosLongPressPhase>(
  (ref) => SosLongPressPhase.idle,
);
final _d203EventLogProvider = StateProvider<List<String>>((ref) => []);

const _kTabs = ['Live Preview', 'Controls', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day203SosLongPressRingScreen extends ConsumerWidget {
  const Day203SosLongPressRingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d203TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 203 · SOS Long-Press Ring'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d203TabProvider.notifier).state = i,
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

  void _logEvent(WidgetRef ref, String message) {
    final now = TimeOfDay.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    ref.read(_d203EventLogProvider.notifier).update(
          (log) => ['$stamp · $message', ...log].take(8).toList(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(_d203PhaseProvider);
    final haptics = ref.watch(_d203HapticsProvider);
    final reduceMotion = ref.watch(_d203ReduceMotionProvider);
    final enabled = ref.watch(_d203EnabledProvider);
    final size = ref.watch(_d203SizeProvider);
    final events = ref.watch(_d203EventLogProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 3/20 · Hold 2 seconds — release early to cancel',
            style: TextStyle(color: ZapColors.danger, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Isolated SOS button — same widget drops into the production dashboard.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Center(
          child: SosLongPressRingButton(
            size: size,
            enabled: enabled,
            hapticsEnabled: haptics,
            reduceMotion: reduceMotion,
            onPhaseChanged: (p) {
              ref.read(_d203PhaseProvider.notifier).state = p;
              switch (p) {
                case SosLongPressPhase.holding:
                  _logEvent(ref, 'Hold started');
                case SosLongPressPhase.cancelled:
                  _logEvent(ref, 'Cancelled — released early');
                case SosLongPressPhase.triggered:
                  _logEvent(ref, 'SOS triggered (mock)');
                case SosLongPressPhase.idle:
                  break;
              }
            },
            onTriggered: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Mock SOS — would start 15s countdown + notify Tier 1',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Center(child: _PhaseChip(phase: phase)),
        const SizedBox(height: ZapSpacing.xl),
        _ProgressLegend(),
        const SizedBox(height: ZapSpacing.lg),
        _IntegrationNote(),
        if (events.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Event log',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                e,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 205 — Onboarding skip paths.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final SosLongPressPhase phase;

  const _PhaseChip({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      SosLongPressPhase.idle => ('Ready', ZapColors.textMuted),
      SosLongPressPhase.holding => ('Holding…', ZapColors.warning),
      SosLongPressPhase.triggered => ('SOS triggered', ZapColors.danger),
      SosLongPressPhase.cancelled => ('Cancelled', ZapColors.neutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ProgressLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      ('0s', 'Gray ring · light haptic'),
      ('0.5s', 'Ring turns red · medium haptic'),
      ('1.0s', 'Half fill · medium haptic'),
      ('1.5s', 'Three-quarter · heavy haptic'),
      ('2.0s', 'Full ring · SOS fires'),
    ];

    return Container(
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
            'Hold timeline',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        color: ZapColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
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
        ],
      ),
    );
  }
}

class _IntegrationNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgSurface,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard integration',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: ZapSpacing.xs),
          Text(
            'Replace the SOS placeholder in dashboard_placeholder.dart with '
            'SosLongPressRingButton. Wire onTriggered to TriggerOrchestrator '
            'manualSos() — same 2s hold, unchanged trigger timing.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
              height: 1.4,
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
    final haptics = ref.watch(_d203HapticsProvider);
    final reduceMotion = ref.watch(_d203ReduceMotionProvider);
    final enabled = ref.watch(_d203EnabledProvider);
    final size = ref.watch(_d203SizeProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _ControlToggle(
          title: 'Haptic feedback',
          subtitle: 'Light → medium → heavy as ring fills',
          value: haptics,
          onChanged: (v) => ref.read(_d203HapticsProvider.notifier).state = v,
        ),
        _ControlToggle(
          title: 'Reduce motion',
          subtitle: 'Ring jumps to full stroke (hold still 2s)',
          value: reduceMotion,
          onChanged: (v) =>
              ref.read(_d203ReduceMotionProvider.notifier).state = v,
        ),
        _ControlToggle(
          title: 'Button enabled',
          subtitle: 'Disabled state for locked / safe mode',
          value: enabled,
          onChanged: (v) => ref.read(_d203EnabledProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
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
              Text(
                'Button size: ${size.round()}dp',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Slider(
                value: size,
                min: 64,
                max: 96,
                divisions: 8,
                activeColor: ZapColors.danger,
                onChanged: (v) =>
                    ref.read(_d203SizeProvider.notifier).state = v,
              ),
              const Text(
                'Production default: 80dp (accessibility large mode: 96dp)',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Clear event log',
          button: true,
          child: OutlinedButton(
            onPressed: () {
              ref.read(_d203EventLogProvider.notifier).state = [];
              ref.read(_d203PhaseProvider.notifier).state =
                  SosLongPressPhase.idle;
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: const Text('Clear event log'),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy widget import path',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: "import '../widgets/sos_long_press_ring_button.dart';",
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import path copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy widget import'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ControlToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: ZapColors.danger.withOpacity(value ? 0.4 : 0.15),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: ZapColors.danger,
        title: Text(
          title,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Hold duration', '2 seconds — fixed, do not change'),
      ('Ring direction', 'Clockwise from 12 o\'clock'),
      ('Ring colors', 'Gray track → red fill (lerp by progress)'),
      ('Early release', '"Cancelled" flash ~650ms'),
      ('Haptics', '4-step ramp: light / medium / medium / heavy'),
      ('Trigger', 'onTriggered at 100% — wires to SOS pipeline'),
      ('Accessibility', 'Semantics label + reduce-motion mode'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'SOS long-press ring (MASTER_HANDOFF polish item)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rows.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
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
                  r.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  r.$2,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget: lib/presentation/widgets/sos_long_press_ring_button.dart\n'
          '• kSosLongPressDuration = 2 seconds\n'
          '• SosLongPressRingButton — drop-in dashboard SOS\n'
          '• SosLongPressPhase — idle / holding / triggered / cancelled',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ],
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
                        color: selected ? ZapColors.danger : Colors.transparent,
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
