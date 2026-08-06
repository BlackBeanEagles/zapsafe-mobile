/// Day 286 — Legal Launch Blockers Tracker
///
/// Section E (Days 281-300): track backend readiness for GDPR/legal export and
/// deletion API contracts from Section B (Days 166-180). Red/yellow/green per
/// endpoint before store launch.
///
/// Tag: 🟡 MOCK-NOW · status board · no live backend ping.
///
/// Route: [AppRoutes.legalBlockersTracker] → `/legal-blockers-tracker`
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
const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Endpoints', 'Board', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _BlockerStatus { green, yellow, red }

class _LegalEndpoint {
  const _LegalEndpoint({
    required this.id,
    required this.group,
    required this.method,
    required this.path,
    required this.title,
    required this.detail,
    required this.dayLink,
    required this.route,
    required this.defaultStatus,
    required this.owner,
  });

  final String id;
  final String group;
  final String method;
  final String path;
  final String title;
  final String detail;
  final String dayLink;
  final String route;
  final _BlockerStatus defaultStatus;
  final String owner;
}

const _kEndpoints = [
  _LegalEndpoint(
    id: 'export_request',
    group: 'Data Export',
    method: 'POST',
    path: '/api/v1/data-export/request',
    title: 'Start GDPR export job',
    detail: 'Creates async export · returns export_id + ETA.',
    dayLink: 'Day 166',
    route: AppRoutes.dataExportRequest,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'export_status',
    group: 'Data Export',
    method: 'GET',
    path: '/api/v1/data-export/status/{id}',
    title: 'Poll export job status',
    detail: 'queued → processing → ready · webhook optional.',
    dayLink: 'Day 166',
    route: AppRoutes.dataExportRequest,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'export_download',
    group: 'Data Export',
    method: 'GET',
    path: '/api/v1/data-export/download/{id}',
    title: 'Presigned ZIP download',
    detail: 'SHA-256 manifest · 7-day expiry URL.',
    dayLink: 'Day 167',
    route: AppRoutes.dataExportDownload,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'export_integrity',
    group: 'Data Export',
    method: 'GET',
    path: '/api/v1/data-export/integrity/{id}',
    title: 'Server vs local checksum',
    detail: 'Tamper detection before user opens ZIP.',
    dayLink: 'Day 167',
    route: AppRoutes.dataExportDownload,
    defaultStatus: _BlockerStatus.red,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'export_edge',
    group: 'Data Export',
    method: 'POST',
    path: '/api/v1/data-export/cancel/{id}',
    title: 'Cancel in-flight export',
    detail: 'Large account edge case · partial refund of quota.',
    dayLink: 'Day 168',
    route: AppRoutes.dataExportEdgeCases,
    defaultStatus: _BlockerStatus.red,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'deletion_otp',
    group: 'Account Deletion',
    method: 'POST',
    path: '/api/v1/account/send-deletion-otp',
    title: 'Re-auth OTP for deletion',
    detail: 'Separate auditable OTP channel from login.',
    dayLink: 'Day 169',
    route: AppRoutes.accountDeletionRequest,
    defaultStatus: _BlockerStatus.red,
    owner: 'Identity',
  ),
  _LegalEndpoint(
    id: 'deletion_request',
    group: 'Account Deletion',
    method: 'POST',
    path: '/api/v1/account/deletion-request',
    title: 'Queue account deletion',
    detail: 'Starts grace period · notifies trusted contacts.',
    dayLink: 'Day 169',
    route: AppRoutes.accountDeletionRequest,
    defaultStatus: _BlockerStatus.red,
    owner: 'Identity',
  ),
  _LegalEndpoint(
    id: 'deletion_grace',
    group: 'Account Deletion',
    method: 'GET',
    path: '/api/v1/account/deletion-status',
    title: 'Grace-period countdown',
    detail: '14-day window · cancel via DELETE before final.',
    dayLink: 'Day 170',
    route: AppRoutes.accountDeletionGrace,
    defaultStatus: _BlockerStatus.red,
    owner: 'Identity',
  ),
  _LegalEndpoint(
    id: 'deletion_final',
    group: 'Account Deletion',
    method: 'POST',
    path: '/api/v1/account/deletion-finalize',
    title: 'Hard delete after grace',
    detail: 'Cascade wipe · evidence retention policy applied.',
    dayLink: 'Day 171',
    route: AppRoutes.accountDeletionFinal,
    defaultStatus: _BlockerStatus.red,
    owner: 'Identity',
  ),
  _LegalEndpoint(
    id: 'access_audit',
    group: 'Transparency',
    method: 'GET',
    path: '/api/v1/data-access/audit',
    title: 'Who accessed my data',
    detail: 'Counselor + export + law-enforcement log feed.',
    dayLink: 'Day 173',
    route: AppRoutes.dataAccessAudit,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Compliance',
  ),
  _LegalEndpoint(
    id: 'third_party',
    group: 'Transparency',
    method: 'GET',
    path: '/api/v1/third-party/access',
    title: 'Third-party data sharing',
    detail: 'Insurance verify + analytics opt-in ledger.',
    dayLink: 'Day 175',
    route: AppRoutes.thirdPartyAccess,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Compliance',
  ),
  _LegalEndpoint(
    id: 'retention_purge',
    group: 'Retention',
    method: 'POST',
    path: '/api/v1/data-retention/purge',
    title: 'Scheduled retention purge',
    detail: '90-day evidence TTL · user-configurable windows.',
    dayLink: 'Day 177',
    route: AppRoutes.dataRetentionScheduler,
    defaultStatus: _BlockerStatus.red,
    owner: 'Platform',
  ),
  _LegalEndpoint(
    id: 'sessions_active',
    group: 'Sessions',
    method: 'GET',
    path: '/api/v1/sessions/active',
    title: 'List active sessions',
    detail: 'Device fingerprint · last seen · geo coarse.',
    dayLink: 'Day 179',
    route: AppRoutes.activeSessions,
    defaultStatus: _BlockerStatus.green,
    owner: 'Identity',
  ),
  _LegalEndpoint(
    id: 'sessions_revoke',
    group: 'Sessions',
    method: 'POST',
    path: '/api/v1/sessions/revoke-all',
    title: 'Revoke all other sessions',
    detail: 'Required before deletion · LP18 biometric gate.',
    dayLink: 'Day 180',
    route: AppRoutes.sessionSecurity,
    defaultStatus: _BlockerStatus.yellow,
    owner: 'Identity',
  ),
];

String _statusKey(_BlockerStatus s) => switch (s) {
      _BlockerStatus.green => 'green',
      _BlockerStatus.yellow => 'yellow',
      _BlockerStatus.red => 'red',
    };

_BlockerStatus _statusFromKey(String? key) => switch (key) {
      'green' => _BlockerStatus.green,
      'yellow' => _BlockerStatus.yellow,
      'red' => _BlockerStatus.red,
      _ => _BlockerStatus.yellow,
    };

Color _statusColor(_BlockerStatus s) => switch (s) {
      _BlockerStatus.green => ZapColors.safe,
      _BlockerStatus.yellow => ZapColors.warning,
      _BlockerStatus.red => ZapColors.danger,
    };

String _statusLabel(_BlockerStatus s) => switch (s) {
      _BlockerStatus.green => 'READY',
      _BlockerStatus.yellow => 'MOCK',
      _BlockerStatus.red => 'BLOCKED',
    };

IconData _statusIcon(_BlockerStatus s) => switch (s) {
      _BlockerStatus.green => Icons.check_circle_rounded,
      _BlockerStatus.yellow => Icons.schedule_rounded,
      _BlockerStatus.red => Icons.block_rounded,
    };

Map<String, dynamic> _trackerPayload(Map<String, String> statuses) {
  final green = statuses.values.where((v) => v == 'green').length;
  final yellow = statuses.values.where((v) => v == 'yellow').length;
  final red = statuses.values.where((v) => v == 'red').length;
  return {
    'endpoint': 'GET /api/v1/legal/launch-blockers/',
    'section_b_days': '166-180',
    'total_endpoints': _kEndpoints.length,
    'green': green,
    'yellow': yellow,
    'red': red,
    'launch_blocked': red > 0,
    'legal_ready': red == 0 && yellow <= 4,
    'endpoints': _kEndpoints
        .map(
          (e) => {
            'id': e.id,
            'method': e.method,
            'path': e.path,
            'status': statuses[e.id] ?? _statusKey(e.defaultStatus),
            'day_link': e.dayLink,
            'owner': e.owner,
          },
        )
        .toList(),
    'wire_note': 'Mock tracker · ties to Section B GDPR contracts',
  };
}

String _buildBlockerReport(Map<String, String> statuses) {
  final buf = StringBuffer('ZapSafe Legal Launch Blockers (Section B 166-180)\n\n');
  String? lastGroup;
  for (final e in _kEndpoints) {
    if (e.group != lastGroup) {
      buf.writeln('── ${e.group.toUpperCase()} ──');
      lastGroup = e.group;
    }
    final st = _statusFromKey(statuses[e.id]);
    buf.writeln(
      '[${_statusLabel(st)}] ${e.method} ${e.path} · ${e.title} (${e.dayLink})',
    );
  }
  final p = _trackerPayload(statuses);
  buf.writeln();
  buf.writeln(
    'Summary: ${p['green']} ready · ${p['yellow']} mock · ${p['red']} blocked · '
    'launch_blocked=${p['launch_blocked']}',
  );
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d286TabProvider = StateProvider<int>((ref) => 0);
final _d286FilterProvider = StateProvider<_BlockerStatus?>((ref) => null);
final _d286StatusesProvider = StateProvider<Map<String, String>>((ref) {
  return {for (final e in _kEndpoints) e.id: _statusKey(e.defaultStatus)};
});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day286LegalBlockersTrackerScreen extends ConsumerWidget {
  const Day286LegalBlockersTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d286StatusesProvider);
    final red = statuses.values.where((v) => v == 'red').length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 286 · Legal Blockers'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (red > 0 ? ZapColors.danger : _kAccent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (red > 0 ? ZapColors.danger : _kAccent).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  red > 0 ? '$red BLOCKED' : 'TRACKING',
                  style: TextStyle(
                    color: red > 0 ? ZapColors.danger : _kAccent,
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
            tab: ref.watch(_d286TabProvider),
            onSelect: (i) => ref.read(_d286TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d286TabProvider)) {
              0 => const _EndpointsTab(),
              1 => const _BoardTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Endpoints ──────────────────────────────────────────────────────────
class _EndpointsTab extends ConsumerWidget {
  const _EndpointsTab();

  void _cycleStatus(WidgetRef ref, String id) {
    final current = _statusFromKey(ref.read(_d286StatusesProvider)[id]);
    final next = switch (current) {
      _BlockerStatus.green => _BlockerStatus.yellow,
      _BlockerStatus.yellow => _BlockerStatus.red,
      _BlockerStatus.red => _BlockerStatus.green,
    };
    ref.read(_d286StatusesProvider.notifier).state = {
      ...ref.read(_d286StatusesProvider),
      id: _statusKey(next),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d286StatusesProvider);
    final filter = ref.watch(_d286FilterProvider);
    String? lastGroup;

    final items = _kEndpoints.where((e) {
      if (filter == null) return true;
      return _statusFromKey(statuses[e.id]) == filter;
    });

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Export & deletion API readiness',
          subtitle: 'Tap status chip to cycle READY → MOCK → BLOCKED',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: filter == null,
              onSelected: (_) =>
                  ref.read(_d286FilterProvider.notifier).state = null,
            ),
            FilterChip(
              label: const Text('Ready'),
              selected: filter == _BlockerStatus.green,
              onSelected: (_) => ref.read(_d286FilterProvider.notifier).state =
                  _BlockerStatus.green,
            ),
            FilterChip(
              label: const Text('Mock'),
              selected: filter == _BlockerStatus.yellow,
              onSelected: (_) => ref.read(_d286FilterProvider.notifier).state =
                  _BlockerStatus.yellow,
            ),
            FilterChip(
              label: const Text('Blocked'),
              selected: filter == _BlockerStatus.red,
              onSelected: (_) => ref.read(_d286FilterProvider.notifier).state =
                  _BlockerStatus.red,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...items.expand((e) {
          final widgets = <Widget>[];
          if (e.group != lastGroup) {
            lastGroup = e.group;
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(top: ZapSpacing.md, bottom: 4),
                child: Text(
                  e.group.toUpperCase(),
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          }
          final st = _statusFromKey(statuses[e.id]);
          widgets.add(
            Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor(st).withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _cycleStatus(ref, e.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(st).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _statusColor(st)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon(st), size: 14, color: _statusColor(st)),
                              const SizedBox(width: 4),
                              Text(
                                _statusLabel(st),
                                style: TextStyle(
                                  color: _statusColor(st),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        e.owner,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${e.method} ${e.path}',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    e.title,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    e.detail,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ActionChip(
                    label: Text('${e.dayLink} contract →'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.push(e.route),
                  ),
                ],
              ),
            ),
          );
          return widgets;
        }),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(_d286StatusesProvider.notifier).state = {
              for (final e in _kEndpoints) e.id: _statusKey(e.defaultStatus),
            };
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tracker reset to defaults.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset tracker'),
        ),
      ],
    );
  }
}

// ── Tab 1: Board ──────────────────────────────────────────────────────────────
class _BoardTab extends ConsumerWidget {
  const _BoardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d286StatusesProvider);
    final payload = _trackerPayload(statuses);
    final green = payload['green'] as int;
    final yellow = payload['yellow'] as int;
    final red = payload['red'] as int;
    final blocked = payload['launch_blocked'] as bool;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Launch blocker board',
          subtitle: 'legal_ready when red=0 and mock endpoints ≤ 4',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: blocked
                ? ZapColors.danger.withOpacity(0.08)
                : ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: blocked ? ZapColors.danger : ZapColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                blocked ? Icons.gavel_rounded : Icons.fact_check_rounded,
                size: 48,
                color: blocked ? ZapColors.danger : _kAccent,
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                blocked ? 'LAUNCH BLOCKED' : 'TRACKING MOCKS',
                style: TextStyle(
                  color: blocked ? ZapColors.danger : _kAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blocked
                    ? '$red endpoints still blocked — GDPR deletion path incomplete.'
                    : 'No red blockers · review yellow mocks before submission.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              _StatRow(label: 'Ready (green)', value: '$green', color: ZapColors.safe),
              _StatRow(label: 'Mock (yellow)', value: '$yellow', color: ZapColors.warning),
              _StatRow(label: 'Blocked (red)', value: '$red', color: ZapColors.danger),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _buildBlockerReport(statuses),
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
            Clipboard.setData(ClipboardData(text: _buildBlockerReport(statuses)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Blocker report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy blocker report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ZapColors.textMuted, fontSize: 12)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
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
    final statuses = ref.watch(_d286StatusesProvider);
    final payload = _trackerPayload(statuses);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Legal launch blockers',
          subtitle:
              'Maps Section B Days 166-180 client contracts to backend readiness.',
        ),
        const _PolicyRow(
          icon: Icons.archive_rounded,
          title: 'Data export (166-168)',
          subtitle: 'Request, download, integrity, edge-case cancel APIs.',
        ),
        const _PolicyRow(
          icon: Icons.person_off_rounded,
          title: 'Account deletion (169-172)',
          subtitle: 'OTP re-auth, grace period, finalize, edge cases.',
        ),
        const _PolicyRow(
          icon: Icons.policy_rounded,
          title: 'Transparency + retention (173-180)',
          subtitle: 'Access audit, third-party ledger, purge, sessions.',
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
              const SnackBar(content: Text('Tracker spec copied.')),
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
            'Tomorrow: Day 287 — Beta Feedback Round 3 '
            '(post-polish metrics · Day 136 extend).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 166 Export Request'),
              onPressed: () => context.push(AppRoutes.dataExportRequest),
            ),
            ActionChip(
              label: const Text('Day 169 Deletion'),
              onPressed: () => context.push(AppRoutes.accountDeletionRequest),
            ),
            ActionChip(
              label: const Text('Day 285 Security Audit'),
              onPressed: () => context.push(AppRoutes.securityPrelaunchAudit),
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
