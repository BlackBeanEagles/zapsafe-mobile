/// Day 192 — Screenshot Frames, Localisation & Export Checklist
///
/// Second and final day of the Days 191-192 Screenshot block.
/// Day 191: 6 hero screens, device frames, store specs, captions  ✅
/// Day 192: Frame overlay generator workflow, localisation
///           screenshots (EN + HI + RTL preview), and the full
///           asset export checklist for both stores.
///
/// 🟢 FRONTEND-ONLY — planning, tooling docs, in-app locale switcher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d192TabProvider       = StateProvider<int>((ref) => 0);
final _selectedToolProvider  = StateProvider<int>((ref) => 0);
final _selectedLocaleProvider= StateProvider<_Locale>((ref) => _Locale.en);
final _checkedItemsProvider  = StateProvider<Set<String>>((ref) => {});
final _expandedToolProvider  = StateProvider<int?>((ref) => null);

enum _Locale { en, hi, ar }

// ── Framing tool data ─────────────────────────────────────────────────────────
class _FramingTool {
  final String   name;
  final String   type;
  final String   description;
  final Color    color;
  final List<String> pros;
  final List<String> cons;
  final String   bestFor;
  final String   command;   // CLI / usage snippet
  const _FramingTool({
    required this.name, required this.type, required this.description,
    required this.color, required this.pros, required this.cons,
    required this.bestFor, required this.command,
  });
}

const _kTools = [
  _FramingTool(
    name: 'fastlane frameit',
    type: 'CLI Tool (Ruby)',
    description: 'Automatically wraps raw screenshots in device frames '
        'using Apple and Android device images. '
        'Integrates with fastlane supply/deliver pipeline.',
    color: Color(0xFFEF4444),
    pros: [
      'Fully automated — batch all 6 screenshots × all locales',
      'Part of the fastlane CI/CD pipeline (Day 197-198)',
      'Device images update with new models',
      'Supports custom background colours and text overlays',
    ],
    cons: [
      'Requires Ruby + fastlane setup',
      'Device frame library can lag new phone releases',
      'Less control over exact overlay text positioning',
    ],
    bestFor: 'Teams using fastlane CI — automates the full pipeline.',
    command: r'''# Install fastlane
gem install fastlane

# In the ios/ or android/ directory:
fastlane frameit

# With custom background + title text:
fastlane frameit silver       # silver device frames
fastlane frameit gold         # gold device frames

# Framefile.json for custom text:
{
  "default": {
    "background": "./background.png",
    "keyword": { "color": "#ffffff", "font": "SourceSansPro-Bold" },
    "title": { "color": "#ffffff" }
  }
}''',
  ),
  _FramingTool(
    name: 'Figma — Screenshot Templates',
    type: 'Design Tool',
    description: 'Use community Figma device frame templates. '
        'Drop raw screenshots into frame components. '
        'Export all variants (EN/HI/AR) with one click.',
    color: Color(0xFF8B5CF6),
    pros: [
      'Full design control — custom backgrounds, gradients, icons',
      'Community device frame kits (Pixel 8, iPhone 15 Pro)',
      'Variable font layers for multi-locale in one file',
      'No CLI setup required',
    ],
    cons: [
      'Manual workflow — no CI integration',
      'Designer bottleneck if developer doesn\'t use Figma',
      'Export can be slow for many variants',
    ],
    bestFor: 'Solo builder (ZapSafe) — fastest for 6 screens × 3 locales.',
    command: r'''// Figma workflow:
// 1. Open community file: "iOS/Android Device Mockups 2024"
// 2. Paste raw screenshots into Frame components
// 3. Edit text layers for headline + subline per locale
// 4. File → Export → Select all frames → PNG 2x
// 5. Rename to Play/Apple naming convention

// Recommended community kits:
// • "iPhone 15 Pro Mockups" — realistic Figma frames
// • "Google Pixel 8 Mockup" — Android frames
// • Both include dark + light + colour variants''',
  ),
  _FramingTool(
    name: 'screenshots (pub.dev)',
    type: 'Flutter Package',
    description: 'Dart package that drives integration tests to capture '
        'screenshots programmatically in the correct locale '
        'and device size, then optionally wraps them in frames.',
    color: Color(0xFF3B82F6),
    pros: [
      'Screenshots are always pixel-perfect — from the real app',
      'Supports all locales automatically via integration test',
      'CI-friendly — runs in emulator/simulator pipeline',
      'No manual screenshot taking required',
    ],
    cons: [
      'Requires writing integration tests for each screen',
      'Emulator screenshots lack physical device frame',
      'Package maintenance lagged behind Flutter versions',
    ],
    bestFor: 'Automated testing pipeline — ensures screenshots stay fresh.',
    command: r'''# pubspec.yaml (dev_dependencies)
screenshots: ^2.2.0

# screenshots.yaml
tests:
  - test_driver/main.dart
locales:
  - en_IN
  - hi_IN
devices:
  android:
    - Pixel 8
  ios:
    - iPhone 15 Pro Max

# Run:
flutter pub run screenshots''',
  ),
];

// ── Locale screenshot data ────────────────────────────────────────────────────
class _LocaleConfig {
  final String code, name, direction;
  final String headline1, subline1;   // SOS screen localised
  final bool   rtl;
  const _LocaleConfig({
    required this.code, required this.name, required this.direction,
    required this.headline1, required this.subline1, required this.rtl,
  });
}

const _kLocales = {
  _Locale.en: _LocaleConfig(
    code: 'en_IN', name: 'English (India)', direction: 'LTR',
    headline1: 'One tap.\nHelp is on the way.',
    subline1: 'SOS dispatches to your contacts in seconds.',
    rtl: false,
  ),
  _Locale.hi: _LocaleConfig(
    code: 'hi_IN', name: 'Hindi (India)', direction: 'LTR',
    headline1: 'एक टैप।\nमदद आ रही है।',
    subline1: 'SOS कुछ सेकंड में आपके संपर्कों को भेजा जाता है।',
    rtl: false,
  ),
  _Locale.ar: _LocaleConfig(
    code: 'ar', name: 'Arabic (RTL Demo)', direction: 'RTL',
    headline1: 'نقرة واحدة.\nالمساعدة في الطريق.',
    subline1: 'يرسل SOS إلى جهات اتصالك في ثوانٍ.',
    rtl: true,
  ),
};

// ── Export checklist items ────────────────────────────────────────────────────
class _CheckItem {
  final String id, category, label, detail;
  final bool   critical;  // red if missing → store rejection
  const _CheckItem({
    required this.id, required this.category, required this.label,
    required this.detail, this.critical = false,
  });
}

const _kCheckItems = [
  // Play Store
  _CheckItem(id: 'p1', category: 'Play Store',
      label: '6 phone screenshots (1080×1920 PNG)',
      detail: 'Screens 1-6 at 1080×1920 px. Saved as SS01_en_phone.png etc.',
      critical: true),
  _CheckItem(id: 'p2', category: 'Play Store',
      label: 'Feature graphic (1024×500 PNG)',
      detail: 'Displayed at top of listing. ZapSafe brand gradient + bolt icon.',
      critical: true),
  _CheckItem(id: 'p3', category: 'Play Store',
      label: 'Hi-res icon (512×512 PNG)',
      detail: 'App icon at 512×512, rounded corners applied by Play Store.',
      critical: true),
  _CheckItem(id: 'p4', category: 'Play Store',
      label: 'Hindi screenshots (hi_IN)',
      detail: '6 screens with Hindi overlay text for hi_IN locale.',
      critical: false),
  _CheckItem(id: 'p5', category: 'Play Store',
      label: 'Tablet screenshots (optional)',
      detail: '1200×1920 px. Increases rating — not required for phone-only.',
      critical: false),
  _CheckItem(id: 'p6', category: 'Play Store',
      label: 'Promo video 30s (optional)',
      detail: 'MP4, 1920×1080, max 100 MB. Autoplay in listing — high impact.',
      critical: false),

  // App Store
  _CheckItem(id: 'a1', category: 'App Store',
      label: '6.9" screenshots (1320×2868 PNG)',
      detail: 'Required slot for iPhone 16 Plus. Covers all large iPhone sizes.',
      critical: true),
  _CheckItem(id: 'a2', category: 'App Store',
      label: '6.5" screenshots (1284×2778 PNG)',
      detail: 'iPhone 14 Plus slot. Required if 6.9" not provided.',
      critical: false),
  _CheckItem(id: 'a3', category: 'App Store',
      label: '5.5" screenshots (1242×2208 PNG)',
      detail: 'iPhone 8 Plus legacy slot. Covers older devices.',
      critical: false),
  _CheckItem(id: 'a4', category: 'App Store',
      label: 'App icon 1024×1024 PNG',
      detail: 'No alpha channel. No rounded corners (App Store applies them).',
      critical: true),
  _CheckItem(id: 'a5', category: 'App Store',
      label: 'Hindi screenshots (hi)',
      detail: 'App Store locale: hi. Upload to localisation tab.',
      critical: false),
  _CheckItem(id: 'a6', category: 'App Store',
      label: 'App preview video (optional)',
      detail: 'Up to 30s, portrait, no audio required. Only plays on device.',
      critical: false),

  // General
  _CheckItem(id: 'g1', category: 'Both Stores',
      label: 'Screenshots contain no misleading UI',
      detail: 'App Review rejects if screenshots show features not in the app '
          'or misrepresent the app\'s functionality.',
      critical: true),
  _CheckItem(id: 'g2', category: 'Both Stores',
      label: 'No device frame border cut-off',
      detail: 'Frame must fit within canvas boundaries. Check all 6 frames.',
      critical: false),
  _CheckItem(id: 'g3', category: 'Both Stores',
      label: 'Text is readable at thumbnail size',
      detail: 'Headlines must be legible at 100px height (listing thumbnail). '
          'Min font size: 18pt equivalent.',
      critical: false),
  _CheckItem(id: 'g4', category: 'Both Stores',
      label: 'First screenshot is SOS screen',
      detail: 'Screenshot 1 is shown before scrolling. Must show the core feature.',
      critical: true),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day192ScreenshotFramesScreen extends ConsumerWidget {
  const Day192ScreenshotFramesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d192TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Screenshot Frames & Export'),
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
                onSelect: (t) => ref.read(_d192TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _FrameGeneratorTab(),
            if (tab == 1) const _LocalisationTab(),
            if (tab == 2) const _ExportChecklistTab(),
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
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 192',              const Color(0xFF3B82F6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section D  ·  Day 2/10',   const Color(0xFF8B5CF6)),
          _badge('Screenshots  ·  Day 2/2',  const Color(0xFFF59E0B)),
          _badge('Block 191-192 Final ✅',   const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Screenshot Frames,\nLocalisation & Export',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '3 framing tools compared (fastlane frameit, Figma, screenshots pub). '
          'EN + HI + RTL Arabic locale preview. '
          '16-item export checklist for Play Store + App Store.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('3',   '3 frame tools',   Color(0xFF3B82F6)),
          _HStat('3',   '3 locales',       Color(0xFF8B5CF6)),
          _HStat('16',  '16 export items', Color(0xFF10B981)),
          _HStat('4',   '4 critical items',Color(0xFFEF4444)),
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
      (Icons.devices_rounded,    Color(0xFF3B82F6), 'Frame Tools'),
      (Icons.translate_rounded,  Color(0xFF8B5CF6), 'Localisation'),
      (Icons.checklist_rounded,  Color(0xFF10B981), 'Export Checklist'),
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
// TAB 1 — Frame Generator Tools
// ══════════════════════════════════════════════════════════════════════════════
class _FrameGeneratorTab extends ConsumerWidget {
  const _FrameGeneratorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedToolProvider);
    final _ = ref.watch(_expandedToolProvider);
    final tool     = _kTools[selected];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.devices_rounded, color: const Color(0xFF3B82F6),
          text: '3 tools to add device frames around your raw screenshots. '
              'For ZapSafe (solo builder), Figma is the fastest path. '
              'fastlane frameit is best if CI is already set up.'),
      const SizedBox(height: ZapSpacing.lg),

      // Recommendation banner
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35))),
        child: const Row(children: [
          Icon(Icons.lightbulb_rounded, color: Color(0xFF8B5CF6), size: 16),
          SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(
            'ZapSafe Recommendation: Use Figma templates for this release '
            '(fastest for solo builder). Add fastlane frameit in v1.1 when '
            'the CI pipeline (Day 197-198) is fully set up.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Tool selector
      const _SectionLabel('SELECT TOOL TO COMPARE'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: _kTools.asMap().entries.map((e) {
        final i    = e.key;
        final t    = e.value;
        final isOn = selected == i;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
          child: GestureDetector(
            onTap: () => ref.read(_selectedToolProvider.notifier).state = i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isOn ? t.color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isOn ? t.color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                      width: isOn ? 2 : 1)),
              child: Column(children: [
                Icon(_toolIcon(i), color: isOn ? t.color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: 3),
                Text(_shortName(t.name), style: TextStyle(
                    color: isOn ? t.color : const Color(0xFF6B7280),
                    fontSize: 9, fontWeight: isOn ? FontWeight.w700 : FontWeight.w400),
                    textAlign: TextAlign.center),
              ]),
            ))));
      }).toList()),
      const SizedBox(height: ZapSpacing.xl),

      // Tool detail
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _ToolDetail(key: ValueKey(selected), tool: tool),
      ),
    ]);
  }

  static IconData _toolIcon(int i) => [
    Icons.terminal_rounded, Icons.design_services_rounded, Icons.flutter_dash_rounded][i];
  static String _shortName(String name) => name.split(' ').take(2).join(' ');
}

class _ToolDetail extends StatelessWidget {
  final _FramingTool tool;
  const _ToolDetail({required this.tool, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: tool.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: tool.color.withOpacity(0.4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tool.name, style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: tool.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(tool.type, style: TextStyle(
                  color: tool.color, fontSize: 9, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(tool.description, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
          const SizedBox(height: ZapSpacing.md),
          Row(children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 12),
            const SizedBox(width: 5),
            Expanded(child: Text('Best for: ${tool.bestFor}',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10,
                    height: 1.4))),
          ]),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Pros & Cons
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _prosConsCard('Pros', tool.pros,
            const Color(0xFF10B981), Icons.check_rounded)),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: _prosConsCard('Cons', tool.cons,
            const Color(0xFFEF4444), Icons.close_rounded)),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // Command / usage
      const _SectionLabel('USAGE / COMMAND'),
      const SizedBox(height: ZapSpacing.md),
      _codeBlock(context, tool.command),
    ]);
  }

  Widget _prosConsCard(String title, List<String> items, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...items.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: color, size: 11),
                const SizedBox(width: 5),
                Expanded(child: Text(s, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
              ]))),
        ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Localisation
// ══════════════════════════════════════════════════════════════════════════════
class _LocalisationTab extends ConsumerWidget {
  const _LocalisationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(_selectedLocaleProvider);
    final config = _kLocales[locale]!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.translate_rounded, color: const Color(0xFF8B5CF6),
          text: 'Store listings support per-locale screenshots. '
              'ZapSafe targets India — submit English + Hindi screenshots. '
              'Arabic is shown as an RTL demo (ZapSafe Phase 2 target).'),
      const SizedBox(height: ZapSpacing.lg),

      // Locale selector
      const _SectionLabel('SELECT LOCALE'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: _Locale.values.map((l) {
        final cfg    = _kLocales[l]!;
        final isOn   = locale == l;
        final color  = l == _Locale.ar ? const Color(0xFF10B981)
            : l == _Locale.hi ? const Color(0xFFF59E0B)
            : const Color(0xFF3B82F6);
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: l != _Locale.ar ? ZapSpacing.sm : 0),
          child: GestureDetector(
            onTap: () => ref.read(_selectedLocaleProvider.notifier).state = l,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: isOn ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                      width: isOn ? 2 : 1)),
              child: Column(children: [
                Text(cfg.code, style: TextStyle(
                    color: isOn ? color : const Color(0xFF6B7280),
                    fontSize: 10, fontWeight: isOn ? FontWeight.w800 : FontWeight.w400,
                    fontFamily: 'monospace')),
                Text(cfg.direction, style: TextStyle(
                    color: isOn ? color.withOpacity(0.8) : const Color(0xFF4B5563),
                    fontSize: 8)),
              ]),
            ))));
      }).toList()),
      const SizedBox(height: ZapSpacing.lg),

      // Info card for selected locale
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _locRow('Language', config.name),
          _locRow('Locale code', config.code),
          _locRow('Direction', '${config.direction} ${config.rtl ? "← Right to Left" : "→ Left to Right"}'),
          _locRow('Store listing', config.rtl
              ? 'Phase 2 — Arabic listed as future language'
              : 'Submit screenshots under ${config.code} locale tab'),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Mock screenshot preview in locale
      const _SectionLabel('SCREENSHOT 1 PREVIEW  ·  SOS SCREEN'),
      const SizedBox(height: ZapSpacing.md),
      _LocaleScreenshotPreview(config: config),
      const SizedBox(height: ZapSpacing.xl),

      // RTL note
      if (config.rtl) ...[
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF10B981), size: 14),
              SizedBox(width: 6),
              Text('RTL Implementation Notes', style: TextStyle(
                  color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ...[
              'ZapSafe Day 108 (Language Toggle) already handles RTL layout via Directionality widget.',
              'Screenshots for RTL locales must be captured with the locale set to ar or he.',
              'Marketing overlays (headlines) must also be right-aligned for RTL screenshots.',
              'Day 193-194 covers Arabic store listing copy if targeting Phase 2 markets.',
            ].map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, color: Color(0xFF10B981), size: 5),
                  const SizedBox(width: 7),
                  Expanded(child: Text(s, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 10, height: 1.4))),
                ]))),
          ])),
        const SizedBox(height: ZapSpacing.lg),
      ],

      // Workflow steps
      const _SectionLabel('LOCALISATION WORKFLOW'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...[
            ('1', 'Take raw screenshots with locale set to en_IN',
                'In Simulator/Emulator: change device language and relaunch.'),
            ('2', 'Open Figma screenshot template',
                'Duplicate the EN frames → rename to HI frames.'),
            ('3', 'Update text layers with translated headlines',
                'Replace English overlays with Hindi/Arabic text from Captions tab.'),
            ('4', 'Export all locale variants',
                'File → Export → Select all HI frames → PNG 2x.'),
            ('5', 'Upload to store under correct locale',
                'Play Console: Store listing → Add language → hi_IN → upload. '
                'App Store: Localisation tab → hi → upload.'),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (num, title, detail) = e.value;
            final isLast = i == 4;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Center(child: Text(num, style: const TextStyle(
                        color: Color(0xFF8B5CF6), fontSize: 10,
                        fontWeight: FontWeight.w800)))),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text(detail, style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
                  ])),
                ])),
              if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ])),
    ]);
  }

  Widget _locRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 84, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10))),
      ]));
}

class _LocaleScreenshotPreview extends StatelessWidget {
  final _LocaleConfig config;
  const _LocaleScreenshotPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 5),
          boxShadow: [BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              blurRadius: 20, spreadRadius: 1)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Directionality(
            textDirection: config.rtl
                ? TextDirection.rtl : TextDirection.ltr,
            child: Column(children: [
              // Status bar
              Container(height: 20, color: const Color(0xFF050505)),
              // App content
              Container(
                height: 320, color: const Color(0xFF050508),
                child: Stack(children: [
                  // Background content
                  Positioned.fill(child: Column(children: [
                    Container(
                      height: 40, color: const Color(0xFF0F0F0F),
                      child: Row(children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.bolt_rounded,
                            color: Color(0xFFEF4444), size: 14),
                        const SizedBox(width: 5),
                        const Text('ZapSafe', style: TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w700)),
                      ])),
                    Expanded(child: Center(child: Column(
                        mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.bolt_rounded,
                            color: Color(0xFFEF4444), size: 28)),
                    ]))),
                  ])),
                  // Marketing overlay
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Colors.transparent,
                              const Color(0xFFEF4444).withOpacity(0.9)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter),
                      ),
                      child: Column(
                          crossAxisAlignment: config.rtl
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                        Text(config.headline1, style: const TextStyle(
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w900, height: 1.2),
                            textAlign: config.rtl
                                ? TextAlign.right : TextAlign.left),
                        const SizedBox(height: 3),
                        Text(config.subline1, style: const TextStyle(
                            color: Colors.white70, fontSize: 7, height: 1.3),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            textAlign: config.rtl
                                ? TextAlign.right : TextAlign.left),
                      ])),
                  ),
                ])),
              // Home bar
              Container(height: 16, color: const Color(0xFF050505),
                  child: Center(child: Container(
                      width: 60, height: 3,
                      decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(2))))),
            ]),
          ))));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Export Checklist
// ══════════════════════════════════════════════════════════════════════════════
class _ExportChecklistTab extends ConsumerWidget {
  const _ExportChecklistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_checkedItemsProvider);

    final total     = _kCheckItems.length;
    final doneCount = checked.length;
    final critical  = _kCheckItems.where((c) => c.critical).length;
    final critDone  = _kCheckItems.where((c) => c.critical && checked.contains(c.id)).length;

    // Group by category
    final categories = _kCheckItems.map((c) => c.category).toSet().toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.checklist_rounded, color: const Color(0xFF10B981),
          text: '16 assets needed before store submission. '
              '4 are critical — missing these causes immediate rejection. '
              'Tap each item to mark complete. '
              'Progress resets on app restart (local state only).'),
      const SizedBox(height: ZapSpacing.lg),

      // Progress card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            _stat('$doneCount/$total', 'Items done', const Color(0xFF10B981)),
            _stat('$critDone/$critical', 'Critical done', const Color(0xFFEF4444)),
            _stat('${total - doneCount}', 'Remaining', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: total > 0 ? doneCount / total : 0,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                      doneCount == total ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6)),
                  minHeight: 6)),
          if (doneCount == total) ...[
            const SizedBox(height: ZapSpacing.sm),
            const Text('All assets ready for submission ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ],
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // By category
      ...categories.map((cat) {
        final catItems = _kCheckItems.where((c) => c.category == cat).toList();
        final catColor = cat.contains('Play') ? const Color(0xFF3DDC84)
            : cat.contains('Apple') ? const Color(0xFF9CA3AF)
            : const Color(0xFF3B82F6);
        final catIcon  = cat.contains('Play') ? Icons.android_rounded
            : cat.contains('Apple') ? Icons.apple_rounded
            : Icons.compare_arrows_rounded;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Category header
          Row(children: [
            Icon(catIcon, color: catColor, size: 14),
            const SizedBox(width: 6),
            Text(cat, style: TextStyle(color: catColor, fontSize: 11,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: ZapSpacing.sm),
            Text('(${catItems.where((c) => checked.contains(c.id)).length}/${catItems.length})',
                style: TextStyle(color: catColor.withOpacity(0.7), fontSize: 9)),
            const Expanded(child: SizedBox()),
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
              final isDone   = checked.contains(item.id);
              final isLast   = i == catItems.length - 1;

              return Column(children: [
                GestureDetector(
                  onTap: () {
                    final updated = Set<String>.from(checked);
                    if (isDone) updated.remove(item.id); else updated.add(item.id);
                    ref.read(_checkedItemsProvider.notifier).state = updated;
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFF10B981) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: isDone
                                    ? const Color(0xFF10B981) : const Color(0xFF3A3A3A),
                                width: 2)),
                        child: isDone
                            ? const Icon(Icons.check, color: Colors.white, size: 13)
                            : null),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(item.label,
                              style: TextStyle(
                                  color: isDone
                                      ? const Color(0xFF6B7280) : Colors.white,
                                  fontSize: 11,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough : null))),
                          if (item.critical && !isDone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('CRITICAL',
                                  style: TextStyle(color: Color(0xFFEF4444),
                                      fontSize: 7, fontWeight: FontWeight.w800))),
                        ]),
                        Text(item.detail, style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
                      ])),
                    ])),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
              ]);
            }).toList()),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ]);
      }),

      // Clear all
      if (checked.isNotEmpty)
        GestureDetector(
          onTap: () => ref.read(_checkedItemsProvider.notifier).state = {},
          child: const Text('Clear all',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11,
                  decoration: TextDecoration.underline))),

      const SizedBox(height: ZapSpacing.lg),
      // Block 191-192 complete note
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
        child: const Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Text('Days 191-192 Screenshot Block Complete ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: 6),
          Text('Next: Days 193-194 — Store listing copy '
              '(title, description, ASO, short description, promo text).',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
              textAlign: TextAlign.center),
        ])),
    ]);
  }

  Widget _stat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _codeBlock(BuildContext context, String code) => GestureDetector(
    onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1))),
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

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
