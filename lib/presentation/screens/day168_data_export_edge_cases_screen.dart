/// Day 168 — Data Export: Rate Limits, GDPR Art. 20 & Edge Cases
///
/// Third and final day of the Days 166-168 Data Export block.
/// Day 166: Request form + history + API contract         ✅
/// Day 167: Download + SHA-256 integrity + file browser   ✅
/// Day 168: Rate-limit enforcement UI + GDPR Art. 20
///           legal deep dive + 6 edge cases + block sign-off.
///
/// 🟡 MOCK-NOW — same pattern as Days 166-167.
///    Backend contract already documented in Day 166 API Contract tab.
///    This screen covers the error states and legal compliance layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider       = StateProvider<int>((ref) => 0);
final _rateLimitModeProvider   = StateProvider<_RlMode>((ref) => _RlMode.available);
final _countdownProvider       = StateProvider<int>((ref) => 18);   // days remaining
final _expandedEdgeCaseProvider= StateProvider<int?>((ref) => null);
final _gdprExpandedProvider    = StateProvider<int?>((ref) => null);
final _simulatingProvider      = StateProvider<int?>((ref) => null); // which edge-case is simulating

enum _RlMode { available, rateLimited, accountDeleting }

// ── Data ───────────────────────────────────────────────────────────────────────
class _EdgeCase {
  final String   title;
  final String   trigger;
  final String   detection;
  final String   uiResponse;
  final String   apiError;
  final IconData icon;
  final Color    color;
  const _EdgeCase({
    required this.title, required this.trigger,
    required this.detection, required this.uiResponse,
    required this.apiError, required this.icon, required this.color,
  });
}

const _kEdgeCases = [
  _EdgeCase(
    title: 'Rate Limited — 30-day cooldown',
    trigger: 'User submits POST /data-export/request within 30 days of last request.',
    detection: 'API returns HTTP 429 with next_allowed_at timestamp.',
    uiResponse: 'Disable the "Request Export" button. Show a countdown banner: '
        '"Next export available in X days" with a visual ring. '
        'The My Exports tab still shows historical exports for download.',
    apiError: '429 { "error": "rate_limit_exceeded", "next_allowed_at": "2026-06-29T14:25:00Z" }',
    icon: Icons.timer_rounded,
    color: Color(0xFFF59E0B),
  ),
  _EdgeCase(
    title: 'Account Deletion In Progress',
    trigger: 'User requests export while an account-deletion request (Day 169) is pending.',
    detection: 'API returns HTTP 409 Conflict with reason "account_deletion_pending".',
    uiResponse: 'Show a red info banner: "Export unavailable — account deletion is pending. '
        'Cancel the deletion in Settings → Account → Delete Account to re-enable exports." '
        'Both request and download buttons are disabled.',
    apiError: '409 { "error": "account_deletion_pending", "deletion_requested_at": "2026-05-28T10:00:00Z" }',
    icon: Icons.person_off_rounded,
    color: Color(0xFFEF4444),
  ),
  _EdgeCase(
    title: 'Export Too Large (> 2 GB)',
    trigger: 'Evidence vault contains years of audio/video — export exceeds 2 GB server limit.',
    detection: 'API returns HTTP 413 with estimated_size_bytes in body.',
    uiResponse: 'Show file-size warning before submission. Offer to split: '
        '"Your evidence vault is 3.2 GB. Deselect Evidence Vault to export other data now, '
        'then request a separate evidence export." Evidence-only request path planned for Day 175.',
    apiError: '413 { "error": "export_too_large", "estimated_size_bytes": 3435973836, "limit_bytes": 2147483648 }',
    icon: Icons.folder_off_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _EdgeCase(
    title: 'No Data to Export (New Account)',
    trigger: 'User account is < 24 hours old — no SOS events, no evidence, no location data.',
    detection: 'API returns HTTP 204 No Content, or a ZIP with only _meta/ folder.',
    uiResponse: 'Show a friendly empty state: "Your ZapSafe data is building up — '
        'there isn\'t much to export yet. Check back after you\'ve used the app for a few days." '
        'Profile and consent data is still exported (2–4 KB).',
    apiError: '204 No Content  OR  200 { "categories_with_data": ["profile","settings"] }',
    icon: Icons.inbox_rounded,
    color: Color(0xFF3B82F6),
  ),
  _EdgeCase(
    title: 'Network Failure Mid-Download',
    trigger: 'Connection drops while streaming the ZIP bytes (partial file).',
    detection: 'http.Client stream throws SocketException. local file < expected size.',
    uiResponse: 'Delete the partial file immediately. Show "Download interrupted" card '
        'with "Retry" button (fetches a fresh presigned URL — old one may have expired). '
        'Integrity check would also catch this if the partial file slipped through.',
    apiError: 'SocketException: OS Error: Connection reset by peer (client-side only)',
    icon: Icons.wifi_off_rounded,
    color: Color(0xFFEF4444),
  ),
  _EdgeCase(
    title: 'Export Link Expired Before Download',
    trigger: 'User waits > 30 days after export is ready without downloading.',
    detection: 'GET /data-export/download/{id} returns HTTP 410 Gone.',
    uiResponse: 'In the My Exports history, mark the row as "Expired" (grey chip). '
        'Show "This export has expired. Submit a new request to get your data." '
        'New request resets the 30-day cooldown from the new request date.',
    apiError: '410 { "error": "export_expired", "expired_at": "2026-06-29T14:30:00Z" }',
    icon: Icons.link_off_rounded,
    color: Color(0xFF6B7280),
  ),
];

class _GdprPoint {
  final String article;
  final String title;
  final String body;
  final String zapSafeImpl;
  final Color  color;
  const _GdprPoint({
    required this.article, required this.title,
    required this.body, required this.zapSafeImpl, required this.color});
}

const _kGdprPoints = [
  _GdprPoint(
    article: 'Art. 20(1)',
    title: 'Right to receive personal data',
    body: 'The data subject shall have the right to receive the personal data '
        'concerning them, which they have provided to a controller, in a structured, '
        'commonly used and machine-readable format.',
    zapSafeImpl: 'ZapSafe delivers data as JSON (machine-readable), '
        'ZIP (structured archive), or PDF (human-readable). '
        'Every export includes _meta/manifest.json with schema version and checksums.',
    color: Color(0xFF3B82F6),
  ),
  _GdprPoint(
    article: 'Art. 20(2)',
    title: 'Right to transmit to another controller',
    body: 'The data subject shall have the right to transmit those data to another '
        'controller without hindrance from the controller to which the personal data '
        'have been provided.',
    zapSafeImpl: 'The JSON export format is self-documented and controller-agnostic. '
        'No proprietary encoding. Third parties can ingest the export without a '
        'ZapSafe-specific adapter. Schema v1.0 published at zapsafe.app/export-schema.',
    color: Color(0xFF8B5CF6),
  ),
  _GdprPoint(
    article: 'Art. 20(3)',
    title: 'Exceptions: impact on others',
    body: 'The right to data portability shall not apply where processing is necessary '
        'for the performance of a task carried out in the public interest or in the '
        'exercise of official authority vested in the controller.',
    zapSafeImpl: 'ZapSafe\'s processing is consent- and contract-based — no public '
        'authority exemption applies. Emergency contacts\' data is redacted in exports '
        '(phone numbers partially masked) to protect third parties\' privacy.',
    color: Color(0xFF10B981),
  ),
  _GdprPoint(
    article: 'Art. 12(3)',
    title: 'Response timeline — 1 month',
    body: 'The controller shall provide information on action taken on a request '
        'within one month of receipt. That period may be extended by two further months '
        'where necessary, taking into account the complexity and number of requests.',
    zapSafeImpl: 'ZapSafe targets < 15 minutes (automated processing). '
        'Legal maximum is 1 month. If extension needed (rare), user is notified '
        'by email within 1 month of the request. Extension reason must be stated.',
    color: Color(0xFFF59E0B),
  ),
  _GdprPoint(
    article: 'DPDP §11',
    title: 'India DPDP Act 2023 — Right to Access',
    body: 'Every Data Principal shall have the right to obtain from the Data Fiduciary '
        'a summary of personal data being processed and the processing activities '
        'being undertaken with respect to such personal data.',
    zapSafeImpl: 'The export manifest.json acts as the required "summary of personal data '
        'being processed." The export itself fulfils the right to obtain the data. '
        'Timeline: 30 days per DPDP §11(1). Free of charge per DPDP §11(2).',
    color: Color(0xFF10B981),
  ),
  _GdprPoint(
    article: 'DPDP §11(3)',
    title: 'India DPDP — Grievance redressal',
    body: 'If the Data Fiduciary fails to provide the data within the stipulated time, '
        'the Data Principal may raise a complaint with the Data Protection Board.',
    zapSafeImpl: 'If the automated export fails after 30 days, the user is directed to '
        'privacy@zapsafe.app with SLA escalation. Contact details for the Data '
        'Protection Board of India are included in the README.txt of every export.',
    color: Color(0xFF3B82F6),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day168DataExportEdgeCasesScreen extends ConsumerWidget {
  const Day168DataExportEdgeCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Export: Limits, Legal & Edge Cases'),
        elevation: 0,
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
            _TabBar(
                active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _RateLimitTab(),
            if (tab == 1) const _GdprTab(),
            if (tab == 2) const _EdgeCasesTab(),
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
            colors: [Color(0xFF0A0A10), Color(0xFF050508), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 168', const Color(0xFFF59E0B)),
          _badge('🟡 MOCK-NOW', const Color(0xFFF59E0B)),
          _badge('Data Export  ·  Day 3/3', const Color(0xFF8B5CF6)),
          _badge('Block 166-168 Final ✅', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Rate Limits, GDPR\nArt. 20 & Edge Cases',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '30-day cooldown countdown UI. Six error scenarios with full '
          'detection + response. GDPR Art. 20 + DPDP §11 six-point legal '
          'walkthrough. Days 166-168 Data Export block is done.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('30d',  '30-day rate limit', Color(0xFFF59E0B)),
          _HStat('6',    '6 edge cases',      Color(0xFFEF4444)),
          _HStat('6',    'GDPR/DPDP points',  Color(0xFF3B82F6)),
          _HStat('3/3',  'Block complete',    Color(0xFF10B981)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]));
}

// ── Labels / TabBar ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.timer_rounded,       Color(0xFFF59E0B), 'Rate Limit'),
      (Icons.gavel_rounded,       Color(0xFF3B82F6), 'GDPR Art.20'),
      (Icons.warning_rounded,     Color(0xFFEF4444), 'Edge Cases'),
    ];
    return Row(
      children: List.generate(3, (i) {
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
                  color: isActive
                      ? color.withOpacity(0.12)
                      : const Color(0xFF1A1A1A),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isActive
                          ? color.withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isActive ? 2 : 1)),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Rate Limit
// ══════════════════════════════════════════════════════════════════════════════
class _RateLimitTab extends ConsumerWidget {
  const _RateLimitTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode      = ref.watch(_rateLimitModeProvider);
    final countdown = ref.watch(_countdownProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(
          icon: Icons.info_outline_rounded,
          color: const Color(0xFFF59E0B),
          text: 'ZapSafe enforces a 30-day cooldown between data export requests '
              '(DPDP §11 + GDPR Art. 12(3) allow up to 1 month for repeat requests). '
              'Use the simulator below to see each UI state.'),
      const SizedBox(height: ZapSpacing.lg),

      // ── Mode switcher ─────────────────────────────────────────────
      const _SectionLabel('SIMULATE MODE  ·  TAP TO SWITCH'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        _modeBtn(_RlMode.available,       'Available',        const Color(0xFF10B981), mode, ref),
        const SizedBox(width: ZapSpacing.sm),
        _modeBtn(_RlMode.rateLimited,     'Rate Limited',     const Color(0xFFF59E0B), mode, ref),
        const SizedBox(width: ZapSpacing.sm),
        _modeBtn(_RlMode.accountDeleting, 'Acct. Deleting',   const Color(0xFFEF4444), mode, ref),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // ── Countdown slider (only in rateLimited mode) ───────────────
      if (mode == _RlMode.rateLimited) ...[
        const _SectionLabel('DAYS REMAINING IN COOLDOWN'),
        const SizedBox(height: ZapSpacing.sm),
        Row(children: [
          Text('$countdown days', style: const TextStyle(
              color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w700)),
          Expanded(child: Slider(
            value: countdown.toDouble(),
            min: 1, max: 30,
            divisions: 29,
            activeColor: const Color(0xFFF59E0B),
            inactiveColor: const Color(0xFF2A2A2A),
            onChanged: (v) =>
                ref.read(_countdownProvider.notifier).state = v.round(),
          )),
          const Text('30', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        ]),
        const SizedBox(height: ZapSpacing.lg),
      ],

      // ── Live UI mock ──────────────────────────────────────────────
      const _SectionLabel('REQUEST EXPORT SCREEN  ·  MOCK UI'),
      const SizedBox(height: ZapSpacing.md),
      _RequestMock(mode: mode, countdown: countdown),
      const SizedBox(height: ZapSpacing.xl),

      // ── Technical detail ──────────────────────────────────────────
      const _SectionLabel('IMPLEMENTATION DETAIL'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _detailRow(const Color(0xFF10B981), 'Available state',
              'Button enabled. Shows "Request Export" in purple. '
              'Last export date shown in My Exports tab.'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _detailRow(const Color(0xFFF59E0B), 'Rate limited state',
              'Button disabled + greyed. Countdown ring shows days remaining. '
              'API 429 next_allowed_at parsed to human "X days Y hours" label. '
              'My Exports tab still functional — past exports downloadable.'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _detailRow(const Color(0xFFEF4444), 'Account deleting state',
              'Both request AND download buttons disabled. '
              'Banner explains: cancel deletion to re-enable. '
              'Detected via 409 Conflict from API.'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _detailRow(const Color(0xFF3B82F6), 'History always available',
              'Even when rate-limited, My Exports tab shows all past '
              'exports. Users can still download an existing ready export '
              'during the cooldown — only new requests are blocked.'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // ── 30-day rule explained ─────────────────────────────────────
      const _SectionLabel('WHY 30 DAYS?'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(
        icon: Icons.gavel_rounded,
        color: const Color(0xFF3B82F6),
        text: 'GDPR Art. 12(3) gives controllers up to 1 month to respond, '
            'with a possible 2-month extension for complex/multiple requests. '
            'ZapSafe responds instantly (automated) but limits the frequency to '
            'prevent server abuse and excessive storage costs. DPDP §11 does not '
            'specify a minimum interval — the 30-day limit is a ZapSafe policy '
            'choice within the legal framework.',
      ),
    ]);
  }

  static Widget _modeBtn(_RlMode target, String label, Color color,
      _RlMode current, WidgetRef ref) {
    final isOn = current == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(_rateLimitModeProvider.notifier).state = target,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: isOn ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isOn ? 2 : 1)),
          child: Text(label,
              style: TextStyle(
                  color: isOn ? color : const Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: isOn ? FontWeight.w700 : FontWeight.w400),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }

  static Widget _detailRow(Color color, String title, String body) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(body,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
            ]),
          ),
        ]),
      );
}

/// The mock "Request Export" button/banner that reflects the current RL mode.
class _RequestMock extends StatelessWidget {
  final _RlMode mode;
  final int countdown;
  const _RequestMock({required this.mode, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // "App screen" header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: const Row(children: [
            Icon(Icons.smartphone_rounded, color: Color(0xFF4B5563), size: 14),
            SizedBox(width: 6),
            Text('Download My Data  ·  Request Export tab',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status banner
            if (mode == _RlMode.rateLimited) _rateLimitBanner(countdown),
            if (mode == _RlMode.accountDeleting) _accountDeletingBanner(),
            if (mode != _RlMode.available) const SizedBox(height: ZapSpacing.md),

            // Mock category chips (abbreviated)
            const Wrap(spacing: 6, runSpacing: 6, children: [
              _MockChip('Profile ✓', Color(0xFF3B82F6)),
              _MockChip('Contacts ✓', Color(0xFF10B981)),
              _MockChip('SOS Events ✓', Color(0xFFEF4444)),
              _MockChip('Evidence ✓', Color(0xFFF59E0B)),
            ]),
            const SizedBox(height: ZapSpacing.md),

            // Request button — state-dependent
            _requestButton(mode),

            if (mode == _RlMode.available) ...[
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Last export: May 17, 2026  ·  Next available: Jun 16, 2026',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _rateLimitBanner(int days) {
    // Countdown ring approximation with a progress indicator
    final progress = days / 30;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border:
              Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
      child: Column(children: [
        Row(children: [
          // Mini ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                strokeWidth: 4,
              ),
              Text('$days',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Export cooldown active',
                  style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text('Next request available in $days day${days == 1 ? "" : "s"}',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10)),
            ]),
          ),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: 1 - progress,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor:
                const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Row(children: [
          Text('Cooldown started: May 30, 2026',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
          Spacer(),
          Text('Ends: Jun 29, 2026',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _accountDeletingBanner() => Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.4))),
        child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Icon(Icons.person_off_rounded, color: Color(0xFFEF4444), size: 16),
          SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Export unavailable — account deletion is in progress. '
              'Cancel the deletion in Settings → Account to re-enable data exports.',
              style: TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
          ),
        ]),
      );

  Widget _requestButton(_RlMode mode) {
    final canRequest = mode == _RlMode.available;
    final color      = canRequest
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF2A2A2A);
    final label      = switch (mode) {
      _RlMode.available       => 'Request Export',
      _RlMode.rateLimited     => 'Request Unavailable — Cooldown Active',
      _RlMode.accountDeleting => 'Request Unavailable — Deletion Pending',
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
          color: canRequest ? null : const Color(0xFF1A1A1A),
          gradient: canRequest
              ? LinearGradient(
                  colors: [color, color.withOpacity(0.8)])
              : null,
          borderRadius:
              BorderRadius.circular(ZapSpacing.radiusSmall),
          border: canRequest
              ? null
              : Border.all(color: const Color(0xFF2A2A2A))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.download_rounded,
            color: canRequest
                ? Colors.white
                : const Color(0xFF4B5563),
            size: 16),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: canRequest
                    ? Colors.white
                    : const Color(0xFF4B5563),
                fontSize: 12,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _MockChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MockChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600)));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — GDPR Art. 20
// ══════════════════════════════════════════════════════════════════════════════
class _GdprTab extends ConsumerWidget {
  const _GdprTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_gdprExpandedProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(
          icon: Icons.gavel_rounded,
          color: const Color(0xFF3B82F6),
          text: '6 legal points covering GDPR Art. 20, Art. 12(3), and '
              'India DPDP Act 2023 §11. Each maps to a specific ZapSafe '
              'implementation. Tap any card to see the implementation detail.'),
      const SizedBox(height: ZapSpacing.lg),

      // Compliance scorecard
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.35))),
        child: Column(children: [
          const Row(children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Compliance Score  —  6 / 6 Requirements Met',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          const Wrap(spacing: 6, runSpacing: 6, children: [
            _LegalChip('GDPR Art.20(1) ✅', Color(0xFF3B82F6)),
            _LegalChip('GDPR Art.20(2) ✅', Color(0xFF8B5CF6)),
            _LegalChip('GDPR Art.20(3) ✅', Color(0xFF10B981)),
            _LegalChip('GDPR Art.12(3) ✅', Color(0xFFF59E0B)),
            _LegalChip('DPDP §11 ✅',       Color(0xFF10B981)),
            _LegalChip('DPDP §11(3) ✅',    Color(0xFF3B82F6)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 REQUIREMENTS  ·  TAP TO SEE IMPLEMENTATION'),
      const SizedBox(height: ZapSpacing.md),

      ..._kGdprPoints.asMap().entries.map((e) {
        final i     = e.key;
        final point = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_gdprExpandedProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? point.color.withOpacity(0.07)
                    : const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? point.color.withOpacity(0.4)
                        : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: point.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(point.article,
                        style: TextStyle(
                            color: point.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                      child: Text(point.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                  Icon(
                      isExp
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563),
                      size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                              const SizedBox(height: ZapSpacing.xs),
                              Text(point.body,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 11,
                                      height: 1.6,
                                      fontStyle: FontStyle.italic)),
                            ]),
                          ),
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
                                    style: TextStyle(
                                        color: point.color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                              ]),
                              const SizedBox(height: ZapSpacing.xs),
                              Text(point.zapSafeImpl,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 11,
                                      height: 1.6)),
                            ]),
                          ),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),
      _infoBox(
          icon: Icons.balance_rounded,
          color: const Color(0xFF6B7280),
          text: 'Note: GDPR Art. 20 applies only to data processed on the basis of '
              'consent or contract — both bases ZapSafe uses. It does not apply to '
              'data processed for legal obligations or vital interests. '
              'ZapSafe does not process data on those bases for regular features.'),
    ]);
  }
}

class _LegalChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegalChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35))),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700)));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Edge Cases + Block Complete
// ══════════════════════════════════════════════════════════════════════════════
class _EdgeCasesTab extends ConsumerWidget {
  const _EdgeCasesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded   = ref.watch(_expandedEdgeCaseProvider);
    final simulating = ref.watch(_simulatingProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(
          icon: Icons.warning_rounded,
          color: const Color(0xFFEF4444),
          text: '6 edge cases with full trigger → detection → UI response '
              'documented. Tap any card to expand. Tap "Simulate" to see '
              'the mock UI state for that error scenario.'),
      const SizedBox(height: ZapSpacing.lg),

      // Summary strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _ecStat('6',    'Total cases',    const Color(0xFFEF4444)),
          _ecStat('2',    'HTTP 4xx',       const Color(0xFFF59E0B)),
          _ecStat('1',    'HTTP 409',       const Color(0xFF8B5CF6)),
          _ecStat('1',    'HTTP 410',       const Color(0xFF6B7280)),
          _ecStat('1',    'Client error',   const Color(0xFF3B82F6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 EDGE CASES  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kEdgeCases.asMap().entries.map((e) {
        final i    = e.key;
        final ec   = e.value;
        final isExp = expanded == i;
        final isSim = simulating == i;

        return Column(children: [
          GestureDetector(
            onTap: () => ref.read(_expandedEdgeCaseProvider.notifier).state =
                isExp ? null : i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                  color: isExp
                      ? ec.color.withOpacity(0.07)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExp
                          ? ec.color.withOpacity(0.4)
                          : const Color(0xFF2A2A2A),
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
                    Expanded(
                        child: Text(ec.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                    Icon(
                        isExp
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563),
                        size: 16),
                  ]),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isExp
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                          child: _EdgeCaseDetail(ec: ec, index: i,
                              isSim: isSim, ref: ref))
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Simulated UI state when active
          if (isSim) ...[
            _SimulatedState(ec: ec),
            const SizedBox(height: ZapSpacing.sm),
            GestureDetector(
              onTap: () =>
                  ref.read(_simulatingProvider.notifier).state = null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                child: const Center(
                    child: Text('Clear simulation',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 11))),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
          ],
        ]);
      }),

      const SizedBox(height: ZapSpacing.xl),

      // ── Block complete ─────────────────────────────────────────────
      _BlockCompleteCard(),
    ]);
  }

  Widget _ecStat(String v, String l, Color c) => Expanded(
        child: Column(children: [
          Text(v,
              style: TextStyle(
                  color: c, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(l,
              style:
                  const TextStyle(color: Color(0xFF6B7280), fontSize: 8),
              textAlign: TextAlign.center),
        ]));
}

class _EdgeCaseDetail extends StatelessWidget {
  final _EdgeCase ec;
  final int index;
  final bool isSim;
  final WidgetRef ref;
  const _EdgeCaseDetail(
      {required this.ec, required this.index,
       required this.isSim, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section('Trigger', ec.trigger, Icons.bolt_rounded, ec.color),
      const SizedBox(height: ZapSpacing.sm),
      _section('Detection', ec.detection, Icons.radar_rounded, const Color(0xFF3B82F6)),
      const SizedBox(height: ZapSpacing.sm),
      _section('UI Response', ec.uiResponse, Icons.phone_iphone_rounded, const Color(0xFF10B981)),
      const SizedBox(height: ZapSpacing.sm),
      // API error code
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('API Error',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: ZapSpacing.xs),
          Text(ec.apiError,
              style: const TextStyle(
                  color: Color(0xFF86EFAC),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  height: 1.5)),
        ]),
      ),
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
                color: isSim ? const Color(0xFF6B7280) : ec.color,
                size: 14),
            const SizedBox(width: 6),
            Text(isSim ? 'Hide simulation' : 'Simulate this error state',
                style: TextStyle(
                    color:
                        isSim ? const Color(0xFF6B7280) : ec.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 3),
              Text(body,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                      height: 1.5)),
            ]),
          ),
        ]),
      );
}

/// Shows a mock in-app UI snippet for the selected edge case.
class _SimulatedState extends StatelessWidget {
  final _EdgeCase ec;
  const _SimulatedState({required this.ec});

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
            Icon(ec.icon, color: ec.color, size: 12),
            const SizedBox(width: 6),
            Text('Simulated UI — ${ec.title}',
                style: TextStyle(
                    color: ec.color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: ec.color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border:
                    Border.all(color: ec.color.withOpacity(0.35))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ec.icon, color: ec.color, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ec.title,
                      style: TextStyle(
                          color: ec.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(ec.uiResponse,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          height: 1.5)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Block Complete Card ────────────────────────────────────────────────────────
class _BlockCompleteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Celebration
      Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.45), width: 2),
        ),
        child: const Column(children: [
          Text('📦', style: TextStyle(fontSize: 40)),
          SizedBox(height: ZapSpacing.md),
          Text('Data Export Block Complete',
              style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.xs),
          Text('DAYS 166 – 168 ✅',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900),
              textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.md),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _LegalChip('Request Form ✅',       Color(0xFF8B5CF6)),
              _LegalChip('History + Re-download ✅',Color(0xFF3B82F6)),
              _LegalChip('API Contract ✅',        Color(0xFFF59E0B)),
              _LegalChip('Download Pipeline ✅',   Color(0xFF3B82F6)),
              _LegalChip('SHA-256 Integrity ✅',   Color(0xFF10B981)),
              _LegalChip('File Browser ✅',        Color(0xFF8B5CF6)),
              _LegalChip('Rate-limit UI ✅',       Color(0xFFF59E0B)),
              _LegalChip('GDPR Art.20 6pts ✅',    Color(0xFF3B82F6)),
              _LegalChip('6 Edge Cases ✅',        Color(0xFFEF4444)),
            ],
          ),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // What's next
      const _SectionLabel('NEXT  ·  DAYS 169-172: ACCOUNT DELETION FLOW'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _nextRow(const Color(0xFFEF4444), 'Day 169',
              'Account deletion request screen — confirm identity, enter reason, '
              'submit deletion (30-day grace period starts)'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _nextRow(const Color(0xFFEF4444), 'Day 170',
              'Grace period UI — countdown timer, "cancel deletion" button, '
              'what gets deleted breakdown, emergency contact notification'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _nextRow(const Color(0xFFEF4444), 'Day 171',
              'Permanent deletion confirmation — re-auth gate, final warning, '
              'deletion in progress screen, account wiped state'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _nextRow(const Color(0xFFF59E0B), 'Day 172',
              'Deletion edge cases — partial delete, linked devices, active SOS, '
              'evidence hold, DPDP 30-day legal retention requirement'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(
          icon: Icons.construction_rounded,
          color: const Color(0xFFF59E0B),
          text: 'Days 169-172 Account Deletion is also 🟡 MOCK-NOW. '
              'Backend at Day 78 has no DELETE /api/v1/account endpoint. '
              'Build with mock + document the contract the same way as Days 166-168.'),
    ]);
  }

  Widget _nextRow(Color color, String day, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(day,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      );
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
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));
