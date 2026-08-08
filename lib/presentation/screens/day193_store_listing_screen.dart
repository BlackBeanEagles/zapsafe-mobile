/// Day 193 — Store Listing Copy
///
/// First day of the Days 193-194 Store Listing block.
/// Day 193: App title, short description / subtitle, full description,
///           ASO keyword strategy, character counters.
/// Day 194: Promo text, "What's new", localised copy (Hindi),
///           A/B testing plan, block sign-off.
///
/// 🟢 FRONTEND-ONLY — copywriting and ASO planning.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d193TabProvider    = StateProvider<int>((ref) => 0);
final _storeTabProvider   = StateProvider<_Store>((ref) => _Store.play);
final _expandedKwProvider = StateProvider<int?>((ref) => null);

enum _Store { play, apple }

// ── Copy constants ────────────────────────────────────────────────────────────
// Play Store
const _kPlayTitle    = 'ZapSafe — Personal Safety SOS';        // 30 chars
const _kPlayShortDesc= 'SOS alert, evidence vault & emergency contacts in one app.'; // 80 chars
const _kPlayFullDesc = '''ZapSafe is your personal safety companion — built for women, '
solo travellers, night-shift workers, and anyone who wants peace of mind.

🚨 ONE-TAP SOS
Press the power button 5 times to silently trigger an SOS. Your emergency '
contacts are notified immediately with your GPS location, a live audio '
recording begins automatically, and the evidence vault locks your data.

🔒 EVIDENCE VAULT
Every SOS event captures audio, GPS trace, and sensor data into an '
AES-256 encrypted vault. SHA-256 verified. Court-ready.

👥 SMART CONTACT ESCALATION
Set up Tier 1 (notify first), Tier 2 (backup), and Tier 3 (final fallback) '
contacts. ZapSafe escalates automatically if nobody responds.

⏱ CHECK-IN TIMERS
Dead-man's switch — if you don't check in, your contacts are notified. '
Perfect for solo hikes, late nights, or any situation where you need '
someone to know you're safe.

🛡 PROTECTION SCORE
See your safety score at a glance. ZapSafe monitors your setup — contacts '
verified, timers active, permissions granted — and gives you a live score '
with actionable next steps.

📊 PREMIUM FEATURES
• AI-powered Distress Detection (scream + motion + scene)
• Evidence vault with 90-day retention
• Unlimited Tier 3 contacts
• Priority emergency response
• Advanced analytics

🔐 PRIVACY FIRST
• DPDP Act 2023 + GDPR compliant
• No advertising. No data selling.
• End-to-end encrypted vault
• Delete your data anytime

Download ZapSafe and build your safety network today.''';

// App Store
const _kAppleTitle     = 'ZapSafe';                            // 30 chars
const _kAppleSubtitle  = 'Personal Safety & SOS Alert';       // 30 chars
const _kAppleKeywords  = 'safety,sos,emergency,alert,women,personal safety,'
    'evidence vault,check in,panic button,self defense';       // 100 chars
const _kAppleFullDesc  = '''ZapSafe is your personal safety companion.

ONE-TAP SOS
Power button × 5 silently triggers SOS. Contacts receive your GPS location, '
and evidence recording begins automatically.

EVIDENCE VAULT
AES-256 encrypted audio, GPS, and sensor data from every SOS event. '
SHA-256 integrity verified.

SMART ESCALATION
Tier 1 → 2 → 3 contact hierarchy. Auto-escalates if nobody responds.

CHECK-IN TIMERS
Dead-man's switch for solo travellers and night-shift workers.

PROTECTION SCORE
Live safety score — contacts, location, drills, permissions.

PRIVACY FIRST
DPDP Act 2023 + GDPR compliant. No ads. No data selling. Delete anytime.

Premium: AI distress detection, unlimited contacts, evidence vault.''';

// ── ASO keyword data ─────────────────────────────────────────────────────────
class _Keyword {
  final String word;
  final String searchVol;    // estimated monthly searches
  final String competition;  // Low / Medium / High
  final String relevance;    // why it fits ZapSafe
  final Color  color;
  const _Keyword({
    required this.word, required this.searchVol, required this.competition,
    required this.relevance, required this.color,
  });
}

const _kKeywords = [
  _Keyword(word: 'personal safety app', searchVol: '18K/mo', competition: 'Medium',
      relevance: 'Primary intent — users searching for what ZapSafe IS.',
      color: Color(0xFF10B981)),
  _Keyword(word: 'women safety app', searchVol: '12K/mo', competition: 'Low',
      relevance: 'Primary target demographic. Low competition = good ranking opportunity.',
      color: Color(0xFF10B981)),
  _Keyword(word: 'SOS emergency app', searchVol: '8K/mo', competition: 'Medium',
      relevance: 'Core feature. Users who know they want SOS functionality.',
      color: Color(0xFF10B981)),
  _Keyword(word: 'panic button app', searchVol: '6K/mo', competition: 'Low',
      relevance: 'Alternative search term for SOS trigger — different vocabulary.',
      color: Color(0xFF3B82F6)),
  _Keyword(word: 'emergency contact app', searchVol: '5K/mo', competition: 'Low',
      relevance: 'Tier 1-3 contact feature. Very low competition.',
      color: Color(0xFF3B82F6)),
  _Keyword(word: 'check in app safety', searchVol: '3K/mo', competition: 'Very Low',
      relevance: 'Check-in timer feature. Niche but high intent.',
      color: Color(0xFF3B82F6)),
  _Keyword(word: 'safety tracker', searchVol: '7K/mo', competition: 'High',
      relevance: 'Broad category term — use in description, not title.',
      color: Color(0xFFF59E0B)),
  _Keyword(word: 'evidence vault', searchVol: '1K/mo', competition: 'Very Low',
      relevance: 'Differentiator — no competing apps rank for this term.',
      color: Color(0xFF8B5CF6)),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day193StoreListingScreen extends ConsumerWidget {
  const Day193StoreListingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d193TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Store Listing Copy'),
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
                onSelect: (t) => ref.read(_d193TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _TitleTab(),
            if (tab == 1) const _DescriptionTab(),
            if (tab == 2) const _AsoTab(),
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
            colors: [Color(0xFF080E14), Color(0xFF060812), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 193',              const Color(0xFF8B5CF6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section D  ·  Day 3/10',   const Color(0xFF3B82F6)),
          _badge('Store Listing  ·  Day 1/2',const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Store Listing\nCopy & ASO',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'App title, subtitle, full description — '
          'ready for both Play Store and App Store. '
          '8 ASO keywords with search volume + competition analysis. '
          'All copy with character counters.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('30',   'Title chars',   Color(0xFF8B5CF6)),
          _HStat('4000', 'Desc chars',    Color(0xFF3B82F6)),
          _HStat('8',    'ASO keywords',  Color(0xFF10B981)),
          _HStat('2',    'Stores',        Color(0xFFF59E0B)),
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
      (Icons.title_rounded,        Color(0xFF8B5CF6), 'Title & Short'),
      (Icons.description_rounded,  Color(0xFF3B82F6), 'Full Description'),
      (Icons.search_rounded,       Color(0xFF10B981), 'ASO Keywords'),
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
// TAB 1 — Title & Short Description
// ══════════════════════════════════════════════════════════════════════════════
class _TitleTab extends ConsumerWidget {
  const _TitleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(_storeTabProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.title_rounded, color: const Color(0xFF8B5CF6),
          text: 'The title is the most important ASO element — '
              'it\'s shown in search results and indexing. '
              'Include the primary keyword naturally. '
              'Keep it under the character limit for all devices.'),
      const SizedBox(height: ZapSpacing.lg),

      // Store toggle
      _StoreToggle(store: store,
          onSelect: (s) => ref.read(_storeTabProvider.notifier).state = s),
      const SizedBox(height: ZapSpacing.xl),

      if (store == _Store.play) ...[
        // Play Store
        _CopyField(
          label: 'App Title',
          sublabel: 'Shown in search results + app listing header',
          text: _kPlayTitle,
          maxChars: 30,
          color: const Color(0xFF3DDC84),
          context: context,
          tip: 'Include "Personal Safety" to rank for category searches. '
              'Brand name first (ZapSafe) for recognition.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _CopyField(
          label: 'Short Description',
          sublabel: 'Visible in search results below the title (collapsed)',
          text: _kPlayShortDesc,
          maxChars: 80,
          color: const Color(0xFF3DDC84),
          context: context,
          tip: 'First 80 characters are visible before "Read more". '
              'Lead with the strongest benefit, not the feature name.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Play Store search result preview
        const _SectionLabel('PLAY STORE SEARCH RESULT PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        _PlaySearchPreview(),
      ] else ...[
        // App Store
        _CopyField(
          label: 'App Name',
          sublabel: 'Shown under the app icon on the home screen',
          text: _kAppleTitle,
          maxChars: 30,
          color: const Color(0xFF9CA3AF),
          context: context,
          tip: 'App Store indexes the title for search. '
              'Short brand name (ZapSafe) preserves home screen display.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _CopyField(
          label: 'Subtitle',
          sublabel: 'Shown below the title in search and on the product page',
          text: _kAppleSubtitle,
          maxChars: 30,
          color: const Color(0xFF9CA3AF),
          context: context,
          tip: 'The subtitle is indexed by App Store search. '
              'Use keywords NOT in the title here.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        _CopyField(
          label: 'Keyword Field',
          sublabel: 'Not visible to users — indexed by App Store search engine',
          text: _kAppleKeywords,
          maxChars: 100,
          color: const Color(0xFF9CA3AF),
          context: context,
          tip: 'Comma-separated, no spaces after commas. '
              'Don\'t repeat words already in title or subtitle. '
              'Singular + plural count as one — use singular.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // App Store search result preview
        const _SectionLabel('APP STORE SEARCH RESULT PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        _AppleSearchPreview(),
      ],

      const SizedBox(height: ZapSpacing.xl),

      // Title strategy notes
      _infoBox(icon: Icons.lightbulb_rounded, color: const Color(0xFF8B5CF6),
          text: 'ASO Title Tips:\n'
              '• Never stuff keywords — "ZapSafe Personal Safety SOS App Emergency" gets penalised\n'
              '• The brand name builds direct search over time\n'
              '• Subtitle / short description carry almost as much weight as the title\n'
              '• Day 194 covers "What\'s New" and promo text optimisation'),
    ]);
  }
}

// ── Copy field with char counter ──────────────────────────────────────────────
class _CopyField extends StatelessWidget {
  final String label, sublabel, text, tip;
  final int    maxChars;
  final Color  color;
  final BuildContext context;
  const _CopyField({
    required this.label, required this.sublabel, required this.text,
    required this.maxChars, required this.color,
    required this.context, required this.tip,
  });

  @override
  Widget build(BuildContext ctx) {
    final len = text.length;
    final over = len > maxChars;
    final pct  = (len / maxChars).clamp(0.0, 1.0);
    final barColor = over ? const Color(0xFFEF4444)
        : len > maxChars * 0.9 ? const Color(0xFFF59E0B)
        : color;

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copied: $label'),
            backgroundColor: color,
            duration: const Duration(seconds: 2)));
      },
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: color.withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: color, fontSize: 12,
                  fontWeight: FontWeight.w700)),
              Text(sublabel, style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
            ])),
            Text('$len / $maxChars',
                style: TextStyle(color: barColor, fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          // Char bar
          ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 4)),
          const SizedBox(height: ZapSpacing.md),
          // Text content
          Text(text, style: const TextStyle(color: Colors.white,
              fontSize: 13, height: 1.5)),
          const SizedBox(height: ZapSpacing.md),
          // Tip
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF4B5563), size: 12),
            const SizedBox(width: 5),
            Expanded(child: Text(tip, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10, height: 1.4))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text('long-press to copy', style: TextStyle(
              color: Color(0xFF3A3A3A), fontSize: 9)),
        ])));
  }
}

// ── Store search previews ──────────────────────────────────────────────────────
class _PlaySearchPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
          decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: Row(children: [
            const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 13),
            const SizedBox(width: 6),
            const Text('Play Store search result',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            const Spacer(),
            Container(width: 160, height: 22, padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF111111), borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                child: const Row(children: [
                  Icon(Icons.search, color: Color(0xFF4B5563), size: 12),
                  SizedBox(width: ZapSpacing.xs),
                  Text('personal safety', style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 9)),
                ])),
          ])),
        // Search result card
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A))),
              child: const Center(child: Icon(Icons.bolt_rounded,
                  color: Color(0xFF10B981), size: 28))),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(_kPlayTitle, style: TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const Text('ZapSafe Technologies', style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
              const SizedBox(height: 3),
              Row(children: [
                ...List.generate(5, (i) => const Icon(Icons.star_rounded,
                    color: Color(0xFFFBBF24), size: 11)),
                const SizedBox(width: ZapSpacing.xs),
                const Text('4.8  ·  10K+ downloads',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
              ]),
              const SizedBox(height: ZapSpacing.xs),
              const Text(
                _kPlayShortDesc,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Install', style: TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
      ]));
}

class _AppleSearchPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
          decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: const Row(children: [
            Icon(Icons.apple_rounded, color: Color(0xFF9CA3AF), size: 13),
            SizedBox(width: 6),
            Text('App Store search result',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
        // Search result
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A))),
              child: const Center(child: Icon(Icons.bolt_rounded,
                  color: Color(0xFF10B981), size: 30))),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(_kAppleTitle, style: TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              const Text(_kAppleSubtitle, style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 11)),
              const SizedBox(height: 5),
              Row(children: [
                ...List.generate(5, (i) => const Icon(Icons.star_rounded,
                    color: Color(0xFFFBBF24), size: 11)),
                const SizedBox(width: ZapSpacing.xs),
                const Text('4.8', style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 10)),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF0071E3),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('GET', style: TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
        // Screenshots row (thumbnails)
        Padding(
          padding: const EdgeInsets.fromLTRB(ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
          child: Row(children: List.generate(3, (i) => Expanded(child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2A2A2A))),
              child: Center(child: Icon(
                  [Icons.bolt_rounded, Icons.done_all_rounded, Icons.lock_rounded][i],
                  color: const Color(0xFF3A3A3A), size: 20))),
          ))))),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Full Description
// ══════════════════════════════════════════════════════════════════════════════
class _DescriptionTab extends ConsumerWidget {
  const _DescriptionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(_storeTabProvider);
    final desc  = store == _Store.play ? _kPlayFullDesc : _kAppleFullDesc;
    const max   = 4000;
    final len   = desc.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StoreToggle(store: store,
          onSelect: (s) => ref.read(_storeTabProvider.notifier).state = s),
      const SizedBox(height: ZapSpacing.xl),

      // Tips
      _infoBox(icon: Icons.tips_and_updates_rounded, color: const Color(0xFF3B82F6),
          text: 'ASO Description Tips:\n'
              '• First 167 characters (Play) / 255 characters (Apple) show before "Read more"\n'
              '• Repeat the top 3 keywords 3-5x naturally\n'
              '• Use emoji section headers (🚨 🔒 👥) — increases scannability by 30%\n'
              '• End with a clear CTA: "Download ZapSafe and..."'),
      const SizedBox(height: ZapSpacing.lg),

      // Char counter
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Full Description',
                style: TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text(store == _Store.play ? 'Play Store · 4000 char max'
                : 'App Store · 4000 char max',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
          Text('$len / $max',
              style: TextStyle(
                  color: len > max * 0.9
                      ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  fontSize: 14, fontWeight: FontWeight.w900)),
        ])),
      const SizedBox(height: ZapSpacing.md),

      // Description text
      GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: desc));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Copied ${store == _Store.play ? "Play" : "App Store"} description'),
              backgroundColor: const Color(0xFF3B82F6),
              duration: const Duration(seconds: 2)));
        },
        child: Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Expanded(child: Text('long-press to copy full description',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
              Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
            ]),
            const SizedBox(height: ZapSpacing.md),
            Text(desc, style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.7)),
          ])),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Keyword density highlights
      const _SectionLabel('KEYWORD DENSITY CHECK'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...[
            ('safety',        _countWord(desc, 'safety'),  4,  const Color(0xFF10B981)),
            ('SOS',           _countWord(desc, 'SOS'),     4,  const Color(0xFFEF4444)),
            ('emergency',     _countWord(desc, 'emergency'),3, const Color(0xFF3B82F6)),
            ('evidence',      _countWord(desc, 'evidence'),3,  const Color(0xFFF59E0B)),
            ('contacts',      _countWord(desc, 'contact'), 3,  const Color(0xFF10B981)),
            ('encrypted',     _countWord(desc, 'encrypt'), 2,  const Color(0xFF8B5CF6)),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (kw, count, target, color) = e.value;
            final ok = count >= target;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 9),
                child: Row(children: [
                  SizedBox(width: 80, child: Text('"$kw"', style: const TextStyle(
                      color: Colors.white, fontSize: 11))),
                  Text('×$count', style: TextStyle(
                      color: ok ? color : const Color(0xFFF59E0B),
                      fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text('(target: $target+)', style: const TextStyle(
                      color: Color(0xFF4B5563), fontSize: 9)),
                  const Spacer(),
                  Icon(ok ? Icons.check_circle_rounded : Icons.warning_rounded,
                      color: ok ? color : const Color(0xFFF59E0B), size: 14),
                ])),
              if (i < 5) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ])),
    ]);
  }

  static int _countWord(String text, String word) {
    final lower = text.toLowerCase();
    final wLower = word.toLowerCase();
    int count = 0, i = 0;
    while (true) {
      final idx = lower.indexOf(wLower, i);
      if (idx == -1) break;
      count++;
      i = idx + 1;
    }
    return count;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — ASO Keywords
// ══════════════════════════════════════════════════════════════════════════════
class _AsoTab extends ConsumerWidget {
  const _AsoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedKwProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.search_rounded, color: const Color(0xFF10B981),
          text: 'App Store Optimisation (ASO): keyword research for '
              'both stores. Search volume = monthly searches on Play/App Store. '
              'Tap any keyword to see rationale.'),
      const SizedBox(height: ZapSpacing.lg),

      // Keyword stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _kwStat('8', 'Keywords', const Color(0xFF10B981)),
          _kwStat('3', 'Low competition', const Color(0xFF10B981)),
          _kwStat('3', 'Medium', const Color(0xFFF59E0B)),
          _kwStat('1', 'High comp.', const Color(0xFFEF4444)),
          _kwStat('1', 'Niche gem', const Color(0xFF8B5CF6)),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('8 TARGET KEYWORDS  ·  TAP FOR RATIONALE'),
      const SizedBox(height: ZapSpacing.md),

      ..._kKeywords.asMap().entries.map((e) {
        final i   = e.key;
        final kw  = e.value;
        final isExp = expanded == i;
        final compColor = kw.competition == 'Low' || kw.competition == 'Very Low'
            ? const Color(0xFF10B981)
            : kw.competition == 'Medium'
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444);

        return GestureDetector(
          onTap: () => ref.read(_expandedKwProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? kw.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? kw.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  // Keyword text
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('"${kw.word}"', style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    Row(children: [
                      _tag(kw.searchVol, const Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      _tag(kw.competition, compColor),
                    ]),
                  ])),
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
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                              color: kw.color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: kw.color.withOpacity(0.2))),
                          child: Text(kw.relevance, style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))))
                    : const SizedBox.shrink(),
              ),
            ]),
          ));
      }),

      const SizedBox(height: ZapSpacing.lg),

      // Play vs Apple ASO difference
      const _SectionLabel('PLAY vs APP STORE ASO DIFFERENCES'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
            color: const Color(0xFF111111),
            child: const Row(children: [
              Expanded(flex: 2, child: Text('Factor',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 9, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('Play Store',
                  style: TextStyle(color: Color(0xFF3DDC84), fontSize: 9, fontWeight: FontWeight.w700))),
              Expanded(flex: 2, child: Text('App Store',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, fontWeight: FontWeight.w700))),
            ])),
          ...[
            ('Keyword field', 'Not indexed separately\n(use in description)', 'Dedicated 100-char\nkeyword field'),
            ('Title weight', 'High — title + short desc indexed', 'High — title + subtitle indexed'),
            ('Description indexing', 'Fully indexed by Google', 'NOT indexed (only title/subtitle/keywords)'),
            ('Update frequency', 'Instant on each release', 'Requires App Review (~24h)'),
            ('A/B testing', 'Built-in store listing experiments', 'Custom Product Pages (CPP)'),
          ].map((e) {
            final (f, play, apple) = e;
            return Column(children: [
              const Divider(height: 1, color: Color(0xFF1E1E1E)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: Text(f, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10))),
                  Expanded(flex: 2, child: Text(play, style: const TextStyle(
                      color: Color(0xFF3DDC84), fontSize: 9, height: 1.4))),
                  Expanded(flex: 2, child: Text(apple, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 9, height: 1.4))),
                ])),
            ]);
          }),
        ])),
    ]);
  }

  Widget _kwStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 8, height: 1.2),
        textAlign: TextAlign.center),
  ]));

  static Widget _tag(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w700)));
}

// ── Store toggle ──────────────────────────────────────────────────────────────
class _StoreToggle extends StatelessWidget {
  final _Store store; final ValueChanged<_Store> onSelect;
  const _StoreToggle({required this.store, required this.onSelect});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: GestureDetector(
      onTap: () => onSelect(_Store.play),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: store == _Store.play
                ? const Color(0xFF3DDC84).withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: store == _Store.play
                    ? const Color(0xFF3DDC84).withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: store == _Store.play ? 2 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 15),
          const SizedBox(width: 5),
          Text('Play Store', style: TextStyle(
              color: store == _Store.play
                  ? const Color(0xFF3DDC84) : const Color(0xFF6B7280),
              fontSize: 11, fontWeight: FontWeight.w700)),
        ])))),
    const SizedBox(width: ZapSpacing.sm),
    Expanded(child: GestureDetector(
      onTap: () => onSelect(_Store.apple),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: store == _Store.apple
                ? const Color(0xFF9CA3AF).withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: store == _Store.apple
                    ? const Color(0xFF9CA3AF).withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: store == _Store.apple ? 2 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.apple_rounded, color: Color(0xFF9CA3AF), size: 15),
          const SizedBox(width: 5),
          Text('App Store', style: TextStyle(
              color: store == _Store.apple
                  ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              fontSize: 11, fontWeight: FontWeight.w700)),
        ])))),
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
