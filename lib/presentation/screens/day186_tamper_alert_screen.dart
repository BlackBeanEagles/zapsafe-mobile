/// Day 186 — Tamper Alert UI, Scoring & Block Sign-Off
///
/// Second and final day of the Days 185-186 detection block.
/// Day 185: 6 iOS + 6 Android checks, scan simulation, detection modes ✅
/// Day 186: Tamper alert screen (Safe Mode + Block), multi-check scoring
///           system, Play Integrity API attestation, block sign-off.
///
/// 🟢 FRONTEND-ONLY — alert UI and scoring run on device.
///    Play Integrity token verification requires a server call (noted),
///    but the client code and UI are all local.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _d186TabProvider         = StateProvider<int>((ref) => 0);
final _alertModeProvider       = StateProvider<_AlertMode>((ref) => _AlertMode.safeMode);
final _scoringCheckProvider    = StateProvider<Set<String>>((ref) => {});
final _integrityStateProvider  = StateProvider<_IntegrityState>((ref) => _IntegrityState.idle);
final _expandedScoringProvider = StateProvider<int?>((ref) => null);

enum _AlertMode      { safeMode, block }
enum _IntegrityState { idle, requesting, verifying, passed, failed }

// ── Scoring data ──────────────────────────────────────────────────────────────
class _ScoredCheck {
  final String   id;
  final String   name;
  final int      weight;     // contribution to total risk score (0-100)
  final String   rationale;  // why this weight
  final bool     isAndroid;
  final Color    color;
  const _ScoredCheck({
    required this.id, required this.name, required this.weight,
    required this.rationale, required this.isAndroid,
    this.color = const Color(0xFFF59E0B),
  });
}

const _kScoredChecks = [
  // iOS
  _ScoredCheck(id: 'ios_cydia',    name: 'Cydia/Sileo app',       weight: 35,
      rationale: 'Strongest single signal — Cydia is installed only on jailbroken devices.',
      isAndroid: false),
  _ScoredCheck(id: 'ios_su',       name: 'su/bash binary',         weight: 30,
      rationale: 'High confidence — root shells absent on stock iOS.',
      isAndroid: false),
  _ScoredCheck(id: 'ios_substrate',name: 'Substrate/Theos dylib',  weight: 25,
      rationale: 'Strong — only installed by jailbreaks needing tweak support.',
      isAndroid: false),
  _ScoredCheck(id: 'ios_sandbox',  name: 'Sandbox escape',         weight: 20,
      rationale: 'Very strong confirmation — but may throw exception on strict jailbreaks.',
      isAndroid: false),
  _ScoredCheck(id: 'ios_urlscheme',name: 'cydia:// URL scheme',    weight: 15,
      rationale: 'Moderate — blocked by iOS 18+ canOpenURL restrictions.',
      isAndroid: false),
  _ScoredCheck(id: 'ios_dynlib',   name: 'Injected dylib',         weight: 20,
      rationale: 'Moderate-high — but may false-positive on some debug builds.',
      isAndroid: false),
  // Android
  _ScoredCheck(id: 'aos_su',       name: 'su binary',              weight: 35,
      rationale: 'Strongest — su not present on OEM stock Android.',
      isAndroid: true),
  _ScoredCheck(id: 'aos_testkeys', name: 'test-keys build',        weight: 25,
      rationale: 'Strong — release builds always have release-keys.',
      isAndroid: true),
  _ScoredCheck(id: 'aos_magisk',   name: 'Magisk/SuperSU app',     weight: 30,
      rationale: 'High — root management app is a definitive indicator.',
      isAndroid: true),
  _ScoredCheck(id: 'aos_busybox',  name: 'BusyBox binary',         weight: 15,
      rationale: 'Moderate — can be installed without full root on some devices.',
      isAndroid: true),
  _ScoredCheck(id: 'aos_rwsystem', name: '/system rw mount',       weight: 25,
      rationale: 'Strong — stock Android never mounts /system as rw.',
      isAndroid: true),
  _ScoredCheck(id: 'aos_debuggable',name: 'ro.debuggable=1',       weight: 20,
      rationale: 'High — only set on userdebug/eng builds, never production.',
      isAndroid: true),
];

// ── Safe mode feature restrictions ───────────────────────────────────────────
const _kSafeModeRestrictions = [
  ('Evidence Vault',      false,  'Locked — cannot access on compromised device'),
  ('SOS Protection',      true,   'Active — SOS always works regardless'),
  ('Account Settings',    false,  'Locked — sensitive changes blocked'),
  ('Data Export',         false,  'Locked — cannot export on compromised device'),
  ('Check-in Timers',     true,   'Active — safety-critical, never blocked'),
  ('Emergency Contacts',  true,   'Read-only — view but not modify'),
  ('Notification History',true,   'Active — no sensitive data risk'),
  ('Analytics',           false,  'Stopped — no data sent from compromised device'),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day186TamperAlertScreen extends ConsumerWidget {
  const Day186TamperAlertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d186TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Tamper Alert & Scoring'),
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
            child: const Text('🟢 FRONTEND-ONLY',
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
                onSelect: (t) => ref.read(_d186TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _AlertTab(),
            if (tab == 1) const _ScoringTab(),
            if (tab == 2) const _BlockCompleteTab(),
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
            colors: [Color(0xFF100808), Color(0xFF080504), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 186',               const Color(0xFFEF4444)),
          _badge('🟢 FRONTEND-ONLY',          const Color(0xFF10B981)),
          _badge('Section C  ·  Day 6/10',    const Color(0xFF3B82F6)),
          _badge('Block 185-186 Final ✅',    const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Tamper Alert\nUI & Check Scoring',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Interactive Safe Mode + Block tamper screens. '
          'Weighted risk scoring — check combination logic. '
          'Play Integrity API attestation (Android). '
          'Days 185-186 block complete.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('2',   '2 alert modes',   Color(0xFFEF4444)),
          _HStat('12',  '12 scored checks',Color(0xFFF59E0B)),
          _HStat('60',  'Block threshold', Color(0xFFEF4444)),
          _HStat('✅',  'Block done',      Color(0xFF10B981)),
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
      (Icons.warning_rounded,      Color(0xFFEF4444), 'Alert Screens'),
      (Icons.bar_chart_rounded,    Color(0xFFF59E0B), 'Scoring'),
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
// TAB 1 — Alert Screens
// ══════════════════════════════════════════════════════════════════════════════
class _AlertTab extends ConsumerWidget {
  const _AlertTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_alertModeProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.warning_rounded, color: const Color(0xFFEF4444),
          text: 'Two tamper alert screens depending on the configured detection mode. '
              '"Safe Mode" warns and restricts. "Block" halts the entire app. '
              'SOS is always accessible regardless of mode.'),
      const SizedBox(height: ZapSpacing.lg),

      // Mode toggle
      const _SectionLabel('SELECT ALERT MODE TO PREVIEW'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => ref.read(_alertModeProvider.notifier).state = _AlertMode.safeMode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: mode == _AlertMode.safeMode
                    ? const Color(0xFFF59E0B).withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: mode == _AlertMode.safeMode
                        ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: mode == _AlertMode.safeMode ? 2 : 1)),
            child: Column(children: [
              Icon(Icons.warning_amber_rounded,
                  color: mode == _AlertMode.safeMode
                      ? const Color(0xFFF59E0B) : const Color(0xFF6B7280), size: 20),
              const SizedBox(height: 4),
              Text('Safe Mode', style: TextStyle(
                  color: mode == _AlertMode.safeMode
                      ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                  fontSize: 11, fontWeight: FontWeight.w700)),
              const Text('Warn + restrict', style: TextStyle(
                  color: Color(0xFF4B5563), fontSize: 9)),
            ]),
          ))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: GestureDetector(
          onTap: () => ref.read(_alertModeProvider.notifier).state = _AlertMode.block,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: mode == _AlertMode.block
                    ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: mode == _AlertMode.block
                        ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: mode == _AlertMode.block ? 2 : 1)),
            child: Column(children: [
              Icon(Icons.block_rounded,
                  color: mode == _AlertMode.block
                      ? const Color(0xFFEF4444) : const Color(0xFF6B7280), size: 20),
              const SizedBox(height: 4),
              Text('Block', style: TextStyle(
                  color: mode == _AlertMode.block
                      ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                  fontSize: 11, fontWeight: FontWeight.w700)),
              const Text('Refuse to run', style: TextStyle(
                  color: Color(0xFF4B5563), fontSize: 9)),
            ]),
          ))),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Mock screen
      const _SectionLabel('MOCK ALERT SCREEN'),
      const SizedBox(height: ZapSpacing.md),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: mode == _AlertMode.safeMode
            ? const _SafeModeScreen(key: ValueKey('safe'))
            : const _BlockScreen(key: ValueKey('block')),
      ),
    ]);
  }
}

class _SafeModeScreen extends StatelessWidget {
  const _SafeModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF0A0800),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 2)),
      child: Column(children: [
        // Phone header
        _phoneHeader('ZapSafe  ·  Safe Mode', const Color(0xFFF59E0B)),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 44),
            const SizedBox(height: ZapSpacing.md),
            const Text('Security Risk Detected',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 16,
                    fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text(
              'This device shows signs of modification '
              '(jailbreak or root). ZapSafe is running in '
              'Safe Mode with reduced functionality.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
              textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.xl),
            // Feature list
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1100),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25))),
              child: Column(children: [
                const Text('FEATURE STATUS', style: TextStyle(
                    color: Color(0xFF6B7280), fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: ZapSpacing.sm),
                ..._kSafeModeRestrictions.take(5).map((r) {
                  final (feature, available, _) = r;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(available ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: available ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          size: 13),
                      const SizedBox(width: 6),
                      Expanded(child: Text(feature, style: const TextStyle(
                          color: Colors.white, fontSize: 11))),
                      Text(available ? 'ON' : 'OFF',
                          style: TextStyle(
                              color: available ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 9, fontWeight: FontWeight.w700)),
                    ]));
                }),
                const Text('+ 3 more  (see Scoring tab)',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
              ]),
            ),
            const SizedBox(height: ZapSpacing.lg),
            // SOS always works
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.bolt_rounded, color: Color(0xFFEF4444), size: 14),
                SizedBox(width: 6),
                Text('SOS is always active — tap to trigger',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(height: ZapSpacing.md),
            _mockBtn('Continue in Safe Mode', const Color(0xFFF59E0B)),
            const SizedBox(height: 8),
            const Text('Learn more about device security →',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}

class _BlockScreen extends StatelessWidget {
  const _BlockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF0A0000),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6), width: 2)),
      child: Column(children: [
        _phoneHeader('ZapSafe  ·  BLOCKED', const Color(0xFFEF4444)),
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            const Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444), size: 52),
            const SizedBox(height: ZapSpacing.md),
            const Text('ZapSafe Cannot Run',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 18,
                    fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'This device has been rooted or jailbroken. '
              'ZapSafe cannot guarantee the security of your '
              'emergency data on a compromised device.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.xl),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
              child: Column(children: [
                ...[
                  'All ZapSafe features are disabled.',
                  'No data is stored or transmitted.',
                  'Existing encrypted data remains intact.',
                  'Uninstall and reinstall on a secure device.',
                ].map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(children: [
                        const Icon(Icons.circle, color: Color(0xFFEF4444), size: 5),
                        const SizedBox(width: 7),
                        Expanded(child: Text(s, style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4))),
                      ]))),
              ]),
            ),
            const SizedBox(height: ZapSpacing.lg),
            // Emergency call — always visible
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.call_rounded, color: Color(0xFFEF4444), size: 14),
                SizedBox(width: 6),
                Text('Emergency: dial 112 directly',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ])),
            const SizedBox(height: ZapSpacing.md),
            const Text('contact support@zapsafe.app if you believe this is an error',
                style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

Widget _phoneHeader(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 8),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(ZapSpacing.radius),
            topRight: Radius.circular(ZapSpacing.radius))),
    child: Row(children: [
      const Icon(Icons.smartphone_rounded, color: Color(0xFF4B5563), size: 12),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]));

Widget _mockBtn(String label, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
    child: Center(child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))));

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Multi-Check Scoring + Play Integrity
// ══════════════════════════════════════════════════════════════════════════════
class _ScoringTab extends ConsumerWidget {
  const _ScoringTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged   = ref.watch(_scoringCheckProvider);
    final expanded  = ref.watch(_expandedScoringProvider);
    final intState  = ref.watch(_integrityStateProvider);

    // Score from flagged checks
    final iosScore = _kScoredChecks.where((c) => !c.isAndroid && flagged.contains(c.id))
        .fold(0, (s, c) => s + c.weight);
    final aosScore = _kScoredChecks.where((c) => c.isAndroid && flagged.contains(c.id))
        .fold(0, (s, c) => s + c.weight);


    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.bar_chart_rounded, color: const Color(0xFFF59E0B),
          text: 'Not every check is equally reliable. ZapSafe uses a '
              'weighted score — tap individual checks to "flag" them, '
              'and watch the risk score update live. '
              'Score ≥ 60 → Block. Score 20-59 → Safe Mode. < 20 → Clean.'),
      const SizedBox(height: ZapSpacing.lg),

      // Score displays
      Row(children: [
        _scoreCard('iOS Risk Score', iosScore, const Color(0xFF9CA3AF)),
        const SizedBox(width: ZapSpacing.sm),
        _scoreCard('Android Risk Score', aosScore, const Color(0xFF3DDC84)),
      ]),
      const SizedBox(height: ZapSpacing.md),

      // Thresholds
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _threshold('0-19', 'Clean ✅', const Color(0xFF10B981)),
          _divider(),
          _threshold('20-59', 'Safe Mode ⚠', const Color(0xFFF59E0B)),
          _divider(),
          _threshold('60+', 'Block 🔴', const Color(0xFFEF4444)),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Checks — tap to flag
      const _SectionLabel('TAP CHECKS TO ADD TO RISK SCORE'),
      const SizedBox(height: ZapSpacing.sm),
      const Text('iOS checks', style: TextStyle(color: Color(0xFF9CA3AF),
          fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: ZapSpacing.sm),
      Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
          children: _kScoredChecks.where((c) => !c.isAndroid).map((c) {
        final isFlagged = flagged.contains(c.id);
        return GestureDetector(
          onTap: () {
            final updated = Set<String>.from(flagged);
            if (isFlagged) updated.remove(c.id); else updated.add(c.id);
            ref.read(_scoringCheckProvider.notifier).state = updated;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: isFlagged
                    ? c.color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isFlagged ? c.color.withOpacity(0.6) : const Color(0xFF2A2A2A),
                    width: isFlagged ? 2 : 1)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isFlagged) Icon(Icons.warning_rounded, color: c.color, size: 11),
              if (isFlagged) const SizedBox(width: 4),
              Text('${c.name} (+${c.weight})',
                  style: TextStyle(
                      color: isFlagged ? c.color : const Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: isFlagged ? FontWeight.w700 : FontWeight.w400)),
            ])));
      }).toList()),
      const SizedBox(height: ZapSpacing.sm),
      const Text('Android checks', style: TextStyle(color: Color(0xFF9CA3AF),
          fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: ZapSpacing.sm),
      Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
          children: _kScoredChecks.where((c) => c.isAndroid).map((c) {
        final isFlagged = flagged.contains(c.id);
        return GestureDetector(
          onTap: () {
            final updated = Set<String>.from(flagged);
            if (isFlagged) updated.remove(c.id); else updated.add(c.id);
            ref.read(_scoringCheckProvider.notifier).state = updated;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: isFlagged
                    ? c.color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isFlagged ? c.color.withOpacity(0.6) : const Color(0xFF2A2A2A),
                    width: isFlagged ? 2 : 1)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isFlagged) Icon(Icons.warning_rounded, color: c.color, size: 11),
              if (isFlagged) const SizedBox(width: 4),
              Text('${c.name} (+${c.weight})',
                  style: TextStyle(
                      color: isFlagged ? c.color : const Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: isFlagged ? FontWeight.w700 : FontWeight.w400)),
            ])));
      }).toList()),

      if (flagged.isNotEmpty) ...[
        const SizedBox(height: ZapSpacing.sm),
        GestureDetector(
          onTap: () => ref.read(_scoringCheckProvider.notifier).state = {},
          child: const Text('Clear all flags',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 10,
                  decoration: TextDecoration.underline))),
      ],

      const SizedBox(height: ZapSpacing.xl),
      const Divider(color: Color(0xFF1E1E1E)),
      const SizedBox(height: ZapSpacing.xl),

      // Play Integrity API
      const _SectionLabel('PLAY INTEGRITY API (ANDROID)'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.android_rounded, color: const Color(0xFF3DDC84),
          text: 'Play Integrity is a server-verified attestation — much harder '
              'to bypass than client-only checks. '
              'The client requests a signed token from Google, '
              'then ZapSafe backend verifies it. '
              'Replaces the deprecated SafetyNet Attestation API.'),
      const SizedBox(height: ZapSpacing.lg),

      // Play Integrity flow
      _PlayIntegrityFlow(state: intState, ref: ref),
      const SizedBox(height: ZapSpacing.lg),

      // Scoring weights detail
      const _SectionLabel('ALL 12 WEIGHTED CHECKS  ·  TAP TO SEE RATIONALE'),
      const SizedBox(height: ZapSpacing.md),
      ..._kScoredChecks.asMap().entries.map((e) {
        final i     = e.key;
        final check = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedScoringProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
                color: isExp ? check.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? check.color.withOpacity(0.35) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: check.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(check.isAndroid ? 'ANDROID' : 'iOS',
                        style: TextStyle(color: check.color, fontSize: 8,
                            fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(check.name, style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))),
                  // Weight bar
                  SizedBox(width: 60, child: Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: check.weight / 100,
                          backgroundColor: const Color(0xFF2A2A2A),
                          valueColor: AlwaysStoppedAnimation(check.color),
                          minHeight: 4))),
                    const SizedBox(width: 5),
                    Text('${check.weight}', style: TextStyle(
                        color: check.color, fontSize: 10, fontWeight: FontWeight.w700)),
                  ])),
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
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                              color: check.color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: check.color.withOpacity(0.2))),
                          child: Text(check.rationale, style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))))
                    : const SizedBox.shrink(),
              ),
            ]),
          ));
      }),
    ]);
  }

  Widget _scoreCard(String label, int score, Color color) {
    const blockT = 60; const warnT = 20;
    final barColor = score >= blockT ? const Color(0xFFEF4444)
        : score >= warnT ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final statusLabel = score >= blockT ? 'BLOCK'
        : score >= warnT ? 'SAFE MODE'
        : 'CLEAN';

    return Expanded(child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: barColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: barColor.withOpacity(0.35))),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
        const SizedBox(height: 4),
        Text('$score / 100', style: TextStyle(color: barColor, fontSize: 20,
            fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
                value: score.clamp(0, 100) / 100,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(barColor), minHeight: 5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: barColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(statusLabel, style: TextStyle(color: barColor, fontSize: 9,
              fontWeight: FontWeight.w800))),
      ])));
  }

  Widget _threshold(String range, String label, Color color) =>
      Expanded(child: Column(children: [
        Text(range, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 9),
            textAlign: TextAlign.center),
      ]));

  Widget _divider() => Container(width: 1, height: 28, color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _PlayIntegrityFlow extends StatelessWidget {
  final _IntegrityState state; final WidgetRef ref;
  const _PlayIntegrityFlow({required this.state, required this.ref});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.phone_iphone_rounded, 'App requests nonce from ZapSafe server'),
      (Icons.android_rounded,      'App calls Play Integrity API with nonce'),
      (Icons.cloud_rounded,        'Google returns signed integrity token'),
      (Icons.dns_rounded,          'ZapSafe backend verifies token with Google'),
      (Icons.verified_rounded,     'Verdict: MEETS_DEVICE_INTEGRITY / PASSES'),
    ];
    final activeIdx = switch (state) {
      _IntegrityState.idle       => -1,
      _IntegrityState.requesting => 0,
      _IntegrityState.verifying  => 2,
      _IntegrityState.passed     => 5,
      _IntegrityState.failed     => -2,
    };

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3DDC84).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 16),
          const SizedBox(width: ZapSpacing.sm),
          const Text('Play Integrity API verification flow',
              style: TextStyle(color: Color(0xFF3DDC84), fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('🟡 Server call required',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9,
                    fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: ZapSpacing.md),
        ...steps.asMap().entries.map((e) {
          final i    = e.key;
          final (icon, label) = e.value;
          final isDone = activeIdx > i;
          final isNow  = activeIdx == i;
          final color  = isDone || isNow
              ? const Color(0xFF3DDC84) : const Color(0xFF2A2A2A);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              isNow
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Color(0xFF3DDC84), strokeWidth: 2))
                  : Icon(isDone ? Icons.check_circle_rounded : icon,
                      color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(
                  color: isDone || isNow ? Colors.white : const Color(0xFF4B5563),
                  fontSize: 11))),
            ]));
        }),
        const SizedBox(height: ZapSpacing.md),
        if (state == _IntegrityState.idle)
          GestureDetector(
            onTap: () => _runIntegrity(ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFF3DDC84).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFF3DDC84).withOpacity(0.4))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.play_circle_rounded, color: Color(0xFF3DDC84), size: 14),
                SizedBox(width: 6),
                Text('Simulate Play Integrity check (mock)',
                    style: TextStyle(color: Color(0xFF3DDC84), fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ])))
        else if (state == _IntegrityState.passed) ...[
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
            child: const Text(
              'Verdict: MEETS_DEVICE_INTEGRITY\nDevice is genuine Google-certified Android.',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                  fontFamily: 'monospace', height: 1.5))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () =>
                ref.read(_integrityStateProvider.notifier).state = _IntegrityState.idle,
            child: const Text('Run again', style: TextStyle(
                color: Color(0xFF3B82F6), fontSize: 10,
                decoration: TextDecoration.underline))),
        ],
      ]));
  }

  Future<void> _runIntegrity(WidgetRef ref) async {
    ref.read(_integrityStateProvider.notifier).state = _IntegrityState.requesting;
    await Future.delayed(const Duration(milliseconds: 700));
    ref.read(_integrityStateProvider.notifier).state = _IntegrityState.verifying;
    await Future.delayed(const Duration(milliseconds: 900));
    ref.read(_integrityStateProvider.notifier).state = _IntegrityState.passed;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Block Complete
// ══════════════════════════════════════════════════════════════════════════════
class _BlockCompleteTab extends StatelessWidget {
  const _BlockCompleteTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        const Text('🛡️', style: TextStyle(fontSize: 44)),
        const SizedBox(height: ZapSpacing.md),
        const Text('Root / Jailbreak Detection Block',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 14,
                fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        const Text('DAYS 185 – 186  ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: const [
          _Chip('6 iOS checks ✅',       Color(0xFF9CA3AF)),
          _Chip('6 Android checks ✅',   Color(0xFF3DDC84)),
          _Chip('Weighted scoring ✅',   Color(0xFFF59E0B)),
          _Chip('Safe Mode screen ✅',   Color(0xFFF59E0B)),
          _Chip('Block screen ✅',       Color(0xFFEF4444)),
          _Chip('Play Integrity ✅',     Color(0xFF3DDC84)),
          _Chip('3 response modes ✅',   Color(0xFF8B5CF6)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // Section C progress
    const _SectionLabel('SECTION C: SECURITY HARDENING  ·  PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    ...[
      (const Color(0xFF10B981), 'Days 181-182', 'Cert Pinning + Network Security Config', true),
      (const Color(0xFF10B981), 'Days 183-184', 'Biometric Lock + LP18 Hardening', true),
      (const Color(0xFF10B981), 'Days 185-186', 'Jailbreak + Root Detection', true),
      (const Color(0xFF3B82F6), 'Days 187-188', 'Secure Storage + Hive Key Rotation  ←  NEXT', false),
      (const Color(0xFF6B7280), 'Days 189-190', 'Security Dashboard + Section C Sign-Off', false),
    ].map((e) {
      final (color, days, title, done) = e;
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: done
                ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF2A2A2A))),
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
    const SizedBox(height: ZapSpacing.lg),

    // 6/10 progress
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Section C progress',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const Spacer(),
        const Text('6 / 10 days  ·  3 / 5 blocks',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: ZapSpacing.sm),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: const LinearProgressIndicator(
            value: 6 / 10,
            backgroundColor: Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
            minHeight: 8)),
    ]),
    const SizedBox(height: ZapSpacing.xl),

    // Next block preview
    const _SectionLabel('NEXT  ·  DAYS 187-188: SECURE STORAGE & HIVE KEY ROTATION'),
    const SizedBox(height: ZapSpacing.md),
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(children: [
        _nextRow('Day 187', '🟢 FRONTEND-ONLY',
            'Secure storage audit — Hive vs flutter_secure_storage comparison, '
            'what data is in each store, encryption keys stored in Keychain/Keystore.'),
        const Divider(height: 16, color: Color(0xFF1A1A1A)),
        _nextRow('Day 188', '🟢 FRONTEND-ONLY',
            'Hive encryption key rotation — rotate AES key on biometric '
            're-enrol, new biometric detected, or manually triggered. '
            'Days 187-188 block sign-off.'),
      ])),
    const SizedBox(height: ZapSpacing.md),
    _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF10B981),
        text: 'Days 187-188 remain 🟢 FRONTEND-ONLY. '
            'Hive encryption and key storage run entirely on-device '
            'using the platform Keychain (iOS) and Keystore (Android).'),
  ]);

  static Widget _nextRow(String day, String badge, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Text(day, style: const TextStyle(color: Color(0xFF3B82F6),
              fontSize: 9, fontWeight: FontWeight.w800))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6)),
          child: Text(badge, style: const TextStyle(color: Color(0xFF10B981),
              fontSize: 8, fontWeight: FontWeight.w700))),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(body, style: const TextStyle(
            color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4))),
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
