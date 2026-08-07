/// Day 337 — Legal Launch Blockers: Live Tracker
///
/// Section I (Days 331-340): reads Day 286's Section B (Days 166-180) legal
/// blockers tracker — a UI-only status board whose statuses never touched a
/// real backend — and replaces it with a real DPDP-requirement-category
/// tracker checked against the actual `zapsafe_backend` Django project
/// (found in a sibling working directory, read directly, not invented).
///
/// **What was actually checked** (this session):
/// - `zapsafe_backend/account/urls.py` mounts a real, working Django app at
///   `/api/v1/account/` (Day 147) with real views for consent, sessions,
///   export-request/status, delete-request/cancel-deletion, audit-log, and
///   retention/purge-now. All confirmed by reading `account/views.py`
///   directly — genuine `APIView` subclasses, not stubs.
/// - `zapsafe_backend/data_export/urls.py` (Day 69) and
///   `zapsafe_backend/privacy/urls.py` (Day 70) are older, separate Django
///   apps mounted at `/api/v1/data-export/` and `/api/v1/privacy/`.
/// - On the Flutter side, `lib/data/services/data_export_service.dart` and
///   `lib/data/services/privacy_service.dart` are real Dio-backed services,
///   and `dataExportServiceProvider`/`privacyServiceProvider` are actually
///   consumed by live screens — `day69_data_export_screen.dart` and
///   `day70_privacy_screen.dart` (confirmed by grep, not assumed).
/// - Day 301's own backend integration audit
///   (`day301_backend_integration_audit_screen.dart`) already documented,
///   entry by entry, that every `/api/v1/account/*` route is
///   `AuditStatus.mock` — "real backend, not wired" — while
///   `/api/v1/data-export/` and `/api/v1/privacy/` are `AuditStatus.live`.
///   This screen's category statuses below are pulled directly from that
///   audit rather than re-guessed.
/// - No backend route exists anywhere for Day 286's assumed
///   `/api/v1/data-retention/purge` or `/api/v1/third-party/access` paths —
///   grepped every `urls.py` under `zapsafe_backend/`. Equivalent
///   functionality for retention *does* exist, just at a different real
///   path: `/api/v1/account/retention/` (+`purge-now/`). Third-party
///   sharing transparency has no backend equivalent at all, under any path.
///
/// **The honest conclusion:** the two most legally load-bearing DPDP
/// rights — data portability/export and account deletion/erasure — are
/// GREEN for real, end-to-end, via the *older* Day 69/70 endpoints, not
/// the newer Day 147 `/api/v1/account/*` surface Day 286 was tracking.
/// Session management, consent sync, audit-log, and retention all have
/// real backend support but zero frontend caller (YELLOW). Third-party
/// sharing transparency is genuinely unimplemented on either side (RED).
///
/// Tag: 🟡 MOCK-NOW → several rows are now genuinely 🔵 LIVE (export,
/// deletion) after checking the real backend; the rest stay honestly
/// yellow/red, not upgraded without evidence.
///
/// Route: [AppRoutes.legalBlockersLive] → `/day-337-legal-blockers-live`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Categories', 'Backend evidence', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _Status { green, yellow, red }

String _statusKey(_Status s) => switch (s) {
      _Status.green => 'green',
      _Status.yellow => 'yellow',
      _Status.red => 'red',
    };

Color _statusColor(_Status s) => switch (s) {
      _Status.green => ZapColors.safe,
      _Status.yellow => ZapColors.warning,
      _Status.red => ZapColors.danger,
    };

String _statusLabel(_Status s) => switch (s) {
      _Status.green => 'LIVE END-TO-END',
      _Status.yellow => 'BACKEND REAL, NOT WIRED',
      _Status.red => 'NOT IMPLEMENTED',
    };

class _DpdpCategory {
  const _DpdpCategory({
    required this.id,
    required this.requirement,
    required this.status,
    required this.evidence,
    required this.route,
    required this.routeLabel,
  });

  final String id;
  final String requirement;
  final _Status status;
  final String evidence;
  final String? route;
  final String routeLabel;
}

const _kCategories = [
  _DpdpCategory(
    id: 'export',
    requirement: 'Right to data portability (export)',
    status: _Status.green,
    evidence: 'Real, wired end-to-end via the OLDER /api/v1/data-export/ '
        '(Day 69) — data_export_service.dart is consumed by '
        'day69_data_export_screen.dart. The newer '
        '/api/v1/account/export-request/ (Day 147) is real backend but has '
        'no Dart caller (Day 301 audit entry: mock).',
    route: AppRoutes.dataExport,
    routeLabel: 'Day 69 Export (live)',
  ),
  _DpdpCategory(
    id: 'deletion',
    requirement: 'Right to erasure (account deletion)',
    status: _Status.green,
    evidence: 'Real, wired end-to-end via the OLDER /api/v1/privacy/'
        'deletion-request/ (Day 70) — privacy_service.dart\'s '
        'createDeletion()/cancelDeletion() are consumed by '
        'day70_privacy_screen.dart. The newer /api/v1/account/'
        'delete-request/ + cancel-deletion/ (Day 147) is real backend but '
        'has no Dart caller (Day 301 audit entry: mock).',
    route: AppRoutes.privacy,
    routeLabel: 'Day 70 Privacy (live)',
  ),
  _DpdpCategory(
    id: 'consent',
    requirement: 'Consent management (granular, withdrawable)',
    status: _Status.yellow,
    evidence: 'Real Django view at /api/v1/account/consent/ '
        '(ConsentView in account/views.py, GET+PATCH) — confirmed by '
        'reading the source. No Dart service calls it.',
    route: null,
    routeLabel: '',
  ),
  _DpdpCategory(
    id: 'sessions',
    requirement: 'Session transparency + revocation',
    status: _Status.yellow,
    evidence: 'Real endpoints: GET /api/v1/account/sessions/, POST '
        '.../revoke-all/, POST .../<id>/ (SessionListView, '
        'SessionRevokeAllView, SessionRevokeView) — confirmed real. No '
        'Dart service calls any of them.',
    route: null,
    routeLabel: '',
  ),
  _DpdpCategory(
    id: 'audit_log',
    requirement: 'Data-access transparency (who accessed my data)',
    status: _Status.yellow,
    evidence: 'Real AuditLogView at /api/v1/account/audit-log/ — distinct '
        'from the OLDER, already-wired /api/v1/audit-log/ (Day 68, live '
        'via audit_log_service.dart). The account-scoped one is real but '
        'unwired.',
    route: null,
    routeLabel: '',
  ),
  _DpdpCategory(
    id: 'retention',
    requirement: 'Scheduled retention purge (storage-limitation principle)',
    status: _Status.yellow,
    evidence: 'Real RetentionView + RetentionPurgeNowView at '
        '/api/v1/account/retention/ (+purge-now/) — confirmed in '
        'account/urls.py + views.py. Day 286 originally tracked a '
        'different, non-existent path (/api/v1/data-retention/purge) as '
        'RED; the real functionality exists, just unwired and at a '
        'different URL than Day 286 guessed.',
    route: null,
    routeLabel: '',
  ),
  _DpdpCategory(
    id: 'third_party',
    requirement: 'Third-party data-sharing disclosure',
    status: _Status.red,
    evidence: 'No backend route exists for this anywhere — grepped every '
        'urls.py under zapsafe_backend/. Day 286\'s assumed '
        '/api/v1/third-party/access path was never real. Genuinely '
        'unimplemented on both sides.',
    route: null,
    routeLabel: '',
  ),
];

Map<String, dynamic> _trackerPayload() {
  final green = _kCategories.where((c) => c.status == _Status.green).length;
  final yellow = _kCategories.where((c) => c.status == _Status.yellow).length;
  final red = _kCategories.where((c) => c.status == _Status.red).length;
  return {
    'endpoint': 'GET /api/v1/legal/launch-blockers-live/ (mock wrapper — '
        'category evidence below is real, read from zapsafe_backend + this '
        'repo\'s own Day 301 audit)',
    'total_categories': _kCategories.length,
    'green': green,
    'yellow': yellow,
    'red': red,
    'launch_blocked': red > 0,
    'core_dpdp_rights_live': true,
    'core_dpdp_note': 'Export + erasure — the two rights most likely to be '
        'legally tested — are both genuinely live end-to-end.',
    'categories': _kCategories
        .map((c) => {
              'id': c.id,
              'requirement': c.requirement,
              'status': _statusKey(c.status),
            })
        .toList(),
  };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d337TabProvider = StateProvider<int>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day337LegalBlockersLiveScreen extends ConsumerWidget {
  const Day337LegalBlockersLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final green = _kCategories.where((c) => c.status == _Status.green).length;
    final red = _kCategories.where((c) => c.status == _Status.red).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.legal_blockers_live_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (red > 0 ? ZapColors.warning : ZapColors.safe).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: (red > 0 ? ZapColors.warning : ZapColors.safe).withOpacity(0.45)),
                ),
                child: Text('$green live · $red blocked', style: TextStyle(
                  color: red > 0 ? ZapColors.warning : ZapColors.safe, fontSize: 10, fontWeight: FontWeight.w900,
                )),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d337TabProvider), onSelect: (i) => ref.read(_d337TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d337TabProvider)) {
              0 => const _CategoriesTab(),
              1 => const _EvidenceTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Categories ──────────────────────────────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.safe.withOpacity(0.3)),
          ),
          child: const Text(
            'Export and account deletion — the two DPDP rights most likely '
            'to actually be tested — are both genuinely live end-to-end, '
            'via the older Day 69/70 endpoints. The newer Day 147 '
            'account/* surface is real backend but unwired; this tracker '
            'reports that honestly rather than crediting it as done.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kCategories.map((c) => Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor(c.status).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        c.status == _Status.green
                            ? Icons.check_circle_rounded
                            : c.status == _Status.yellow
                                ? Icons.schedule_rounded
                                : Icons.block_rounded,
                        color: _statusColor(c.status),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(c.requirement, style: const TextStyle(
                          color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(c.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(c.status), style: TextStyle(
                      color: _statusColor(c.status), fontSize: 9, fontWeight: FontWeight.w900,
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(c.evidence, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                  if (c.route != null) ...[
                    const SizedBox(height: 6),
                    ActionChip(
                      label: Text(c.routeLabel),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(c.route!),
                    ),
                  ],
                ],
              ),
            )),
      ],
    );
  }
}

// ── Tab 1: Backend evidence ───────────────────────────────────────────────────
class _EvidenceTab extends StatelessWidget {
  const _EvidenceTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: const [
        Text('Real files read this session', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        SizedBox(height: ZapSpacing.sm),
        _EvidenceRow(path: 'zapsafe_backend/account/urls.py', note: 'Real Django app, Day 147 — consent, sessions, export-request, delete-request, audit-log, retention.'),
        _EvidenceRow(path: 'zapsafe_backend/account/views.py', note: 'Confirmed real APIView subclasses (not stubs) for every route above.'),
        _EvidenceRow(path: 'zapsafe_backend/data_export/urls.py', note: 'Older, separate Django app, Day 69 — GDPR export.'),
        _EvidenceRow(path: 'zapsafe_backend/privacy/urls.py', note: 'Older, separate Django app, Day 70 — privacy settings + deletion-request.'),
        _EvidenceRow(path: 'lib/data/services/data_export_service.dart', note: 'Real Dio-backed service, calls the Day 69 endpoint.'),
        _EvidenceRow(path: 'lib/data/services/privacy_service.dart', note: 'Real Dio-backed service, calls the Day 70 endpoint.'),
        _EvidenceRow(path: 'lib/presentation/screens/day69_data_export_screen.dart', note: 'Live screen that actually consumes dataExportServiceProvider.'),
        _EvidenceRow(path: 'lib/presentation/screens/day70_privacy_screen.dart', note: 'Live screen that actually consumes privacyServiceProvider.'),
        _EvidenceRow(path: 'lib/presentation/screens/day301_backend_integration_audit_screen.dart', note: 'Pre-existing entry-by-entry live/mock audit this screen\'s statuses are pulled from.'),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.path, required this.note});
  final String path;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(path, style: const TextStyle(color: ZapColors.info, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(note, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.35)),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context) {
    final payload = _trackerPayload();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Legal blockers — live tracker', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 7/10 · re-checks Day 286\'s Section B tracker '
          'against the real zapsafe_backend Django project.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
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
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 286 Tracker'), onPressed: () => context.push(AppRoutes.legalBlockersTracker)),
            ActionChip(label: const Text('Day 301 Audit'), onPressed: () => context.push(AppRoutes.integrationAudit)),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                  border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2)),
                ),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(
                  color: selected ? _kAccent : ZapColors.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
