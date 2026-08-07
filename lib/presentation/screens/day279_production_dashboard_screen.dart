/// Day 279 — Production Dashboard Integration
///
/// Section D (Days 261-280): wires polished widgets from Days 202–204 into a
/// unified production dashboard layout and documents delta from the placeholder.
///
/// Tag: 🟣 POLISH · integrates ModeStatusCard, notification stack, SOS ring.
///
/// Route: [AppRoutes.productionDashboard] → `/production-dashboard`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/trigger_orchestrator_providers.dart';
import '../widgets/dashboard_notification_banner.dart';
import '../widgets/mode_status_card.dart';
import '../widgets/sos_long_press_ring_button.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kTabs = ['Dashboard', 'Delta', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kSeedNotifications = [
  DashboardNotificationData(
    id: 'critical_battery',
    tier: DashboardNotificationTier.critical,
    title: 'Battery critically low',
    message:
        'Battery below 10%. SOS evidence may be limited to audio-only until you charge.',
  ),
  DashboardNotificationData(
    id: 'important_contact',
    tier: DashboardNotificationTier.important,
    title: 'Tier 2 contact unverified',
    message:
        'Priya Sharma has not confirmed your emergency contact request.',
    actionLabel: 'Verify now',
  ),
  DashboardNotificationData(
    id: 'suggestion_drill',
    tier: DashboardNotificationTier.suggestion,
    title: 'Monthly drill due',
    message: 'Last drill was 28 days ago. A 10-second practice helps.',
    actionLabel: 'Start drill',
  ),
];

const _kPlaceholderDelta = [
  (
    'Mode header',
    'Static text in PlaceholderScaffold',
    'ModeStatusCard — expandable · battery · DCS (Day 204)',
  ),
  (
    'Inline alerts',
    'Listed as future feature bullet',
    'DashboardNotificationStack — 3 tiers (Day 202)',
  ),
  (
    'SOS button',
    'Described in placeholder copy',
    'SosLongPressRingButton — 2s ring + haptics (Day 203)',
  ),
  (
    'Protection score',
    'Referenced Day 4 widget',
    'Score ring wired in dashboard column',
  ),
  (
    'Simple mode',
    'Mentioned in placeholder',
    'Toggle hides chrome · SOS + mode label only',
  ),
];

Map<String, dynamic> _dashboardPayload({
  required SafetyDashboardMode mode,
  required bool simpleMode,
  required int notificationCount,
  required bool modeExpanded,
}) =>
    {
      'endpoint': 'GET /api/v1/dashboard/home/',
      'layout': 'production_v279',
      'simple_mode': simpleMode,
      'mode': mode.name,
      'mode_card_expanded': modeExpanded,
      'widgets_integrated': [
        'ModeStatusCard (Day 204)',
        'DashboardNotificationStack (Day 202)',
        'SosLongPressRingButton (Day 203)',
      ],
      'placeholder_route': AppRoutes.dashboard,
      'active_notifications': notificationCount,
      'wire_note': 'Replace DashboardPlaceholderScreen when backend home API ships',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d279TabProvider = StateProvider<int>((ref) => 0);
final _d279ModeProvider = StateProvider<SafetyDashboardMode>(
  (ref) => SafetyDashboardMode.monitoring,
);
final _d279ExpandedProvider = StateProvider<bool>((ref) => false);
final _d279SimpleModeProvider = StateProvider<bool>((ref) => false);
final _d279ActiveProvider = StateProvider<Set<String>>((ref) => {
      'critical_battery',
      'important_contact',
      'suggestion_drill',
    });
final _d279PendingAckProvider = StateProvider<Set<String>>((ref) => {
      'critical_battery',
    });
final _d279ProtectionProvider = StateProvider<int>((ref) => 78);

ModeStatusData _modeData(WidgetRef ref) {
  final mode = ref.watch(_d279ModeProvider);
  return ModeStatusData(
    mode: mode,
    batteryPercent: mode == SafetyDashboardMode.critical ? 9 : 72,
    lastDcsScore: 0.18,
    gpsActive: mode != SafetyDashboardMode.minimal,
    protectionScore: ref.watch(_d279ProtectionProvider),
    activeModels: mode == SafetyDashboardMode.minimal ? 0 : 4,
  );
}

List<DashboardNotificationData> _visibleNotifications(WidgetRef ref) {
  final active = ref.watch(_d279ActiveProvider);
  final pendingAck = ref.watch(_d279PendingAckProvider);

  return _kSeedNotifications.where((n) {
    if (!active.contains(n.id)) return false;
    if (n.tier == DashboardNotificationTier.critical) {
      return pendingAck.contains(n.id);
    }
    return true;
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day279ProductionDashboardScreen extends ConsumerWidget {
  const Day279ProductionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simpleMode = ref.watch(_d279SimpleModeProvider);
    final mode = ref.watch(_d279ModeProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 279 · Production Dashboard'),
        actions: [
          IconButton(
            tooltip: simpleMode ? 'Exit simple mode' : 'Simple mode preview',
            onPressed: () => ref.read(_d279SimpleModeProvider.notifier).state =
                !simpleMode,
            icon: Icon(
              simpleMode ? Icons.dashboard_rounded : Icons.view_compact_rounded,
              color: simpleMode ? _kAccent : ZapColors.textMuted,
            ),
          ),
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
                child: Text(
                  simpleMode ? 'SIMPLE' : mode.label,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
            tab: ref.watch(_d279TabProvider),
            onSelect: (i) => ref.read(_d279TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d279TabProvider)) {
              0 => const _DashboardTab(),
              1 => const _DeltaTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simpleMode = ref.watch(_d279SimpleModeProvider);
    final modeData = _modeData(ref);
    final expanded = ref.watch(_d279ExpandedProvider);
    final notifications = _visibleNotifications(ref);
    final score = ref.watch(_d279ProtectionProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (!simpleMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: const Text(
              '🟣 POLISH · Section D Day 19/20 · Days 202–204 widgets integrated · production layout',
              style: TextStyle(color: _kAccent, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ModeStatusCard(
            data: modeData,
            expanded: expanded,
            onExpandedChanged: (v) =>
                ref.read(_d279ExpandedProvider.notifier).state = v,
          ),
          const SizedBox(height: ZapSpacing.md),
          DashboardNotificationStack(
            notifications: notifications,
            onDismiss: (id) {
              ref.read(_d279ActiveProvider.notifier).update(
                    (s) => {...s}..remove(id),
                  );
            },
            onAcknowledge: (id) {
              ref.read(_d279PendingAckProvider.notifier).update(
                    (s) => {...s}..remove(id),
                  );
              ref.read(_d279ActiveProvider.notifier).update(
                    (s) => {...s}..remove(id),
                  );
            },
            onAction: (id) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Action tapped: $id (mock)')),
              );
            },
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _ProtectionScoreRing(score: score),
              const SizedBox(width: ZapSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Protection Score',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(
                      'Day 4 widget pattern · $score/100',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Start journey'),
                          onPressed: () =>
                              context.push(AppRoutes.journeyModeV2),
                        ),
                        ActionChip(
                          label: const Text('Trusted circle'),
                          onPressed: () =>
                              context.push(AppRoutes.trustedCircleV2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
        ] else ...[
          Center(
            child: Text(
              modeData.mode.label,
              style: TextStyle(
                color: modeData.mode.accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
        ],
        Center(
          child: SosLongPressRingButton(
            size: simpleMode ? 96 : 80,
            onTriggered: () {
              ref.read(triggerOrchestratorProvider).dispatchManual(
                    TriggerMethod.manual,
                    cause: 'production dashboard SOS ring',
                  );
            },
          ),
        ),
        if (!simpleMode) ...[
          const SizedBox(height: ZapSpacing.lg),
          const Center(
            child: Text(
              'Hold 2 seconds · release early to cancel',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.dashboard),
            icon: const Icon(Icons.compare_arrows_rounded, size: 16),
            label: const Text('Open placeholder dashboard (Day 46–50)'),
          ),
        ],
      ],
    );
  }
}

class _ProtectionScoreRing extends StatelessWidget {
  const _ProtectionScoreRing({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? ZapColors.safe
        : score >= 60
            ? ZapColors.warning
            : ZapColors.danger;

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: ZapColors.border,
            color: color,
          ),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Delta ──────────────────────────────────────────────────────────────
class _DeltaTab extends ConsumerWidget {
  const _DeltaTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Placeholder vs production',
          subtitle: 'Delta from DashboardPlaceholderScreen (Day 46–50)',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'AppRoutes.dashboard still routes to the placeholder scaffold. '
            'This screen is the integration reference — swap the route when '
            'the home API and state machine are production-ready.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kPlaceholderDelta.map(
          (row) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.article_outlined,
                        size: 14, color: ZapColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Before: ${row.$2}',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: ZapColors.safe),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'After: ${row.$3}',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Mode preview',
          subtitle: 'Cycle safety modes · updates ModeStatusCard live',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SafetyDashboardMode.values.map((m) {
            final selected = ref.watch(_d279ModeProvider) == m;
            return FilterChip(
              label: Text(m.label),
              selected: selected,
              selectedColor: m.accent.withOpacity(0.2),
              onSelected: (_) =>
                  ref.read(_d279ModeProvider.notifier).state = m,
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_d279ModeProvider);
    final simpleMode = ref.watch(_d279SimpleModeProvider);
    final expanded = ref.watch(_d279ExpandedProvider);
    final notifications = _visibleNotifications(ref);
    final payload = _dashboardPayload(
      mode: mode,
      simpleMode: simpleMode,
      notificationCount: notifications.length,
      modeExpanded: expanded,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.dashboard_customize_rounded,
          title: 'Production dashboard integration',
          subtitle:
              'Composes ModeStatusCard (204), DashboardNotificationStack (202), '
              'and SosLongPressRingButton (203) into one scrollable home layout.',
        ),
        const _PolicyRow(
          icon: Icons.compare_arrows_rounded,
          title: 'Placeholder delta documented',
          subtitle:
              'Delta tab lists every upgrade from DashboardPlaceholderScreen · '
              'route swap deferred until backend home API ships.',
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
              const SnackBar(content: Text('Production dashboard spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy dashboard spec'),
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
              label: const Text('Day 204 Mode Status Card'),
              onPressed: () => context.push(AppRoutes.modeStatusCard),
            ),
            ActionChip(
              label: const Text('Day 202 Notifications'),
              onPressed: () => context.push(AppRoutes.dashboardNotifications),
            ),
            ActionChip(
              label: const Text('Day 203 SOS Ring'),
              onPressed: () => context.push(AppRoutes.sosLongPressRing),
            ),
            ActionChip(
              label: const Text('Placeholder dashboard'),
              onPressed: () => context.push(AppRoutes.dashboard),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
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
