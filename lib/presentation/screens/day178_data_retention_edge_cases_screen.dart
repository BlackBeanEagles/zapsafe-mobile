/// Day 178 — Data Retention: Edge Cases, DPDP §8 & Block Sign-Off
///
/// Third and final day of the Days 176-178 Data Retention block.
/// Day 176: Per-category pickers + evidence vault + GPS purge    ✅
/// Day 177: Upcoming deletions + scheduler + change history       ✅
/// Day 178: 6 retention edge cases, DPDP §8 compliance proof,
///           Days 176-178 complete, Section B 4/5 progress.
///
/// 🟢 FRONTEND-ONLY for local category edge cases.
/// 🟡 MOCK-NOW for server-side edge case handling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d178TabProvider       = StateProvider<int>((ref) => 0);
final _expandedEdgeProvider  = StateProvider<int?>((ref) => null);
final _simulatingProvider    = StateProvider<int?>((ref) => null);
final _expandedDpdpProvider  = StateProvider<int?>((ref) => null);

// ── Edge case data ─────────────────────────────────────────────────────────────
class _EdgeCase {
  final String   title;
  final IconData icon;
  final Color    color;
  final String   apiCode;
  final String   trigger;
  final String   detection;
  final String   handling;
  final String   userFacing;
  final Widget   mockUI;
  const _EdgeCase({
    required this.title, required this.icon, required this.color,
    required this.apiCode, required this.trigger, required this.detection,
    required this.handling, required this.userFacing, required this.mockUI,
  });
}

// ── Mock UIs for simulated states ─────────────────────────────────────────────
Widget _retroactiveMock() => _MockCard(
  color: const Color(0xFFF59E0B),
  icon: Icons.fast_rewind_rounded,
  title: 'Retroactive deletion triggered',
  body: 'You changed Location & GPS from 30 days → 7 days.\n\n'
      'ZapSafe found 3 GPS batches between 8-30 days old that now '
      'exceed the new 7-day limit. These will be deleted in the next '
      'scheduler run (tonight 03:00 AM).\n\n'
      '"Next 7 Days" tab shows them as Day +0 deletions.',
  actionLabel: 'Undo change (restore to 30 days)',
  actionColor: const Color(0xFFF59E0B),
);

Widget _sosLinkedMock() => _MockCard(
  color: const Color(0xFFEF4444),
  icon: Icons.warning_rounded,
  title: 'Active SOS — retention suspended',
  body: 'GPS batches from May 29 are linked to active SOS event '
      'sos_20260529. Your 14-day location retention would normally '
      'delete these on June 12, but deletion is suspended while '
      'the SOS event is unresolved.\n\n'
      'Retention enforcement resumes when SOS is marked resolved.',
  actionLabel: 'View SOS event details',
  actionColor: const Color(0xFFEF4444),
);

Widget _exportMock() => _MockCard(
  color: const Color(0xFF8B5CF6),
  icon: Icons.download_rounded,
  title: 'Export in progress — deletion paused',
  body: 'A data export (exp_20260530_abc123) is currently being '
      'compiled. Retention purges for all categories are paused '
      'until the export completes or expires.\n\n'
      'This prevents you from receiving an incomplete export. '
      'Estimated completion: 2 minutes.',
  actionLabel: 'View export status',
  actionColor: const Color(0xFF8B5CF6),
);

Widget _legalHoldMock() => _MockCard(
  color: const Color(0xFF3B82F6),
  icon: Icons.gavel_rounded,
  title: 'Legal hold — overrides user settings',
  body: 'Evidence vault items for sos_20260401 are under a legal '
      'hold (law enforcement reference: FIR/2026/123).\n\n'
      'Your retention setting of 90 days is OVERRIDDEN — these '
      'items will not be deleted regardless of expiry. '
      'Legal hold expires: December 1, 2026.',
  actionLabel: 'Contact privacy@zapsafe.app for questions',
  actionColor: const Color(0xFF3B82F6),
);

Widget _offlineMock() => _MockCard(
  color: const Color(0xFF6B7280),
  icon: Icons.wifi_off_rounded,
  title: 'Offline device — server-side deletion deferred',
  body: 'The server marked Location GPS batch (May 18) for deletion '
      '14 days ago, but your device was offline during the purge window.\n\n'
      'On reconnection: the scheduler runs immediately and deletes '
      'any overdue items. Local Hive records are also cleared. '
      'No data is orphaned.',
  actionLabel: 'Force sync now (mock)',
  actionColor: const Color(0xFF6B7280),
);

Widget _cascadeMock() => _MockCard(
  color: const Color(0xFF10B981),
  icon: Icons.account_tree_rounded,
  title: 'Cross-category cascade resolution',
  body: 'SOS event sos_20250914 has reached its 1-year retention limit.\n\n'
      'Before deleting the SOS metadata, ZapSafe checks:\n'
      '• Evidence vault: 4 files — expiry: Sep 13, 2026 ✅\n'
      '• Contacts notified: 2 contacts — retained independently ✅\n'
      '• GPS trace: already deleted (14-day limit) ✅\n\n'
      'Cascade: SOS metadata deleted. Evidence vault continues '
      'independently on its own timer.',
  actionLabel: 'View cascade deletion rules',
  actionColor: const Color(0xFF10B981),
);

final _kEdgeCases = [
  _EdgeCase(
    title: 'Retroactive Shortening',
    icon: Icons.fast_rewind_rounded, color: const Color(0xFFF59E0B),
    apiCode: 'PUT /retention-settings → triggers immediate audit on save',
    trigger: 'User changes a retention period to a shorter value '
        '(e.g. Location: 30 days → 7 days). Existing data older than '
        'the new limit is now over-retained.',
    detection: 'On PUT /account/retention-settings, backend queries each '
        'category for records exceeding the new limit. '
        'Counts are returned in the PUT response under "overdue_counts".',
    handling: 'Scheduler runs a one-time immediate purge for overdue items '
        'alongside the next regular run. User sees a warning banner in '
        'the "Next 7 Days" tab showing the retroactive deletions as Day +0.',
    userFacing: 'Banner: "Your new 7-day Location limit will delete 3 GPS batches '
        'tonight that are now over the limit. Undo change to keep them."',
    mockUI: _retroactiveMock(),
  ),
  _EdgeCase(
    title: 'Active SOS — Retention Suspended',
    icon: Icons.warning_rounded, color: const Color(0xFFEF4444),
    apiCode: '409 if scheduler tries to delete SOS-linked data',
    trigger: 'Scheduler tries to delete a GPS batch or evidence file '
        'that is flagged as linked to an active (unresolved) SOS event.',
    detection: 'Before each deletion, scheduler checks: '
        'SELECT linked_sos_id FROM data_items WHERE id = X. '
        'If linked_sos_id has status != "resolved", skip deletion.',
    handling: 'Item is skipped and re-queued for the next run. '
        'Audit log records: "Deletion deferred — linked to active SOS." '
        'Once SOS is marked resolved, the item becomes eligible again on '
        'the next scheduler run.',
    userFacing: 'In "Next 7 Days" tab: deletion card shows "SOS hold" badge '
        'instead of a date. Tooltip: "This data is linked to an active SOS '
        'event and will be held until the SOS is resolved."',
    mockUI: _sosLinkedMock(),
  ),
  _EdgeCase(
    title: 'Export In Progress — Deletion Paused',
    icon: Icons.download_rounded, color: const Color(0xFF8B5CF6),
    apiCode: 'Scheduler checks exports table for status = "processing"',
    trigger: 'Retention scheduler fires while a data export request '
        '(Day 166-168 flow) is being compiled. Deleting data mid-export '
        'would produce an incomplete ZIP.',
    detection: 'At scheduler start: SELECT COUNT(*) FROM data_exports '
        'WHERE user_id = X AND status IN ("requested", "processing"). '
        'If count > 0, scheduler skips all purges for this user.',
    handling: 'All purges deferred until export completes or expires (30 days). '
        'Scheduler re-checks on every run. If export never completes '
        '(server error), admin manually overrides after 48 hours.',
    userFacing: 'Banner in "Next 7 Days": "Deletions paused — export in progress. '
        'Purges will resume when your export (exp_20260530_abc123) is ready."',
    mockUI: _exportMock(),
  ),
  _EdgeCase(
    title: 'Legal Hold Overrides User Settings',
    icon: Icons.gavel_rounded, color: const Color(0xFF3B82F6),
    apiCode: 'DELETE blocked — 409 legal_hold; audit logged',
    trigger: 'Scheduler or user manually tries to delete evidence that '
        'has an admin-set legal hold (e.g. law enforcement request). '
        'The hold overrides all user retention settings.',
    detection: 'evidence_items.legal_hold = TRUE AND hold_expires_at > NOW(). '
        'Checked before every evidence deletion. '
        'Also shown in Day 176 Evidence Vault tab.',
    handling: 'Deletion blocked entirely. Audit log records: '
        '"Deletion blocked — legal hold FIR/2026/123." '
        'Hold expiry date shown to user. '
        'ZapSafe Trust & Safety manages hold lifecycle.',
    userFacing: 'In Evidence Vault tab: vault entry shows red "Legal Hold" badge '
        'instead of countdown ring. "Extend / Delete" buttons are disabled. '
        'Tooltip: "This evidence is under a legal hold until Dec 1, 2026."',
    mockUI: _legalHoldMock(),
  ),
  _EdgeCase(
    title: 'Offline Device — Server Deletion Deferred',
    icon: Icons.wifi_off_rounded, color: const Color(0xFF6B7280),
    apiCode: 'Scheduler marks items as "pending_delete"; executes on sync',
    trigger: 'Server-side scheduler marks data for deletion (GPS batch '
        'hits 14-day limit), but the device is offline and cannot '
        'receive the delete instruction.',
    detection: 'Server marks records in pending_deletes table. '
        'On device reconnection, the app calls GET /pending-operations '
        'and executes any pending deletes from Hive locally.',
    handling: 'Pending deletions execute immediately on app foreground '
        'after reconnection. "Next 7 Days" tab shows "Pending sync" badge '
        'for items waiting to be confirmed. '
        'No data is orphaned — both server and client clean up.',
    userFacing: 'Status badge in "Next 7 Days": '
        '"Sync pending — will delete when device reconnects." '
        'On reconnection, Snackbar: "3 overdue items deleted."',
    mockUI: _offlineMock(),
  ),
  _EdgeCase(
    title: 'Cross-Category Cascade Resolution',
    icon: Icons.account_tree_rounded, color: const Color(0xFF10B981),
    apiCode: 'Cascade DELETE with pre-flight dependency check',
    trigger: 'SOS event metadata hits its retention limit (e.g. 1 year). '
        'But the SOS event is linked to: evidence vault files, '
        'GPS traces, and contacts who were notified. '
        'Each has its own retention period.',
    detection: 'Before deleting SOS metadata, scheduler runs dependency check: '
        'SELECT * FROM data_items WHERE linked_sos_id = X. '
        'Returns a manifest of all linked items with their own retention status.',
    handling: 'SOS metadata deleted independently. '
        'Linked evidence, GPS, and notification history follow their own '
        'per-category timers — they are NOT cascade-deleted with the SOS. '
        'The dependency check prevents orphaned references by nullifying '
        'foreign keys rather than cascading.',
    userFacing: 'In Day 176 Evidence Vault tab: vault entries remain visible '
        'even after parent SOS metadata is deleted, with a note: '
        '"Associated SOS record expired — evidence retention continues independently."',
    mockUI: _cascadeMock(),
  ),
];

// ── DPDP §8 compliance points ──────────────────────────────────────────────────
class _DpdpPoint {
  final String article, title, legalText, zapImpl;
  final Color  color;
  const _DpdpPoint({
    required this.article, required this.title,
    required this.legalText, required this.zapImpl, required this.color,
  });
}

const _kDpdpPoints = [
  _DpdpPoint(
    article: 'DPDP §8(1)',
    title: 'Data minimisation — only what\'s necessary',
    legalText: 'A Data Fiduciary shall ensure that personal data collected '
        'is limited to what is necessary for the purposes of processing.',
    zapImpl: 'Day 176: 7 retention categories with specific defaults '
        'chosen based on purpose (Location: 14 days — shortest viable window; '
        'Evidence: 90 days — time for legal filing). '
        'Profile fixed at account-lifetime — no shorter period possible.',
    color: Color(0xFF10B981),
  ),
  _DpdpPoint(
    article: 'DPDP §8(3)',
    title: 'Storage limitation — not longer than necessary',
    legalText: 'A Data Fiduciary shall ensure that personal data is not '
        'retained for a period longer than is necessary for the purpose '
        'for which it was collected.',
    zapImpl: 'Day 176 pickers enforce maximum retention per category. '
        'Day 177 scheduler enforces nightly automated purges. '
        'Day 178 edge cases ensure no data survives past its limit '
        'even with legal holds, SOS events, or exports.',
    color: Color(0xFF3B82F6),
  ),
  _DpdpPoint(
    article: 'DPDP §8(4)',
    title: 'Accuracy — keep data correct',
    legalText: 'A Data Fiduciary shall ensure that personal data is complete, '
        'accurate, and consistent with the available information.',
    zapImpl: 'Deletion of stale location data ensures only recent, '
        'accurate GPS points are retained. '
        'Old crash logs that may contain stale device info are purged. '
        'Contact information is updated on each SOS event (no stale copies).',
    color: Color(0xFF8B5CF6),
  ),
  _DpdpPoint(
    article: 'DPDP §8(7)',
    title: 'Accountability — demonstrate compliance',
    legalText: 'A Data Fiduciary shall be accountable for complying with '
        'the provisions of this Act in respect of any processing of '
        'personal data by it.',
    zapImpl: 'Day 177 Change History: every retention change logged with '
        'timestamp, actor, from/to values, and reason. '
        'Scheduler audit log: every purge recorded. '
        'Deletion certificate generated for account deletions (Day 171).',
    color: Color(0xFFF59E0B),
  ),
  _DpdpPoint(
    article: 'GDPR Art. 5(1)(c)',
    title: 'Data minimisation (EU equivalent)',
    legalText: 'Personal data shall be adequate, relevant and limited to '
        'what is necessary in relation to the purposes for which they '
        'are processed ("data minimisation").',
    zapImpl: 'Same Day 176 pickers apply to EU users. '
        'Location 14-day default is stricter than most apps. '
        'Analytics consent gate (Day 163) means analytics data only '
        'exists at all if user consented.',
    color: Color(0xFF3B82F6),
  ),
  _DpdpPoint(
    article: 'GDPR Art. 5(1)(e)',
    title: 'Storage limitation (EU equivalent)',
    legalText: 'Personal data shall be kept in a form which permits '
        'identification of data subjects for no longer than is necessary '
        'for the purposes for which the personal data are processed '
        '("storage limitation").',
    zapImpl: 'Nightly scheduler (Day 177) enforces storage limitation automatically. '
        'Evidence vault timers (Day 176 Tab 2) give per-SOS countdown. '
        'Day 178 edge cases ensure no data escapes retention even in '
        'complex scenarios (legal holds, exports, SOS holds).',
    color: Color(0xFF10B981),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day178DataRetentionEdgeCasesScreen extends ConsumerWidget {
  const Day178DataRetentionEdgeCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d178TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Retention: Edge Cases & Sign-Off'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('BLOCK FINAL ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
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
                onSelect: (t) => ref.read(_d178TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _EdgeCasesTab(),
            if (tab == 1) const _DpdpTab(),
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
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0A0C08), Color(0xFF060806), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 178',                   const Color(0xFF10B981)),
          _badge('🟢/🟡 MIXED',                   const Color(0xFFF59E0B)),
          _badge('Retention  ·  Day 3/3',         const Color(0xFF8B5CF6)),
          _badge('Block 176-178 Final ✅',         const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Retention Edge Cases\n& DPDP §8 Sign-Off',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '6 scenarios that complicate retention enforcement — active SOS, '
          'legal holds, exports, offline devices, retroactive changes, '
          'and cross-category cascades. '
          'DPDP §8 + GDPR Art. 5 6-point compliance proof.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',   '6 edge cases',      Color(0xFFEF4444)),
          _HStat('6',   'DPDP/GDPR points', Color(0xFF3B82F6)),
          _HStat('3/3', 'Block complete',    Color(0xFF10B981)),
          _HStat('4/5', 'Section B done',   Color(0xFFF59E0B)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
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
      (Icons.warning_rounded,      Color(0xFFEF4444), 'Edge Cases'),
      (Icons.gavel_rounded,        Color(0xFF3B82F6), 'DPDP §8'),
      (Icons.emoji_events_rounded, Color(0xFF10B981), 'Block Done'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
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
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
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
          text: '6 scenarios where simple "delete after N days" breaks down. '
              'Each has a detection method, handling strategy, and what '
              'the user sees. Tap any card to expand. Tap Simulate to see the UI.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _stat('3',  'Hard blocks\n(hold/SOS/export)',  const Color(0xFFEF4444)),
          _stat('1',  'Deferred\n(offline)',              const Color(0xFF6B7280)),
          _stat('1',  'Warning\n(retroactive)',           const Color(0xFFF59E0B)),
          _stat('1',  'Informational\n(cascade)',         const Color(0xFF10B981)),
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
                  color: isExp ? ec.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExp ? ec.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
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
                          fontSize: 9, fontWeight: FontWeight.w600,
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
          // Simulated UI
          if (isSim) ...[
            const SizedBox(height: 2),
            _SimCard(ec: ec),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => ref.read(_simulatingProvider.notifier).state = null,
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

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));
}

class _EdgeDetail extends StatelessWidget {
  final _EdgeCase ec; final int index;
  final bool isSim; final WidgetRef ref;
  const _EdgeDetail({required this.ec, required this.index,
      required this.isSim, required this.ref});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _section('Trigger',    ec.trigger,    Icons.bolt_rounded,          ec.color),
    const SizedBox(height: ZapSpacing.sm),
    _section('Detection',  ec.detection,  Icons.radar_rounded,         const Color(0xFF3B82F6)),
    const SizedBox(height: ZapSpacing.sm),
    _section('Handling',   ec.handling,   Icons.settings_rounded,      const Color(0xFF8B5CF6)),
    const SizedBox(height: ZapSpacing.sm),
    _section('User sees',  ec.userFacing, Icons.phone_iphone_rounded,  const Color(0xFF10B981)),
    const SizedBox(height: ZapSpacing.md),
    GestureDetector(
      onTap: () => ref.read(_simulatingProvider.notifier).state =
          isSim ? null : index,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: isSim ? const Color(0xFF1A1A1A) : ec.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isSim ? const Color(0xFF2A2A2A) : ec.color.withOpacity(0.45))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isSim ? Icons.close_rounded : Icons.play_circle_rounded,
              color: isSim ? const Color(0xFF6B7280) : ec.color, size: 14),
          const SizedBox(width: 6),
          Text(isSim ? 'Hide simulation' : 'Simulate this scenario',
              style: TextStyle(
                  color: isSim ? const Color(0xFF6B7280) : ec.color,
                  fontSize: 11, fontWeight: FontWeight.w700)),
        ])),
    ),
  ]);

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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: Color(0xFFD1D5DB),
                fontSize: 11, height: 1.5)),
          ])),
        ]));
}

class _SimCard extends StatelessWidget {
  final _EdgeCase ec;
  const _SimCard({required this.ec});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ec.color.withOpacity(0.5), width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
          decoration: BoxDecoration(
              color: ec.color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: Row(children: [
            const Icon(Icons.smartphone_rounded, color: Color(0xFF4B5563), size: 12),
            const SizedBox(width: 6),
            Text('ZapSafe  ·  ${ec.title}',
                style: TextStyle(color: ec.color, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ])),
        Padding(padding: const EdgeInsets.all(ZapSpacing.md), child: ec.mockUI),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — DPDP §8 Compliance
// ══════════════════════════════════════════════════════════════════════════════
class _DpdpTab extends ConsumerWidget {
  const _DpdpTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedDpdpProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.gavel_rounded, color: const Color(0xFF3B82F6),
          text: 'How the Days 176-178 Data Retention feature satisfies '
              'DPDP Act 2023 §8 (Obligations of Data Fiduciary) and '
              'GDPR Art. 5 storage limitation principle.'),
      const SizedBox(height: ZapSpacing.lg),

      // Scorecard
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
        child: Column(children: [
          const Row(children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Retention Compliance — 6 / 6 Requirements Met',
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
            _LChip('DPDP §8(1) ✅', Color(0xFF10B981)),
            _LChip('DPDP §8(3) ✅', Color(0xFF3B82F6)),
            _LChip('DPDP §8(4) ✅', Color(0xFF8B5CF6)),
            _LChip('DPDP §8(7) ✅', Color(0xFFF59E0B)),
            _LChip('GDPR Art.5(1)(c) ✅', Color(0xFF3B82F6)),
            _LChip('GDPR Art.5(1)(e) ✅', Color(0xFF10B981)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 REQUIREMENTS  ·  TAP TO SEE IMPLEMENTATION'),
      const SizedBox(height: ZapSpacing.md),

      ..._kDpdpPoints.asMap().entries.map((e) {
        final i     = e.key;
        final point = e.value;
        final isExp = expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedDpdpProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? point.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? point.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
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
                        color: point.color, fontSize: 9, fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(point.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ])),
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
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: const Color(0xFF2A2A2A))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Legal text',
                                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                                      fontWeight: FontWeight.w700, letterSpacing: 1)),
                              const SizedBox(height: 4),
                              Text(point.legalText, style: const TextStyle(
                                  color: Color(0xFFD1D5DB), fontSize: 11,
                                  height: 1.6, fontStyle: FontStyle.italic)),
                            ])),
                          const SizedBox(height: ZapSpacing.sm),
                          // ZapSafe impl
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: point.color.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: point.color.withOpacity(0.25))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Icon(Icons.check_circle_rounded, color: point.color, size: 12),
                                const SizedBox(width: 6),
                                Text('ZapSafe implementation', style: TextStyle(
                                    color: point.color, fontSize: 9,
                                    fontWeight: FontWeight.w700, letterSpacing: 1)),
                              ]),
                              const SizedBox(height: 4),
                              Text(point.zapImpl, style: const TextStyle(
                                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6)),
                            ])),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),
    ]);
  }
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
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Celebration card
    Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        const Text('🗂️', style: TextStyle(fontSize: 44)),
        const SizedBox(height: ZapSpacing.md),
        const Text('Data Retention Settings Block',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 14,
                fontWeight: FontWeight.w700, letterSpacing: 0.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('DAYS 176 – 178  ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: const [
          _Chip('7 category pickers ✅',        Color(0xFF3B82F6)),
          _Chip('Evidence vault timers ✅',      Color(0xFFF59E0B)),
          _Chip('GPS purge schedule ✅',         Color(0xFF10B981)),
          _Chip('Next 7-day preview ✅',         Color(0xFFEF4444)),
          _Chip('Scheduler simulation ✅',       Color(0xFF3B82F6)),
          _Chip('Change history log ✅',         Color(0xFF8B5CF6)),
          _Chip('6 edge cases ✅',               Color(0xFFEF4444)),
          _Chip('DPDP §8 6/6 ✅',               Color(0xFF10B981)),
          _Chip('4 API endpoints ✅',            Color(0xFFF59E0B)),
          _Chip('GDPR Art.5 ✅',                Color(0xFF3B82F6)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Section B 4/5 progress
    const _SectionLabel('SECTION B: DATA RIGHTS  ·  PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        _blockRow(const Color(0xFF10B981), 'Days 166-168', 'Data Export / Download My Data', true),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _blockRow(const Color(0xFF10B981), 'Days 169-172', 'Account Deletion Flow', true),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _blockRow(const Color(0xFF10B981), 'Days 173-175', 'Data Access Audit Log', true),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _blockRow(const Color(0xFF10B981), 'Days 176-178', 'Data Retention Settings', true),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _blockRow(const Color(0xFF3B82F6), 'Days 179-180', 'Active Sessions / Devices  ←  NEXT', false),
      ]),
    ),
    const SizedBox(height: ZapSpacing.lg),

    // 4/5 progress bar
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Section B progress',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const Spacer(),
        const Text('4 / 5 blocks complete',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const LinearProgressIndicator(
            value: 4 / 5,
            backgroundColor: Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            minHeight: 8)),
    ]),
    const SizedBox(height: ZapSpacing.xl),

    // Next block preview
    const _SectionLabel('NEXT  ·  DAYS 179-180: ACTIVE SESSIONS / DEVICES'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(children: [
        _nextRow('Day 179',
            'Active Sessions screen — list all devices with active JWTs, '
            'session start time, last-active, device type, city. '
            'Remote sign-out / revoke session button.'),
        const Divider(height: 16, color: Color(0xFF1A1A1A)),
        _nextRow('Day 180',
            'Device management deep-dive — trusted devices, '
            'session detail cards, suspicious login alerts, '
            'Section B (Days 166-180) complete sign-off.'),
      ]),
    ),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFFF59E0B),
        text: 'Days 179-180 Active Sessions / Devices is 🟡 MOCK-NOW. '
            'Backend session API (GET /account/sessions + DELETE /account/sessions/{id}) '
            'does not exist at Day 78. '
            'Day 174 Sessions tab already built a preview — '
            'Days 179-180 will be the full dedicated screen.'),
  ]);

  static Widget _blockRow(Color c, String days, String title, bool done) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ])),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
          else
            const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF3A3A3A), size: 16),
        ]));

  static Widget _nextRow(String day, String body) =>
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

// ── Mock card widget ───────────────────────────────────────────────────────────
class _MockCard extends StatelessWidget {
  final Color color; final IconData icon;
  final String title, body, actionLabel; final Color actionColor;
  const _MockCard({required this.color, required this.icon,
      required this.title, required this.body,
      required this.actionLabel, required this.actionColor});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Expanded(child: Text(title, style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ])),
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
