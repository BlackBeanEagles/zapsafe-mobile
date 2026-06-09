/// Day 195 — Privacy Policy, Content Rating & Store Compliance
///
/// First day of the Days 195-196 Privacy & Compliance block.
/// Day 195: Privacy policy URL setup, IARC content rating
///           questionnaire (ZapSafe answers), DPDP/GDPR checklist
///           for store submission.
/// Day 196: App Store privacy nutrition label cross-check,
///           Play Data Safety form review, block sign-off.
///
/// 🟢 FRONTEND-ONLY — store compliance documentation and planning.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d195TabProvider        = StateProvider<int>((ref) => 0);
final _checkedStoreProvider   = StateProvider<Set<String>>((ref) => {});
final _expandedIarcProvider   = StateProvider<int?>((ref) => null);
final _expandedPpProvider     = StateProvider<int?>((ref) => null);

// ── Privacy policy sections ───────────────────────────────────────────────────
class _PolicySection {
  final String title, required_, notes;
  final bool   alreadyCovered;  // covered in Day 151 privacy policy screen
  const _PolicySection({
    required this.title, required this.required_,
    required this.notes, required this.alreadyCovered,
  });
}

const _kPolicySections = [
  _PolicySection(
    title: 'What data is collected',
    required_: 'Both stores — mandatory',
    notes: 'Covered in Day 151 Section 1 (What We Collect). '
        'Phone number, location, audio, device ID, contacts.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'Why data is collected (purpose)',
    required_: 'Both stores — mandatory',
    notes: 'Day 151 Section 2 (Why We Collect). '
        'Emergency dispatch, evidence capture, account authentication.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'Who data is shared with',
    required_: 'Both stores — mandatory',
    notes: 'Day 151 Section 3 (Who We Share With). '
        'Emergency contacts, Sentry (crash), Google Play.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'Data retention period',
    required_: 'Both stores — mandatory',
    notes: 'Day 151 Section 5 (Retention). '
        'Day 176-178 retention settings. GPS 14 days, evidence 90 days.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'User rights (access, deletion, portability)',
    required_: 'Both stores — mandatory for GDPR/DPDP countries',
    notes: 'Day 151 Section 5 (Your Rights). '
        'Links to Days 166-172 export/deletion flows.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'Security measures',
    required_: 'Recommended by both stores',
    notes: 'Day 151 Section 6 (Security). '
        'AES-256, cert pinning, biometric gate. '
        'Day 181-188 Section C backs this up.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'Contact information',
    required_: 'Both stores — mandatory',
    notes: 'privacy@zapsafe.app. '
        'Must be reachable — App Review emails the privacy contact.',
    alreadyCovered: true,
  ),
  _PolicySection(
    title: 'DPDP Act 2023 §7 consent mechanism',
    required_: 'India — DPDP-specific',
    notes: 'Day 161 Consent Gate satisfies §7. '
        'Must reference consent gate in privacy policy.',
    alreadyCovered: true,
  ),
];

// ── IARC questionnaire ────────────────────────────────────────────────────────
class _IarcQuestion {
  final String category, question, answer, impact;
  const _IarcQuestion({
    required this.category, required this.question,
    required this.answer, required this.impact,
  });
}

const _kIarcQuestions = [
  _IarcQuestion(
    category: 'Violence',
    question: 'Does the app contain depictions of realistic violence?',
    answer: 'NO — ZapSafe has no violent imagery or animations.',
    impact: 'No violence rating.',
  ),
  _IarcQuestion(
    category: 'Scary Content',
    question: 'Does the app contain content that may be frightening?',
    answer: 'MILD — The SOS alert screen could be alarming to young children. '
        'Red visual design during active SOS.',
    impact: 'Minor suitability concern for very young children (under 7).',
  ),
  _IarcQuestion(
    category: 'Sexual Content',
    question: 'Does the app contain sexual content?',
    answer: 'NO — No sexual content of any kind.',
    impact: 'No restriction.',
  ),
  _IarcQuestion(
    category: 'Language',
    question: 'Does the app contain profanity or crude language?',
    answer: 'NO — All text is professional and safety-focused.',
    impact: 'No restriction.',
  ),
  _IarcQuestion(
    category: 'Location Sharing',
    question: 'Does the app share the user\'s location with others?',
    answer: 'YES — GPS location is shared with emergency contacts during SOS. '
        'This is the core safety feature, done with explicit user consent.',
    impact: 'Triggers "Location Sharing" disclosure in IARC. '
        'This is expected and correct for a safety app.',
  ),
  _IarcQuestion(
    category: 'Microphone / Audio',
    question: 'Does the app use the microphone?',
    answer: 'YES — Audio recording starts automatically during SOS for evidence. '
        'User is informed at onboarding and consent gate.',
    impact: 'Triggers "Audio Recording" disclosure. '
        'Correct — Day 158 permissions screen covers this.',
  ),
  _IarcQuestion(
    category: 'Contacts',
    question: 'Does the app access the device\'s contacts list?',
    answer: 'NO — ZapSafe does NOT read the device contacts list. '
        'Users manually enter emergency contacts within the app.',
    impact: 'No contacts permission disclosure needed.',
  ),
  _IarcQuestion(
    category: 'In-App Purchases',
    question: 'Does the app offer in-app purchases?',
    answer: 'YES — ZapSafe Premium subscription available. '
        'Disclosed in Day 91-93 subscription screens.',
    impact: 'IAP disclosure required. Play Store badge appears on listing.',
  ),
];

// ── DPDP/GDPR store checklist ─────────────────────────────────────────────────
class _ComplianceItem {
  final String id, store, requirement, evidence;
  final bool critical;
  const _ComplianceItem({
    required this.id, required this.store, required this.requirement,
    required this.evidence, this.critical = false,
  });
}

const _kComplianceItems = [
  _ComplianceItem(
    id: 'c1', store: 'Play Store',
    requirement: 'Privacy Policy URL submitted',
    evidence: 'App Content → Privacy Policy → https://zapsafe.app/privacy',
    critical: true),
  _ComplianceItem(
    id: 'c2', store: 'Play Store',
    requirement: 'Data Safety form completed',
    evidence: 'Day 164 Data Safety screen has all answers. '
        'Play Console → Policy → App Content → Data Safety.',
    critical: true),
  _ComplianceItem(
    id: 'c3', store: 'Play Store',
    requirement: 'Data Safety matches Privacy Policy',
    evidence: 'Day 164 Tab 3 "all must match" table verified. '
        'Location / Audio / Contacts / Device IDs / Crash logs.',
    critical: true),
  _ComplianceItem(
    id: 'c4', store: 'Play Store',
    requirement: 'IARC content rating completed',
    evidence: 'App Content → Content Rating → complete questionnaire. '
        'ZapSafe expected rating: Teen (13+) due to location sharing.',
    critical: true),
  _ComplianceItem(
    id: 'c5', store: 'Play Store',
    requirement: 'Sensitive permissions declared (location, microphone)',
    evidence: 'Permissions declared in Data Safety. '
        'Day 158 App Permissions screen documents all 8 permissions.',
    critical: false),
  _ComplianceItem(
    id: 'c6', store: 'Play Store',
    requirement: 'Target audience confirmed (not for children)',
    evidence: 'App Content → Target Audience → "18+" selected. '
        'Day 153 ToS §1: users under 13 not permitted.',
    critical: false),
  _ComplianceItem(
    id: 'a1', store: 'App Store',
    requirement: 'Privacy Policy URL submitted',
    evidence: 'App Information → Privacy Policy URL → https://zapsafe.app/privacy',
    critical: true),
  _ComplianceItem(
    id: 'a2', store: 'App Store',
    requirement: 'Privacy Nutrition Label completed',
    evidence: 'Day 164 Apple Privacy Label: Location (linked to you), '
        'Crash Data (not linked), Usage Data (not linked). '
        'App Privacy tab in App Store Connect.',
    critical: true),
  _ComplianceItem(
    id: 'a3', store: 'App Store',
    requirement: 'NSPrivacyAccessedAPITypes in PrivacyInfo.xcprivacy',
    evidence: 'Required for Apps using UserDefaults, file timestamps. '
        'Add PrivacyInfo.xcprivacy to ios/Runner/ with API reason codes.',
    critical: true),
  _ComplianceItem(
    id: 'a4', store: 'App Store',
    requirement: 'Age rating set appropriately',
    evidence: 'App Information → Age Rating → 12+ (infrequent/mild scary, '
        'location sharing). Day 152 policy has no adult content.',
    critical: false),
  _ComplianceItem(
    id: 'a5', store: 'App Store',
    requirement: 'NSFaceIDUsageDescription in Info.plist',
    evidence: 'Day 183 biometric lock — already added in Day 183 implementation. '
        'Required for Face ID — App Review rejects without it.',
    critical: true),
  _ComplianceItem(
    id: 'a6', store: 'App Store',
    requirement: 'NSMicrophoneUsageDescription in Info.plist',
    evidence: 'Required for audio recording. '
        'Value: "ZapSafe records audio during SOS events for evidence."',
    critical: false),
  _ComplianceItem(
    id: 'a7', store: 'App Store',
    requirement: 'NSLocationAlwaysAndWhenInUseUsageDescription',
    evidence: 'Required for background location (SOS tracking). '
        'Day 158 permissions screen has the rationale copy.',
    critical: false),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day195PrivacyComplianceScreen extends ConsumerWidget {
  const Day195PrivacyComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d195TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Privacy, Rating & Compliance'),
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
            child: const Text('🟢 SECTION D',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                    fontWeight: FontWeight.w800)),
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
                onSelect: (t) => ref.read(_d195TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _PrivacyPolicyTab(),
            if (tab == 1) const _IarcTab(),
            if (tab == 2) const _ComplianceTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF080E0C), Color(0xFF050A08), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 195',              const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section D  ·  Day 5/10',   const Color(0xFF3B82F6)),
          _badge('Compliance  ·  Day 1/2',   const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Privacy Policy,\nContent Rating & Compliance',
            style: TextStyle(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Privacy policy URL hosting checklist. '
          'IARC content rating — 8 questionnaire answers for ZapSafe. '
          '13-item DPDP/GDPR store compliance checklist.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('8',  '8 policy sections', Color(0xFF10B981)),
          _HStat('8',  '8 IARC answers',    Color(0xFF3B82F6)),
          _HStat('13', '13 compliance items',Color(0xFF8B5CF6)),
          _HStat('5',  '5 critical',        Color(0xFFEF4444)),
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
      (Icons.policy_rounded,     Color(0xFF10B981), 'Privacy Policy'),
      (Icons.child_care_rounded, Color(0xFF3B82F6), 'Content Rating'),
      (Icons.checklist_rounded,  Color(0xFF8B5CF6), 'Compliance'),
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
// TAB 1 — Privacy Policy
// ══════════════════════════════════════════════════════════════════════════════
class _PrivacyPolicyTab extends ConsumerWidget {
  const _PrivacyPolicyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedPpProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.policy_rounded, color: const Color(0xFF10B981),
          text: 'Both stores require a privacy policy URL before submission. '
              'ZapSafe\'s policy was built across Days 151-165 (Section A). '
              'This tab verifies the policy meets store requirements '
              'and documents where to host it.'),
      const SizedBox(height: ZapSpacing.lg),

      // Policy URL card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.link_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('Privacy Policy URL', style: TextStyle(
                color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text('https://zapsafe.app/privacy',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          const SizedBox(height: ZapSpacing.sm),
          ...[
            ('Hosted at', 'https://zapsafe.app/privacy'),
            ('Format',    'HTML page — accessible on all devices'),
            ('Language',  'English + Hindi (hi_IN equivalent)'),
            ('Last updated', 'June 17, 2026 (v2.0)'),
            ('HTTPS',     'Yes — required by both stores'),
            ('No login required', 'Yes — publicly accessible'),
          ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                SizedBox(width: 120, child: Text(t.$1, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 10))),
                Expanded(child: Text(t.$2, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 10))),
              ]))),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Hosting options
      const _SectionLabel('HOSTING OPTIONS'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...[
            (Icons.public_rounded, const Color(0xFF10B981),
                'Own website (recommended)',
                'https://zapsafe.app/privacy — branded, professional. '
                'Host as a static HTML file on GitHub Pages, Vercel, or Netlify.'),
            (Icons.description_rounded, const Color(0xFF3B82F6),
                'Google Docs (quick)',
                'Publish as public web page. URL format: docs.google.com/document/… '
                'Some stores prefer this for solo builders.'),
            (Icons.hub_rounded, const Color(0xFF8B5CF6),
                'App Privacy Tools (privacy.app etc.)',
                'Auto-generated privacy policy from questionnaire. '
                'Fast but less customised — less suited for DPDP compliance.'),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (icon, color, title, detail) = e.value;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: color, size: 15),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(detail, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
                  ])),
                ])),
              if (i < 2) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ])),
      const SizedBox(height: ZapSpacing.xl),

      // Policy sections checklist
      const _SectionLabel('8 REQUIRED SECTIONS  ·  ALL COVERED IN DAY 151'),
      const SizedBox(height: ZapSpacing.md),
      ..._kPolicySections.asMap().entries.map((e) {
        final i    = e.key;
        final sec  = e.value;
        final isExp= expanded == i;

        return GestureDetector(
          onTap: () => ref.read(_expandedPpProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? const Color(0xFF10B981).withOpacity(0.06) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(sec.title, style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Day 151',
                        style: TextStyle(color: Color(0xFF3B82F6), fontSize: 8,
                            fontWeight: FontWeight.w700))),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _row('Required', sec.required_, const Color(0xFFEF4444)),
                          const SizedBox(height: 4),
                          _row('Evidence', sec.notes, const Color(0xFF10B981)),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ));
      }),
    ]);
  }

  Widget _row(String k, String v, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 60, child: Text(k, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4))),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — IARC Content Rating
// ══════════════════════════════════════════════════════════════════════════════
class _IarcTab extends ConsumerWidget {
  const _IarcTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedIarcProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.child_care_rounded, color: const Color(0xFF3B82F6),
          text: 'IARC (International Age Rating Coalition) provides content ratings '
              'for both Google Play and App Store. '
              'Complete the questionnaire once — ratings are generated for all regions '
              '(USK, PEGI, ESRB, CERO, ClassInd, etc.).'),
      const SizedBox(height: ZapSpacing.lg),

      // Expected rating result
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4))),
        child: Column(children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF3B82F6), size: 20),
            SizedBox(width: ZapSpacing.sm),
            Text('Expected IARC Rating Result',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.lg),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _ratingBadge('PEGI', '12', const Color(0xFF3B82F6)),
            _ratingBadge('USK',  '12', const Color(0xFF10B981)),
            _ratingBadge('ESRB', 'E10+', const Color(0xFFF59E0B)),
            _ratingBadge('CERO', 'B', const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Ratings driven by: Location sharing with contacts, '
            'audio recording feature, in-app purchases. '
            'No violent, sexual, or disturbing content.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5),
            textAlign: TextAlign.center),
        ])),
      const SizedBox(height: ZapSpacing.xl),

      // Questionnaire
      const _SectionLabel('8 QUESTIONNAIRE ANSWERS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kIarcQuestions.asMap().entries.map((e) {
        final i   = e.key;
        final q   = e.value;
        final isExp = expanded == i;
        // Determine if answer is YES (flagged) or NO (clean)
        final isFlagged = q.answer.startsWith('YES') || q.answer.startsWith('MILD');
        final color = isFlagged ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

        return GestureDetector(
          onTap: () => ref.read(_expandedIarcProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(q.category, style: const TextStyle(
                        color: Color(0xFF3B82F6), fontSize: 8, fontWeight: FontWeight.w700))),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(q.question, style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isFlagged ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: color, size: 14),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ])),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                border: Border.all(color: color.withOpacity(0.25))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Text('Answer: ', style: TextStyle(
                                    color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 3),
                              Text(q.answer, style: const TextStyle(
                                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
                              const SizedBox(height: ZapSpacing.sm),
                              Row(children: [
                                const Text('Rating impact: ', style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 3),
                              Text(q.impact, style: const TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4)),
                            ])),
                        ]))
                    : const SizedBox.shrink(),
              ),
            ]),
          ));
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'IARC access:\n'
              '• Play Console: App Content → Content Rating → Start Questionnaire\n'
              '• App Store Connect: App Information → Content Rights → Content Rating\n'
              'Both use the same IARC system. Complete once on Play Console '
              'then use the certificate code in App Store Connect.'),
    ]);
  }

  Widget _ratingBadge(String system, String rating, Color color) => Column(children: [
    Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 2)),
      child: Center(child: Text(rating, style: TextStyle(
          color: color, fontSize: 14, fontWeight: FontWeight.w900)))),
    const SizedBox(height: 4),
    Text(system, style: TextStyle(color: color.withOpacity(0.8),
        fontSize: 9, fontWeight: FontWeight.w700)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Store Compliance Checklist
// ══════════════════════════════════════════════════════════════════════════════
class _ComplianceTab extends ConsumerWidget {
  const _ComplianceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked   = ref.watch(_checkedStoreProvider);
    final total     = _kComplianceItems.length;
    final done      = checked.length;
    final critCount = _kComplianceItems.where((c) => c.critical).length;
    final critDone  = _kComplianceItems.where(
        (c) => c.critical && checked.contains(c.id)).length;

    final categories = ['Play Store', 'App Store'];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.checklist_rounded, color: const Color(0xFF8B5CF6),
          text: '13 compliance items across Play Store and App Store. '
              '5 are critical — missing these causes rejection or policy violation. '
              'Tap to mark complete.'),
      const SizedBox(height: ZapSpacing.lg),

      // Progress
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            _pStat('$done/$total', 'Items done', const Color(0xFF8B5CF6)),
            _pStat('$critDone/$critCount', 'Critical', const Color(0xFFEF4444)),
            _pStat('${total - done}', 'Remaining', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                      done == total ? const Color(0xFF10B981) : const Color(0xFF8B5CF6)),
                  minHeight: 6)),
          if (done == total) ...[
            const SizedBox(height: ZapSpacing.sm),
            const Text('All compliance checks complete — ready for submission ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ],
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // By store
      ...categories.map((cat) {
        final catItems = _kComplianceItems.where((c) => c.store == cat).toList();
        final catColor = cat.contains('Play')
            ? const Color(0xFF3DDC84) : const Color(0xFF9CA3AF);
        final catIcon  = cat.contains('Play')
            ? Icons.android_rounded : Icons.apple_rounded;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(catIcon, color: catColor, size: 14),
            const SizedBox(width: 6),
            Text(cat, style: TextStyle(color: catColor, fontSize: 11,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: ZapSpacing.sm),
            Text('(${catItems.where((c) => checked.contains(c.id)).length}/${catItems.length})',
                style: TextStyle(color: catColor.withOpacity(0.7), fontSize: 9)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: Column(children: catItems.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              final isD  = checked.contains(item.id);
              return Column(children: [
                GestureDetector(
                  onTap: () {
                    final updated = Set<String>.from(checked);
                    if (isD) updated.remove(item.id); else updated.add(item.id);
                    ref.read(_checkedStoreProvider.notifier).state = updated;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                            color: isD ? const Color(0xFF10B981) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: isD ? const Color(0xFF10B981) : const Color(0xFF3A3A3A),
                                width: 2)),
                        child: isD
                            ? const Icon(Icons.check, color: Colors.white, size: 13)
                            : null),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(item.requirement,
                              style: TextStyle(
                                  color: isD ? const Color(0xFF6B7280) : Colors.white,
                                  fontSize: 11,
                                  decoration: isD ? TextDecoration.lineThrough : null))),
                          if (item.critical && !isD)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('CRITICAL',
                                  style: TextStyle(color: Color(0xFFEF4444),
                                      fontSize: 7, fontWeight: FontWeight.w800))),
                        ]),
                        Text(item.evidence, style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
                      ])),
                    ])),
                ),
                if (i < catItems.length - 1)
                  const Divider(height: 1, color: Color(0xFF1E1E1E)),
              ]);
            }).toList()),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ]);
      }),

      if (checked.isNotEmpty)
        GestureDetector(
          onTap: () => ref.read(_checkedStoreProvider.notifier).state = {},
          child: const Text('Clear all', style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 11,
              decoration: TextDecoration.underline))),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF3B82F6),
          text: 'Day 196 cross-checks the App Store Privacy Nutrition Label '
              '(Day 164) against the Data Safety form (Day 164) '
              'to ensure they are perfectly aligned, then signs off '
              'the Days 195-196 block.'),
    ]);
  }

  Widget _pStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
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
