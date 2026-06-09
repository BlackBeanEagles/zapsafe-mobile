/// Day 191 — App Store Screenshots
///
/// First day of Section D: App Store Prep & Polish (Days 191-200).
/// All of Section D is 🟢 FRONTEND-ONLY.
///
/// Day 191: Screenshot plan — 6 hero screens, device frames,
///           store requirements, caption copy.
/// Day 192: Screenshot frames builder — frame overlay generator,
///           localisation + RTL screenshots, asset export checklist.
///
/// 🟢 FRONTEND-ONLY — screenshot planning and caption copy.
///    Actual frame rendering is documented for the designer workflow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d191TabProvider      = StateProvider<int>((ref) => 0);
final _selectedScreenProvider = StateProvider<int>((ref) => 0);
final _storeProvider        = StateProvider<_Store>((ref) => _Store.play);
final _expandedReqProvider  = StateProvider<int?>((ref) => null);

enum _Store { play, apple }

// ── Screenshot definitions ────────────────────────────────────────────────────
class _Screenshot {
  final int    number;
  final String screenName;
  final String headline;     // big marketing headline (overlaid on screenshot)
  final String subline;      // supporting text
  final String whyInclude;   // why this screen should be in the listing
  final Color  accentColor;
  final IconData icon;
  final List<String> keyFeatures;  // bullet points visible in the screenshot
  const _Screenshot({
    required this.number, required this.screenName,
    required this.headline, required this.subline,
    required this.whyInclude, required this.accentColor,
    required this.icon, required this.keyFeatures,
  });
}

const _kScreenshots = [
  _Screenshot(
    number: 1,
    screenName: 'SOS Active Screen (Day 76)',
    headline: 'One tap.\nHelp is on the way.',
    subline: 'SOS dispatches to your emergency contacts in seconds.',
    whyInclude: 'The SOS screen is ZapSafe\'s core value prop — '
        'it must be screenshot 1 to immediately show what the app does.',
    accentColor: Color(0xFFEF4444),
    icon: Icons.bolt_rounded,
    keyFeatures: [
      'Power button × 5 triggers SOS',
      'Contacts notified via push + SMS',
      'Live GPS location shared',
      'Evidence recording starts automatically',
    ],
  ),
  _Screenshot(
    number: 2,
    screenName: 'SOS Active — Contact Delivery (Day 128)',
    headline: 'Know your contacts\ngot the alert.',
    subline: 'Real-time delivery confirmation for every contact.',
    whyInclude: 'Delivery confirmation builds trust — '
        '"What if they don\'t get the message?" is the #1 concern. '
        'Showing delivery badges answers it directly.',
    accentColor: Color(0xFF10B981),
    icon: Icons.done_all_rounded,
    keyFeatures: [
      'Delivered ✅ / Read ✅ / Acknowledged ✅ badges',
      'Push + SMS dual channel',
      'Tier 1 → Tier 2 → auto-escalation',
      'Timestamps for each contact',
    ],
  ),
  _Screenshot(
    number: 3,
    screenName: 'Evidence Vault (Day 82)',
    headline: 'Your evidence,\nsecure and sealed.',
    subline: 'Audio, video, GPS and sensor data — court-ready.',
    whyInclude: 'The evidence vault differentiates ZapSafe from simple SOS apps. '
        'It shows depth and professionalism — key for premium upgrade conversion.',
    accentColor: Color(0xFFF59E0B),
    icon: Icons.lock_rounded,
    keyFeatures: [
      'AES-256 encrypted vault',
      'SHA-256 integrity verification',
      'Audio + GPS + IMU streams',
      'PIN + biometric protected',
    ],
  ),
  _Screenshot(
    number: 4,
    screenName: 'Protection Score (Day 59)',
    headline: 'See your safety\nscore at a glance.',
    subline: 'ZapSafe monitors 7 factors and gives you a live score.',
    whyInclude: 'The protection score gamifies safety and drives engagement. '
        'Screenshots of dashboards with metrics perform well in store A/B tests.',
    accentColor: Color(0xFF3B82F6),
    icon: Icons.shield_rounded,
    keyFeatures: [
      '0-100 protection score',
      'Contact coverage, location, drills',
      'Actionable next steps',
      '30-day history chart',
    ],
  ),
  _Screenshot(
    number: 5,
    screenName: 'Check-in Timers (Day 65)',
    headline: 'If you don\'t check in,\nwe check on you.',
    subline: 'Dead-man\'s switch — your contacts are notified automatically.',
    whyInclude: 'Check-in timers appeal to solo travellers, night-shift workers, '
        'and students — a large addressable market. Shows proactive safety.',
    accentColor: Color(0xFF8B5CF6),
    icon: Icons.timer_rounded,
    keyFeatures: [
      'Custom countdown timers',
      'Auto-escalation on expiry',
      'Pause / extend / cancel',
      'Works offline',
    ],
  ),
  _Screenshot(
    number: 6,
    screenName: 'Emergency Contacts (Day 83)',
    headline: 'Build your\nsafety network.',
    subline: 'Tier 1 → 2 → 3 escalation. Contacts you can count on.',
    whyInclude: 'Contact setup is the first major action after install. '
        'Showing it reassures users the setup is easy and structured.',
    accentColor: Color(0xFF10B981),
    icon: Icons.people_rounded,
    keyFeatures: [
      'Tier 1 / 2 / 3 hierarchy',
      'Verification badges',
      'Smart escalation order',
      'Up to ∞ Tier 3 contacts',
    ],
  ),
];

// ── Store requirements ────────────────────────────────────────────────────────
class _StoreReq {
  final String store, field, value, note;
  const _StoreReq({required this.store, required this.field,
      required this.value, required this.note});
}

const _kPlayReqs = [
  _StoreReq(store: 'Play', field: 'Min screenshots', value: '2',
      note: 'Aim for 6-8 to tell a complete story.'),
  _StoreReq(store: 'Play', field: 'Max screenshots', value: '8',
      note: 'Play Store shows all 8 in the listing gallery.'),
  _StoreReq(store: 'Play', field: 'Format', value: 'PNG or JPEG',
      note: 'PNG preferred — lossless for text clarity.'),
  _StoreReq(store: 'Play', field: 'Phone dimensions', value: '1080 × 1920 px (portrait)',
      note: 'Minimum 320 px on each side. 16:9 or 9:16 ratio.'),
  _StoreReq(store: 'Play', field: 'Tablet dimensions', value: '1200 × 1920 px',
      note: 'Recommended but not required for phone-only apps.'),
  _StoreReq(store: 'Play', field: 'Max file size', value: '8 MB per image',
      note: 'Keep under 2 MB for fast loading in the listing.'),
  _StoreReq(store: 'Play', field: 'Overlay text allowed', value: 'YES',
      note: 'Google allows marketing overlays and device frames.'),
  _StoreReq(store: 'Play', field: 'Promotional graphic', value: '1024 × 500 px',
      note: 'Feature graphic — shown at the top of the listing.'),
];

const _kAppleReqs = [
  _StoreReq(store: 'Apple', field: 'Min screenshots', value: '3',
      note: 'First 3 are visible without scrolling — make them count.'),
  _StoreReq(store: 'Apple', field: 'Max screenshots', value: '10',
      note: 'Per device type. iPhone and iPad slots are separate.'),
  _StoreReq(store: 'Apple', field: 'Format', value: 'PNG or JPEG',
      note: 'No alpha channel on JPEG. PNG recommended.'),
  _StoreReq(store: 'Apple', field: '6.9" (iPhone 16 Plus)', value: '1320 × 2868 px',
      note: 'Required slot — covers all large iPhone sizes.'),
  _StoreReq(store: 'Apple', field: '6.5" (iPhone 14 Plus)', value: '1284 × 2778 px',
      note: 'Required if 6.9" not provided.'),
  _StoreReq(store: 'Apple', field: '5.5" (iPhone 8 Plus)', value: '1242 × 2208 px',
      note: 'Legacy slot — covers older devices.'),
  _StoreReq(store: 'Apple', field: 'Max file size', value: '500 KB per image',
      note: 'Much stricter than Play Store — optimise carefully.'),
  _StoreReq(store: 'Apple', field: 'Overlay text allowed', value: 'YES (guidelines)',
      note: 'Allowed but App Review rejects misleading overlays.'),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day191ScreenshotsScreen extends ConsumerWidget {
  const Day191ScreenshotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d191TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('App Store Screenshots'),
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
                onSelect: (t) => ref.read(_d191TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _GalleryTab(),
            if (tab == 1) const _RequirementsTab(),
            if (tab == 2) const _CaptionsTab(),
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
          _badge('⚡  DAY 191',             const Color(0xFF3B82F6)),
          _badge('🟢 FRONTEND-ONLY',        const Color(0xFF10B981)),
          _badge('Section D  ·  Day 1/10',  const Color(0xFF8B5CF6)),
          _badge('Screenshots  ·  Day 1/2', const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('App Store\nScreenshots',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '6 hero screens selected for Play Store + App Store. '
          'Each has a marketing headline, supporting copy, '
          'key features list, and "why include" rationale. '
          'Store specs for both platforms documented.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('6',    '6 screenshots',  Color(0xFF3B82F6)),
          _HStat('2',    '2 stores',       Color(0xFF10B981)),
          _HStat('8',    '8 Play specs',   Color(0xFF3DDC84)),
          _HStat('8',    '8 Apple specs',  Color(0xFF9CA3AF)),
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
      (Icons.photo_library_rounded, Color(0xFF3B82F6), 'Gallery'),
      (Icons.rule_rounded,          Color(0xFF10B981), 'Requirements'),
      (Icons.text_fields_rounded,   Color(0xFF8B5CF6), 'Captions'),
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
// TAB 1 — Gallery
// ══════════════════════════════════════════════════════════════════════════════
class _GalleryTab extends ConsumerWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedScreenProvider);
    final shot     = _kScreenshots[selected];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.photo_library_rounded, color: const Color(0xFF3B82F6),
          text: '6 screens selected for the store listing. '
              'Tap any thumbnail to preview the marketing frame. '
              'First screenshot is the most important — it\'s visible before scrolling.'),
      const SizedBox(height: ZapSpacing.lg),

      // Thumbnail strip
      SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _kScreenshots.length,
          separatorBuilder: (_, __) => const SizedBox(width: ZapSpacing.sm),
          itemBuilder: (_, i) {
            final s       = _kScreenshots[i];
            final isActive= selected == i;
            return GestureDetector(
              onTap: () => ref.read(_selectedScreenProvider.notifier).state = i,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52, height: 52,
                decoration: BoxDecoration(
                    color: isActive
                        ? s.accentColor.withOpacity(0.15) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: isActive ? s.accentColor : const Color(0xFF2A2A2A),
                        width: isActive ? 2 : 1)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(s.icon, color: s.accentColor, size: 18),
                  Text('${s.number}', style: TextStyle(
                      color: isActive ? s.accentColor : const Color(0xFF6B7280),
                      fontSize: 9, fontWeight: FontWeight.w800)),
                ])));
          },
        )),
      const SizedBox(height: ZapSpacing.lg),

      // Mock device frame
      _DeviceFrame(shot: shot),
      const SizedBox(height: ZapSpacing.xl),

      // Details card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: shot.accentColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: shot.accentColor.withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: shot.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Screenshot ${shot.number} of ${_kScreenshots.length}',
                  style: TextStyle(color: shot.accentColor, fontSize: 9,
                      fontWeight: FontWeight.w800))),
            const Spacer(),
            Icon(shot.icon, color: shot.accentColor, size: 16),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Text(shot.screenName, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 10)),
          const SizedBox(height: 4),
          Text(shot.headline.replaceAll('\n', ' '),
              style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(shot.subline, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
          const SizedBox(height: ZapSpacing.md),
          const Text('WHY INCLUDE THIS SCREEN',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(shot.whyInclude, style: const TextStyle(
              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
          const SizedBox(height: ZapSpacing.md),
          const Text('KEY FEATURES VISIBLE',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 6),
          ...shot.keyFeatures.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.circle, color: shot.accentColor, size: 5),
                const SizedBox(width: 7),
                Text(f, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11)),
              ]))),
        ])),

      const SizedBox(height: ZapSpacing.lg),
      // Navigation
      Row(children: [
        if (selected > 0)
          Expanded(child: _outlineBtn('← Previous', const Color(0xFF6B7280),
              () => ref.read(_selectedScreenProvider.notifier).state = selected - 1)),
        if (selected > 0 && selected < _kScreenshots.length - 1)
          const SizedBox(width: ZapSpacing.sm),
        if (selected < _kScreenshots.length - 1)
          Expanded(child: _primaryBtn(
            label: 'Next → Screenshot ${selected + 2}',
            color: shot.accentColor,
            onTap: () => ref.read(_selectedScreenProvider.notifier).state = selected + 1,
          )),
      ]),
    ]);
  }
}

// ── Device frame mock ─────────────────────────────────────────────────────────
class _DeviceFrame extends StatelessWidget {
  final _Screenshot shot;
  const _DeviceFrame({required this.shot});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 6),
          boxShadow: [BoxShadow(
              color: shot.accentColor.withOpacity(0.2),
              blurRadius: 24, spreadRadius: 2)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(children: [
            // Status bar
            Container(
              height: 24, color: const Color(0xFF050505),
              child: Row(children: [
                const SizedBox(width: 16),
                const Spacer(),
                // Notch/pill
                Container(width: 60, height: 10, margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(5))),
                const Spacer(),
                const SizedBox(width: 16),
              ])),
            // App content area
            Container(
              height: 360,
              color: const Color(0xFF050508),
              child: _ScreenContent(shot: shot)),
            // Home bar
            Container(
              height: 20, color: const Color(0xFF050505),
              child: Center(child: Container(
                  width: 80, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(2))))),
          ]),
        )),
    );
  }
}

class _ScreenContent extends StatelessWidget {
  final _Screenshot shot;
  const _ScreenContent({required this.shot});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // App UI (minimal mock)
      Positioned.fill(child: Column(children: [
        // App bar
        Container(
          height: 44,
          color: const Color(0xFF0F0F0F),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.bolt_rounded, color: shot.accentColor, size: 16),
            const SizedBox(width: 6),
            const Text('ZapSafe', style: TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700)),
          ])),
        // Content placeholder
        Expanded(child: Container(
          color: const Color(0xFF0A0A0F),
          child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: shot.accentColor.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(shot.icon, color: shot.accentColor, size: 32)),
            const SizedBox(height: 12),
            // Feature list mini
            ...shot.keyFeatures.take(3).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: shot.accentColor, size: 10),
                  const SizedBox(width: 5),
                  Expanded(child: Text(f, style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 8))),
                ]))),
          ]))),
        ),
      ])),
      // Marketing overlay (gradient + text)
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.transparent, shot.accentColor.withOpacity(0.85)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(shot.headline,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 3),
            Text(shot.subline, style: const TextStyle(
                color: Colors.white70, fontSize: 8, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
      ),
      // Screenshot number badge
      Positioned(top: 50, right: 8,
          child: Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
                color: shot.accentColor, shape: BoxShape.circle),
            child: Center(child: Text('${shot.number}',
                style: const TextStyle(color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w900))))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Requirements
// ══════════════════════════════════════════════════════════════════════════════
class _RequirementsTab extends ConsumerWidget {
  const _RequirementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store    = ref.watch(_storeProvider);
    final expanded = ref.watch(_expandedReqProvider);
    final reqs     = store == _Store.play ? _kPlayReqs : _kAppleReqs;
    final storeColor  = store == _Store.play
        ? const Color(0xFF3DDC84) : const Color(0xFF9CA3AF);
    final storeIcon   = store == _Store.play
        ? Icons.android_rounded : Icons.apple_rounded;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.rule_rounded, color: const Color(0xFF10B981),
          text: 'Technical requirements for screenshot submission. '
              'Non-compliance causes rejection at review. '
              'Switch between Play Store and App Store specs.'),
      const SizedBox(height: ZapSpacing.lg),

      // Store toggle
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () {
            ref.read(_storeProvider.notifier).state = _Store.play;
            ref.read(_expandedReqProvider.notifier).state = null;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: store == _Store.play
                    ? const Color(0xFF3DDC84).withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: store == _Store.play
                        ? const Color(0xFF3DDC84).withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: store == _Store.play ? 2 : 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 16),
              const SizedBox(width: 6),
              Text('Play Store', style: TextStyle(
                  color: store == _Store.play
                      ? const Color(0xFF3DDC84) : const Color(0xFF6B7280),
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]))),),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: GestureDetector(
          onTap: () {
            ref.read(_storeProvider.notifier).state = _Store.apple;
            ref.read(_expandedReqProvider.notifier).state = null;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: store == _Store.apple
                    ? const Color(0xFF9CA3AF).withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: store == _Store.apple
                        ? const Color(0xFF9CA3AF).withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: store == _Store.apple ? 2 : 1)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.apple_rounded, color: Color(0xFF9CA3AF), size: 16),
              const SizedBox(width: 6),
              Text('App Store', style: TextStyle(
                  color: store == _Store.apple
                      ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]))),),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Requirements table
      const _SectionLabel('SCREENSHOT REQUIREMENTS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 9),
            decoration: BoxDecoration(
                color: storeColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(ZapSpacing.radius),
                    topRight: Radius.circular(ZapSpacing.radius))),
            child: Row(children: [
              Icon(storeIcon, color: storeColor, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Text('${store == _Store.play ? "Google Play Store" : "Apple App Store"} Requirements',
                  style: TextStyle(color: storeColor, fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ])),
          ...reqs.asMap().entries.map((e) {
            final i   = e.key;
            final req = e.value;
            final isExp = expanded == i;
            final isLast = i == reqs.length - 1;
            return Column(children: [
              GestureDetector(
                onTap: () => ref.read(_expandedReqProvider.notifier).state =
                    isExp ? null : i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  color: isExp ? storeColor.withOpacity(0.05) : Colors.transparent,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.md, vertical: 11),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text(req.field,
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11))),
                        Expanded(flex: 2, child: Text(req.value,
                            style: TextStyle(color: storeColor, fontSize: 11,
                                fontWeight: FontWeight.w700))),
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
                              child: Container(
                                padding: const EdgeInsets.all(ZapSpacing.sm),
                                decoration: BoxDecoration(
                                    color: storeColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                                    border: Border.all(color: storeColor.withOpacity(0.2))),
                                child: Text(req.note, style: const TextStyle(
                                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))))
                          : const SizedBox.shrink(),
                    ),
                  ]),
                )),
              if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Comparison quick-ref
      const _SectionLabel('QUICK COMPARISON'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _compRow('Max screenshots', '8', '10'),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          _compRow('Max file size', '8 MB', '500 KB'),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          _compRow('Phone portrait size', '1080×1920', '1320×2868 (6.9")'),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          _compRow('Overlay text', 'Allowed ✅', 'Allowed ✅'),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          _compRow('Device frame', 'Optional', 'Optional'),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          _compRow('Video autoplay', 'Yes (30s)', 'No (preview)'),
        ])),
    ]);
  }

  static Widget _compRow(String feature, String play, String apple) =>
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.md, vertical: 9),
        child: Row(children: [
          Expanded(child: Text(feature, style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 10))),
          Expanded(child: Text(play, style: const TextStyle(
              color: Color(0xFF3DDC84), fontSize: 10,
              fontWeight: FontWeight.w600))),
          Expanded(child: Text(apple, style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 10,
              fontWeight: FontWeight.w600))),
        ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Captions
// ══════════════════════════════════════════════════════════════════════════════
class _CaptionsTab extends StatelessWidget {
  const _CaptionsTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.text_fields_rounded, color: const Color(0xFF8B5CF6),
        text: 'Marketing copy for each screenshot. '
            'The headline is overlaid on the image. '
            'The subline appears below the image in some store layouts. '
            '"Why include" rationale for the team.'),
    const SizedBox(height: ZapSpacing.lg),

    ..._kScreenshots.map((shot) => Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.md),
        decoration: BoxDecoration(
            color: shot.accentColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: shot.accentColor.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Card header
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: shot.accentColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(ZapSpacing.radius),
                    topRight: Radius.circular(ZapSpacing.radius))),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: shot.accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(shot.icon, color: shot.accentColor, size: 16)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Screenshot ${shot.number}  ·  ${shot.screenName}',
                    style: TextStyle(color: shot.accentColor, fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ])),
            ])),
          // Copy
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Headline
              _copyBlock('Headline (overlaid on image)',
                  shot.headline, shot.accentColor, context),
              const SizedBox(height: ZapSpacing.sm),
              _copyBlock('Sub-headline (below image)',
                  shot.subline, const Color(0xFF3B82F6), context),
              const SizedBox(height: ZapSpacing.sm),
              // Key features
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Key features (visible in screenshot UI)',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  ...shot.keyFeatures.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.circle, color: shot.accentColor, size: 5),
                        const SizedBox(width: 7),
                        Text(f, style: const TextStyle(
                            color: Color(0xFFD1D5DB), fontSize: 10)),
                      ]))),
                ])),
            ])),
        ]))),

    // Character count guidance
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
        text: 'Caption length guidelines: '
            'Play Store headline overlay — keep under 5 words for readability. '
            'App Store custom product page — 30 char limit on preview text. '
            'Day 193-194 covers the full listing description (long + short form).'),
  ]);

  Widget _copyBlock(String label, String text, Color color,
      BuildContext context) =>
      GestureDetector(
        onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Copied: $text'), backgroundColor: color,
            duration: const Duration(seconds: 1))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label, style: TextStyle(color: color, fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
              const Spacer(),
              const Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 10),
              const SizedBox(width: 3),
              const Text('long-press',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
            ]),
            const SizedBox(height: 5),
            Text(text, style: TextStyle(color: color.withOpacity(0.9),
                fontSize: 13, fontWeight: FontWeight.w800, height: 1.3)),
          ])));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 3))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))));

Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)))));

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
