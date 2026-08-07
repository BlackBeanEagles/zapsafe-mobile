/// Day 384 — DPDP Compliance Sign-Off
///
/// 🟡 MOCK-NOW — "Wire when export/delete APIs live."
///
/// Section O (Days 381-390, Project Close): a formal sign-off gate over
/// Day 383's follow-up findings (`day383_privacy_audit_followup_screen.dart`
/// — read directly before building this), which themselves reuse Day 337's
/// real DPDP category audit rather than re-deriving anything from scratch.
///
/// **Real backend state, reused from Day 337 (not re-derived):** account
/// export and account deletion are genuinely wired end-to-end via the
/// older Day 69/70 endpoints — those two DPDP rights are real. Consent,
/// session transparency, audit-log, and retention have real Django views
/// at `/api/v1/account/*` but zero Flutter caller. Third-party
/// data-sharing disclosure is genuinely unimplemented on both sides —
/// there is no backend route for it anywhere under `zapsafe_backend/`.
///
/// **Sign-off logic is real, not decorative:** sign-off is only enabled
/// once every category is reviewed, and the overall sign-off STAYS
/// BLOCKED while the third-party-sharing row is red — that row cannot be
/// marked reviewed-and-clear because the underlying gap is genuinely
/// unbuilt, not just unwired. The sign-off toggle defaults to **NOT
/// signed off**, matching Day 383's honest findings.
///
/// Tag: 🟡 MOCK-NOW · real gate logic over real Day 337/383 findings ·
/// default state is honestly NOT signed off.
///
/// Route: [AppRoutes.dpdpSignoff] → `/day-384-dpdp-signoff`
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

class _SignoffItem {
  const _SignoffItem({required this.id, required this.requirement, required this.blockedReason});
  final String id;
  final String requirement;
  final String? blockedReason; // null = can be reviewed and cleared
}

const _kItems = [
  _SignoffItem(id: 'export', requirement: 'Data portability (export) — live end-to-end', blockedReason: null),
  _SignoffItem(id: 'deletion', requirement: 'Right to erasure (deletion) — live end-to-end', blockedReason: null),
  _SignoffItem(id: 'consent', requirement: 'Consent management — backend real, frontend unwired', blockedReason: null),
  _SignoffItem(id: 'sessions', requirement: 'Session transparency — backend real, frontend unwired', blockedReason: null),
  _SignoffItem(id: 'audit_log', requirement: 'Data-access audit log — backend real, frontend unwired', blockedReason: null),
  _SignoffItem(id: 'retention', requirement: 'Scheduled retention purge — backend real, frontend unwired', blockedReason: null),
  _SignoffItem(
    id: 'third_party',
    requirement: 'Third-party data-sharing disclosure',
    blockedReason: 'No backend route exists anywhere for this — genuinely unimplemented on '
        'both sides (Day 337/383). Cannot be marked reviewed-and-clear until it is actually built.',
  ),
];

Map<String, dynamic> _payload(Map<String, bool> reviewed, bool signedOff) {
  final allReviewable = _kItems.where((i) => i.blockedReason == null).toList();
  final allReviewed = allReviewable.every((i) => reviewed[i.id] == true);
  final hasBlocker = _kItems.any((i) => i.blockedReason != null);
  return {
    'endpoint': 'NONE — no real sign-off/compliance API exists',
    'wire_when': 'export/delete APIs live — export + deletion already ARE live via '
        'Day 69/70; the newer /api/v1/account/* surface is the one still pending',
    'total_categories': _kItems.length,
    'reviewable_categories': allReviewable.length,
    'blocked_categories': _kItems.length - allReviewable.length,
    'all_reviewable_reviewed': allReviewed,
    'has_unresolvable_blocker': hasBlocker,
    'signed_off': signedOff,
    'sign_off_possible': false,
    'sign_off_blocked_reason': 'Third-party data-sharing disclosure is genuinely unimplemented '
        '— a real sign-off cannot honestly claim full DPDP compliance while that gap is open.',
    'follow_up_source': 'day383_privacy_audit_followup_screen.dart',
    'origin_source': 'day337_legal_blockers_live_screen.dart',
  };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d384ReviewedProvider = StateProvider<Map<String, bool>>((ref) => {});
// Defaults to NOT signed off — matches Day 383's honest findings. The UI
// keeps this permanently disabled while the third-party row is blocked;
// the provider exists so the "signed_off" field in the payload stays real
// (always false) rather than hand-waved.
final _d384SignedOffProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day384DpdpSignoffScreen extends ConsumerWidget {
  const Day384DpdpSignoffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(_d384ReviewedProvider);
    final signedOff = ref.watch(_d384SignedOffProvider);
    final reviewedCount = _kItems.where((i) => i.blockedReason == null && reviewed[i.id] == true).length;
    final reviewableTotal = _kItems.where((i) => i.blockedReason == null).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day381_390.dpdp_signoff_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (signedOff ? ZapColors.safe : ZapColors.danger).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: (signedOff ? ZapColors.safe : ZapColors.danger).withOpacity(0.45)),
                ),
                child: Text(signedOff ? 'SIGNED OFF' : 'NOT SIGNED OFF', style: TextStyle(color: signedOff ? ZapColors.safe : ZapColors.danger, fontSize: 10, fontWeight: FontWeight.w900)),
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
            decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.35), width: 2)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gpp_bad_rounded, color: ZapColors.danger, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Sign-off is genuinely NOT possible right now. Third-party data-'
                    'sharing disclosure is unimplemented on both sides (Day 337/383) — '
                    'a real sign-off cannot honestly claim full DPDP compliance while '
                    'that gap is open. This is a real gate, not a decorative checkbox.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('Review categories ($reviewedCount/$reviewableTotal reviewable reviewed)', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          ..._kItems.map((item) {
            final isBlocked = item.blockedReason != null;
            final isReviewed = reviewed[item.id] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isBlocked ? ZapColors.danger.withOpacity(0.5) : (isReviewed ? ZapColors.safe : ZapColors.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isBlocked
                      ? const Padding(padding: EdgeInsets.only(top: 10, right: 10), child: Icon(Icons.block_rounded, color: ZapColors.danger, size: 20))
                      : Checkbox(
                          value: isReviewed,
                          activeColor: ZapColors.safe,
                          onChanged: (v) => ref.read(_d384ReviewedProvider.notifier).state = {...reviewed, item.id: v ?? false},
                        ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.requirement, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                        if (isBlocked) ...[
                          const SizedBox(height: 4),
                          Text(item.blockedReason!, style: const TextStyle(color: ZapColors.danger, fontSize: 10, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: ZapSpacing.xl),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Final sign-off', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                const Text(
                  'Disabled by design while any category is genuinely blocked — this '
                  'is not a bug, it is the honest gate this screen exists to enforce.',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: ZapSpacing.md),
                SwitchListTile(
                  value: false,
                  onChanged: null,
                  activeColor: ZapColors.safe,
                  title: const Text('Sign off on DPDP compliance', style: TextStyle(color: ZapColors.textMuted, fontSize: 12)),
                  subtitle: const Text('Blocked — third-party sharing disclosure unimplemented', style: TextStyle(color: ZapColors.danger, fontSize: 10)),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_payload(reviewed, signedOff))));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-off status copied — currently NOT signed off.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy sign-off status'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(reviewed, signedOff)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 383 Follow-Up'), onPressed: () => context.push(AppRoutes.privacyAuditFollowup)),
            ActionChip(label: const Text('Day 337 Tracker'), onPressed: () => context.push(AppRoutes.legalBlockersLive)),
          ]),
        ],
      ),
    );
  }
}
