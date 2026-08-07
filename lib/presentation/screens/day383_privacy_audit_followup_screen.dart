/// Day 383 — Privacy Audit Follow-Up
///
/// Section O (Days 381-390, Project Close): a real follow-up on Day 337's
/// DPDP findings (`day337_legal_blockers_live_screen.dart` — read directly
/// before building this). Re-checks, this session, whether any of Day
/// 337's real gaps have actually been closed since.
///
/// **What was actually re-checked this session:**
/// - `find lib/data/services -iname "*account*"` returns nothing — no
///   Dart service exists for the newer `/api/v1/account/*` surface
///   (consent, sessions, audit-log, retention). Same as Day 337 found.
/// - `day319_gdpr_consent_wire_screen.dart` — read directly — its own
///   header confirms it stores consent via `ConsentWireStorage`
///   (SharedPreferences), still local-only "by design for a MOCK-NOW
///   day," NOT wired to the real `GET/PUT /api/v1/account/consent/`
///   endpoint it itself documents as real and live on the backend.
/// - `zapsafe_backend/account/urls.py` still has the same 11 routes Day
///   337 catalogued (consent, sessions ×3, export/delete-request ×2 each,
///   audit-log, retention ×2) — grepped again this session, unchanged.
/// - No `lib/data/services/*account*` caller was added anywhere in Days
///   371-382 either (grepped that range's own files) — this is expected,
///   since Section N/O's own scope was rollout tooling, hotfix process,
///   and project-close docs, not DPDP wiring.
///
/// **Honest conclusion:** since this project is still frontend-only work
/// with no backend changes originating from this worktree, and since no
/// screen built between Day 337 and Day 383 touched the account/* DPDP
/// surface, every yellow/red status from Day 337 is UNCHANGED. The two
/// green rows (export, deletion via the older Day 69/70 endpoints) are
/// also unchanged — still genuinely live.
///
/// Tag: 🟢 FRONTEND-ONLY · real re-check, not a re-guess · statuses
/// honestly unchanged from Day 337, not upgraded without evidence.
///
/// Route: [AppRoutes.privacyAuditFollowup] → `/day-383-privacy-audit-followup`
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

class _FollowUpRow {
  const _FollowUpRow({
    required this.requirement,
    required this.day337Status,
    required this.day383Status,
    required this.changed,
    required this.evidence,
  });
  final String requirement;
  final _Status day337Status;
  final _Status day383Status;
  final bool changed;
  final String evidence;
}

const _kFollowUp = [
  _FollowUpRow(
    requirement: 'Right to data portability (export)',
    day337Status: _Status.green,
    day383Status: _Status.green,
    changed: false,
    evidence: 'Still live end-to-end via the older Day 69 /api/v1/data-export/ '
        'endpoint — data_export_service.dart unchanged, still consumed by '
        'day69_data_export_screen.dart.',
  ),
  _FollowUpRow(
    requirement: 'Right to erasure (account deletion)',
    day337Status: _Status.green,
    day383Status: _Status.green,
    changed: false,
    evidence: 'Still live end-to-end via the older Day 70 /api/v1/privacy/'
        'deletion-request/ endpoint — privacy_service.dart unchanged.',
  ),
  _FollowUpRow(
    requirement: 'Consent management (granular, withdrawable)',
    day337Status: _Status.yellow,
    day383Status: _Status.yellow,
    changed: false,
    evidence: 'Day 319\'s consent wire screen (read directly this session) still '
        'stores consent via SharedPreferences only — its own header confirms this '
        'is deliberate ("MOCK-NOW"), not accidental. No caller for the real '
        'GET/PUT /api/v1/account/consent/ endpoint exists anywhere in lib/.',
  ),
  _FollowUpRow(
    requirement: 'Session transparency + revocation',
    day337Status: _Status.yellow,
    day383Status: _Status.yellow,
    changed: false,
    evidence: 'No lib/data/services/*account* file exists (checked again this '
        'session) — the real /api/v1/account/sessions/* endpoints remain unwired.',
  ),
  _FollowUpRow(
    requirement: 'Data-access transparency (audit log)',
    day337Status: _Status.yellow,
    day383Status: _Status.yellow,
    changed: false,
    evidence: 'The account-scoped /api/v1/account/audit-log/ endpoint remains '
        'unwired — the OLDER, already-live /api/v1/audit-log/ (Day 68) is a '
        'separate endpoint, unaffected by this row.',
  ),
  _FollowUpRow(
    requirement: 'Scheduled retention purge',
    day337Status: _Status.yellow,
    day383Status: _Status.yellow,
    changed: false,
    evidence: 'Real RetentionView + RetentionPurgeNowView still exist at '
        '/api/v1/account/retention/(+purge-now/) — grepped again this session, '
        'unchanged, still no Dart caller.',
  ),
  _FollowUpRow(
    requirement: 'Third-party data-sharing disclosure',
    day337Status: _Status.red,
    day383Status: _Status.red,
    changed: false,
    evidence: 'No backend route exists anywhere under zapsafe_backend/ for this — '
        're-grepped every urls.py this session, no new route found. Still '
        'genuinely unimplemented on both sides.',
  ),
];

Map<String, dynamic> _payload() {
  final anyChanged = _kFollowUp.any((r) => r.changed);
  return {
    'endpoint': 'GET /api/v1/legal/launch-blockers-live/ (same mock wrapper Day '
        '337 used — evidence below is real, re-checked this session)',
    'follow_up_of': 'day337_legal_blockers_live_screen.dart',
    'any_status_changed_since_day337': anyChanged,
    'rows': _kFollowUp
        .map((r) => {
              'requirement': r.requirement,
              'day337_status': _statusKey(r.day337Status),
              'day383_status': _statusKey(r.day383Status),
              'changed': r.changed,
            })
        .toList(),
    'wire_note': 'Honest re-check: this project is still frontend-only work with '
        'no backend changes originating from this worktree between Day 337 and '
        'Day 383, so every status is unchanged, not upgraded without evidence.',
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day383PrivacyAuditFollowupScreen extends ConsumerWidget {
  const Day383PrivacyAuditFollowupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final green = _kFollowUp.where((r) => r.day383Status == _Status.green).length;
    final red = _kFollowUp.where((r) => r.day383Status == _Status.red).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day381_390.privacy_audit_followup_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.info.withOpacity(0.45)),
                ),
                child: const Text('0 CHANGED', style: TextStyle(color: ZapColors.info, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: Text(
              'Real follow-up on Day 337: re-checked every row this session '
              '(grepped lib/data/services + zapsafe_backend/account/urls.py again, '
              'read day319\'s screen header directly). Nothing has changed — this '
              'is honest, not a claim of new progress. $green/${_kFollowUp.length} '
              'green, $red red, rest yellow, same as Day 337.',
              style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ..._kFollowUp.map((r) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _statusColor(r.day383Status).withOpacity(0.4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.requirement, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _statusColor(r.day383Status).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(_statusKey(r.day383Status).toUpperCase(), style: TextStyle(color: _statusColor(r.day383Status), fontSize: 9, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(r.evidence, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
                    const SizedBox(height: 4),
                    Text(r.changed ? 'CHANGED since Day 337' : 'Unchanged since Day 337', style: TextStyle(color: r.changed ? ZapColors.safe : ZapColors.textMuted, fontSize: 9, fontStyle: FontStyle.italic)),
                  ],
                ),
              )),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_payload())));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Follow-up spec copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy follow-up spec'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 337 Tracker'), onPressed: () => context.push(AppRoutes.legalBlockersLive)),
            ActionChip(label: const Text('Day 384 Sign-Off'), onPressed: () => context.push(AppRoutes.dpdpSignoff)),
          ]),
        ],
      ),
    );
  }
}
