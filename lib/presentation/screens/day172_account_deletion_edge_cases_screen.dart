/// Day 172 — Account Deletion: Edge Cases & Legal Deep Dive
///
/// Fourth and final day of the Days 169-172 Account Deletion block.
/// Day 169: Request — warnings, reason, re-auth, submit            ✅
/// Day 170: Grace period — countdown, notifications, cancel         ✅
/// Day 171: Permanent deletion — day-30 flow, wipe, wiped state    ✅
/// Day 172: Edge cases — active SOS, evidence hold, linked devices,
///           mid-wipe failure, phone re-use, active timers.
///           DPDP §13 + GDPR Art. 17 legal deep dive.
///           Days 169-172 block complete.
///
/// 🟡 MOCK-NOW — same pattern as Days 169-171.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _expandedEdgeProvider   = StateProvider<int?>((ref) => null);
final _simulatingProvider     = StateProvider<int?>((ref) => null);
final _expandedLegalProvider  = StateProvider<int?>((ref) => null);
final _legalScanDoneProvider  = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
class _EdgeCase {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   apiCode;
  final String   trigger;
  final String   detection;
  final String   uiResponse;
  final String   resolution;
  final Widget   simulatedUI;
  const _EdgeCase({
    required this.icon, required this.color, required this.title,
    required this.apiCode, required this.trigger, required this.detection,
    required this.uiResponse, required this.resolution,
    required this.simulatedUI,
  });
}

// ── simulated UI snippets ──────────────────────────────────────────────────────
Widget _sosMockUI() => _MockCard(
  color: const Color(0xFFEF4444),
  icon: Icons.warning_rounded,
  title: 'Cannot delete — SOS active',
  body: 'You have an active SOS event (sos_20260530_001). '
      'Account deletion is blocked until the SOS is resolved.\n\n'
      'Please wait for the SOS to be resolved or manually cancel it in '
      'SOS History before requesting deletion.',
  apiLabel: '409 { "error": "active_sos", "sos_id": "sos_20260530_001" }',
  actionLabel: 'View SOS History',
  actionColor: const Color(0xFFEF4444),
);

Widget _holdMockUI() => _MockCard(
  color: const Color(0xFFF59E0B),
  icon: Icons.gavel_rounded,
  title: 'Evidence under legal hold',
  body: 'Your Evidence Vault contains data submitted to law enforcement. '
      'This evidence cannot be deleted under Section 65B of the Indian Evidence Act.\n\n'
      'The legal hold expires: December 1, 2026. '
      'You may proceed with deleting all other data.',
  apiLabel: '409 { "error": "evidence_hold", "hold_until": "2026-12-01", '
      '"reason": "law_enforcement_ref: FIR/2026/123" }',
  actionLabel: 'Delete non-evidence data only',
  actionColor: const Color(0xFFF59E0B),
);

Widget _devicesMockUI() => _MockCard(
  color: const Color(0xFF3B82F6),
  icon: Icons.devices_rounded,
  title: '3 devices will be signed out',
  body: 'Your ZapSafe account is active on 3 devices:\n'
      '• Samsung Galaxy S24 (this device)\n'
      '• iPad Air (last active: May 28)\n'
      '• Xiaomi 14 (last active: Apr 12)\n\n'
      'All devices will be signed out immediately when deletion completes. '
      'Local Hive data will be wiped on each device on next app open.',
  apiLabel: 'GET /api/v1/account/sessions → 3 active sessions',
  actionLabel: 'Proceed with deletion',
  actionColor: const Color(0xFF3B82F6),
);

Widget _partialMockUI() => _MockCard(
  color: const Color(0xFF8B5CF6),
  icon: Icons.error_outline_rounded,
  title: 'Deletion interrupted — retry',
  body: 'The deletion process was interrupted after 4 of 9 data categories '
      'were wiped (server timeout). Your account is in a partial-deletion state.\n\n'
      'Tap "Resume Deletion" to continue from where it stopped. '
      'Your JWT is still valid until the wipe completes.',
  apiLabel: '500 { "error": "wipe_interrupted", "wiped_categories": 4, '
      '"deletion_id": "del_20260530_xyz" }',
  actionLabel: 'Resume Deletion',
  actionColor: const Color(0xFF8B5CF6),
);

Widget _reusePhoneMockUI() => _MockCard(
  color: const Color(0xFF10B981),
  icon: Icons.phone_iphone_rounded,
  title: 'New account — fresh start',
  body: 'Your previous ZapSafe account (+91 98765 43210) was deleted on '
      'June 29, 2026. You are creating a new account with the same number.\n\n'
      'This is a completely new account. No previous data, contacts, '
      'SOS history, or settings will be restored.',
  apiLabel: 'POST /auth/send-otp → 200 (phone number re-usable after deletion)',
  actionLabel: 'Continue setting up new account',
  actionColor: const Color(0xFF10B981),
);

Widget _timerMockUI() => _MockCard(
  color: const Color(0xFF6B7280),
  icon: Icons.timer_off_rounded,
  title: 'Active check-in timers cancelled',
  body: 'You have 2 active check-in timers:\n'
      '• "Daily walk" — expires in 3h 20m\n'
      '• "Night commute" — expires tomorrow 23:00\n\n'
      'These timers will be cancelled automatically when your deletion '
      'request is accepted. Your emergency contacts will not be alerted.',
  apiLabel: 'Deletion request auto-cancels timers via CASCADE DELETE on users table',
  actionLabel: 'Understood — proceed',
  actionColor: const Color(0xFF6B7280),
);

final _kEdgeCases = [
  _EdgeCase(
    icon: Icons.warning_rounded, color: const Color(0xFFEF4444),
    title: 'Active SOS Event In Progress',
    apiCode: '409 Conflict — active_sos',
    trigger: 'User submits POST /account/deletion-request while an SOS event '
        'is in status "active" or "dispatching" (within last 2 hours).',
    detection: 'Backend checks sos_events table for records with '
        'user_id = current_user AND status IN (\'active\', \'dispatching\') '
        'AND created_at > NOW() - INTERVAL \'2 hours\'.',
    uiResponse: 'Block the deletion request entirely. Show a red banner explaining '
        'the active SOS. The "Request Export" and "Start Deletion" buttons '
        'are disabled until the SOS resolves.',
    resolution: 'Wait for SOS to auto-resolve, or manually cancel it in '
        'SOS History → Mark as Resolved. Then re-submit the deletion request.',
    simulatedUI: _sosMockUI(),
  ),
  _EdgeCase(
    icon: Icons.gavel_rounded, color: const Color(0xFFF59E0B),
    title: 'Evidence Under Legal Hold',
    apiCode: '409 Conflict — evidence_hold',
    trigger: 'Evidence Vault items have been flagged with a legal hold '
        '(shared with law enforcement via the incident report API). '
        'Legal hold set by ZapSafe Trust & Safety team.',
    detection: 'Backend checks evidence_items table for '
        'WHERE user_id = X AND legal_hold = true AND hold_expires_at > NOW(). '
        'Returns 409 with hold_until and reason.',
    uiResponse: 'Show amber warning: "Legal hold prevents full deletion." '
        'Offer a partial deletion option: delete everything EXCEPT evidence vault. '
        'Evidence vault items deleted automatically when hold expires.',
    resolution: 'Option A: wait for hold expiry date, then full deletion proceeds. '
        'Option B: proceed with partial deletion now — all data except evidence. '
        'Evidence auto-deleted when hold expires.',
    simulatedUI: _holdMockUI(),
  ),
  _EdgeCase(
    icon: Icons.devices_rounded, color: const Color(0xFF3B82F6),
    title: 'Multiple Linked Devices',
    apiCode: '200 OK — multi-device sign-out',
    trigger: 'User has the ZapSafe app installed on multiple devices '
        '(phone + tablet, or two phones). All have active JWTs.',
    detection: 'On deletion request acceptance, backend invalidates '
        'all JWTs for user_id in the sessions table. '
        'GET /account/sessions returns the device list pre-deletion.',
    uiResponse: 'Show the list of active devices before confirming deletion. '
        'Warn that all will be signed out. When deletion completes, '
        'each device sees "Account Deleted" screen on next API call (401).',
    resolution: 'No action needed. Deletion automatically handles all devices. '
        'Users can optionally sign out individual devices first '
        'via Settings → Account → Active Sessions.',
    simulatedUI: _devicesMockUI(),
  ),
  _EdgeCase(
    icon: Icons.broken_image_rounded, color: const Color(0xFF8B5CF6),
    title: 'Mid-Wipe Server Failure',
    apiCode: '500 — wipe_interrupted',
    trigger: 'Server crashes, times out, or loses database connection '
        'after wiping some (but not all) data categories.',
    detection: 'Deletion job tracks wiped_categories in deletion_jobs table. '
        'On server restart, if status = "in_progress" and updated_at < 10 min ago, '
        'job is resumed from last completed category.',
    uiResponse: 'App shows "Deletion interrupted" error with retry button. '
        'Account stays in partial-deletion state — JWT still valid. '
        '"Resume Deletion" calls POST /account/deletion-request/resume/{id}.',
    resolution: 'Backend auto-resumes on next health check (within 5 min). '
        'Frontend polls GET /account/deletion-status every 30s '
        'and shows updated progress. Data integrity guaranteed — '
        'each category wipe is transactional.',
    simulatedUI: _partialMockUI(),
  ),
  _EdgeCase(
    icon: Icons.phone_iphone_rounded, color: const Color(0xFF10B981),
    title: 'Re-Creating Account With Same Phone',
    apiCode: '200 OK — phone number re-usable',
    trigger: 'Deleted user tries to sign up again with the same phone number '
        'after their previous account was fully deleted.',
    detection: 'POST /auth/send-otp checks phone_number against users table. '
        'Deleted accounts are soft-deleted (deleted_at set, not removed). '
        'Auth allows re-registration if deleted_at IS NOT NULL.',
    uiResponse: 'No special UI needed — normal sign-up flow. '
        'On first app open after OTP verify, user gets the onboarding flow. '
        'A subtle "Welcome back" message if deleted_at found for that number '
        '(avoids confusion if they thought deletion failed).',
    resolution: 'New account is a completely clean slate. '
        'No previous data, contacts, SOS history, or settings restored. '
        'DPDP §13(2): data erasure means no restoration without explicit consent.',
    simulatedUI: _reusePhoneMockUI(),
  ),
  _EdgeCase(
    icon: Icons.timer_off_rounded, color: const Color(0xFF6B7280),
    title: 'Active Check-in Timers During Deletion',
    apiCode: '200 OK — timers auto-cancelled',
    trigger: 'User has one or more active check-in timers (dead-man\'s switches) '
        'running when the deletion request is accepted.',
    detection: 'Deletion request handler queries check_in_timers '
        'WHERE user_id = X AND status = \'active\'. '
        'Cancelled via CASCADE DELETE — no separate API call needed.',
    uiResponse: 'During the deletion request flow (Day 169 Step 3 Confirm screen), '
        'show a summary of active timers that will be cancelled. '
        'Emphasise: emergency contacts will NOT be triggered by the cancellation.',
    resolution: 'Timers are cancelled server-side atomically with the deletion '
        'job creation. Contacts receive no alert. '
        'ZapSafe sends a one-time email: "Your check-in timers have been cancelled '
        'as part of your account deletion request."',
    simulatedUI: _timerMockUI(),
  ),
];

class _LegalPoint {
  final String article;
  final String title;
  final String legalText;
  final String zapImpl;
  final Color  color;
  const _LegalPoint({
    required this.article, required this.title, required this.legalText,
    required this.zapImpl, required this.color,
  });
}

const _kLegalPoints = [
  _LegalPoint(
    article: 'DPDP §13(1)',
    title: 'Right to erasure — core right',
    legalText: 'Every Data Principal shall have the right to erasure of their '
        'personal data that is no longer necessary for the purpose for which '
        'it was processed, or where consent has been withdrawn.',
    zapImpl: 'ZapSafe processes data under consent and contract. '
        'When the user withdraws consent via deletion request, §13(1) applies. '
        'The 30-day grace period is a ZapSafe operational policy — '
        'DPDP does not mandate any minimum grace period.',
    color: Color(0xFF10B981),
  ),
  _LegalPoint(
    article: 'DPDP §13(2)',
    title: 'No restoration without consent',
    legalText: 'Once data is erased under §13(1), the Data Fiduciary shall not '
        'process such data again without obtaining fresh consent from the '
        'Data Principal.',
    zapImpl: 'Account re-creation with the same phone number (Edge Case 5) '
        'starts a completely fresh account. No previous data is restored. '
        'Fresh consent collected via Day 161 ConsentGate during new onboarding.',
    color: Color(0xFF10B981),
  ),
  _LegalPoint(
    article: 'DPDP §13(3)',
    title: 'Retention for legal obligation',
    legalText: 'Nothing in §13(1) shall affect the obligation of the Data '
        'Fiduciary to retain data where required by any law for the time being '
        'in force in India.',
    zapImpl: 'Billing records retained 7 years (GST Act). '
        'Law-enforcement submitted evidence retained per court order. '
        'DPDP §13(3) is the explicit basis — shown in the deletion certificate.',
    color: Color(0xFF10B981),
  ),
  _LegalPoint(
    article: 'GDPR Art. 17(1)',
    title: 'Right to erasure — core right (EU)',
    legalText: 'The data subject shall have the right to obtain from the '
        'controller the erasure of personal data concerning them without undue '
        'delay where one of the following grounds applies: the personal data '
        'are no longer necessary; consent is withdrawn; there is no legitimate '
        'overriding interest.',
    zapImpl: 'ZapSafe is India-based but applies GDPR for EU users. '
        '"Without undue delay" = our 30-day grace period. '
        'We interpret this as reasonable — immediate deletion would prevent '
        'the user from cancelling if they change their mind.',
    color: Color(0xFF3B82F6),
  ),
  _LegalPoint(
    article: 'GDPR Art. 17(3)',
    title: 'Exceptions to erasure',
    legalText: 'Art. 17(1) shall not apply to the extent that processing is '
        'necessary: (b) for compliance with a legal obligation; '
        '(e) for the establishment, exercise or defence of legal claims.',
    zapImpl: 'Basis for retaining billing records (legal obligation) and '
        'evidence under active legal proceedings (legal claims). '
        'Both exceptions are stated in the deletion certificate sent to the user.',
    color: Color(0xFF3B82F6),
  ),
  _LegalPoint(
    article: 'GDPR Art. 12(3)',
    title: 'Response timeline',
    legalText: 'The controller shall provide information on action taken on '
        'a request within one month of receipt. That period may be extended '
        'by two further months where necessary.',
    zapImpl: 'Deletion is confirmed immediately (202 Accepted). '
        'The 30-day grace period fits within the 1-month legal maximum. '
        'No extension needed — automated processing. '
        'Deletion certificate sent within 5 minutes of wipe completing.',
    color: Color(0xFF8B5CF6),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day172AccountDeletionEdgeCasesScreen extends ConsumerWidget {
  const Day172AccountDeletionEdgeCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Deletion: Edge Cases & Legal'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
            ),
            child: const Text('BLOCK FINAL ✅',
                style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _EdgeCasesTab(),
            if (tab == 1) const _LegalTab(),
            if (tab == 2) const _BlockCompleteTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0C080E), Color(0xFF060408), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 172',                   const Color(0xFF8B5CF6)),
          _badge('🟡 MOCK-NOW',                   const Color(0xFFF59E0B)),
          _badge('Account Deletion  ·  Day 4/4',  const Color(0xFFEF4444)),
          _badge('Block 169-172 Final ✅',         const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Deletion Edge Cases\n& Legal Deep Dive',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '6 edge cases — active SOS, evidence hold, multi-device, '
          'mid-wipe failure, phone re-use, active timers. '
          'DPDP §13 + GDPR Art. 17 six-point legal breakdown. '
          'Days 169-172 Account Deletion block is done.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',    '6 edge cases',      Color(0xFFEF4444)),
          _HStat('6',    'Legal articles',    Color(0xFF3B82F6)),
          _HStat('4/4',  'Days complete',     Color(0xFF10B981)),
          _HStat('173→', 'Audit Log next',    Color(0xFF8B5CF6)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.warning_rounded,  Color(0xFFEF4444), 'Edge Cases'),
      (Icons.gavel_rounded,    Color(0xFF3B82F6), 'DPDP / GDPR'),
      (Icons.emoji_events_rounded, Color(0xFF10B981), 'Block Done'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1)),
            child: Column(children: [
              Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
              const SizedBox(height: ZapSpacing.xs),
              Text(label, style: TextStyle(
                  color: isActive ? color : const Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Edge Cases
// ══════════════════════════════════════════════════════════════════════════════
class _EdgeCasesTab extends ConsumerWidget {
  const _EdgeCasesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded   = ref.watch(_expandedEdgeProvider);
    final simulating = ref.watch(_simulatingProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.warning_rounded, color: const Color(0xFFEF4444),
          text: '6 scenarios that block or complicate account deletion. '
              'Each has a trigger, detection method, UI response, and resolution. '
              'Tap any card to expand. Tap "Simulate" to see the mock error UI.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _statBox('2', 'Hard blocks\n(409)',   const Color(0xFFEF4444)),
          _statBox('1', 'Partial block\n(409)', const Color(0xFFF59E0B)),
          _statBox('1', 'Recovery\n(500)',      const Color(0xFF8B5CF6)),
          _statBox('2', 'Informational\n(200)', const Color(0xFF10B981)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 EDGE CASES  ·  TAP TO EXPAND + SIMULATE'),
      const SizedBox(height: ZapSpacing.md),

      ..._kEdgeCases.asMap().entries.map((e) {
        final i   = e.key;
        final ec  = e.value;
        final isExp = expanded == i;
        final isSim = simulating == i;

        return Column(children: [
          GestureDetector(
            onTap: () => ref.read(_expandedEdgeProvider.notifier).state =
                isExp ? null : i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                  color: isExp
                      ? ec.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExp
                          ? ec.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                      width: isExp ? 2 : 1)),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                            color: ec.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(ec.icon, color: ec.color, size: 16)),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ec.title, style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(ec.apiCode, style: TextStyle(color: ec.color,
                          fontSize: 9, fontWeight: FontWeight.w700,
                          fontFamily: 'monospace')),
                    ])),
                    Icon(isExp
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 16),
                  ]),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isExp
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                          child: _EdgeDetail(ec: ec, index: i,
                              isSim: isSim, ref: ref))
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),

          // Simulated UI below the card when active
          if (isSim) ...[
            const SizedBox(height: 2),
            _SimContainer(ec: ec),
            const SizedBox(height: ZapSpacing.xs),
            GestureDetector(
              onTap: () =>
                  ref.read(_simulatingProvider.notifier).state = null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                child: const Center(child: Text('Clear simulation',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 11))))),
          ],
          const SizedBox(height: ZapSpacing.sm),
        ]);
      }),
    ]);
  }

  Widget _statBox(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9,
        height: 1.3), textAlign: TextAlign.center),
  ]));
}

class _EdgeDetail extends StatelessWidget {
  final _EdgeCase ec;
  final int       index;
  final bool      isSim;
  final WidgetRef ref;
  const _EdgeDetail({required this.ec, required this.index,
      required this.isSim, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Trigger',    ec.trigger,    Icons.bolt_rounded,          ec.color),
      const SizedBox(height: ZapSpacing.sm),
      _section('Detection',  ec.detection,  Icons.radar_rounded,         const Color(0xFF3B82F6)),
      const SizedBox(height: ZapSpacing.sm),
      _section('UI Response',ec.uiResponse, Icons.phone_iphone_rounded,  const Color(0xFF10B981)),
      const SizedBox(height: ZapSpacing.sm),
      _section('Resolution', ec.resolution, Icons.check_circle_rounded,  const Color(0xFF8B5CF6)),
      const SizedBox(height: ZapSpacing.md),
      GestureDetector(
        onTap: () => ref.read(_simulatingProvider.notifier).state =
            isSim ? null : index,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isSim
                  ? const Color(0xFF1A1A1A)
                  : ec.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isSim
                      ? const Color(0xFF2A2A2A)
                      : ec.color.withOpacity(0.45))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isSim ? Icons.close_rounded : Icons.play_circle_rounded,
                color: isSim ? const Color(0xFF6B7280) : ec.color, size: 14),
            const SizedBox(width: 6),
            Text(isSim ? 'Hide simulation' : 'Simulate this error state',
                style: TextStyle(
                    color: isSim ? const Color(0xFF6B7280) : ec.color,
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]);
  }

  Widget _section(String label, String body, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 6),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: Color(0xFFD1D5DB),
                fontSize: 11, height: 1.5)),
          ])),
        ]));
}

class _SimContainer extends StatelessWidget {
  final _EdgeCase ec;
  const _SimContainer({required this.ec});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ec.color.withOpacity(0.5), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: BoxDecoration(
              color: ec.color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: Row(children: [
            const Icon(Icons.smartphone_rounded,
                color: Color(0xFF4B5563), size: 12),
            const SizedBox(width: 6),
            Text('ZapSafe  ·  ${ec.title}',
                style: TextStyle(color: ec.color, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ])),
        Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: ec.simulatedUI),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Legal Deep Dive
// ══════════════════════════════════════════════════════════════════════════════
class _LegalTab extends ConsumerWidget {
  const _LegalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded  = ref.watch(_expandedLegalProvider);
    final _ = ref.watch(_legalScanDoneProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.gavel_rounded, color: const Color(0xFF3B82F6),
          text: 'Six legal articles from DPDP Act 2023 and GDPR Art. 17 '
              'that govern the account deletion feature. Each maps to a specific '
              'ZapSafe implementation decision.'),
      const SizedBox(height: ZapSpacing.lg),

      // Compliance scorecard
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            const Text('Deletion Compliance Score  —  6 / 6 Requirements Met',
                style: TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
                minHeight: 6)),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(spacing: 6, runSpacing: 6, children: const [
            _LChip('DPDP §13(1) ✅', Color(0xFF10B981)),
            _LChip('DPDP §13(2) ✅', Color(0xFF10B981)),
            _LChip('DPDP §13(3) ✅', Color(0xFF10B981)),
            _LChip('GDPR Art.17(1) ✅', Color(0xFF3B82F6)),
            _LChip('GDPR Art.17(3) ✅', Color(0xFF3B82F6)),
            _LChip('GDPR Art.12(3) ✅', Color(0xFF8B5CF6)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // 30-day choice rationale
      const _SectionLabel('WHY 30 DAYS?  ·  LEGAL + UX RATIONALE'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _ratRow(const Color(0xFF10B981), 'DPDP §13 — no mandatory grace period',
              'DPDP does not specify a minimum or maximum delay. '
              'ZapSafe chose 30 days as a policy decision.'),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _ratRow(const Color(0xFF3B82F6), 'GDPR Art. 12(3) — max 1 month to action',
              'Deletion must be completed within 1 month. '
              'Our 30-day grace fits exactly within this limit.'),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _ratRow(const Color(0xFFF59E0B), 'UX — accidental deletion prevention',
              'Safety apps carry high stakes data. A 30-day window lets '
              'users cancel if the request was accidental or coerced.'),
          const Divider(height: 16, color: Color(0xFF2A2A2A)),
          _ratRow(const Color(0xFF8B5CF6), 'Operations — export window',
              'Users need time to download their data (Day 166-168 export). '
              '30 days is sufficient for even large evidence vaults.'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 LEGAL ARTICLES  ·  TAP TO SEE IMPLEMENTATION'),
      const SizedBox(height: ZapSpacing.md),

      ..._kLegalPoints.asMap().entries.map((e) {
        final i     = e.key;
        final point = e.value;
        final isExp = expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedLegalProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? point.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? point.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: point.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(point.article, style: TextStyle(
                        color: point.color, fontSize: 9,
                        fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(point.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600))),
                  Icon(isExp
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(children: [
                          // Legal text
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(
                                    ZapSpacing.radiusSmall),
                                border: Border.all(
                                    color: const Color(0xFF2A2A2A))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Legal text',
                                  style: TextStyle(color: Color(0xFF6B7280),
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                              const SizedBox(height: ZapSpacing.xs),
                              Text(point.legalText,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 11, height: 1.6,
                                      fontStyle: FontStyle.italic)),
                            ])),
                          const SizedBox(height: ZapSpacing.sm),
                          // ZapSafe implementation
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: point.color.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(
                                    ZapSpacing.radiusSmall),
                                border: Border.all(
                                    color: point.color.withOpacity(0.25))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Icon(Icons.check_circle_rounded,
                                    color: point.color, size: 12),
                                const SizedBox(width: 6),
                                Text('ZapSafe implementation',
                                    style: TextStyle(color: point.color,
                                        fontSize: 9, fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                              ]),
                              const SizedBox(height: ZapSpacing.xs),
                              Text(point.zapImpl,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 11, height: 1.6)),
                            ])),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.balance_rounded, color: const Color(0xFF6B7280),
          text: 'GDPR Art. 17 applies to EU users. ZapSafe serves primarily '
              'India — DPDP §13 is the primary basis. '
              'For any user who invokes GDPR explicitly (email to privacy@zapsafe.app), '
              'ZapSafe processes under both frameworks and the stricter deadline applies.'),
    ]);
  }

  static Widget _ratRow(Color color, String title, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: ZapSpacing.md),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white,
          fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
          fontSize: 11, height: 1.5)),
    ])),
  ]);
}

class _LChip extends StatelessWidget {
  final String label; final Color color;
  const _LChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w700)));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Block Complete
// ══════════════════════════════════════════════════════════════════════════════
class _BlockCompleteTab extends StatelessWidget {
  const _BlockCompleteTab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Big celebration card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.03),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
        ),
        child: Column(children: [
          const Text('🗑️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: ZapSpacing.md),
          const Text('Account Deletion Block',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.xs),
          const Text('DAYS 169 – 172  ✅',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center, children: const [
            _Chip('Request flow ✅',          Color(0xFF8B5CF6)),
            _Chip('Grace period UI ✅',        Color(0xFFF59E0B)),
            _Chip('Day-30 walkthrough ✅',     Color(0xFFEF4444)),
            _Chip('Wipe animation ✅',         Color(0xFFEF4444)),
            _Chip('Account wiped state ✅',    Color(0xFF6B7280)),
            _Chip('6 edge cases ✅',           Color(0xFFEF4444)),
            _Chip('DPDP §13 (3pts) ✅',       Color(0xFF10B981)),
            _Chip('GDPR Art.17 (3pts) ✅',    Color(0xFF3B82F6)),
            _Chip('5 API endpoints ✅',        Color(0xFF3B82F6)),
            _Chip('Re-auth gate ✅',           Color(0xFF8B5CF6)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Section B progress so far
      const _SectionLabel('SECTION B: DATA RIGHTS  ·  PROGRESS'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _blockRow(const Color(0xFF10B981), 'Days 166-168',
              'Data Export / Download My Data', true),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _blockRow(const Color(0xFF10B981), 'Days 169-172',
              'Account Deletion Flow', true),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _blockRow(const Color(0xFF3B82F6), 'Days 173-175',
              'Data Access Audit Log  ←  NEXT', false),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _blockRow(const Color(0xFF6B7280), 'Days 176-178',
              'Data Retention Settings', false),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _blockRow(const Color(0xFF6B7280), 'Days 179-180',
              'Active Sessions / Devices', false),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Section B progress bar
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Section B progress',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          const Spacer(),
          const Text('2 / 5 blocks complete',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
              value: 2 / 5,
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8)),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Next block preview
      const _SectionLabel('NEXT  ·  DAYS 173-175: DATA ACCESS AUDIT LOG'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
        child: Column(children: [
          _nextItem('Day 173',
              'Audit log screen — timeline of who accessed your data, '
              'what was accessed, when and from where. '
              'Filter by access type (read/write/delete/export).'),
          const Divider(height: 16, color: Color(0xFF1A1A1A)),
          _nextItem('Day 174',
              'Data access details — per-item drill-down, IP addresses '
              'redacted per DPDP, device type, session ID. '
              'Export audit log as CSV or PDF.'),
          const Divider(height: 16, color: Color(0xFF1A1A1A)),
          _nextItem('Day 175',
              'Third-party access log — which integrations or contacts '
              'triggered data reads. Review and revoke access. '
              'DPDP §11 right to access + Days 173-175 block sign-off.'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.construction_rounded, color: const Color(0xFFF59E0B),
          text: 'Days 173-175 Data Access Audit Log is 🟡 MOCK-NOW. '
              'Backend at Day 78 has no audit-log API. '
              'Same pattern as Days 166-172: build with mock data + document contract.'),
    ]);
  }

  static Widget _blockRow(Color color, String days, String title, bool done) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days, style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.w700)),
            Text(title, style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w500)),
          ])),
          if (done)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 16)
          else
            const Icon(Icons.radio_button_unchecked_rounded,
                color: Color(0xFF3A3A3A), size: 16),
        ]));

  static Widget _nextItem(String day, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(day, style: const TextStyle(color: Color(0xFF3B82F6),
              fontSize: 9, fontWeight: FontWeight.w800))),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Text(body, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5))),
      ]);
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w600)));
}

// ── Reusable mock card widget ──────────────────────────────────────────────────
class _MockCard extends StatelessWidget {
  final Color    color;
  final IconData icon;
  final String   title;
  final String   body;
  final String   apiLabel;
  final String   actionLabel;
  final Color    actionColor;
  const _MockCard({
    required this.color, required this.icon, required this.title,
    required this.body, required this.apiLabel,
    required this.actionLabel, required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(title, style: TextStyle(color: color,
                fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Text(body, style: const TextStyle(color: Color(0xFFD1D5DB),
              fontSize: 11, height: 1.5)),
        ])),
      const SizedBox(height: ZapSpacing.sm),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Text(apiLabel, style: const TextStyle(color: Color(0xFF6B7280),
            fontSize: 9, fontFamily: 'monospace'))),
      const SizedBox(height: ZapSpacing.sm),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: actionColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: actionColor.withOpacity(0.4))),
        child: Center(child: Text(actionLabel, style: TextStyle(
            color: actionColor, fontSize: 11, fontWeight: FontWeight.w700)))),
    ]);
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
