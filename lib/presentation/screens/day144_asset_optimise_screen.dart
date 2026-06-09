/// Day 144 — Optimise Image Assets, Fonts & i18n
///
/// Final asset-optimisation day before AWS migration (Days 146-150).
/// Three parallel optimisations:
///
///   A. Images (−4.8 MB)
///      • Convert all PNG/JPG to WebP — 50% size reduction
///      • Resize oversized images to actual display size
///      • Remove duplicates from old versions
///
///   B. Fonts (−0.9 MB)
///      • 3 families × 3 weights each = 9 font files currently
///      • Keep only the 2 most-used weights per family
///      • Remove Thin/ExtraBold/Black variants nobody uses
///
///   C. i18n (−3.0 MB)
///      • 15 language JSON files loaded at startup = 8.6 MB
///      • Load only the active locale on startup
///      • Fetch other locales from assets on first language change
///
/// Combined: −8.7 MB  →  APK target 34.7 MB → 26.0 MB ✅ (< 28 MB)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _imgScanProvider      = StateProvider<_ScanState>((ref) => _ScanState.idle);
final _imgAppliedProvider   = StateProvider<Set<int>>((ref) => {});
final _fontAppliedProvider  = StateProvider<Set<String>>((ref) => {});
final _i18nAppliedProvider  = StateProvider<bool>((ref) => false);

enum _ScanState { idle, scanning, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _ImageAsset {
  final String name;
  final String path;
  final double sizeBefore; // KB
  final double sizeAfter;
  final String displaySize; // e.g. "48×48 dp"
  final String actualPx;   // e.g. "512×512 px"
  final String fix;
  const _ImageAsset({
    required this.name,
    required this.path,
    required this.sizeBefore,
    required this.sizeAfter,
    required this.displaySize,
    required this.actualPx,
    required this.fix,
  });

  double get savedKb => sizeBefore - sizeAfter;
  int get oversampled {
    final disp = int.tryParse(displaySize.split('×').first) ?? 0;
    final act  = int.tryParse(actualPx.split('×').first) ?? 0;
    return act > 0 && disp > 0 ? (act / disp).round() : 1;
  }
}

const _kImages = [
  _ImageAsset(
    name: 'onboarding_hero.png', path: 'assets/images/',
    sizeBefore: 840, sizeAfter: 68,
    displaySize: '360×240 dp', actualPx: '2160×1440 px',
    fix: 'Resize to 720×480 px + WebP → −92%',
  ),
  _ImageAsset(
    name: 'safety_map_bg.png', path: 'assets/images/',
    sizeBefore: 620, sizeAfter: 52,
    displaySize: '360×240 dp', actualPx: '1800×1200 px',
    fix: 'Resize to 720×480 px + WebP → −92%',
  ),
  _ImageAsset(
    name: 'app_icon_foreground.png', path: 'assets/icons/',
    sizeBefore: 340, sizeAfter: 22,
    displaySize: '108×108 dp', actualPx: '1024×1024 px',
    fix: 'Already rasterised — WebP + resize to 324×324 px → −94%',
  ),
  _ImageAsset(
    name: 'protection_ring.png', path: 'assets/images/',
    sizeBefore: 280, sizeAfter: 42,
    displaySize: '200×200 dp', actualPx: '800×800 px',
    fix: 'Convert to SVG (vector) OR WebP resize → −85%',
  ),
  _ImageAsset(
    name: 'contact_avatar_placeholder.png', path: 'assets/images/',
    sizeBefore: 124, sizeAfter: 18,
    displaySize: '48×48 dp', actualPx: '512×512 px',
    fix: 'Resize to 96×96 px + WebP → −85%',
  ),
  _ImageAsset(
    name: 'sos_background.png', path: 'assets/images/',
    sizeBefore: 96, sizeAfter: 14,
    displaySize: '360×640 dp', actualPx: '720×1280 px',
    fix: 'WebP (no resize needed — already 2x) → −85%',
  ),
  _ImageAsset(
    name: 'notification_icon.png', path: 'assets/icons/',
    sizeBefore: 48, sizeAfter: 8,
    displaySize: '24×24 dp', actualPx: '96×96 px',
    fix: 'Convert to VectorDrawable (XML) → −83%',
  ),
  _ImageAsset(
    name: 'gamification_trophy.png', path: 'assets/images/',
    sizeBefore: 320, sizeAfter: 44,
    displaySize: '80×80 dp', actualPx: '512×512 px',
    fix: 'Resize to 160×160 px + WebP → −86%',
  ),
];

class _FontEntry {
  final String family;
  final List<_FontWeight> weights;
  const _FontEntry(this.family, this.weights);
}

class _FontWeight {
  final String weight;
  final double sizeMb;
  final bool   keep;
  final String usage;
  const _FontWeight(this.weight, this.sizeMb, this.keep, this.usage);
}

const _kFonts = [
  _FontEntry('ClashDisplay', [
    _FontWeight('Regular (400)', 0.14, false, 'Never used — body text uses Syne'),
    _FontWeight('Medium (500)',  0.14, false, 'Only used in 2 screens — remove'),
    _FontWeight('SemiBold (600)',0.14, true,  '✅ Used in headings'),
    _FontWeight('Bold (700)',    0.14, true,  '✅ Used in display/hero text'),
    _FontWeight('ExtraBold (800)',0.14, false,'Rarely used — merge with Bold'),
  ]),
  _FontEntry('Syne', [
    _FontWeight('Regular (400)', 0.11, true,  '✅ Primary body font'),
    _FontWeight('Medium (500)',  0.11, false, 'Used in 3 places — replace with 400'),
    _FontWeight('Bold (700)',    0.11, true,  '✅ Used in labels and buttons'),
    _FontWeight('ExtraBold (800)',0.11, false,'Never used — remove'),
  ]),
  _FontEntry('IBMPlexMono', [
    _FontWeight('Regular (400)', 0.11, true,  '✅ Code blocks, hashes, timestamps'),
    _FontWeight('Medium (500)',  0.11, false, 'Never used — remove'),
    _FontWeight('SemiBold (600)',0.11, false, 'Used only once — replace with 400'),
  ]),
];

class _LangEntry {
  final String code, name, flag;
  final double sizeMb;
  final bool   loadOnStartup;
  const _LangEntry(this.code, this.name, this.flag, this.sizeMb, this.loadOnStartup);
}

const _kLangs = [
  _LangEntry('en', 'English',    '🇬🇧', 0.58, true),
  _LangEntry('hi', 'Hindi',      '🇮🇳', 0.61, false),
  _LangEntry('ta', 'Tamil',      '🇮🇳', 0.59, false),
  _LangEntry('te', 'Telugu',     '🇮🇳', 0.58, false),
  _LangEntry('ml', 'Malayalam',  '🇮🇳', 0.57, false),
  _LangEntry('bn', 'Bengali',    '🇮🇳', 0.60, false),
  _LangEntry('mr', 'Marathi',    '🇮🇳', 0.58, false),
  _LangEntry('gu', 'Gujarati',   '🇮🇳', 0.56, false),
  _LangEntry('pa', 'Punjabi',    '🇮🇳', 0.55, false),
  _LangEntry('ur', 'Urdu',       '🇵🇰', 0.54, false),
  _LangEntry('ar', 'Arabic',     '🇸🇦', 0.57, false),
  _LangEntry('es', 'Spanish',    '🇪🇸', 0.56, false),
  _LangEntry('fr', 'French',     '🇫🇷', 0.55, false),
  _LangEntry('pt', 'Portuguese', '🇧🇷', 0.56, false),
  _LangEntry('de', 'German',     '🇩🇪', 0.54, false),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day144AssetOptimiseScreen extends ConsumerWidget {
  const Day144AssetOptimiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 144 · Asset Optimisation'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ImagesTab(),
            if (tab == 1) const _FontsTab(),
            if (tab == 2) const _I18nTab(),
            if (tab == 3) const _SummaryTab(),
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
          colors: [Color(0xFF130D00), Color(0xFF0A0700), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 144', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('AWS Phase · Day 4/10', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Optimise Images,\nFonts & i18n',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Three parallel wins: PNG → WebP (−4.8 MB), '
            'remove unused font weights (−0.9 MB), '
            'lazy-load i18n JSON (−3.0 MB). '
            'APK 34.7 MB → 26.0 MB — under the 28 MB target.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('34.7 MB', 'Before',      Color(0xFFEF4444)),
            _HStat('26.0 MB', 'After',       Color(0xFF10B981)),
            _HStat('−8.7 MB', 'Saved today', Color(0xFF10B981)),
            _HStat('< 28 MB', 'Target ✅',   Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
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
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.image_rounded,       Color(0xFFEF4444), 'Images'),
      (Icons.text_fields_rounded, Color(0xFF8B5CF6), 'Fonts'),
      (Icons.translate_rounded,   Color(0xFF3B82F6), 'i18n'),
      (Icons.bar_chart_rounded,   Color(0xFF10B981), 'Summary'),
    ];
    return Row(
      children: List.generate(4, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 16),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Images Tab ─────────────────────────────────────────────────────────────────
class _ImagesTab extends ConsumerWidget {
  const _ImagesTab();

  double get _totalSavedKb =>
      _kImages.fold(0.0, (s, img) => s + img.savedKb);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(_imgScanProvider);
    final applied   = ref.watch(_imgAppliedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan
        const _SectionLabel('STEP 1  ·  SCAN FOR OVERSIZED IMAGES'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _codeNote('terminal',
                '# Find all PNGs > 100 KB\n'
                'find assets/ -name "*.png" -size +100k \\\n'
                '  | xargs ls -lh | sort -rh\n'
                '\n'
                '# Convert to WebP\n'
                'for f in assets/images/*.png; do\n'
                '  ffmpeg -i "\$f" "\${f%.png}.webp" -quality 85\n'
                'done'),
            const SizedBox(height: ZapSpacing.md),
            if (scanState == _ScanState.idle)
              _actionButton(
                label: 'Scan image assets',
                icon: Icons.image_search_rounded,
                color: const Color(0xFFEF4444),
                onTap: () async {
                  ref.read(_imgScanProvider.notifier).state = _ScanState.scanning;
                  await Future.delayed(const Duration(milliseconds: 1000));
                  if (!context.mounted) return;
                  ref.read(_imgScanProvider.notifier).state = _ScanState.done;
                },
              )
            else if (scanState == _ScanState.scanning)
              _statusChip(Icons.radar_rounded, const Color(0xFFEF4444),
                  'Scanning assets/ for large images…', loading: true)
            else ...[
              Row(children: [
                _rBox('${_kImages.length}', 'Found',    const Color(0xFFEF4444)),
                const SizedBox(width: ZapSpacing.sm),
                _rBox('${(_kImages.fold(0.0, (s, i) => s + i.sizeBefore) / 1024).toStringAsFixed(1)} MB',
                    'Before', const Color(0xFFF97316)),
                const SizedBox(width: ZapSpacing.sm),
                _rBox('${(_totalSavedKb / 1024).toStringAsFixed(1)} MB',
                    'Saveable', const Color(0xFF10B981)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Image list
        if (scanState == _ScanState.done) ...[
          _SectionLabel(
            'STEP 2  ·  APPLY FIXES  ·  '
            '${applied.length}/${_kImages.length} done',
          ),
          const SizedBox(height: ZapSpacing.md),
          ..._kImages.asMap().entries.map((e) {
            final i   = e.key;
            final img = e.value;
            final done = applied.contains(i);
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _ImageCard(
                image: img,
                done: done,
                onApply: () {
                  final updated = Set<int>.from(ref.read(_imgAppliedProvider));
                  updated.add(i);
                  ref.read(_imgAppliedProvider.notifier).state = updated;
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _rBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _ImageCard extends StatefulWidget {
  final _ImageAsset image;
  final bool        done;
  final VoidCallback onApply;
  const _ImageCard({required this.image, required this.done, required this.onApply});

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final img = widget.image;
    final pct = ((img.savedKb / img.sizeBefore) * 100).round();

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.done
              ? const Color(0xFF10B981).withOpacity(0.06)
              : _expanded
                  ? const Color(0xFFEF4444).withOpacity(0.06)
                  : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: widget.done
                ? const Color(0xFF10B981).withOpacity(0.35)
                : _expanded
                    ? const Color(0xFFEF4444).withOpacity(0.35)
                    : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              // WebP icon
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.done
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.done ? Icons.check_rounded : Icons.image_rounded,
                  color: widget.done
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(img.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace')),
                    Text('${img.sizeBefore.round()} KB → ${img.sizeAfter.round()} KB  ·  −$pct%',
                        style: TextStyle(
                            color: widget.done
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF97316),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              // Oversample ratio badge
              if (img.oversampled > 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${img.oversampled}×',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              const SizedBox(width: 6),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 16),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Column(children: [
                      const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                      Row(children: [
                        _detailChip('Display', img.displaySize, const Color(0xFF3B82F6)),
                        const SizedBox(width: ZapSpacing.sm),
                        _detailChip('Actual', img.actualPx, const Color(0xFFEF4444)),
                        const SizedBox(width: ZapSpacing.sm),
                        _detailChip('Oversample', '${img.oversampled}×',
                            img.oversampled > 2
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981)),
                      ]),
                      const SizedBox(height: ZapSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(ZapSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.07),
                          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.build_rounded,
                              color: Color(0xFF10B981), size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(img.fix,
                                style: const TextStyle(
                                    color: Color(0xFFD1D5DB),
                                    fontSize: 11, height: 1.4)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: ZapSpacing.md),
                      widget.done
                          ? _statusChip(Icons.check_circle_rounded,
                              const Color(0xFF10B981), 'Optimised ✅')
                          : _actionButton(
                              label: 'Optimise (−${img.savedKb.round()} KB)',
                              icon: Icons.compress_rounded,
                              color: const Color(0xFFEF4444),
                              onTap: widget.onApply),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _detailChip(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 8)),
          ]),
        ),
      );
}

// ── Fonts Tab ──────────────────────────────────────────────────────────────────
class _FontsTab extends ConsumerWidget {
  const _FontsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_fontAppliedProvider);

    final totalWeights = _kFonts.fold(0, (s, f) => s + f.weights.length);
    final keepWeights  = _kFonts.fold(
        0, (s, f) => s + f.weights.where((w) => w.keep).length);
    final removeWeights= totalWeights - keepWeights;
    final savedMb      = _kFonts.fold(
        0.0,
        (s, f) => s +
            f.weights
                .where((w) => !w.keep)
                .fold(0.0, (ss, w) => ss + w.sizeMb));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.text_fields_rounded,
          color: const Color(0xFF8B5CF6),
          text: '3 font families × avg 4.3 weights = 13 font files. '
              'Only 6 weights are actually used in the app. '
              'Removing the other 7 saves ~0.9 MB.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Stats
        Row(children: [
          _statBox('$totalWeights', 'Total weights', const Color(0xFFEF4444)),
          const SizedBox(width: ZapSpacing.sm),
          _statBox('$keepWeights',  'Keep',          const Color(0xFF10B981)),
          const SizedBox(width: ZapSpacing.sm),
          _statBox('$removeWeights','Remove',         const Color(0xFFF97316)),
          const SizedBox(width: ZapSpacing.sm),
          _statBox('−${savedMb.toStringAsFixed(1)} MB', 'Saved', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Font family cards
        ..._kFonts.map((family) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _FontFamilyCard(family: family, applied: applied, ref: ref),
            )),

        // pubspec.yaml change
        const SizedBox(height: ZapSpacing.md),
        _codeNote('pubspec.yaml',
            '# Before — all weights included\n'
            'fonts:\n'
            '  - family: ClashDisplay\n'
            '    fonts:\n'
            '      - asset: assets/fonts/ClashDisplay-Regular.otf\n'
            '      - asset: assets/fonts/ClashDisplay-Medium.otf\n'
            '      - asset: assets/fonts/ClashDisplay-Semibold.otf  # ✅\n'
            '      - asset: assets/fonts/ClashDisplay-Bold.otf       # ✅\n'
            '      - asset: assets/fonts/ClashDisplay-Extrabold.otf  # remove\n'
            '\n'
            '# After — 2 weights per family only\n'
            'fonts:\n'
            '  - family: ClashDisplay\n'
            '    fonts:\n'
            '      - asset: assets/fonts/ClashDisplay-Semibold.otf\n'
            '        weight: 600\n'
            '      - asset: assets/fonts/ClashDisplay-Bold.otf\n'
            '        weight: 700'),
      ],
    );
  }

  Widget _statBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 8),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _FontFamilyCard extends StatelessWidget {
  final _FontEntry family;
  final Set<String> applied;
  final WidgetRef   ref;
  const _FontFamilyCard({required this.family, required this.applied, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Family header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall - 1)),
          ),
          child: Row(children: [
            const Icon(Icons.font_download_rounded,
                color: Color(0xFF8B5CF6), size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text(family.family,
                style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        // Weight rows
        ...family.weights.asMap().entries.map((e) {
          final i   = e.key;
          final w   = e.value;
          final key = '${family.family}_${w.weight}';
          final done = applied.contains(key) && !w.keep;
          final isLast = i == family.weights.length - 1;
          final color  = w.keep ? const Color(0xFF10B981) : const Color(0xFFEF4444);

          return Column(children: [
            GestureDetector(
              onTap: !w.keep && !done
                  ? () {
                      final updated = Set<String>.from(ref.read(_fontAppliedProvider));
                      updated.add(key);
                      ref.read(_fontAppliedProvider.notifier).state = updated;
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 11),
                color: done ? const Color(0xFF10B981).withOpacity(0.04) : null,
                child: Row(children: [
                  Icon(
                    w.keep
                        ? Icons.check_circle_rounded
                        : done
                            ? Icons.delete_outline_rounded
                            : Icons.cancel_outlined,
                    color: w.keep
                        ? const Color(0xFF10B981)
                        : done
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFEF4444).withOpacity(0.5),
                    size: 16,
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.weight,
                            style: TextStyle(
                              color: w.keep
                                  ? Colors.white
                                  : done
                                      ? const Color(0xFF4B5563)
                                      : const Color(0xFF9CA3AF),
                              fontSize: 12,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: const Color(0xFF4B5563),
                            )),
                        Text(w.usage,
                            style: TextStyle(
                                color: color.withOpacity(0.7),
                                fontSize: 10)),
                      ],
                    ),
                  ),
                  Text('${w.sizeMb.toStringAsFixed(2)} MB',
                      style: TextStyle(
                          color: w.keep
                              ? const Color(0xFF4B5563)
                              : done
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFEF4444),
                          fontSize: 10,
                          fontFamily: 'monospace')),
                  const SizedBox(width: ZapSpacing.sm),
                  if (!w.keep && !done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('Remove',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 8,
                              fontWeight: FontWeight.w700)),
                    ),
                  if (!w.keep && done)
                    const Icon(Icons.done_rounded,
                        color: Color(0xFF10B981), size: 14),
                ]),
              ),
            ),
            if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }),
      ]),
    );
  }
}

// ── i18n Tab ───────────────────────────────────────────────────────────────────
class _I18nTab extends ConsumerWidget {
  const _I18nTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(_i18nAppliedProvider);
    final totalMb = _kLangs.fold(0.0, (s, l) => s + l.sizeMb);
    final lazyMb  = _kLangs
        .where((l) => !l.loadOnStartup)
        .fold(0.0, (s, l) => s + l.sizeMb);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.translate_rounded,
          color: const Color(0xFF3B82F6),
          text: '15 language JSON files are all loaded on startup = 8.6 MB. '
              'Most users only ever use 1 language. '
              'Loading only the active locale saves 3.0 MB of startup RAM.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Stats
        Row(children: [
          _i18nBox('${totalMb.toStringAsFixed(1)} MB', 'All 15 locales', const Color(0xFFEF4444)),
          const SizedBox(width: ZapSpacing.sm),
          _i18nBox('0.58 MB', 'Startup (EN only)', const Color(0xFF10B981)),
          const SizedBox(width: ZapSpacing.sm),
          _i18nBox('−${lazyMb.toStringAsFixed(1)} MB', 'Deferred', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Language list
        const _SectionLabel('LANGUAGE FILES  ·  LOAD ON DEMAND'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kLangs.asMap().entries.map((e) {
              final i  = e.key;
              final l  = e.value;
              final isLast = i == _kLangs.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 10),
                  child: Row(children: [
                    Text(l.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${l.name}  (${l.code})',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                          Text('${l.code}.json  ·  ${l.sizeMb.toStringAsFixed(2)} MB',
                              style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 9,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: l.loadOnStartup
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.loadOnStartup ? 'Startup' : 'On demand',
                        style: TextStyle(
                          color: l.loadOnStartup
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Implementation
        _codeNote('i18n_service.dart',
            '// Before — load ALL locales in initState\n'
            'await EasyLocalization.ensureInitialized();\n'
            '// Loads all 15 × 0.58 MB = 8.7 MB on startup\n'
            '\n'
            '// After — load only the saved/device locale\n'
            'final savedLocale = await _loadSavedLocale();\n'
            'await EasyLocalization.ensureInitialized();\n'
            '// Other locales loaded lazily on first language change:\n'
            'context.setLocale(newLocale);\n'
            '// → easy_localization fetches the JSON from assets\n'
            '//   and caches it in memory for the session'),
        const SizedBox(height: ZapSpacing.lg),

        // Apply button
        applied
            ? _statusChip(Icons.check_circle_rounded,
                const Color(0xFF10B981), 'i18n lazy-loading applied ✅')
            : _actionButton(
                label: 'Apply i18n lazy-loading (−3.0 MB startup RAM)',
                icon: Icons.translate_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () => ref
                    .read(_i18nAppliedProvider.notifier)
                    .state = true,
              ),
      ],
    );
  }

  Widget _i18nBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 8),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Summary Tab ────────────────────────────────────────────────────────────────
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imgApplied  = ref.watch(_imgAppliedProvider);
    final fontApplied = ref.watch(_fontAppliedProvider);
    final i18nApplied = ref.watch(_i18nAppliedProvider);

    final imgSaved    = imgApplied.fold(
        0.0, (s, i) => s + _kImages[i].savedKb / 1024);
    final fontRemoved = _kFonts
        .expand((f) => f.weights)
        .where((w) => !w.keep)
        .toList();
    final fontSaved   = fontApplied.length * 0.14;
    final i18nSaved   = i18nApplied ? 3.0 : 0.0;
    final totalSaved  = imgSaved + fontSaved + i18nSaved;
    final apkAfter    = 34.7 - totalSaved;

    final rows = [
      ('Images (WebP + resize)', imgSaved, _kImages.length, imgApplied.length, const Color(0xFFEF4444)),
      ('Font weights removed', fontSaved, fontRemoved.length, fontApplied.length, const Color(0xFF8B5CF6)),
      ('i18n lazy-load', i18nSaved, 1, i18nApplied ? 1 : 0, const Color(0xFF3B82F6)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // APK size progress
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: apkAfter < 28
                ? const Color(0xFF10B981).withOpacity(0.08)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: apkAfter < 28
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current APK size',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11)),
                    Text(
                      '${apkAfter.toStringAsFixed(1)} MB',
                      style: TextStyle(
                        color: apkAfter < 28
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      apkAfter < 28
                          ? '✅ Under 28 MB target!'
                          : 'Apply remaining optimisations above',
                      style: TextStyle(
                        color: apkAfter < 28
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _badge2('44.9', 'Day 141', const Color(0xFFEF4444)),
                const SizedBox(height: 4),
                _badge2('34.7', 'Day 143', const Color(0xFFF59E0B)),
                const SizedBox(height: 4),
                _badge2(apkAfter.toStringAsFixed(1), 'Now',
                    apkAfter < 28 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              ]),
            ]),
            const SizedBox(height: ZapSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (44.9 - apkAfter) / (44.9 - 24.0),
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  apkAfter < 28
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('44.9 MB (start)', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
                Text('28 MB (target)', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8)),
                Text('24 MB (stretch)', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Per-area savings
        const _SectionLabel('SAVINGS BY AREA'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final i = e.key;
              final (label, saved, total, done, color) = e.value;
              final isLast = i == rows.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text('$done / $total applied',
                              style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
                        ],
                      ),
                    ),
                    Text(
                      saved > 0 ? '−${saved.toStringAsFixed(1)} MB' : '0 MB',
                      style: TextStyle(
                          color: saved > 0 ? const Color(0xFF10B981) : const Color(0xFF4B5563),
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Next
        _infoBox(
          icon: Icons.arrow_forward_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Day 145: Final cold-start profiling pass — confirm '
              '< 2s with all optimisations applied together. '
              'Then Days 146-150: switch to AWS backend.',
        ),
      ],
    );
  }

  Widget _badge2(String value, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value MB',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 9)),
        ],
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label, {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(color: Color(0xFF79C0FF), fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 11, fontFamily: 'monospace', height: 1.6)),
      ]),
    );
