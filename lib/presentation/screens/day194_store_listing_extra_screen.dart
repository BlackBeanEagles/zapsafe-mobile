/// Day 194 — Promo Text, What's New, Hindi Listing & A/B Testing
///
/// Second and final day of the Days 193-194 Store Listing block.
/// Day 193: Title, short desc, full desc, ASO keywords  ✅
/// Day 194: Promo text, "What's New" / release notes,
///           localised Hindi listing, A/B test plan,
///           block 193-194 sign-off.
///
/// 🟢 FRONTEND-ONLY — copywriting, localisation, and ASO planning.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d194TabProvider    = StateProvider<int>((ref) => 0);
final _selectedAbProvider = StateProvider<int>((ref) => 0);
final _expandedAbProvider = StateProvider<int?>((ref) => null);

// ── Copy constants ─────────────────────────────────────────────────────────────

// App Store Promo Text (170 chars, changeable without review)
const _kPromoText =
    '🚨 NEW: AI-powered distress detection now in Premium. '
    'Scream detection + motion analysis triggers SOS automatically. '
    'Stay safer. Stay connected.';

// What's New — v1.0.0 initial release
const _kWhatsNewV100 = '''Welcome to ZapSafe v1.0.0 🎉

Your personal safety companion is here.

• One-tap SOS — power button × 5 sends your location to contacts
• Evidence Vault — AES-256 encrypted audio, GPS & sensor capture
• Smart Escalation — Tier 1 → 2 → 3 contact hierarchy
• Check-in Timers — dead-man's switch for solo travellers
• Protection Score — live safety health score
• DPDP Act 2023 + GDPR compliant — privacy first

Thank you for choosing ZapSafe. Your safety is our mission.''';

// What's New — v1.1 template
const _kWhatsNewV110 = '''ZapSafe v1.1 — AI Detection Update

• AI Distress Detection now in Premium
  Scream detection + motion analysis + scene recognition
• Improved battery optimisation (-30% drain)
• Fixed: notification delivery on Xiaomi/Huawei devices
• Evidence vault: extend expiry now supports up to 1 year
• New: Arabic and Tamil language support

Questions? support@zapsafe.app''';

// Hindi localised listing
// Untrimmed title 'ZapSafe — व्यक्तिगत सुरक्षा SOS' is 33 chars (Play allows 30), so it's trimmed below.
const _kHiTitleTrim = 'ZapSafe — सेफ्टी SOS';               // 22 chars
const _kHiShortDesc = 'SOS अलर्ट, एविडेंस वॉल्ट और इमरजेंसी कॉन्टैक्ट — एक ऐप में।';
const _kHiFullDescSnippet = '''ZapSafe आपका व्यक्तिगत सुरक्षा साथी है।

🚨 एक-टैप SOS
पावर बटन 5 बार दबाएं — आपकी लोकेशन तुरंत इमरजेंसी कॉन्टैक्ट को भेजी जाती है।

🔒 एविडेंस वॉल्ट
हर SOS इवेंट का AES-256 एन्क्रिप्टेड ऑडियो, GPS और सेंसर डेटा।

👥 स्मार्ट एस्केलेशन
टियर 1 → 2 → 3 कॉन्टैक्ट हायरार्की — कोई जवाब न दे तो अगला अलर्ट होता है।

⏱ चेक-इन टाइमर
अगर आप चेक-इन नहीं करते, तो आपके कॉन्टैक्ट को अपने आप नोटिफाई किया जाता है।

ZapSafe डाउनलोड करें और अपना सेफ्टी नेटवर्क बनाएं।''';

// A/B test plans
class _AbTest {
  final String id, name, store, hypothesis, variantA, variantB, metric, duration;
  const _AbTest({
    required this.id, required this.name, required this.store,
    required this.hypothesis, required this.variantA, required this.variantB,
    required this.metric, required this.duration,
  });
}

const _kAbTests = [
  _AbTest(
    id: 'ab1',
    name: 'Title variant — keyword vs brand',
    store: 'Play Store',
    hypothesis: 'Including "Women Safety" in the title increases installs from '
        'that demographic without hurting overall conversion.',
    variantA: 'ZapSafe — Personal Safety SOS (current)',
    variantB: 'ZapSafe — Women Safety & SOS App',
    metric: 'Install conversion rate from "safety" keyword search',
    duration: '30 days, min 1000 impressions per variant',
  ),
  _AbTest(
    id: 'ab2',
    name: 'Screenshot order — SOS first vs Score first',
    store: 'Play Store',
    hypothesis: 'Showing the Protection Score (gamification) first could hook '
        'users who haven\'t experienced a safety emergency before.',
    variantA: 'Screenshot 1: SOS Active screen (current)',
    variantB: 'Screenshot 1: Protection Score dashboard',
    metric: 'Store listing conversion rate (impressions → installs)',
    duration: '30 days, min 500 installs per variant',
  ),
  _AbTest(
    id: 'ab3',
    name: 'App Store Custom Product Page — student market',
    store: 'App Store',
    hypothesis: 'A CPP targeting "college student safety" with campus-focused '
        'copy + check-in timer screenshots will convert better for that segment.',
    variantA: 'Default product page (general audience)',
    variantB: 'CPP: "Safe on Campus" — check-in, late night, hostel keywords',
    metric: 'Conversion from Apple Search Ads targeting students',
    duration: '4 weeks, ASA campaign with 500 AUD budget',
  ),
  _AbTest(
    id: 'ab4',
    name: 'Short description — feature vs emotion',
    store: 'Play Store',
    hypothesis: 'Emotional framing ("peace of mind") converts better than '
        'feature listing ("SOS alert, evidence vault…").',
    variantA: 'SOS alert, evidence vault & emergency contacts in one app.',
    variantB: 'Peace of mind for you and everyone who cares about you. 🛡',
    metric: 'Click-through from search result to listing page',
    duration: '30 days, min 2000 search impressions',
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day194StoreListingExtraScreen extends ConsumerWidget {
  const Day194StoreListingExtraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d194TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Promo, Hindi & A/B Testing'),
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
                onSelect: (t) => ref.read(_d194TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _PromoTab(),
            if (tab == 1) const _HindiTab(),
            if (tab == 2) const _AbTestTab(),
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
            colors: [Color(0xFF0C080E), Color(0xFF080512), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 194',              const Color(0xFF8B5CF6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section D  ·  Day 4/10',   const Color(0xFF3B82F6)),
          _badge('Store Listing  ·  Day 2/2 ✅', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Promo Text,\nHindi & A/B Tests',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'App Store promo text (170 chars, no review). '
          '"What\'s New" for v1.0.0 + v1.1 template. '
          'Full Hindi listing — title, short desc, description snippet. '
          '4 A/B test plans with hypothesis + metric.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('170', 'Promo chars', Color(0xFF8B5CF6)),
          _HStat('2',   'Release notes', Color(0xFF3B82F6)),
          _HStat('HI',  'Hindi listing', Color(0xFFF59E0B)),
          _HStat('4',   'A/B tests',    Color(0xFF10B981)),
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
      (Icons.campaign_rounded,     Color(0xFF8B5CF6), 'Promo & Notes'),
      (Icons.language_rounded,     Color(0xFFF59E0B), 'Hindi Listing'),
      (Icons.science_rounded,      Color(0xFF10B981), 'A/B Testing'),
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
// TAB 1 — Promo Text & What's New
// ══════════════════════════════════════════════════════════════════════════════
class _PromoTab extends StatelessWidget {
  const _PromoTab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // App Store Promo Text
      const _SectionLabel('APP STORE PROMO TEXT  ·  iOS ONLY'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.apple_rounded, color: const Color(0xFF9CA3AF),
          text: 'Promotional text (170 chars) appears above the description. '
              'Unlike the description, it can be CHANGED at any time without '
              'submitting a new app version or going through review. '
              'Great for seasonal promotions or new feature announcements.'),
      const SizedBox(height: ZapSpacing.md),
      _CopyCard(
        label: 'Promotional Text (App Store)',
        sublabel: 'Shown above description · changeable without review',
        text: _kPromoText,
        maxChars: 170,
        color: const Color(0xFF9CA3AF),
        context: context,
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Mock App Store product page snippet
      const _SectionLabel('PRODUCT PAGE PREVIEW'),
      const SizedBox(height: ZapSpacing.md),
      _AppStoreProductPageMock(),
      const SizedBox(height: ZapSpacing.xl),

      // What's New — v1.0.0
      const _SectionLabel('WHAT\'S NEW  ·  v1.0.0 INITIAL RELEASE'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.new_releases_rounded, color: const Color(0xFF3B82F6),
          text: '"What\'s New" appears in the Updates tab and in search for '
              'existing users. First launch: introduce the app. '
              'Subsequent updates: bullet-point changes. '
              'Max 4000 chars — keep to under 500 for readability.'),
      const SizedBox(height: ZapSpacing.md),
      _CopyCard(
        label: 'What\'s New — v1.0.0',
        sublabel: 'Initial release · shown on first install page',
        text: _kWhatsNewV100,
        maxChars: 4000,
        color: const Color(0xFF3B82F6),
        context: context,
      ),
      const SizedBox(height: ZapSpacing.lg),

      // What's New — v1.1 template
      const _SectionLabel('WHAT\'S NEW TEMPLATE  ·  v1.1 (FUTURE)'),
      const SizedBox(height: ZapSpacing.md),
      _CopyCard(
        label: 'What\'s New — v1.1 (template)',
        sublabel: 'AI Detection update · future release',
        text: _kWhatsNewV110,
        maxChars: 4000,
        color: const Color(0xFF8B5CF6),
        context: context,
      ),
      const SizedBox(height: ZapSpacing.lg),

      _infoBox(icon: Icons.lightbulb_rounded, color: const Color(0xFF6B7280),
          text: 'Best practices for "What\'s New":\n'
              '• Lead with the most impactful change\n'
              '• Use bullet points — users scan, not read\n'
              '• Mention bug fixes last — they\'re less exciting but build trust\n'
              '• Emoji headers improve scannability on mobile'),
    ]);
  }
}

class _AppStoreProductPageMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: const Row(children: [
            Icon(Icons.apple_rounded, color: Color(0xFF9CA3AF), size: 12),
            SizedBox(width: 6),
            Text('App Store product page — promo text placement',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ])),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Promo text block (highlighted)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                  color: const Color(0xFF9CA3AF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: const Color(0xFF9CA3AF).withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Promotional text (above description)',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 8,
                        fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 5),
                const Text(_kPromoText, style: TextStyle(
                    color: Colors.white, fontSize: 11, height: 1.5)),
              ])),
            const SizedBox(height: ZapSpacing.sm),
            const Text('ZapSafe is your personal safety companion...',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: ZapSpacing.xs),
            const Text('More', style: TextStyle(
                color: Color(0xFF0071E3), fontSize: 11)),
          ])),
      ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Hindi Listing
// ══════════════════════════════════════════════════════════════════════════════
class _HindiTab extends StatelessWidget {
  const _HindiTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.language_rounded, color: const Color(0xFFF59E0B),
        text: 'India is ZapSafe\'s primary market. '
            'Uploading a Hindi (hi_IN) listing increases discovery '
            'among Hindi-speaking users — ~600M people. '
            'Both Play Store and App Store support per-locale listings.'),
    const SizedBox(height: ZapSpacing.lg),

    // Hindi fields
    _CopyCard(
      label: 'App Title (Hindi) — Play Store',
      sublabel: 'hi_IN · Store listing title · 22 chars',
      text: _kHiTitleTrim,
      maxChars: 30,
      color: const Color(0xFFF59E0B),
      context: context,
    ),
    const SizedBox(height: ZapSpacing.lg),

    _CopyCard(
      label: 'Short Description (Hindi)',
      sublabel: 'hi_IN · Play Store · 80 chars',
      text: _kHiShortDesc,
      maxChars: 80,
      color: const Color(0xFFF59E0B),
      context: context,
    ),
    const SizedBox(height: ZapSpacing.lg),

    // Full description snippet
    const _SectionLabel('FULL DESCRIPTION SNIPPET (HINDI)'),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
        text: 'This is an excerpt. The full Hindi description mirrors the English '
            'version with translated headings. '
            'Professional proofreading recommended before submission.'),
    const SizedBox(height: ZapSpacing.md),
    _CopyCard(
      label: 'Full Description Snippet (Hindi)',
      sublabel: 'First ~400 chars of the full Hindi description',
      text: _kHiFullDescSnippet,
      maxChars: 4000,
      color: const Color(0xFFF59E0B),
      context: context,
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Localisation comparison
    const _SectionLabel('EN vs HI  ·  KEY PHRASES TRANSLATED'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: const BoxDecoration(
              color: Color(0xFF111111),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(ZapSpacing.radius),
                  topRight: Radius.circular(ZapSpacing.radius))),
          child: const Row(children: [
            Expanded(child: Text('English',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 9,
                    fontWeight: FontWeight.w700))),
            Expanded(child: Text('Hindi (Devanagari)',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9,
                    fontWeight: FontWeight.w700))),
          ])),
        ...[
          ('Personal Safety',   'व्यक्तिगत सुरक्षा'),
          ('SOS Alert',         'SOS अलर्ट'),
          ('Evidence Vault',    'एविडेंस वॉल्ट'),
          ('Emergency Contacts','इमरजेंसी कॉन्टैक्ट'),
          ('Check-in Timer',    'चेक-इन टाइमर'),
          ('Protection Score',  'प्रोटेक्शन स्कोर'),
          ('One-tap SOS',       'एक-टैप SOS'),
          ('Privacy First',     'प्राइवेसी पहले'),
        ].asMap().entries.map((e) {
          final i = e.key;
          final (en, hi) = e.value;
          final isLast = i == 7;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 9),
              child: Row(children: [
                Expanded(child: Text(en, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11))),
                Expanded(child: Text(hi, style: const TextStyle(
                    color: Color(0xFFF59E0B), fontSize: 11))),
              ])),
            if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
          ]);
        }),
      ])),
    const SizedBox(height: ZapSpacing.lg),

    // Upload workflow
    const _SectionLabel('UPLOAD WORKFLOW'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: [
        ...[
          (Icons.android_rounded, const Color(0xFF3DDC84),
              'Play Console → Store Presence → Main Store Listing → Add language → hi-IN'),
          (Icons.apple_rounded, const Color(0xFF9CA3AF),
              'App Store Connect → App Information → Localisation → +  → Hindi'),
          (Icons.translate_rounded, const Color(0xFFF59E0B),
              'Upload translated title, short description, and full description in each store.'),
          (Icons.photo_library_rounded, const Color(0xFF8B5CF6),
              'Upload Hindi screenshots (from Day 192 localisation tab) in the locale slot.'),
        ].asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, text) = e.value;
          final isLast = i == 3;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(width: ZapSpacing.md),
                Expanded(child: Text(text, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))),
              ])),
            if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
          ]);
        }),
      ])),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — A/B Testing + Block Sign-Off
// ══════════════════════════════════════════════════════════════════════════════
class _AbTestTab extends ConsumerWidget {
  const _AbTestTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedAbProvider);
    final _ = ref.watch(_expandedAbProvider);
    final test     = _kAbTests[selected];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.science_rounded, color: const Color(0xFF10B981),
          text: 'A/B testing your store listing can increase install '
              'conversion by 10-30%. '
              'Play Store has built-in Store Listing Experiments. '
              'App Store uses Custom Product Pages (CPP) via Search Ads.'),
      const SizedBox(height: ZapSpacing.lg),

      // Test selector
      const _SectionLabel('4 PLANNED A/B TESTS  ·  SELECT TO PREVIEW'),
      const SizedBox(height: ZapSpacing.md),
      ...(_kAbTests.asMap().entries.map((e) {
        final i    = e.key;
        final t    = e.value;
        final isOn = selected == i;
        final storeColor = t.store.contains('Play')
            ? const Color(0xFF3DDC84) : const Color(0xFF9CA3AF);
        return GestureDetector(
          onTap: () => ref.read(_selectedAbProvider.notifier).state = i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: isOn
                    ? const Color(0xFF10B981).withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isOn
                        ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isOn ? 2 : 1)),
            child: Row(children: [
              // Number
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                    color: isOn
                        ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isOn
                            ? const Color(0xFF10B981) : const Color(0xFF3A3A3A))),
                child: Center(child: Text('${i + 1}', style: TextStyle(
                    color: isOn ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                    fontSize: 10, fontWeight: FontWeight.w800)))),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: TextStyle(
                    color: isOn ? Colors.white : const Color(0xFF9CA3AF),
                    fontSize: 11, fontWeight: FontWeight.w600)),
                Text(t.store, style: TextStyle(color: storeColor, fontSize: 9,
                    fontWeight: FontWeight.w700)),
              ])),
              if (isOn)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 16),
            ]),
          ));
      })),
      const SizedBox(height: ZapSpacing.xl),

      // Selected test detail
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _AbTestDetail(key: ValueKey(selected), test: test),
      ),

      const SizedBox(height: ZapSpacing.xl),
      const Divider(color: Color(0xFF1E1E1E)),
      const SizedBox(height: ZapSpacing.xl),

      // Block sign-off
      _BlockSignOff(),
    ]);
  }
}

class _AbTestDetail extends StatelessWidget {
  final _AbTest test;
  const _AbTestDetail({required this.test, super.key});

  @override
  Widget build(BuildContext context) {
    final storeColor = test.store.contains('Play')
        ? const Color(0xFF3DDC84) : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.science_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(test.name, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: storeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(test.store, style: TextStyle(
                color: storeColor, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Hypothesis
        _detailRow('Hypothesis', test.hypothesis, Icons.psychology_rounded,
            const Color(0xFF8B5CF6)),
        const SizedBox(height: ZapSpacing.sm),

        // Variants
        const _SectionLabel('VARIANTS'),
        const SizedBox(height: ZapSpacing.sm),
        Row(children: [
          Expanded(child: _variantCard('A (Control)', test.variantA,
              const Color(0xFF3B82F6))),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _variantCard('B (Test)', test.variantB,
              const Color(0xFF10B981))),
        ]),
        const SizedBox(height: ZapSpacing.sm),

        // Metric + duration
        _detailRow('Success metric', test.metric,
            Icons.bar_chart_rounded, const Color(0xFFF59E0B)),
        const SizedBox(height: 6),
        _detailRow('Test duration', test.duration,
            Icons.timer_rounded, const Color(0xFF3B82F6)),
      ]));
  }

  Widget _variantCard(String label, String text, Color color) => Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: ZapSpacing.xs),
        Text(text, style: const TextStyle(color: Color(0xFFD1D5DB),
            fontSize: 11, height: 1.4)),
      ]));

  Widget _detailRow(String label, String body, IconData icon, Color color) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        SizedBox(width: 68, child: Text(label, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text(body, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4))),
      ]);
}

// ── Block Sign-Off ────────────────────────────────────────────────────────────
class _BlockSignOff extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF8B5CF6).withOpacity(0.12),
          const Color(0xFF8B5CF6).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        const Text('✍️', style: TextStyle(fontSize: 40)),
        const SizedBox(height: ZapSpacing.md),
        const Text('Store Listing Block',
            style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 14,
                fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.xs),
        const Text('DAYS 193 – 194  ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: const [
          _Chip('Title + subtitle ✅',    Color(0xFF8B5CF6)),
          _Chip('Short description ✅',   Color(0xFF3B82F6)),
          _Chip('Full description ✅',    Color(0xFF3B82F6)),
          _Chip('8 ASO keywords ✅',      Color(0xFF10B981)),
          _Chip('Promo text ✅',          Color(0xFF9CA3AF)),
          _Chip('What\'s New ✅',         Color(0xFF8B5CF6)),
          _Chip('Hindi listing ✅',       Color(0xFFF59E0B)),
          _Chip('4 A/B tests planned ✅', Color(0xFF10B981)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Section D 4/10 progress
    const _SectionLabel('SECTION D: STORE PREP  ·  PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    ...[
      (const Color(0xFF10B981), 'Days 191-192', 'Screenshots + Frames + Export Checklist', true),
      (const Color(0xFF10B981), 'Days 193-194', 'Store Listing Copy + ASO + Hindi + A/B', true),
      (const Color(0xFF3B82F6), 'Days 195-196', 'Privacy Policy + Content Ratings + DPDP  ←', false),
      (const Color(0xFF6B7280), 'Days 197-198', 'Release Checklist + QA Gate', false),
      (const Color(0xFF6B7280), 'Days 199-200', 'Final Submission + Sign-Off 🏆', false),
    ].map((s) {
      final (color, days, title, done) = s;
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: done ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: done ? color.withOpacity(0.25) : const Color(0xFF2A2A2A))),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ])),
          if (done)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
          else
            const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFF3A3A3A), size: 16),
        ]));
    }),
    const SizedBox(height: ZapSpacing.md),
    // 4/10 bar
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Section D progress',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const Spacer(),
        const Text('4 / 10 days  ·  2 / 5 blocks',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      ClipRRect(borderRadius: BorderRadius.circular(4),
          child: const LinearProgressIndicator(
              value: 4 / 10,
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
              minHeight: 8)),
    ]),
    const SizedBox(height: ZapSpacing.lg),
    _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF3B82F6),
        text: 'Next: Days 195-196 — Privacy Policy URL, '
            'content rating questionnaire (IARC), '
            'DPDP/GDPR compliance checklist for store submission.'),
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

// ── _CopyCard ─────────────────────────────────────────────────────────────────
class _CopyCard extends StatelessWidget {
  final String label, sublabel, text;
  final int maxChars;
  final Color color;
  final BuildContext context;
  const _CopyCard({
    required this.label, required this.sublabel, required this.text,
    required this.maxChars, required this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final len     = text.length;
    final pct     = (len / maxChars).clamp(0.0, 1.0);
    final barColor= len > maxChars * 0.95
        ? const Color(0xFFF59E0B) : color;

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
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: color, fontSize: 12,
                  fontWeight: FontWeight.w700)),
              Text(sublabel, style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
            ])),
            Text('$len / $maxChars',
                style: TextStyle(color: barColor, fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 4)),
          const SizedBox(height: ZapSpacing.md),
          Text(text, style: const TextStyle(color: Colors.white,
              fontSize: 12, height: 1.6)),
          const SizedBox(height: ZapSpacing.sm),
          const Text('long-press to copy', style: TextStyle(
              color: Color(0xFF3A3A3A), fontSize: 9)),
        ])));
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
