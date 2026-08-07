/// Day 189 — Security Dashboard
///
/// First day of the Days 189-190 Security Dashboard block.
/// Day 189: Aggregated security health — score ring, 5 feature cards,
///           full scan simulation, score breakdown.
/// Day 190: Section C complete sign-off + Section D preview.
///
/// 🟢 FRONTEND-ONLY — all checks run on-device, no server call.
///    Aggregates results from all Section C screens (Days 181-188).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d189TabProvider      = StateProvider<int>((ref) => 0);
final _scanStateProvider    = StateProvider<_ScanState>((ref) => _ScanState.idle);
final _scanResultsProvider  = StateProvider<Map<String, bool>>((ref) => _kDefaultResults);
final _expandedCardProvider = StateProvider<int?>((ref) => null);
final _expandedScoreProvider= StateProvider<int?>((ref) => null);

enum _ScanState { idle, scanning, done }

// ── Default result state (all passing) ───────────────────────────────────────
const _kDefaultResults = {
  'cert_pinning':       true,
  'nsc_ats':            true,
  'proxy_detection':    true,
  'biometric_lock':     true,
  'lp18_gates':         true,
  'crypto_binding':     true,
  'jailbreak_clean':    true,
  'root_clean':         true,
  'play_integrity':     true,
  'storage_encrypted':  true,
  'jwt_secure':         true,
  'key_rotation_fresh': true,
};

// ── Feature card definitions ──────────────────────────────────────────────────
class _FeatureCard {
  final String   id;
  final String   name;
  final String   days;
  final IconData icon;
  final Color    color;
  final List<String> checks;   // check IDs from _kDefaultResults
  final String   details;
  const _FeatureCard({
    required this.id, required this.name, required this.days,
    required this.icon, required this.color,
    required this.checks, required this.details,
  });
}

const _kFeatureCards = [
  _FeatureCard(
    id: 'cert_pinning',
    name: 'Certificate Pinning',
    days: 'Days 181-182',
    icon: Icons.lock_rounded,
    color: Color(0xFF10B981),
    checks: ['cert_pinning', 'nsc_ats', 'proxy_detection'],
    details: '2 domains pinned (api + exports). '
        'Android NSC + iOS ATS enforced. '
        'Proxy detection active on release builds.',
  ),
  _FeatureCard(
    id: 'biometric',
    name: 'Biometric Lock & LP18',
    days: 'Days 183-184',
    icon: Icons.fingerprint_rounded,
    color: Color(0xFF8B5CF6),
    checks: ['biometric_lock', 'lp18_gates', 'crypto_binding'],
    details: 'Auto-lock: 1 minute. '
        '6 LP18 gates active. '
        'Hardware-bound crypto key (Keystore/Enclave).',
  ),
  _FeatureCard(
    id: 'root_detection',
    name: 'Root / Jailbreak Detection',
    days: 'Days 185-186',
    icon: Icons.security_rounded,
    color: Color(0xFFEF4444),
    checks: ['jailbreak_clean', 'root_clean', 'play_integrity'],
    details: 'Last scan: clean — no compromise signals. '
        'Play Integrity: MEETS_DEVICE_INTEGRITY. '
        'Response mode: Safe Mode.',
  ),
  _FeatureCard(
    id: 'secure_storage',
    name: 'Secure Storage',
    days: 'Days 187-188',
    icon: Icons.storage_rounded,
    color: Color(0xFF3B82F6),
    checks: ['storage_encrypted', 'jwt_secure', 'key_rotation_fresh'],
    details: 'JWT in Keychain/Keystore. '
        'Hive AES-256 key in secure storage. '
        'Last key rotation: 2 days ago.',
  ),
];

// ── Score breakdown ───────────────────────────────────────────────────────────
class _ScoreItem {
  final String id, label, description;
  final int    points;
  final Color  color;
  const _ScoreItem({
    required this.id, required this.label, required this.description,
    required this.points, required this.color,
  });
}

const _kScoreItems = [
  _ScoreItem(id: 'cert_pinning',    label: 'Certificate pinning active',
      description: 'SHA-256 SPKI pins for api + exports domains.',
      points: 10, color: Color(0xFF10B981)),
  _ScoreItem(id: 'nsc_ats',        label: 'NSC + ATS enforced',
      description: 'Android NSC blocks cleartext. iOS ATS enabled.',
      points: 8, color: Color(0xFF10B981)),
  _ScoreItem(id: 'proxy_detection',label: 'Proxy detection on release',
      description: 'Charles/Burp blocked on production builds.',
      points: 7, color: Color(0xFF10B981)),
  _ScoreItem(id: 'biometric_lock', label: 'Biometric auto-lock active',
      description: 'App locks after 1 minute of inactivity.',
      points: 10, color: Color(0xFF8B5CF6)),
  _ScoreItem(id: 'lp18_gates',     label: 'All LP18 gates wired',
      description: '6 sensitive operations require biometric/PIN.',
      points: 8, color: Color(0xFF8B5CF6)),
  _ScoreItem(id: 'crypto_binding', label: 'Hardware crypto binding',
      description: 'Biometric gate uses Keystore/Enclave key — Frida-proof.',
      points: 9, color: Color(0xFF8B5CF6)),
  _ScoreItem(id: 'jailbreak_clean',label: 'No jailbreak detected',
      description: '6 iOS checks passed — device appears stock.',
      points: 10, color: Color(0xFFEF4444)),
  _ScoreItem(id: 'root_clean',     label: 'No root detected',
      description: '6 Android checks passed — device appears stock.',
      points: 10, color: Color(0xFFEF4444)),
  _ScoreItem(id: 'play_integrity', label: 'Play Integrity passed',
      description: 'MEETS_DEVICE_INTEGRITY — Google-certified hardware.',
      points: 8, color: Color(0xFFEF4444)),
  _ScoreItem(id: 'storage_encrypted', label: 'All Hive boxes encrypted',
      description: '4 sensitive boxes opened with AES-256 cipher.',
      points: 8, color: Color(0xFF3B82F6)),
  _ScoreItem(id: 'jwt_secure',     label: 'JWT in secure storage',
      description: 'Auth tokens in Keychain/Keystore — not SharedPreferences.',
      points: 8, color: Color(0xFF3B82F6)),
  _ScoreItem(id: 'key_rotation_fresh', label: 'Key rotation recent (< 90 days)',
      description: 'Hive AES key last rotated 2 days ago.',
      points: 4, color: Color(0xFF3B82F6)),
];

const _kMaxScore = 100; // sum of all points = 100

// ── Scan check definitions ────────────────────────────────────────────────────
const _kScanChecks = [
  ('cert_pinning',       'Cert pinning — api.zapsafe.app',    'SHA-256 pin match ✅'),
  ('nsc_ats',            'NSC / ATS enforced',                'Cleartext blocked ✅'),
  ('proxy_detection',    'Proxy detection',                   'No proxy active ✅'),
  ('biometric_lock',     'Biometric auto-lock',               'Timer: 1 min ✅'),
  ('lp18_gates',         'LP18 gates',                        '6/6 gates active ✅'),
  ('crypto_binding',     'Crypto binding (Keystore/Enclave)', 'Hardware key present ✅'),
  ('jailbreak_clean',    'Jailbreak scan',                    '6/6 checks clean ✅'),
  ('root_clean',         'Root scan',                         '6/6 checks clean ✅'),
  ('play_integrity',     'Play Integrity attestation',        'MEETS_DEVICE_INTEGRITY ✅'),
  ('storage_encrypted',  'Hive box encryption',               '4/4 boxes encrypted ✅'),
  ('jwt_secure',         'JWT storage',                       'Keychain/Keystore ✅'),
  ('key_rotation_fresh', 'Key rotation age',                  '2 days ago ✅'),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day189SecurityDashboardScreen extends ConsumerWidget {
  const Day189SecurityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d189TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Security Dashboard'),
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
                onSelect: (t) => ref.read(_d189TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _DashboardTab(),
            if (tab == 1) const _FullScanTab(),
            if (tab == 2) const _ScoreBreakdownTab(),
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
            colors: [Color(0xFF081208), Color(0xFF050A05), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 189',              const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section C  ·  Day 9/10',   const Color(0xFF3B82F6)),
          _badge('Security Dashboard',        const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Security\nDashboard',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Aggregates all Section C security checks into one view. '
          '12 checks across 4 feature blocks. '
          'Overall security score out of 100. '
          'Full scan simulation.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('12', '12 checks',     Color(0xFF10B981)),
          _HStat('4',  '4 blocks',      Color(0xFF8B5CF6)),
          _HStat('100','Max score',     Color(0xFF3B82F6)),
          _HStat('9/10','Section C',    Color(0xFFF59E0B)),
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
      (Icons.dashboard_rounded,   Color(0xFF10B981), 'Dashboard'),
      (Icons.radar_rounded,       Color(0xFF3B82F6), 'Full Scan'),
      (Icons.bar_chart_rounded,   Color(0xFF8B5CF6), 'Score Breakdown'),
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
// TAB 1 — Dashboard
// ══════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results  = ref.watch(_scanResultsProvider);
    final expanded = ref.watch(_expandedCardProvider);

    // Compute score from results
    final score = _kScoreItems.fold(0, (sum, item) =>
        sum + (results[item.id] == true ? item.points : 0));
    final scoreColor = score >= 85 ? const Color(0xFF10B981)
        : score >= 60 ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final scoreLabel = score >= 85 ? 'Excellent'
        : score >= 60 ? 'Moderate'
        : 'At Risk';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Score ring
      _ScoreRing(score: score, maxScore: _kMaxScore,
          color: scoreColor, label: scoreLabel),
      const SizedBox(height: ZapSpacing.xl),

      // Quick stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _quickStat('${results.values.where((v) => v).length}',
              'Checks passing', const Color(0xFF10B981)),
          _quickStat('${results.values.where((v) => !v).length}',
              'Checks failing', const Color(0xFFEF4444)),
          _quickStat('${_kFeatureCards.length}', 'Feature blocks', const Color(0xFF8B5CF6)),
          _quickStat('May 30', 'Last scan', const Color(0xFF6B7280)),
        ])),
      const SizedBox(height: ZapSpacing.xl),

      // Feature cards
      const _SectionLabel('4 SECTION C BLOCKS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kFeatureCards.asMap().entries.map((e) {
        final i    = e.key;
        final card = e.value;
        final isExp= expanded == i;
        // Card passes only if ALL its checks pass
        final allPass = card.checks.every((c) => results[c] == true);
        final passCount = card.checks.where((c) => results[c] == true).length;
        final cardColor = allPass ? card.color : const Color(0xFFEF4444);

        return GestureDetector(
          onTap: () => ref.read(_expandedCardProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? cardColor.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? cardColor.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(card.icon, color: cardColor, size: 18)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(card.name, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(card.days, style: TextStyle(color: cardColor,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                  ])),
                  // Check dots
                  Row(children: card.checks.map((c) => Container(
                      width: 8, height: 8, margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                          color: results[c] == true ? cardColor : const Color(0xFFEF4444),
                          shape: BoxShape.circle))).toList()),
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: cardColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$passCount/${card.checks.length}',
                        style: TextStyle(color: cardColor, fontSize: 9,
                            fontWeight: FontWeight.w800))),
                  const SizedBox(width: ZapSpacing.sm),
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
                        child: _FeatureDetail(card: card, results: results))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      // Toggle a failure to demo the score changing
      _infoBox(icon: Icons.touch_app_rounded, color: const Color(0xFF6B7280),
          text: 'Run the Full Scan (Tab 2) to refresh all check results. '
              'The score ring and feature card badges update live.'),
    ]);
  }

  Widget _quickStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9, height: 1.3),
        textAlign: TextAlign.center),
  ]));
}

// ── Score ring widget ─────────────────────────────────────────────────────────
class _ScoreRing extends StatelessWidget {
  final int score, maxScore;
  final Color color; final String label;
  const _ScoreRing({required this.score, required this.maxScore,
      required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final fraction = score / maxScore;
    return Center(
      child: SizedBox(
        width: 180, height: 180,
        child: Stack(alignment: Alignment.center, children: [
          // Background ring
          SizedBox(width: 180, height: 180,
              child: CircularProgressIndicator(
                  value: 1.0, strokeWidth: 14,
                  valueColor: AlwaysStoppedAnimation(
                      const Color(0xFF2A2A2A)))),
          // Score arc
          SizedBox(width: 180, height: 180,
              child: CircularProgressIndicator(
                  value: fraction, strokeWidth: 14,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color))),
          // Center content
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score', style: TextStyle(color: color, fontSize: 48,
                fontWeight: FontWeight.w900, height: 1.0)),
            Text('/ $maxScore', style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 12)),
            const SizedBox(height: ZapSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(label, style: TextStyle(color: color, fontSize: 11,
                  fontWeight: FontWeight.w800))),
          ]),
        ]),
      ));
  }
}

// ── Feature detail card ───────────────────────────────────────────────────────
class _FeatureDetail extends StatelessWidget {
  final _FeatureCard card; final Map<String, bool> results;
  const _FeatureDetail({required this.card, required this.results});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Details text
      Text(card.details, style: const TextStyle(
          color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
      const SizedBox(height: ZapSpacing.md),
      // Individual checks
      ...card.checks.map((checkId) {
        final item   = _kScoreItems.firstWhere((s) => s.id == checkId);
        final passed = results[checkId] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: passed ? card.color : const Color(0xFFEF4444), size: 14),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(item.label, style: const TextStyle(
                color: Colors.white, fontSize: 11))),
            Text('+${item.points} pts', style: TextStyle(
                color: passed ? card.color : const Color(0xFF4B5563),
                fontSize: 9, fontWeight: FontWeight.w700)),
          ]));
      }),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Full Scan
// ══════════════════════════════════════════════════════════════════════════════
class _FullScanTab extends ConsumerWidget {
  const _FullScanTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(_scanStateProvider);
    final results   = ref.watch(_scanResultsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.radar_rounded, color: const Color(0xFF3B82F6),
          text: 'Runs all 12 security checks in sequence. '
              'Results update the Dashboard score ring in real time. '
              'Takes < 500 ms on a real device.'),
      const SizedBox(height: ZapSpacing.lg),

      if (scanState == _ScanState.idle)
        _primaryBtn(
          label: 'Run Full Security Scan (12 checks)',
          color: const Color(0xFF3B82F6),
          onTap: () => _runFullScan(ref),
        )
      else ...[
        // Header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35))),
          child: Row(children: [
            scanState == _ScanState.scanning
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6), strokeWidth: 2))
                : const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              scanState == _ScanState.scanning
                  ? 'Scanning ${results.length} / ${_kScanChecks.length} checks…'
                  : 'Scan complete — ${results.values.where((v) => v).length} / ${results.length} checks passed ✅',
              style: TextStyle(
                  color: scanState == _ScanState.scanning
                      ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        const SizedBox(height: ZapSpacing.md),

        // Results list
        Container(
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(children: [
            ..._kScanChecks.asMap().entries.map((e) {
              final i = e.key;
              final (checkId, checkLabel, passDetail) = e.value;
              final isDone     = results.containsKey(checkId);
              final isRunning  = scanState == _ScanState.scanning &&
                  results.length == i;
              final passed     = results[checkId] ?? false;
              final isLast     = i == _kScanChecks.length - 1;
              final color = passed ? const Color(0xFF10B981) : const Color(0xFFEF4444);

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 9),
                  child: Row(children: [
                    isRunning
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Color(0xFF3B82F6), strokeWidth: 2))
                        : isDone
                            ? Icon(passed
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                                color: color, size: 14)
                            : const Icon(Icons.radio_button_unchecked_rounded,
                                color: Color(0xFF2A2A2A), size: 14),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(child: Text(checkLabel, style: TextStyle(
                        color: isDone || isRunning
                            ? Colors.white : const Color(0xFF4B5563),
                        fontSize: 11))),
                    if (isDone && passed)
                      Text(passDetail, style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 9)),
                  ])),
                if (!isLast) const Divider(height: 1, color: Color(0xFF1E1E1E)),
              ]);
            }),
          ])),

        if (scanState == _ScanState.done) ...[
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: () {
              ref.read(_scanStateProvider.notifier).state = _ScanState.idle;
              ref.read(_scanResultsProvider.notifier).state = _kDefaultResults;
            },
            child: const Text('Run again', style: TextStyle(
                color: Color(0xFF3B82F6), fontSize: 11,
                decoration: TextDecoration.underline))),
          const SizedBox(height: ZapSpacing.sm),
          _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF10B981),
              text: 'Score and feature card badges in Tab 1 update '
                  'based on these scan results.'),
        ],
      ],
    ]);
  }

  Future<void> _runFullScan(WidgetRef ref) async {
    ref.read(_scanStateProvider.notifier).state = _ScanState.scanning;
    ref.read(_scanResultsProvider.notifier).state = {};

    final resultMap = <String, bool>{};
    for (final (checkId, _, _) in _kScanChecks) {
      await Future.delayed(const Duration(milliseconds: 280));
      resultMap[checkId] = true;   // all pass in mock
      ref.read(_scanResultsProvider.notifier).state = Map.from(resultMap);
    }
    ref.read(_scanStateProvider.notifier).state = _ScanState.done;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Score Breakdown
// ══════════════════════════════════════════════════════════════════════════════
class _ScoreBreakdownTab extends ConsumerWidget {
  const _ScoreBreakdownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results  = ref.watch(_scanResultsProvider);
    final expanded = ref.watch(_expandedScoreProvider);
    final score    = _kScoreItems.fold(0, (sum, item) =>
        sum + (results[item.id] == true ? item.points : 0));
    final scoreColor = score >= 85 ? const Color(0xFF10B981)
        : score >= 60 ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.bar_chart_rounded, color: const Color(0xFF8B5CF6),
          text: 'How the 100-point security score is calculated. '
              '12 checks weighted by security impact. '
              'Tap any check to see what it measures.'),
      const SizedBox(height: ZapSpacing.lg),

      // Current score summary
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: scoreColor.withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            Text('$score / $_kMaxScore points',
                style: TextStyle(color: scoreColor, fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                score >= 85 ? 'Excellent 🛡️'
                    : score >= 60 ? 'Moderate ⚠'
                    : 'At Risk 🔴',
                style: TextStyle(color: scoreColor, fontSize: 12,
                    fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: score / _kMaxScore,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                  minHeight: 8)),
        ])),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('12 SCORED CHECKS  ·  TAP TO SEE DESCRIPTION'),
      const SizedBox(height: ZapSpacing.md),

      ..._kScoreItems.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value;
        final isExp= expanded == i;
        final passed = results[item.id] == true;

        return GestureDetector(
          onTap: () => ref.read(_expandedScoreProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
                color: isExp ? item.color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? item.color.withOpacity(0.35) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(children: [
                  Icon(passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: passed ? item.color : const Color(0xFFEF4444),
                      size: 14),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(item.label, style: const TextStyle(
                      color: Colors.white, fontSize: 11))),
                  // Weight bar
                  SizedBox(width: 56, child: Row(children: [
                    Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                            value: item.points / 10,
                            backgroundColor: const Color(0xFF2A2A2A),
                            valueColor: AlwaysStoppedAnimation(
                                passed ? item.color : const Color(0xFF4B5563)),
                            minHeight: 4))),
                    const SizedBox(width: ZapSpacing.xs),
                    Text('${item.points}',
                        style: TextStyle(
                            color: passed ? item.color : const Color(0xFF4B5563),
                            fontSize: 10, fontWeight: FontWeight.w700)),
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
                              color: item.color.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: item.color.withOpacity(0.2))),
                          child: Text(item.description, style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))))
                    : const SizedBox.shrink(),
              ),
            ]),
          ));
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
          text: 'Score thresholds: 85-100 = Excellent 🛡️ '
              '(all major checks pass). '
              '60-84 = Moderate ⚠ (some checks failing — review needed). '
              '0-59 = At Risk 🔴 (critical security gap — fix before shipping).'),
    ]);
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3),
                blurRadius: 14, offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

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
