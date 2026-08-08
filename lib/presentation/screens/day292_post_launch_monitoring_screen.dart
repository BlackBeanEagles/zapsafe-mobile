/// Day 292 — Post-Launch Monitoring Plan
///
/// Section E (Days 281-300): first 72-hour war room checklist — crash rate,
/// SOS success, false-positive rate, and support inbox triage after store launch.
///
/// Tag: 🟢 FRONTEND-ONLY · mock war room · no live ops API.
///
/// Route: [AppRoutes.postLaunchMonitoring] → `/post-launch-monitoring`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFDC2626);
const _kTabs = ['War Room', 'Timeline', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kWarRoomHours = 72;

enum _MonitorStatus { pending, ok, warn, alert }

class _WarRoomItem {
  const _WarRoomItem({
    required this.id,
    required this.window,
    required this.title,
    required this.metric,
    required this.threshold,
    required this.current,
    required this.owner,
    required this.defaultStatus,
  });

  final String id;
  final String window;
  final String title;
  final String metric;
  final String threshold;
  final String current;
  final String owner;
  final _MonitorStatus defaultStatus;
}

const _kWarRoomItems = [
  _WarRoomItem(
    id: 'crash_0_24',
    window: '0–24h',
    title: 'Crash-free sessions',
    metric: 'Sentry crash-free %',
    threshold: '≥ 99.5%',
    current: '99.62%',
    owner: 'Eng',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'sos_0_24',
    window: '0–24h',
    title: 'SOS delivery success',
    metric: 'Tier-1 contact ACK rate',
    threshold: '≥ 98%',
    current: '98.4%',
    owner: 'Safety',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'fp_0_24',
    window: '0–24h',
    title: 'False positive rate',
    metric: 'User-reported FP / journeys',
    threshold: '< 3%',
    current: '2.1%',
    owner: 'ML',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'support_0_24',
    window: '0–24h',
    title: 'Support inbox P0',
    metric: 'Open P0 tickets',
    threshold: '0 open',
    current: '1 open',
    owner: 'Support',
    defaultStatus: _MonitorStatus.warn,
  ),
  _WarRoomItem(
    id: 'crash_24_48',
    window: '24–48h',
    title: 'ANR regression check',
    metric: 'Play vitals ANR',
    threshold: '< 0.1%',
    current: '0.07%',
    owner: 'Eng',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'sos_24_48',
    window: '24–48h',
    title: 'Counselor queue SLA',
    metric: 'P95 wait time',
    threshold: '< 3 min',
    current: '2.4 min',
    owner: 'Ops',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'fp_24_48',
    window: '24–48h',
    title: 'Store review sentiment',
    metric: '1-star rate (rolling)',
    threshold: '< 5%',
    current: '3.8%',
    owner: 'Growth',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'support_24_48',
    window: '24–48h',
    title: 'Billing / deletion tickets',
    metric: 'GDPR + refund queue',
    threshold: '< 4h first response',
    current: '2.1h avg',
    owner: 'Support',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'crash_48_72',
    window: '48–72h',
    title: 'Staged rollout advance',
    metric: 'Play % rollout',
    threshold: '50% if gates pass',
    current: '25% (Day 290 sim)',
    owner: 'Release',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'sos_48_72',
    window: '48–72h',
    title: 'India MSG91 delivery',
    metric: 'OTP + SOS SMS success',
    threshold: '≥ 97%',
    current: '96.2%',
    owner: 'Backend',
    defaultStatus: _MonitorStatus.warn,
  ),
  _WarRoomItem(
    id: 'fp_48_72',
    window: '48–72h',
    title: 'NPS post-launch',
    metric: 'Beta Round 3 NPS',
    threshold: '≥ 50',
    current: '58',
    owner: 'Product',
    defaultStatus: _MonitorStatus.ok,
  ),
  _WarRoomItem(
    id: 'support_48_72',
    window: '48–72h',
    title: 'War room sign-off',
    metric: 'All gates green',
    threshold: '0 alert items',
    current: '2 warn',
    owner: 'Launch lead',
    defaultStatus: _MonitorStatus.warn,
  ),
];

String _statusKey(_MonitorStatus s) => switch (s) {
      _MonitorStatus.pending => 'pending',
      _MonitorStatus.ok => 'ok',
      _MonitorStatus.warn => 'warn',
      _MonitorStatus.alert => 'alert',
    };

_MonitorStatus _statusFromKey(String? key) => switch (key) {
      'ok' => _MonitorStatus.ok,
      'warn' => _MonitorStatus.warn,
      'alert' => _MonitorStatus.alert,
      _ => _MonitorStatus.pending,
    };

Color _statusColor(_MonitorStatus s) => switch (s) {
      _MonitorStatus.pending => ZapColors.textMuted,
      _MonitorStatus.ok => ZapColors.safe,
      _MonitorStatus.warn => ZapColors.warning,
      _MonitorStatus.alert => ZapColors.danger,
    };

IconData _statusIcon(_MonitorStatus s) => switch (s) {
      _MonitorStatus.pending => Icons.radio_button_unchecked_rounded,
      _MonitorStatus.ok => Icons.check_circle_rounded,
      _MonitorStatus.warn => Icons.warning_rounded,
      _MonitorStatus.alert => Icons.error_rounded,
    };

Map<String, dynamic> _monitoringPayload({
  required Map<String, String> statuses,
  required double elapsedHours,
}) {
  final ok = statuses.values.where((v) => v == 'ok').length;
  final warn = statuses.values.where((v) => v == 'warn').length;
  final alert = statuses.values.where((v) => v == 'alert').length;
  return {
    'endpoint': 'GET /api/v1/ops/post-launch-monitoring/',
    'war_room_hours': _kWarRoomHours,
    'elapsed_hours': elapsedHours.round(),
    'items_total': _kWarRoomItems.length,
    'ok': ok,
    'warn': warn,
    'alert': alert,
    'war_room_clear': alert == 0 && warn <= 2,
    'pillars': ['crash_rate', 'sos_success', 'fp_rate', 'support_inbox'],
    'wire_note': 'Mock 72h plan · ties to Day 288 crash-free gate',
  };
}

String _buildWarRoomReport({
  required Map<String, String> statuses,
  required double elapsedHours,
}) {
  final buf = StringBuffer('ZapSafe Post-Launch War Room (72h)\n\n');
  buf.writeln('Elapsed: ${elapsedHours.round()}h / $_kWarRoomHours h');
  buf.writeln();
  String? lastWindow;
  for (final item in _kWarRoomItems) {
    if (item.window != lastWindow) {
      buf.writeln('── ${item.window} ──');
      lastWindow = item.window;
    }
    final st = _statusFromKey(statuses[item.id]);
    buf.writeln(
      '[${_statusKey(st).toUpperCase()}] ${item.title} · ${item.current} '
      '(gate: ${item.threshold})',
    );
  }
  final p = _monitoringPayload(statuses: statuses, elapsedHours: elapsedHours);
  buf.writeln();
  buf.writeln('war_room_clear=${p['war_room_clear']}');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d292TabProvider = StateProvider<int>((ref) => 0);
final _d292StatusesProvider = StateProvider<Map<String, String>>((ref) {
  return {
    for (final i in _kWarRoomItems) i.id: _statusKey(i.defaultStatus),
  };
});
final _d292ElapsedHoursProvider = StateProvider<double>((ref) => 18);
final _d292WindowFilterProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day292PostLaunchMonitoringScreen extends ConsumerWidget {
  const Day292PostLaunchMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d292StatusesProvider);
    final alerts = statuses.values.where((v) => v == 'alert').length;
    final elapsed = ref.watch(_d292ElapsedHoursProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 292 · Post-Launch Monitor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: (alerts > 0 ? ZapColors.danger : _kAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (alerts > 0 ? ZapColors.danger : _kAccent)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  alerts > 0 ? '$alerts ALERT' : 'T+${elapsed.round()}h',
                  style: TextStyle(
                    color: alerts > 0 ? ZapColors.danger : _kAccent,
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
            tab: ref.watch(_d292TabProvider),
            onSelect: (i) => ref.read(_d292TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d292TabProvider)) {
              0 => const _WarRoomTab(),
              1 => const _TimelineTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: War Room ───────────────────────────────────────────────────────────
class _WarRoomTab extends ConsumerWidget {
  const _WarRoomTab();

  void _cycleStatus(WidgetRef ref, String id) {
    final current = _statusFromKey(ref.read(_d292StatusesProvider)[id]);
    final next = switch (current) {
      _MonitorStatus.pending => _MonitorStatus.ok,
      _MonitorStatus.ok => _MonitorStatus.warn,
      _MonitorStatus.warn => _MonitorStatus.alert,
      _MonitorStatus.alert => _MonitorStatus.ok,
    };
    ref.read(_d292StatusesProvider.notifier).state = {
      ...ref.read(_d292StatusesProvider),
      id: _statusKey(next),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d292StatusesProvider);
    final window = ref.watch(_d292WindowFilterProvider);
    final elapsed = ref.watch(_d292ElapsedHoursProvider);
    final items = _kWarRoomItems.where((i) {
      if (window == null) return true;
      return i.window == window;
    });

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: '72-hour war room',
          subtitle: 'Crash · SOS · false positives · support inbox',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'T+${elapsed.round()} hours since launch',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Slider(
                value: elapsed,
                min: 0,
                max: _kWarRoomHours.toDouble(),
                divisions: 24,
                label: 'T+${elapsed.round()}h',
                activeColor: _kAccent,
                onChanged: (v) =>
                    ref.read(_d292ElapsedHoursProvider.notifier).state = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All windows'),
              selected: window == null,
              onSelected: (_) =>
                  ref.read(_d292WindowFilterProvider.notifier).state = null,
            ),
            FilterChip(
              label: const Text('0–24h'),
              selected: window == '0–24h',
              onSelected: (_) =>
                  ref.read(_d292WindowFilterProvider.notifier).state = '0–24h',
            ),
            FilterChip(
              label: const Text('24–48h'),
              selected: window == '24–48h',
              onSelected: (_) =>
                  ref.read(_d292WindowFilterProvider.notifier).state = '24–48h',
            ),
            FilterChip(
              label: const Text('48–72h'),
              selected: window == '48–72h',
              onSelected: (_) =>
                  ref.read(_d292WindowFilterProvider.notifier).state = '48–72h',
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...items.map((item) {
          final st = _statusFromKey(statuses[item.id]);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _statusColor(st).withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _cycleStatus(ref, item.id),
                  child:
                      Icon(_statusIcon(st), color: _statusColor(st), size: 22),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.window} · ${item.owner}',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${item.metric}: ${item.current} (gate ${item.threshold})',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d292StatusesProvider.notifier).state = {
              for (final i in _kWarRoomItems) i.id: _statusKey(i.defaultStatus),
            };
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('War room reset to defaults.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset checklist'),
        ),
      ],
    );
  }
}

// ── Tab 1: Timeline ───────────────────────────────────────────────────────────
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d292StatusesProvider);
    final elapsed = ref.watch(_d292ElapsedHoursProvider);
    final payload = _monitoringPayload(
      statuses: statuses,
      elapsedHours: elapsed,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: '72h launch timeline',
          subtitle: 'Three shifts · escalate alert items immediately',
        ),
        _TimelineBlock(
          title: '0–24h · Launch night',
          subtitle: 'Crash-free, SOS ACK, FP spike watch, P0 inbox',
          active: elapsed < 24,
          items: _kWarRoomItems.where((i) => i.window == '0–24h'),
          statuses: statuses,
        ),
        _TimelineBlock(
          title: '24–48h · Stabilise',
          subtitle: 'ANR, counselor SLA, reviews, GDPR tickets',
          active: elapsed >= 24 && elapsed < 48,
          items: _kWarRoomItems.where((i) => i.window == '24–48h'),
          statuses: statuses,
        ),
        _TimelineBlock(
          title: '48–72h · Expand rollout',
          subtitle: 'Advance Play %, India SMS, NPS, war room sign-off',
          active: elapsed >= 48,
          items: _kWarRoomItems.where((i) => i.window == '48–72h'),
          statuses: statuses,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _buildWarRoomReport(statuses: statuses, elapsedHours: elapsed),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildWarRoomReport(
                  statuses: statuses,
                  elapsedHours: elapsed,
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('War room report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy war room report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'war_room_clear: ${payload['war_room_clear']}',
          style: TextStyle(
            color: payload['war_room_clear'] == true
                ? ZapColors.safe
                : ZapColors.warning,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  const _TimelineBlock({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.items,
    required this.statuses,
  });

  final String title;
  final String subtitle;
  final bool active;
  final Iterable<_WarRoomItem> items;
  final Map<String, String> statuses;

  @override
  Widget build(BuildContext context) {
    final alertCount = items
        .where((i) => _statusFromKey(statuses[i.id]) == _MonitorStatus.alert)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: active ? _kAccent.withOpacity(0.06) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? _kAccent.withOpacity(0.4) : ZapColors.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active ? Icons.sensors_rounded : Icons.schedule_rounded,
                color: active ? _kAccent : ZapColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? ZapColors.textPrimary : ZapColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (alertCount > 0)
                Text(
                  '$alertCount alert',
                  style: const TextStyle(
                    color: ZapColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...items.map((i) {
            final st = _statusFromKey(statuses[i.id]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(_statusIcon(st), size: 14, color: _statusColor(st)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${i.title} · ${i.current}',
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                      ),
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

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d292StatusesProvider);
    final elapsed = ref.watch(_d292ElapsedHoursProvider);
    final payload = _monitoringPayload(
      statuses: statuses,
      elapsedHours: elapsed,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Post-launch monitoring',
          subtitle: 'First 72h war room after Play/App Store go-live.',
        ),
        const _PolicyRow(
          icon: Icons.bug_report_rounded,
          title: 'Crash rate',
          subtitle: 'Day 288 gate ≥ 99.5% · halt rollout if breached.',
        ),
        const _PolicyRow(
          icon: Icons.emergency_rounded,
          title: 'SOS success',
          subtitle: 'Tier-1 ACK + counselor SLA tracked each shift.',
        ),
        const _PolicyRow(
          icon: Icons.warning_amber_rounded,
          title: 'False positive rate',
          subtitle: 'ML + user reports · tie to Day 115 / 124 fixes.',
        ),
        const _PolicyRow(
          icon: Icons.inbox_rounded,
          title: 'Support inbox',
          subtitle: 'P0 zero tolerance · billing/deletion < 4h response.',
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
              const SnackBar(content: Text('Monitoring spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
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
              label: const Text('Day 288 Crash-Free'),
              onPressed: () => context.push(AppRoutes.crashFreeTracker),
            ),
            ActionChip(
              label: const Text('Day 290 Staged Rollout'),
              onPressed: () => context.push(AppRoutes.stagedRolloutSimulator),
            ),
            ActionChip(
              label: const Text('Day 99 Help & Support'),
              onPressed: () => context.push(AppRoutes.helpSupport),
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
