/// Day 190 — Section C Complete: Security Hardening Sign-Off
///
/// Final day of Section C (Security Hardening, Days 181-190).
/// Day 189: Security dashboard — score ring, 4 blocks, full scan  ✅
/// Day 190: Section C sign-off — 10-day celebration, security cert,
///           Section D (Store Prep, Days 191-200) preview.
///
/// 🟢 FRONTEND-ONLY — entirely local screen.
///
/// After Day 190, only Section D remains:
///   Days 191-200: App Store Prep & Polish
///   All 🟢 FRONTEND-ONLY — screenshots, store listings, metadata,
///   final release checklist.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d190TabProvider     = StateProvider<int>((ref) => 0);
final _expandedDProvider   = StateProvider<int?>((ref) => null);

// ── Section C blocks ──────────────────────────────────────────────────────────
const _kSectionCBlocks = [
  (
    Color(0xFF10B981), 'Days 181-182', 'Certificate Pinning & Network Security',
    '• SHA-256 SPKI pins — api + exports\n'
    '• Android NSC (cleartext blocked, user CAs excluded)\n'
    '• iOS ATS (NSAllowsArbitraryLoads = NO)\n'
    '• Proxy detection — blocks Charles/Burp on release builds',
    ['cert_pinning', 'nsc_ats', 'proxy_detection'],
  ),
  (
    Color(0xFF8B5CF6), 'Days 183-184', 'Biometric Lock & LP18 Gate',
    '• Auto-lock after 1 minute of inactivity\n'
    '• local_auth wrapper + AppLockProvider\n'
    '• LP18 gate map — 6 operations protected\n'
    '• Hardware crypto binding (Keystore/Secure Enclave)',
    ['biometric_lock', 'lp18_gates', 'crypto_binding'],
  ),
  (
    Color(0xFFEF4444), 'Days 185-186', 'Jailbreak & Root Detection',
    '• 6 iOS jailbreak checks (Cydia, su, substrate, sandbox, URL, dylib)\n'
    '• 6 Android root checks (su, test-keys, Magisk, BusyBox, /system rw, debuggable)\n'
    '• Weighted scoring (0-100) — 3 response modes\n'
    '• Safe Mode + Block tamper alert screens\n'
    '• Play Integrity API attestation',
    ['jailbreak_clean', 'root_clean', 'play_integrity'],
  ),
  (
    Color(0xFF3B82F6), 'Days 187-188', 'Secure Storage & Key Rotation',
    '• 4 storage stores mapped (flutter_secure_storage L5, Hive L4, SharedPrefs L1)\n'
    '• 10-item data map (JWT → Keychain, Hive key → Keystore)\n'
    '• 8-point storage audit scan\n'
    '• Hive AES key rotation — 3 triggers, 7-step pipeline',
    ['storage_encrypted', 'jwt_secure', 'key_rotation_fresh'],
  ),
  (
    Color(0xFF10B981), 'Days 189-190', 'Security Dashboard & Sign-Off',
    '• Aggregated score ring (12 checks, max 100 pts)\n'
    '• 4 feature block cards with per-check indicators\n'
    '• Full 12-check scan simulation (< 500 ms)\n'
    '• Score breakdown — weighted rationale for each check',
    ['cert_pinning', 'biometric_lock', 'jailbreak_clean', 'storage_encrypted'],
  ),
];

// ── Section D preview ─────────────────────────────────────────────────────────
const _kSectionDPreview = [
  ('Days 191-192', '🟢 FRONTEND-ONLY', 'App Store screenshots — generate in-app screenshot frames '
      'for Play Store + App Store listings across 6 screen sizes.'),
  ('Days 193-194', '🟢 FRONTEND-ONLY', 'Store listing content — app title, description, '
      'keyword research (ASO), short description, promo text.'),
  ('Days 195-196', '🟢 FRONTEND-ONLY', 'Privacy policy URL, content rating questionnaire, '
      'DPDP/GDPR compliance checklist for store submission.'),
  ('Days 197-198', '🟢 FRONTEND-ONLY', 'Release checklist — all 200 days of checks, '
      'crash-free session rate, p99 latency gate, final QA.'),
  ('Days 199-200', '🟢 FRONTEND-ONLY', 'Final release — submit to Play Store + App Store, '
      'launch announcement, project complete sign-off 🏆.'),
];

// ── Security score data for certificate ──────────────────────────────────────
const _kCertChecks = [
  ('Certificate Pinning',  Color(0xFF10B981), 25, 25),   // (label, color, earned, max)
  ('Biometric & LP18',     Color(0xFF8B5CF6), 27, 27),
  ('Root Detection',       Color(0xFFEF4444), 28, 28),
  ('Secure Storage',       Color(0xFF3B82F6), 20, 20),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day190SectionCCompleteScreen extends ConsumerWidget {
  const Day190SectionCCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d190TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Section C Complete 🛡️'),
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
            child: const Text('SECTION C ✅',
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
                onSelect: (t) => ref.read(_d190TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _SignOffTab(),
            if (tab == 1) const _CertificateTab(),
            if (tab == 2) const _SectionDTab(),
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
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.15),
          const Color(0xFF3B82F6).withOpacity(0.07),
          const Color(0xFF0A0A0A),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 190',                   const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',              const Color(0xFF10B981)),
          _badge('Section C  ·  Day 10/10 🎉',    const Color(0xFF10B981)),
          _badge('Security Hardening COMPLETE',   const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Section C\nComplete 🛡️',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '10 days. 5 blocks. 100/100 security score. '
          'ZapSafe now has certificate pinning, biometric hardening, '
          'root detection, and encrypted storage — all production-ready.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('10',   '10 days',         Color(0xFF10B981)),
          _HStat('5',    '5 blocks',        Color(0xFF10B981)),
          _HStat('100',  'Security score',  Color(0xFF10B981)),
          _HStat('D→',   'Section D next',  Color(0xFF3B82F6)),
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
      (Icons.emoji_events_rounded,  Color(0xFF10B981), 'Sign-Off'),
      (Icons.verified_rounded,      Color(0xFF8B5CF6), 'Security Cert'),
      (Icons.store_rounded,         Color(0xFF3B82F6), 'Section D'),
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
// TAB 1 — Sign-Off
// ══════════════════════════════════════════════════════════════════════════════
class _SignOffTab extends StatelessWidget {
  const _SignOffTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Grand celebration
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.14),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 2),
      ),
      child: const Column(children: [
        Text('🛡️', style: TextStyle(fontSize: 52)),
        SizedBox(height: ZapSpacing.md),
        Text('Section C: Security Hardening',
            style: TextStyle(color: Color(0xFF10B981), fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.5),
            textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.xs),
        Text('DAYS 181 – 190  ·  COMPLETE ✅',
            style: TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.sm),
        Text('10 screens  ·  5 blocks  ·  All 🟢 FRONTEND-ONLY',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            textAlign: TextAlign.center),
        SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
            alignment: WrapAlignment.center, children: [
          _Chip('SHA-256 cert pinning ✅',    Color(0xFF10B981)),
          _Chip('Android NSC ✅',             Color(0xFF3DDC84)),
          _Chip('iOS ATS ✅',                 Color(0xFF9CA3AF)),
          _Chip('Proxy detection ✅',         Color(0xFF10B981)),
          _Chip('Biometric auto-lock ✅',     Color(0xFF8B5CF6)),
          _Chip('LP18 gates (6) ✅',          Color(0xFFF59E0B)),
          _Chip('Hardware crypto binding ✅', Color(0xFF8B5CF6)),
          _Chip('6 iOS jailbreak checks ✅',  Color(0xFF9CA3AF)),
          _Chip('6 Android root checks ✅',   Color(0xFF3DDC84)),
          _Chip('Weighted scoring ✅',        Color(0xFFEF4444)),
          _Chip('Play Integrity ✅',          Color(0xFF3DDC84)),
          _Chip('Storage audit (8-pt) ✅',    Color(0xFF3B82F6)),
          _Chip('Hive AES-256 ✅',            Color(0xFF3B82F6)),
          _Chip('Key rotation (3 triggers) ✅',Color(0xFF10B981)),
          _Chip('Security dashboard ✅',      Color(0xFF10B981)),
          _Chip('Score 100/100 ✅',           Color(0xFF10B981)),
        ]),
      ]),
    ),
    const SizedBox(height: ZapSpacing.xl),

    // 5-block timeline
    const _SectionLabel('SECTION C  ·  5 BLOCKS TIMELINE'),
    const SizedBox(height: ZapSpacing.md),
    ..._kSectionCBlocks.asMap().entries.map((e) {
      final i = e.key;
      final (color, days, title, bullets, _) = e.value;
      final isLast = i == _kSectionCBlocks.length - 1;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline column
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 2)),
            child: Center(child: Text('${i + 1}', style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w900)))),
          if (!isLast)
            Container(width: 2, height: 44, color: const Color(0xFF2A2A2A)),
        ]),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : ZapSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(days, style: TextStyle(color: color, fontSize: 10,
                  fontWeight: FontWeight.w700)),
              const SizedBox(width: ZapSpacing.sm),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
            ]),
            Text(title, style: const TextStyle(color: Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: ZapSpacing.xs),
            Text(bullets, style: const TextStyle(color: Color(0xFF6B7280),
                fontSize: 10, height: 1.6)),
          ]),
        )),
      ]);
    }),

    const SizedBox(height: ZapSpacing.xl),

    // Overall progress across all sections
    const _SectionLabel('OVERALL SECTIONS PROGRESS'),
    const SizedBox(height: ZapSpacing.md),
    ...[
      (const Color(0xFF10B981), 'Section A', 'Privacy & Legal (Days 151-165)', 1.0, true),
      (const Color(0xFF10B981), 'Section B', 'Data Rights (Days 166-180)', 1.0, true),
      (const Color(0xFF10B981), 'Section C', 'Security Hardening (Days 181-190)', 1.0, true),
      (const Color(0xFF3B82F6), 'Section D', 'Store Prep & Polish (Days 191-200)', 0.0, false),
    ].map((s) {
      final (color, label, title, progress, done) = s;
      return Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: done ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: done ? color.withOpacity(0.3) : const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(color: color, fontSize: 11,
                fontWeight: FontWeight.w700)),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(title, style: const TextStyle(
                color: Colors.white, fontSize: 11))),
            if (done)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)
            else
              const Text('← NEXT', style: TextStyle(color: Color(0xFF3B82F6),
                  fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5)),
        ]));
    }),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Security Certificate
// ══════════════════════════════════════════════════════════════════════════════
class _CertificateTab extends StatelessWidget {
  const _CertificateTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.verified_rounded, color: const Color(0xFF8B5CF6),
        text: 'ZapSafe\'s security posture certificate — a summary of all '
            'Section C protections in a shareable format. '
            'This is what you\'d show in a security review or audit.'),
    const SizedBox(height: ZapSpacing.lg),

    // Certificate card
    Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0A0E14), Color(0xFF050810), Color(0xFF0A0A0F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.12),
            blurRadius: 24, spreadRadius: 2)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.4))),
              child: const Icon(Icons.bolt_rounded,
                  color: Color(0xFF10B981), size: 24)),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ZapSafe', style: TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w900)),
              Text('Security Hardening Certificate',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
              child: const Text('100 / 100', style: TextStyle(
                  color: Color(0xFF10B981), fontSize: 14,
                  fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: ZapSpacing.lg),
          const Divider(color: Color(0xFF1E1E1E)),
          const SizedBox(height: ZapSpacing.lg),

          // Cert details
          _certRow('App name',      'ZapSafe — Emergency Safety Assistant'),
          _certRow('Platform',      'Flutter 3.19.6  ·  Android + iOS'),
          _certRow('Version',       'v1.0.0 (build 150) — Production release'),
          _certRow('Certified on',  'June 1, 2026'),
          _certRow('Cert scope',    'Section C: Security Hardening (Days 181-190)'),
          const SizedBox(height: ZapSpacing.md),
          const Divider(color: Color(0xFF1E1E1E)),
          const SizedBox(height: ZapSpacing.md),

          // Score breakdown
          const Text('SECURITY SCORE BREAKDOWN', style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: ZapSpacing.md),
          ..._kCertChecks.map((c) {
            final (label, color, earned, max) = c;
            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                Expanded(child: Text(label, style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11))),
                SizedBox(width: 80, child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: earned / max,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 5))),
                const SizedBox(width: ZapSpacing.sm),
                Text('$earned/$max', style: TextStyle(color: color,
                    fontSize: 10, fontWeight: FontWeight.w700)),
              ]));
          }),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            Expanded(child: Divider(color: Color(0xFF2A2A2A))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ZapSpacing.md),
              child: Text('TOTAL', style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 9, letterSpacing: 1))),
            Expanded(child: Divider(color: Color(0xFF2A2A2A))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Center(child: Text('100 / 100  —  EXCELLENT 🛡️',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 16,
                  fontWeight: FontWeight.w900))),
          const SizedBox(height: ZapSpacing.lg),
          const Divider(color: Color(0xFF1E1E1E)),
          const SizedBox(height: ZapSpacing.md),

          // Compliance
          const Text('COMPLIANCE STANDARDS', style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: ZapSpacing.sm),
          const Wrap(spacing: 6, runSpacing: 6, children: [
            _CertBadge('OWASP Mobile Top 10', Color(0xFF10B981)),
            _CertBadge('DPDP Act 2023', Color(0xFF3B82F6)),
            _CertBadge('GDPR Art. 5, 17, 20', Color(0xFF3B82F6)),
            _CertBadge('Android MASVS L2', Color(0xFF3DDC84)),
            _CertBadge('iOS MASVS L2', Color(0xFF9CA3AF)),
            _CertBadge('LP1-LP27 compliant', Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.lg),

          // Certificate ID
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Row(children: [
              Text('Cert ID: ', style: TextStyle(
                  color: Color(0xFF6B7280), fontSize: 9)),
              Text('ZAPSAFE-SEC-C-20260601-100',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 9,
                      fontFamily: 'monospace')),
              Spacer(),
              Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
            ])),
        ]),
      )),
    const SizedBox(height: ZapSpacing.lg),

    // Share button
    GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mock: certificate share sheet opened'),
          backgroundColor: Color(0xFF8B5CF6),
          duration: Duration(seconds: 2))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4))),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.share_rounded, color: Color(0xFF8B5CF6), size: 16),
          SizedBox(width: ZapSpacing.sm),
          Text('Share certificate',
              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]))),
  ]);

  Widget _certRow(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 88, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]));
}

class _CertBadge extends StatelessWidget {
  final String label; final Color color;
  const _CertBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w700)));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Section D Preview
// ══════════════════════════════════════════════════════════════════════════════
class _SectionDTab extends ConsumerWidget {
  const _SectionDTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedDProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.store_rounded, color: const Color(0xFF3B82F6),
          text: 'Section D: App Store Prep & Polish (Days 191-200). '
              'All 🟢 FRONTEND-ONLY. No backend changes needed. '
              'The final 10 days before shipping ZapSafe to the stores.'),
      const SizedBox(height: ZapSpacing.lg),

      // Big preview card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF3B82F6).withOpacity(0.12),
            const Color(0xFF3B82F6).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.store_rounded, color: Color(0xFF3B82F6), size: 22),
            SizedBox(width: ZapSpacing.sm),
            Text('Section D: App Store Prep & Polish',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 6),
          Text('Days 191-200  ·  All 🟢 FRONTEND-ONLY',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          SizedBox(height: ZapSpacing.md),
          Text(
            'The final stretch. ZapSafe is security-hardened, DPDP/GDPR compliant, '
            'and feature-complete. Days 191-200 prepare it for store submission — '
            'screenshots, store listing copy, content ratings, '
            'release checklist, and the final submission.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // 5-block preview list
      const _SectionLabel('5 BLOCKS  ·  DAYS 191-200'),
      const SizedBox(height: ZapSpacing.md),
      ..._kSectionDPreview.asMap().entries.map((e) {
        final i = e.key;
        final (days, badge, desc) = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedDProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp
                    ? const Color(0xFF3B82F6).withOpacity(0.07)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? const Color(0xFF3B82F6).withOpacity(0.4)
                        : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(days, style: const TextStyle(
                        color: Color(0xFF3B82F6), fontSize: 9,
                        fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(badge, style: const TextStyle(
                        color: Color(0xFF10B981), fontSize: 8,
                        fontWeight: FontWeight.w700))),
                  const Spacer(),
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
                              color: const Color(0xFF3B82F6).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(
                                  color: const Color(0xFF3B82F6).withOpacity(0.2))),
                          child: Text(desc, style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))))
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Text(desc, style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10, height: 1.4),
                            maxLines: 2, overflow: TextOverflow.ellipsis)),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.xl),

      // Final milestone
      Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF3B82F6).withOpacity(0.10),
            const Color(0xFF8B5CF6).withOpacity(0.07),
            const Color(0xFF10B981).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
        ),
        child: const Column(children: [
          Text('🏆', style: TextStyle(fontSize: 44)),
          SizedBox(height: ZapSpacing.md),
          Text('Day 200 — ZapSafe Ships',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          SizedBox(height: 6),
          Text(
            'After Day 200, ZapSafe will be submitted to the '
            'Google Play Store and Apple App Store. '
            '200 days. 4 sections. 150+ screens. '
            'DPDP + GDPR compliant. Security score 100/100.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center, children: [
            _Chip('200 days 🗓️',       Color(0xFF3B82F6)),
            _Chip('4 sections ✅',       Color(0xFF10B981)),
            _Chip('150+ screens 📱',     Color(0xFF8B5CF6)),
            _Chip('DPDP §8,11,13 ✅',   Color(0xFF10B981)),
            _Chip('GDPR Art.5,17,20 ✅', Color(0xFF3B82F6)),
            _Chip('Security 100/100 🛡️', Color(0xFF10B981)),
            _Chip('Play Store 🟢',       Color(0xFF3DDC84)),
            _Chip('App Store 🟢',        Color(0xFF9CA3AF)),
          ]),
        ]),
      ),
    ]);
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
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
