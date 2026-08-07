/// Day 204 — Persistent Mode Status Card
///
/// Section A (Days 201-220): expandable dashboard header with mode colors,
/// battery icon, last DCS score, tap-to-expand details.
///
/// Tag: 🟣 POLISH — ships reusable [ModeStatusCard] widget.
///
/// Route: [AppRoutes.modeStatusCard] → `/mode-status-card`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../widgets/mode_status_card.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d204TabProvider = StateProvider<int>((ref) => 0);
final _d204ModeProvider = StateProvider<SafetyDashboardMode>(
  (ref) => SafetyDashboardMode.monitoring,
);
final _d204ExpandedProvider = StateProvider<bool>((ref) => false);
final _d204BatteryProvider = StateProvider<int>((ref) => 72);
final _d204DcsProvider = StateProvider<double>((ref) => 0.18);
final _d204GpsActiveProvider = StateProvider<bool>((ref) => true);
final _d204ReduceMotionProvider = StateProvider<bool>((ref) => false);
final _d204ProtectionProvider = StateProvider<int>((ref) => 78);

const _kTabs = ['Live Preview', 'Mode Controls', 'Spec'];

ModeStatusData _buildData(WidgetRef ref) {
  final mode = ref.watch(_d204ModeProvider);
  return ModeStatusData(
    mode: mode,
    batteryPercent: ref.watch(_d204BatteryProvider),
    lastDcsScore: ref.watch(_d204DcsProvider),
    gpsActive: ref.watch(_d204GpsActiveProvider),
    gpsInterval: switch (mode) {
      SafetyDashboardMode.minimal => 'off',
      SafetyDashboardMode.monitoring => '30s',
      SafetyDashboardMode.elevated => '15s',
      SafetyDashboardMode.high => '10s',
      SafetyDashboardMode.critical => '3s',
    },
    lastDcsAt: switch (mode) {
      SafetyDashboardMode.minimal => '—',
      SafetyDashboardMode.critical => 'just now',
      SafetyDashboardMode.high => '12s ago',
      _ => '2 min ago',
    },
    protectionScore: ref.watch(_d204ProtectionProvider),
    activeModels: mode == SafetyDashboardMode.minimal ? 0 : 4,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day204ModeStatusCardScreen extends ConsumerWidget {
  const Day204ModeStatusCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d204TabProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 204 · Mode Status Card'),
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d204TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _LivePreviewTab(),
              1 => const _ModeControlsTab(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = _buildData(ref);
    final expanded = ref.watch(_d204ExpandedProvider);
    final reduceMotion = ref.watch(_d204ReduceMotionProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 4/20 · Tap card to expand mode details',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Mock dashboard top — replaces the small static mode badge.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModeStatusCard(
                data: data,
                expanded: expanded,
                reduceMotion: reduceMotion,
                onExpandedChanged: (v) =>
                    ref.read(_d204ExpandedProvider.notifier).state = v,
              ),
              const SizedBox(height: ZapSpacing.xl),
              const _DashboardBodyPlaceholder(),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _ModeColorLegend(),
        const SizedBox(height: ZapSpacing.lg),
        _IntegrationNote(),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 206 — Evidence Vault search & filter.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _DashboardBodyPlaceholder extends StatelessWidget {
  const _DashboardBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Day 202 notification banners',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ZapColors.danger.withOpacity(0.15),
            border: Border.all(color: ZapColors.danger),
          ),
          child: const Icon(
            Icons.emergency_rounded,
            color: ZapColors.danger,
            size: 36,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Day 203 SOS ring button',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ModeColorLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode colors',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...SafetyDashboardMode.values.map((mode) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: mode.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  SizedBox(
                    width: 88,
                    child: Text(
                      mode.label,
                      style: TextStyle(
                        color: mode.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      mode.shouldPulse ? '${mode.description} · pulse' : mode.description,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
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
        borderRadius: BorderRadius.circular(8),
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
            'Place ModeStatusCard at the top of dashboard_placeholder.dart. '
            'Feed mode from AppStateNotifier (map alert_pending/sos_active → HIGH/CRITICAL). '
            'Battery from BatteryService · DCS from DCSScoreWatcher.',
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

// ── Tab 1: Mode Controls ──────────────────────────────────────────────────────
class _ModeControlsTab extends ConsumerWidget {
  const _ModeControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_d204ModeProvider);
    final battery = ref.watch(_d204BatteryProvider);
    final dcs = ref.watch(_d204DcsProvider);
    final expanded = ref.watch(_d204ExpandedProvider);
    final gpsActive = ref.watch(_d204GpsActiveProvider);
    final reduceMotion = ref.watch(_d204ReduceMotionProvider);
    final protection = ref.watch(_d204ProtectionProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Safety mode',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          children: SafetyDashboardMode.values.map((m) {
            final selected = mode == m;
            return Semantics(
              label: '${m.label} mode',
              button: true,
              selected: selected,
              child: FilterChip(
                label: Text(m.label),
                selected: selected,
                onSelected: (_) =>
                    ref.read(_d204ModeProvider.notifier).state = m,
                selectedColor: m.accent.withOpacity(0.2),
                checkmarkColor: m.accent,
                labelStyle: TextStyle(
                  color: selected ? m.accent : ZapColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? m.accent : ZapColors.border,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.xl),
        _SliderCard(
          title: 'Battery: $battery%',
          child: Slider(
            value: battery.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            activeColor: battery <= 10
                ? ZapColors.danger
                : battery <= 20
                    ? ZapColors.warning
                    : ZapColors.safe,
            onChanged: (v) =>
                ref.read(_d204BatteryProvider.notifier).state = v.round(),
          ),
        ),
        _SliderCard(
          title: 'Last DCS score: ${(dcs * 100).round()}%',
          child: Slider(
            value: dcs,
            min: 0,
            max: 1,
            divisions: 20,
            activeColor: mode.accent,
            onChanged: (v) => ref.read(_d204DcsProvider.notifier).state = v,
          ),
        ),
        _SliderCard(
          title: 'Protection Score: $protection',
          child: Slider(
            value: protection.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: ZapColors.info,
            onChanged: (v) =>
                ref.read(_d204ProtectionProvider.notifier).state = v.round(),
          ),
        ),
        _ControlToggle(
          title: 'Card expanded',
          subtitle: 'Simulate user tap-to-expand',
          value: expanded,
          onChanged: (v) =>
              ref.read(_d204ExpandedProvider.notifier).state = v,
        ),
        _ControlToggle(
          title: 'GPS active',
          subtitle: 'Shows polling interval in expanded view',
          value: gpsActive,
          onChanged: (v) =>
              ref.read(_d204GpsActiveProvider.notifier).state = v,
        ),
        _ControlToggle(
          title: 'Reduce motion',
          subtitle: 'Disables CRITICAL pulse and color transitions',
          value: reduceMotion,
          onChanged: (v) =>
              ref.read(_d204ReduceMotionProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.xl),
        Semantics(
          label: 'Reset controls to defaults',
          button: true,
          child: OutlinedButton(
            onPressed: () {
              ref.read(_d204ModeProvider.notifier).state =
                  SafetyDashboardMode.monitoring;
              ref.read(_d204BatteryProvider.notifier).state = 72;
              ref.read(_d204DcsProvider.notifier).state = 0.18;
              ref.read(_d204ExpandedProvider.notifier).state = false;
              ref.read(_d204GpsActiveProvider.notifier).state = true;
              ref.read(_d204ReduceMotionProvider.notifier).state = false;
              ref.read(_d204ProtectionProvider.notifier).state = 78;
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
            child: const Text('Reset to defaults'),
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
                  text: "import '../widgets/mode_status_card.dart';",
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

class _SliderCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SliderCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          child,
        ],
      ),
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
          color: ZapColors.safe.withOpacity(value ? 0.4 : 0.15),
        ),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: ZapColors.safe,
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
      ('MINIMAL', 'Gray · sensors off · SOS still available'),
      ('MONITORING', 'Teal/safe · default running state'),
      ('ELEVATED', 'Orange/warning · suspicious signal'),
      ('HIGH', 'Orange-red · strong distress cue'),
      ('CRITICAL', 'Red/danger · border pulse animation'),
      ('Collapsed', 'Mode + battery chip + DCS chip + chevron'),
      ('Expanded', 'Protection score · GPS · last DCS · models'),
      ('Tap target', 'Full card is tappable · 75dp min height'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Persistent mode status card (MASTER_HANDOFF polish item)',
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
              borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 4),
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
          'Widget: lib/presentation/widgets/mode_status_card.dart\n'
          '• SafetyDashboardMode — 5 dashboard modes\n'
          '• ModeStatusData — battery · DCS · GPS · protection\n'
          '• ModeStatusCard — expandable persistent header',
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
                        color: selected ? ZapColors.safe : Colors.transparent,
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
