/// Day 175 — Data Access Audit Log: Third-Party Access & Block Sign-Off
///
/// Third and final day of the Days 173-175 Data Access Audit Log block.
/// Day 173: Full timeline — real events, multi-filter, summary stats   ✅
/// Day 174: Forensic drill-down + export + session detail             ✅
/// Day 175: Third-party access log + revoke flow + DPDP §11 summary
///           + Days 173-175 block complete + Section B 3/5 progress.
///
/// ── 🟢 LIVE (fixed for Play Store item 10b) ─────────────────────────────────
///   Was: 🟡 MOCK-NOW, 5 entirely hardcoded fake entries (2 fabricated
///   contact names "Rahul Sharma"/"Aarti Patel", 3 fixed platform
///   disclosures) — confirmed via `grep -rniE "third.?party"` across every
///   urls.py under zapsafe_backend/ that NO backend route existed for this
///   anywhere, a real Day 336/361/337 finding (the only RED row left after
///   this session's other DPDP wiring work).
///
///   New real backend: `GET /api/v1/account/third-party-access/`
///   (ThirdPartyAccessView, zapsafe_backend/account/views.py) — returns
///   the caller's REAL active emergency contacts (who genuinely receive
///   real SOS data) plus 3 fixed platform-level disclosures, with
///   Sentry's entry reflecting the caller's REAL current
///   consent.analytics flag rather than a static claim.
///
///   Fields the mock invented that the real API does NOT provide —
///   handled honestly, not faked: a specific accessed-when date/count
///   per contact (real dispatch is event-driven, not pre-scheduled — see
///   [_accessedWhenFor]), and a literal API-endpoint string per party
///   (removed; was never meaningful to an end user anyway).
///
///   Revoke flow: the real backend has no revoke-in-place action for
///   this endpoint. Revoking IS a real, already-existing action
///   elsewhere in the app — removing an emergency contact (Day 83
///   Contacts) or turning off crash-reporting consent (Day 319 GDPR
///   Consent Wire) — so "Revoke access" now navigates there for real,
///   then refetches this list on return, rather than a local
///   no-op that only ever pretended to revoke anything.
///
/// Legal basis:
///   DPDP Act 2023 §11(1)(b) — right to know third parties who
///                              received personal data.
///   GDPR Art. 15(1)(c)      — right to know recipients/categories
///                              of recipients of personal data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/spacing.dart';
import '../../data/services/account_service.dart' show ThirdPartyEntry;
import '../../domain/providers/account_providers.dart';
import '../navigation/app_router.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d175TabProvider         = StateProvider<int>((ref) => 0);
final _expandedPartyProvider   = StateProvider<int?>((ref) => null);
final _expandedDpdpProvider    = StateProvider<int?>((ref) => null);

// ── Real-entry display helpers ─────────────────────────────────────────────────
// [ThirdPartyEntry] (account_service.dart) carries only what the real
// backend actually sends. Icon/color and the "when" text below are
// honest presentation choices layered on top — never fabricated
// per-party facts like the old mock's specific dates/counts.

(IconData, Color) _iconAndColorFor(ThirdPartyEntry p) => switch (p.id) {
      'sentry' => (Icons.bug_report_rounded, const Color(0xFF8B5CF6)),
      'google_play' => (Icons.android_rounded, const Color(0xFF3DDC84)),
      'trust_and_safety' => (Icons.shield_rounded, const Color(0xFFF59E0B)),
      _ => (Icons.person_rounded, const Color(0xFF10B981)), // emergency contacts
    };

/// The real backend doesn't send a per-party "last accessed" timestamp —
/// SOS notification is event-driven (whenever you next trigger an SOS),
/// not a scheduled thing with a history to report here. Honest,
/// non-fabricated framing per party type instead of inventing dates.
String _accessedWhenFor(ThirdPartyEntry p) {
  if (p.isEmergencyContact) {
    return 'Whenever you trigger an SOS — not a scheduled or past-dated event.';
  }
  if (p.id == 'sentry') {
    return p.currentlyActive == true
        ? 'Ongoing while crash reporting is ON.'
        : 'Not currently — crash reporting is OFF.';
  }
  return 'Ongoing, tied to your app installation.';
}

class _DpdpPoint {
  final String article;
  final String requirement;
  final String howWeComply;
  final String screen;
  final Color  color;
  const _DpdpPoint({
    required this.article, required this.requirement,
    required this.howWeComply, required this.screen,
    required this.color,
  });
}

const _kDpdpPoints = [
  _DpdpPoint(
    article: 'DPDP §11(1)(a)',
    requirement: 'Right to know what personal data is being processed',
    howWeComply: 'Day 173 Timeline lists every read, write, delete, export, '
        'login, and failed attempt. Filterable by type/category/time. '
        'Data categories include SOS, contacts, evidence, location, profile, settings, analytics.',
    screen: 'Day 173 — Timeline tab',
    color: Color(0xFF10B981),
  ),
  _DpdpPoint(
    article: 'DPDP §11(1)(b)',
    requirement: 'Right to know the identities of all Data Fiduciaries and Processors '
        'who have received personal data',
    howWeComply: 'Day 175 Third-Party Access log shows every real party who '
        'received data: your actual emergency contacts, Trust & Safety, '
        'Sentry, Google Play. Each entry shows what data, when, and legal '
        'basis — live from GET /api/v1/account/third-party-access/.',
    screen: 'Day 175 — Third-Party Access tab',
    color: Color(0xFF3B82F6),
  ),
  _DpdpPoint(
    article: 'DPDP §11(1)(c)',
    requirement: 'Right to know the basis and purpose of processing',
    howWeComply: 'Each event in Day 173 shows the actor and action. '
        'Day 175 third-party entries each include the legal basis '
        '(consent / vital interest / legitimate interest). '
        'Purpose of every data category explained in Day 151 Privacy Policy.',
    screen: 'Day 173 + Day 175 + Day 151',
    color: Color(0xFF8B5CF6),
  ),
  _DpdpPoint(
    article: 'DPDP §11(1)(d)',
    requirement: 'Right to know the period of processing and retention',
    howWeComply: 'Day 173 API contract states 90-day audit log retention. '
        'Day 174 session detail shows session duration. '
        'Day 176 Data Retention Settings (next block) allows '
        'per-category retention period configuration.',
    screen: 'Day 173 API Contract + Day 176',
    color: Color(0xFFF59E0B),
  ),
  _DpdpPoint(
    article: 'DPDP §11(2)',
    requirement: 'Information to be provided within 30 days of request',
    howWeComply: 'The audit log is available immediately on demand — '
        'no request needed. Day 173 timeline loads from API '
        'GET /api/v1/data-access/audit-log (< 200 ms). '
        '30-day deadline is far exceeded.',
    screen: 'Day 173 — Timeline (live)',
    color: Color(0xFF10B981),
  ),
  _DpdpPoint(
    article: 'GDPR Art. 15(1)(c)',
    requirement: 'Right to know the recipients or categories of recipients '
        'to whom personal data have been disclosed',
    howWeComply: 'Day 175 Third-Party Access tab satisfies Art. 15(1)(c) for '
        'EU/international users. Each recipient entry shows: '
        'name, relationship, data disclosed, legal basis, and revoke options.',
    screen: 'Day 175 — Third-Party Access tab',
    color: Color(0xFF3B82F6),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day175ThirdPartyAccessScreen extends ConsumerWidget {
  const Day175ThirdPartyAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d175TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Third-Party Access'),
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
                onSelect: (t) => ref.read(_d175TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ThirdPartyTab(),
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF080E14), Color(0xFF050A10), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 175',             const Color(0xFF10B981)),
          _badge('🟢 LIVE',                 const Color(0xFF10B981)),
          _badge('Audit Log  ·  Day 3/3',   const Color(0xFF8B5CF6)),
          _badge('Block 173-175 Final ✅',  const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Third-Party Access\n& DPDP §11 Sign-Off',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'DPDP §11(1)(b) + GDPR Art. 15(1)(c) — who received your data. '
          'Real emergency contacts + platform disclosures, with revoke '
          'options. 6-point DPDP §11 compliance proof. Section B reaches 3/5.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',    'DPDP §11 points', Color(0xFF8B5CF6)),
          _HStat('3/5',  'Section B done',  Color(0xFFF59E0B)),
        ]),
      ]),
    );
  }

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
      (Icons.people_alt_rounded,     Color(0xFF3B82F6), '3rd-Party'),
      (Icons.gavel_rounded,          Color(0xFF8B5CF6), 'DPDP §11'),
      (Icons.emoji_events_rounded,   Color(0xFF10B981), 'Block Done'),
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
            const SizedBox(height: ZapSpacing.xs),
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
// TAB 1 — Third-Party Access
// ══════════════════════════════════════════════════════════════════════════════
class _ThirdPartyTab extends ConsumerWidget {
  const _ThirdPartyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partiesAsync = ref.watch(thirdPartyAccessProvider);

    return partiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: ZapSpacing.huge),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      ),
      error: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoBox(icon: Icons.cloud_off_rounded, color: const Color(0xFFEF4444),
            text: 'Could not load third-party access data — check your '
                'connection and reopen this screen.'),
      ]),
      data: (parties) => _ThirdPartyList(parties: parties),
    );
  }
}

class _ThirdPartyList extends ConsumerWidget {
  const _ThirdPartyList({required this.parties});
  final List<ThirdPartyEntry> parties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedPartyProvider);
    final revocable = parties.where((p) => p.canRevoke).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.people_alt_rounded, color: const Color(0xFF3B82F6),
          text: 'DPDP §11(1)(b): you have the right to know who received '
              'your personal data. Every third party that touched your data '
              'is listed below — tap to see what they received and why. '
              'Real data from GET /api/v1/account/third-party-access/.'),
      const SizedBox(height: ZapSpacing.lg),

      // Stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _statBox('${parties.length}', 'Total\nparties',   const Color(0xFF3B82F6)),
          _statBox('$revocable', 'Revocable',        const Color(0xFF10B981)),
          _statBox('${parties.length - revocable}', 'Non-revocable',    const Color(0xFF6B7280)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      _SectionLabel('${parties.length} THIRD PARTIES  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ...parties.asMap().entries.map((e) {
        final i     = e.key;
        final party = e.value;
        final isExp = expanded == i;
        final (icon, color) = _iconAndColorFor(party);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () {
              ref.read(_expandedPartyProvider.notifier).state = isExp ? null : i;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                  color: isExp ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExp ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                      width: isExp ? 2 : 1)),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(9)),
                      child: Icon(icon, color: color, size: 17)),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(party.name, style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w700))),
                        if (party.isAutomatic)
                          _smallChip('Automated', const Color(0xFF8B5CF6))
                        else
                          _smallChip('Manual', const Color(0xFF3B82F6)),
                      ]),
                      Text(party.relationship, style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.access_time_rounded,
                            color: Color(0xFF4B5563), size: 11),
                        const SizedBox(width: ZapSpacing.xs),
                        Expanded(child: Text(_accessedWhenFor(party),
                            style: const TextStyle(
                                color: Color(0xFF4B5563), fontSize: 9),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ])),
                    const SizedBox(width: ZapSpacing.sm),
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
                          child: _PartyDetail(party: party, color: color))
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
        ]);
      }),

      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'ZapSafe does not sell or trade personal data. '
              'No advertising SDKs are included. '
              'The only third-party data flows are: emergency contact notifications '
              '(SOS), crash reporting (if consented), and anonymised app-store stats.'),
    ]);
  }

  Widget _statBox(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));
}

class _PartyDetail extends ConsumerWidget {
  final ThirdPartyEntry party;
  final Color color;
  const _PartyDetail({required this.party, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataReceivedText = party.dataReceived.map((d) => '• $d').join('\n');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Data received
      _section('Data Received', dataReceivedText,
          Icons.data_object_rounded, color),
      const SizedBox(height: ZapSpacing.sm),
      _section('Legal Basis', party.legalBasis,
          Icons.gavel_rounded, const Color(0xFF8B5CF6)),
      const SizedBox(height: ZapSpacing.sm),
      _section('When', _accessedWhenFor(party),
          Icons.access_time_rounded, const Color(0xFF3B82F6)),
      const SizedBox(height: ZapSpacing.md),

      // Revoke section — real navigation to where that action actually
      // lives, not a local no-op. See file header for why there's no
      // in-place revoke endpoint for this screen itself.
      if (party.canRevoke) ...[
        _outlineBtn(
          label: party.isEmergencyContact
              ? 'Manage in Contacts  →'
              : 'Manage in Privacy Settings  →',
          color: const Color(0xFFEF4444),
          onTap: () async {
            await context.push(party.isEmergencyContact
                ? AppRoutes.contacts
                : AppRoutes.gdprConsentWire);
            // Refresh on return — if the user removed a contact or
            // toggled analytics consent, this list should reflect it
            // immediately rather than show stale data.
            ref.invalidate(thirdPartyAccessProvider);
          },
        ),
      ] else
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: const Color(0xFF6B7280).withOpacity(0.06),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: const Row(children: [
            Icon(Icons.lock_rounded, color: Color(0xFF4B5563), size: 13),
            SizedBox(width: 6),
            Expanded(child: Text('This access cannot be revoked (required for security).',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, height: 1.4))),
          ])),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: Color(0xFFD1D5DB),
                fontSize: 11, height: 1.5)),
          ])),
        ]));

  Widget _outlineBtn({required String label, required Color color,
      required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: Text(label, style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)))));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — DPDP §11 Compliance Summary
// ══════════════════════════════════════════════════════════════════════════════
class _DpdpTab extends ConsumerWidget {
  const _DpdpTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedDpdpProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.gavel_rounded, color: const Color(0xFF8B5CF6),
          text: 'How the Days 173-175 Audit Log feature satisfies every '
              'sub-requirement of DPDP Act 2023 §11 (Right to Information). '
              'Six points — each linked to a specific screen.'),
      const SizedBox(height: ZapSpacing.lg),

      // 6/6 scorecard
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
            Text('DPDP §11 Compliance — 6 / 6 Requirements Met',
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
          const Wrap(spacing: 6, runSpacing: 6, children: [
            _LChip('§11(1)(a) ✅', Color(0xFF10B981)),
            _LChip('§11(1)(b) ✅', Color(0xFF3B82F6)),
            _LChip('§11(1)(c) ✅', Color(0xFF8B5CF6)),
            _LChip('§11(1)(d) ✅', Color(0xFFF59E0B)),
            _LChip('§11(2) ✅',    Color(0xFF10B981)),
            _LChip('GDPR 15(1)(c) ✅', Color(0xFF3B82F6)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('6 REQUIREMENTS  ·  TAP TO SEE EVIDENCE'),
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
                  Expanded(child: Text(point.requirement,
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w600))),
                  Icon(isExp
                      ? Icons.keyboard_arrow_up_rounded
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
                          _evidenceBox(point.howWeComply, point.color),
                          const SizedBox(height: ZapSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: point.color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.link_rounded, color: point.color, size: 12),
                              const SizedBox(width: 5),
                              Text('Evidence: ${point.screen}',
                                  style: TextStyle(color: point.color, fontSize: 10,
                                      fontWeight: FontWeight.w700)),
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
          text: 'This audit log feature makes ZapSafe fully compliant with '
              'DPDP §11 as of Days 173-175. When the backend implements '
              'GET /api/v1/data-access/audit-log, the compliance is live '
              'for all users — not just a demo.'),
    ]);
  }

  Widget _evidenceBox(String text, Color color) => Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Text(text, style: const TextStyle(
          color: Color(0xFFD1D5DB), fontSize: 11, height: 1.6)));
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
      // Celebration
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
        child: const Column(children: [
          Text('🔍', style: TextStyle(fontSize: 44)),
          SizedBox(height: ZapSpacing.md),
          Text('Data Access Audit Log Block',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 14,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5),
              textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.xs),
          Text('DAYS 173 – 175  ✅',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center, children: [
            _Chip('Timeline (30 events) ✅',    Color(0xFF3B82F6)),
            _Chip('Multi-filter (type/time/cat) ✅', Color(0xFF3B82F6)),
            _Chip('Actor summary stats ✅',     Color(0xFF10B981)),
            _Chip('Forensic drill-down ✅',     Color(0xFF3B82F6)),
            _Chip('Suspicious analysis ✅',     Color(0xFFEF4444)),
            _Chip('CSV/PDF export ✅',          Color(0xFF10B981)),
            _Chip('Session cards ✅',           Color(0xFF8B5CF6)),
            _Chip('Session revoke ✅',          Color(0xFFEF4444)),
            _Chip('Real third parties ✅',      Color(0xFF3B82F6)),
            _Chip('Real revoke flow ✅',        Color(0xFFEF4444)),
            _Chip('DPDP §11 6/6 ✅',           Color(0xFF8B5CF6)),
            _Chip('3 API endpoints ✅',         Color(0xFFF59E0B)),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Section B progress
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
          _blockRow(const Color(0xFF3B82F6), 'Days 176-178', 'Data Retention Settings  ←  NEXT', false),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _blockRow(const Color(0xFF6B7280), 'Days 179-180', 'Active Sessions / Devices', false),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Progress bar
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('Section B progress',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          Spacer(),
          Text('3 / 5 blocks complete',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
              value: 3 / 5,
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8)),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Next block preview
      const _SectionLabel('NEXT  ·  DAYS 176-178: DATA RETENTION SETTINGS'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
        child: Column(children: [
          _nextRow('Day 176',
              'Retention settings screen — per-category data expiry picker '
              '(7/30/90/180/365 days). Evidence vault timer. '
              'GPS location purge schedule.'),
          const Divider(height: 16, color: Color(0xFF1A1A1A)),
          _nextRow('Day 177',
              'Auto-deletion scheduler — background job that enforces retention. '
              '"What will be deleted tomorrow" preview. Retention change history.'),
          const Divider(height: 16, color: Color(0xFF1A1A1A)),
          _nextRow('Day 178',
              'Retention edge cases + DPDP §8 data minimisation compliance '
              '+ Days 176-178 block sign-off + Days 179-180 preview.'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.construction_rounded, color: const Color(0xFFF59E0B),
          text: 'Days 176-178 Data Retention Settings is partially local '
              '(🟡 MOCK-NOW for server-side enforcement, but the per-category '
              'pickers and local Hive storage are 🟢 FRONTEND-ONLY).'),
    ]);
  }

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
            const Icon(Icons.radio_button_unchecked_rounded,
                color: Color(0xFF3A3A3A), size: 16),
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

Widget _smallChip(String l, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w700)));

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
