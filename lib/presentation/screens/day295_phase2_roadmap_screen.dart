/// Day 295 — Phase 2 Roadmap (Days 301-365)
///
/// Section E (Days 281-300): preview the next 65 build days — global launch,
/// v9.2 feature wave, platform hardening, enterprise, and deferred wearables.
///
/// Tag: 🟢 FRONTEND-ONLY · planning preview · no scheduling backend.
///
/// Route: [AppRoutes.phase2Roadmap] → `/phase2-roadmap`
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
const _kAccent = Color(0xFF7C3AED);
const _kTabs = ['Timeline', 'Themes', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kStartDay = 301;
const _kEndDay = 365;
const _kTotalDays = _kEndDay - _kStartDay + 1;
const _kVersionTarget = 'v9.2';

enum _RoadmapPhase {
  globalLaunch,
  v92,
  platform,
  enterprise,
  deferred,
}

class _RoadmapDay {
  const _RoadmapDay({
    required this.day,
    required this.title,
    required this.phase,
    required this.deferred,
    required this.icon,
  });

  final int day;
  final String title;
  final _RoadmapPhase phase;
  final bool deferred;
  final IconData icon;
}

class _RoadmapWeek {
  const _RoadmapWeek({
    required this.week,
    required this.startDay,
    required this.label,
    required this.phase,
    required this.days,
  });

  final int week;
  final int startDay;
  final String label;
  final _RoadmapPhase phase;
  final List<_RoadmapDay> days;
}

String _phaseKey(_RoadmapPhase p) => switch (p) {
      _RoadmapPhase.globalLaunch => 'global_launch',
      _RoadmapPhase.v92 => 'v92',
      _RoadmapPhase.platform => 'platform',
      _RoadmapPhase.enterprise => 'enterprise',
      _RoadmapPhase.deferred => 'deferred',
    };

String _phaseLabel(_RoadmapPhase p) => switch (p) {
      _RoadmapPhase.globalLaunch => 'Global Launch',
      _RoadmapPhase.v92 => 'v9.2 Core',
      _RoadmapPhase.platform => 'Platform',
      _RoadmapPhase.enterprise => 'Enterprise',
      _RoadmapPhase.deferred => 'Deferred',
    };

Color _phaseColor(_RoadmapPhase p) => switch (p) {
      _RoadmapPhase.globalLaunch => const Color(0xFF2563EB),
      _RoadmapPhase.v92 => const Color(0xFF7C3AED),
      _RoadmapPhase.platform => const Color(0xFF06B6D4),
      _RoadmapPhase.enterprise => const Color(0xFF10B981),
      _RoadmapPhase.deferred => const Color(0xFF94A3B8),
    };

IconData _phaseIcon(_RoadmapPhase p) => switch (p) {
      _RoadmapPhase.globalLaunch => Icons.public_rounded,
      _RoadmapPhase.v92 => Icons.upgrade_rounded,
      _RoadmapPhase.platform => Icons.devices_rounded,
      _RoadmapPhase.enterprise => Icons.business_rounded,
      _RoadmapPhase.deferred => Icons.watch_off_rounded,
    };

class _DaySpec {
  const _DaySpec(this.title, this.icon, {this.deferred = false});

  final String title;
  final IconData icon;
  final bool deferred;
}

class _WeekSpec {
  const _WeekSpec({
    required this.week,
    required this.phase,
    required this.label,
    required this.days,
  });

  final int week;
  final _RoadmapPhase phase;
  final String label;
  final List<_DaySpec> days;
}

const _kWeekSpecs = [
  _WeekSpec(
    week: 1,
    phase: _RoadmapPhase.globalLaunch,
    label: 'EU & UK store launch prep',
    days: [
      _DaySpec('EU App Store metadata pack', Icons.store_rounded),
      _DaySpec('Play Console 27-country expansion', Icons.android_rounded),
      _DaySpec('EU emergency number registry', Icons.emergency_rounded),
      _DaySpec('GDPR DPA vendor refresh', Icons.gavel_rounded),
      _DaySpec('EU support macro localization', Icons.translate_rounded),
    ],
  ),
  _WeekSpec(
    week: 2,
    phase: _RoadmapPhase.globalLaunch,
    label: 'LATAM & MENA gateways',
    days: [
      _DaySpec('LATAM SMS gateway routing', Icons.sms_rounded),
      _DaySpec('Brazil Play billing tier', Icons.payments_rounded),
      _DaySpec('MENA Arabic RTL store assets', Icons.format_textdirection_r_to_l_rounded),
      _DaySpec('Mexico emergency 911 deep link', Icons.link_rounded),
      _DaySpec('Global pricing PPP table v2', Icons.table_chart_rounded),
    ],
  ),
  _WeekSpec(
    week: 3,
    phase: _RoadmapPhase.globalLaunch,
    label: 'Southeast Asia rollout',
    days: [
      _DaySpec('SEA Play phased rollout 10%', Icons.rocket_launch_rounded),
      _DaySpec('Thailand/Vietnam store screenshots', Icons.image_rounded),
      _DaySpec('Indonesia Bahasa marketing site', Icons.language_rounded),
      _DaySpec('SEA counselor queue timezone split', Icons.schedule_rounded),
      _DaySpec('Global launch war room dashboard', Icons.monitor_heart_rounded),
    ],
  ),
  _WeekSpec(
    week: 4,
    phase: _RoadmapPhase.globalLaunch,
    label: 'Global launch go-live',
    days: [
      _DaySpec('Day 320 global launch milestone', Icons.celebration_rounded),
      _DaySpec('100% Play worldwide (staged)', Icons.trending_up_rounded),
      _DaySpec('App Store 45 territories live', Icons.apple_rounded),
      _DaySpec('Post-launch NPS cohort #2', Icons.poll_rounded),
      _DaySpec('Global vs India compare v2', Icons.compare_arrows_rounded),
    ],
  ),
  _WeekSpec(
    week: 5,
    phase: _RoadmapPhase.v92,
    label: 'SOS pipeline v9.2',
    days: [
      _DaySpec('SOS state machine refactor', Icons.account_tree_rounded),
      _DaySpec('Cancel PIN biometric fallback', Icons.fingerprint_rounded),
      _DaySpec('Duress path latency budget < 800ms', Icons.speed_rounded),
      _DaySpec('Evidence vault chunked upload', Icons.cloud_upload_rounded),
      _DaySpec('SOS regression suite v2', Icons.bug_report_rounded),
    ],
  ),
  _WeekSpec(
    week: 6,
    phase: _RoadmapPhase.v92,
    label: 'Journey ML tuning',
    days: [
      _DaySpec('Journey risk score model v2', Icons.psychology_rounded),
      _DaySpec('Geofence corridor smoothing', Icons.route_rounded),
      _DaySpec('Night-mode journey sensitivity', Icons.nightlight_rounded),
      _DaySpec('Trusted circle ETA predictions', Icons.groups_rounded),
      _DaySpec('Journey false-positive dashboard', Icons.insights_rounded),
    ],
  ),
  _WeekSpec(
    week: 7,
    phase: _RoadmapPhase.v92,
    label: 'Counselor scale & v9.2 RC',
    days: [
      _DaySpec('Counselor queue auto-assign v2', Icons.support_agent_rounded),
      _DaySpec('Video counselor PIP polish', Icons.videocam_rounded),
      _DaySpec('v9.2 release candidate build', Icons.build_rounded),
      _DaySpec('Beta cohort 500 users', Icons.people_rounded),
      _DaySpec('v9.2 store listing refresh', Icons.description_rounded),
    ],
  ),
  _WeekSpec(
    week: 8,
    phase: _RoadmapPhase.platform,
    label: 'Cross-platform parity',
    days: [
      _DaySpec('Android vs iOS feature matrix', Icons.grid_on_rounded),
      _DaySpec('FLAG_SECURE audit all screens', Icons.security_rounded),
      _DaySpec('iOS widget parity (SOS + score)', Icons.widgets_rounded),
      _DaySpec('Android shortcut deep links QA', Icons.shortcut_rounded),
      _DaySpec('Background location parity test', Icons.location_on_rounded),
    ],
  ),
  _WeekSpec(
    week: 9,
    phase: _RoadmapPhase.platform,
    label: 'Battery & thermal soak',
    days: [
      _DaySpec('8hr MONITORING mode soak log', Icons.battery_charging_full_rounded),
      _DaySpec('Thermal throttle SOS path test', Icons.thermostat_rounded),
      _DaySpec('Low-power SOS degradation mode', Icons.battery_alert_rounded),
      _DaySpec('OEM-specific battery whitelist', Icons.phone_android_rounded),
      _DaySpec('Soak test report template', Icons.summarize_rounded),
    ],
  ),
  _WeekSpec(
    week: 10,
    phase: _RoadmapPhase.platform,
    label: 'Pre-launch gates v2',
    days: [
      _DaySpec('22-item go/no-go gate extended', Icons.fact_check_rounded),
      _DaySpec('Crash-free 99.7% target gate', Icons.verified_rounded),
      _DaySpec('Legal blocker re-audit', Icons.balance_rounded),
      _DaySpec('Security MASVS L2 re-cert', Icons.shield_rounded),
      _DaySpec('Penultimate summary (Day 364)', Icons.checklist_rounded),
    ],
  ),
  _WeekSpec(
    week: 11,
    phase: _RoadmapPhase.enterprise,
    label: 'B2B SSO & employer portal',
    days: [
      _DaySpec('SAML/OIDC employer SSO', Icons.key_rounded),
      _DaySpec('Night-shift roster bulk import', Icons.upload_file_rounded),
      _DaySpec('Seat utilization analytics v2', Icons.analytics_rounded),
      _DaySpec('Employer SOS incident feed', Icons.notifications_active_rounded),
      _DaySpec('B2B quote self-serve portal', Icons.request_quote_rounded),
    ],
  ),
  _WeekSpec(
    week: 12,
    phase: _RoadmapPhase.enterprise,
    label: 'Insurance & partnerships live',
    days: [
      _DaySpec('HDFC ERGO API integration', Icons.handshake_rounded),
      _DaySpec('SOS history verify endpoint', Icons.history_rounded),
      _DaySpec('Partner webhook reliability', Icons.webhook_rounded),
      _DaySpec('Revenue share reporting', Icons.bar_chart_rounded),
      _DaySpec('Enterprise SLA dashboard', Icons.dashboard_rounded),
    ],
  ),
  _WeekSpec(
    week: 13,
    phase: _RoadmapPhase.deferred,
    label: 'Wearables spike (optional)',
    days: [
      _DaySpec('Apple Watch SOS feasibility', Icons.watch_rounded, deferred: true),
      _DaySpec('Wear OS complication spike', Icons.watch_rounded, deferred: true),
      _DaySpec('BLE panic button R&D', Icons.bluetooth_rounded, deferred: true),
      _DaySpec('Wearables privacy assessment', Icons.privacy_tip_rounded, deferred: true),
      _DaySpec('Day 365 halfway milestone', Icons.flag_rounded),
    ],
  ),
];

List<_RoadmapWeek> _buildWeeks() {
  final weeks = <_RoadmapWeek>[];
  var day = _kStartDay;
  for (final spec in _kWeekSpecs) {
    final days = <_RoadmapDay>[];
    for (final d in spec.days) {
      days.add(
        _RoadmapDay(
          day: day,
          title: d.title,
          phase: spec.phase,
          deferred: d.deferred,
          icon: d.icon,
        ),
      );
      day++;
    }
    weeks.add(
      _RoadmapWeek(
        week: spec.week,
        startDay: days.first.day,
        label: spec.label,
        phase: spec.phase,
        days: days,
      ),
    );
  }
  return weeks;
}

final _kWeeks = _buildWeeks();
final _kAllDays = _kWeeks.expand((w) => w.days).toList();

Map<String, dynamic> _roadmapPayload({
  required String phaseFilter,
  required bool hideDeferred,
}) {
  final visible = _kAllDays.where((d) {
    if (hideDeferred && d.deferred) return false;
    if (phaseFilter == 'all') return true;
    return _phaseKey(d.phase) == phaseFilter;
  }).toList();
  return {
    'endpoint': 'GET /api/v1/planning/phase2-roadmap/',
    'range': '$_kStartDay-$_kEndDay',
    'total_days': _kTotalDays,
    'version_target': _kVersionTarget,
    'visible_days': visible.length,
    'phases': _RoadmapPhase.values.map(_phaseKey).toList(),
    'wearables_status': 'deferred_optional',
    'wire_note': 'Planning preview · Days 301-365 after Section E',
  };
}

String _buildRoadmapReport({
  required String phaseFilter,
  required bool hideDeferred,
}) {
  final buf = StringBuffer(
    'ZapSafe Phase 2 Roadmap ($_kStartDay-$_kEndDay) · $_kVersionTarget\n\n',
  );
  for (final week in _kWeeks) {
    final visibleDays = week.days.where((d) {
      if (hideDeferred && d.deferred) return false;
      if (phaseFilter != 'all' && _phaseKey(d.phase) != phaseFilter) {
        return false;
      }
      return true;
    });
    if (visibleDays.isEmpty) continue;
    buf.writeln('Week ${week.week}: ${week.label}');
    for (final d in visibleDays) {
      final tag = d.deferred ? ' [DEFERRED]' : '';
      buf.writeln('  Day ${d.day}: ${d.title}$tag');
    }
    buf.writeln();
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d295TabProvider = StateProvider<int>((ref) => 0);
final _d295PhaseFilterProvider = StateProvider<String>((ref) => 'all');
final _d295HideDeferredProvider = StateProvider<bool>((ref) => false);
final _d295ExpandedWeeksProvider =
    StateProvider<Set<int>>((ref) => {1, 5, 13});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day295Phase2RoadmapScreen extends ConsumerWidget {
  const Day295Phase2RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideDeferred = ref.watch(_d295HideDeferredProvider);
    final deferredCount = _kAllDays.where((d) => d.deferred).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 295 · Phase 2 Roadmap'),
        actions: [
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
                  '$_kTotalDays days',
                  style: TextStyle(
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
            tab: ref.watch(_d295TabProvider),
            onSelect: (i) => ref.read(_d295TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d295TabProvider)) {
              0 => const _TimelineTab(),
              1 => const _ThemesTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
      bottomNavigationBar: hideDeferred
          ? null
          : Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              color: ZapColors.bgCard,
              child: Text(
                '$deferredCount wearables days marked optional/deferred',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
    );
  }
}

// ── Tab 0: Timeline ───────────────────────────────────────────────────────────
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d295PhaseFilterProvider);
    final hideDeferred = ref.watch(_d295HideDeferredProvider);
    final expanded = ref.watch(_d295ExpandedWeeksProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Days $_kStartDay–$_kEndDay timeline',
          subtitle: '13 weeks · $_kVersionTarget · global launch → wearables spike',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          margin: const EdgeInsets.only(bottom: ZapSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.15),
                const Color(0xFF2563EB).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.map_rounded, color: _kAccent),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Phase 2 begins after Day 300 Section E sign-off. '
                  'Wearables (Days 361-364) are optional spikes — phone-first scope preserved.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Hide deferred wearables',
            style: TextStyle(fontSize: 12, color: ZapColors.textPrimary),
          ),
          value: hideDeferred,
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d295HideDeferredProvider.notifier).state = v,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: filter == 'all',
              onTap: () =>
                  ref.read(_d295PhaseFilterProvider.notifier).state = 'all',
            ),
            ..._RoadmapPhase.values.map(
              (p) => _FilterChip(
                label: _phaseLabel(p),
                selected: filter == _phaseKey(p),
                color: _phaseColor(p),
                onTap: () => ref.read(_d295PhaseFilterProvider.notifier).state =
                    _phaseKey(p),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kWeeks.map((week) {
          final visibleDays = week.days.where((d) {
            if (hideDeferred && d.deferred) return false;
            if (filter != 'all' && _phaseKey(d.phase) != filter) return false;
            return true;
          }).toList();
          if (visibleDays.isEmpty) return const SizedBox.shrink();

          final isExpanded = expanded.contains(week.week);
          final color = _phaseColor(week.phase);

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      final next = Set<int>.from(expanded);
                      if (isExpanded) {
                        next.remove(week.week);
                      } else {
                        next.add(week.week);
                      }
                      ref.read(_d295ExpandedWeeksProvider.notifier).state =
                          next;
                    },
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(ZapSpacing.md),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withOpacity(0.2),
                            child: Text(
                              'W${week.week}',
                              style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  week.label,
                                  style: const TextStyle(
                                    color: ZapColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Days ${visibleDays.first.day}–${visibleDays.last.day} · '
                                  '${_phaseLabel(week.phase)}',
                                  style: const TextStyle(
                                    color: ZapColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: ZapColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    ...visibleDays.map(
                      (d) => ListTile(
                        dense: true,
                        leading: Icon(d.icon, size: 18, color: color),
                        title: Text(
                          'Day ${d.day}: ${d.title}',
                          style: TextStyle(
                            color: d.deferred
                                ? ZapColors.textMuted
                                : ZapColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: d.deferred
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: d.deferred
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ZapColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEFERRED',
                                  style: TextStyle(
                                    color: ZapColors.warning,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildRoadmapReport(
                  phaseFilter: filter,
                  hideDeferred: hideDeferred,
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Roadmap report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy roadmap report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

// ── Tab 1: Themes ─────────────────────────────────────────────────────────────
class _ThemesTab extends ConsumerWidget {
  const _ThemesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Phase 2 themes',
          subtitle: '5 blocks · 65 days · tap for related Section E screens',
        ),
        ..._RoadmapPhase.values.map((phase) {
          final days = _kAllDays.where((d) => d.phase == phase).toList();
          final deferred = days.where((d) => d.deferred).length;
          final color = _phaseColor(phase);
          final start = days.first.day;
          final end = days.last.day;

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_phaseIcon(phase), color: color, size: 22),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          _phaseLabel(phase),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        'Days $start–$end',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    '${days.length} build days'
                    '${deferred > 0 ? ' · $deferred deferred' : ''}',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: phase == _RoadmapPhase.deferred ? 0.0 : 0.0,
                      backgroundColor: ZapColors.border,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  const Text(
                    '0% complete — planning phase',
                    style: TextStyle(color: ZapColors.textMuted, fontSize: 9),
                  ),
                  if (phase == _RoadmapPhase.globalLaunch) ...[
                    const SizedBox(height: ZapSpacing.sm),
                    ActionChip(
                      label: const Text('Day 291 Global Compare'),
                      onPressed: () =>
                          context.push(AppRoutes.globalIndiaCompare),
                    ),
                  ],
                  if (phase == _RoadmapPhase.v92) ...[
                    const SizedBox(height: ZapSpacing.sm),
                    ActionChip(
                      label: const Text('Day 290 Rollout Sim'),
                      onPressed: () =>
                          context.push(AppRoutes.stagedRolloutSimulator),
                    ),
                  ],
                  if (phase == _RoadmapPhase.deferred) ...[
                    const SizedBox(height: ZapSpacing.sm),
                    const Text(
                      'Wearables remain out of v9.2 scope per Day 260 milestone '
                      '(phone-only). Spike days are optional R&D.',
                      style: TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Release train',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: ZapSpacing.sm),
              _ReleaseMilestone(
                label: 'v9.1 (Section E)',
                range: 'Days 281–300',
                status: 'In progress',
                color: ZapColors.safe,
              ),
              _ReleaseMilestone(
                label: _kVersionTarget,
                range: 'Days 314–330',
                status: 'Planned RC Week 7',
                color: _kAccent,
              ),
              _ReleaseMilestone(
                label: 'Global launch',
                range: 'Day 320',
                status: 'Go-live milestone',
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReleaseMilestone extends StatelessWidget {
  const _ReleaseMilestone({
    required this.label,
    required this.range,
    required this.status,
    required this.color,
  });

  final String label;
  final String range;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              '$label ($range)',
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(color: color, fontSize: 10),
          ),
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
    final payload = _roadmapPayload(
      phaseFilter: ref.watch(_d295PhaseFilterProvider),
      hideDeferred: ref.watch(_d295HideDeferredProvider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Phase 2 planning',
          subtitle: 'Preview Days 301-365 after Section E completes at Day 300.',
        ),
        const _PolicyRow(
          icon: Icons.public_rounded,
          title: 'Global launch (Days 301-320)',
          subtitle: 'EU · LATAM · SEA store expansion · war room · Day 291 compare v2.',
        ),
        const _PolicyRow(
          icon: Icons.upgrade_rounded,
          title: 'v9.2 core (Days 321-330)',
          subtitle: 'SOS refactor · journey ML · counselor scale · RC build.',
        ),
        const _PolicyRow(
          icon: Icons.devices_rounded,
          title: 'Platform hardening (Days 331-350)',
          subtitle: 'Parity audit · battery soak · go/no-go gate · Days 296-298 previews.',
        ),
        const _PolicyRow(
          icon: Icons.watch_off_rounded,
          title: 'Wearables deferred (Days 361-364)',
          subtitle: 'Optional R&D spikes · phone-first per Day 260 milestone.',
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
              const SnackBar(content: Text('Roadmap spec copied.')),
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
              label: const Text('Day 280 Section D'),
              onPressed: () => context.push(AppRoutes.sectionDMilestone),
            ),
            ActionChip(
              label: const Text('Day 291 Global'),
              onPressed: () => context.push(AppRoutes.globalIndiaCompare),
            ),
            ActionChip(
              label: const Text('Day 290 Rollout'),
              onPressed: () => context.push(AppRoutes.stagedRolloutSimulator),
            ),
            ActionChip(
              label: const Text('Day 260 Phone-only'),
              onPressed: () =>
                  context.push(AppRoutes.sectionCAdvancedMilestone),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _kAccent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : ZapColors.textSecondary,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
