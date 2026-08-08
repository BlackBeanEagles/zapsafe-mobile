/// Day 197 — Release Checklist & Quality Gates
///
/// First day of the Days 197-198 Release Checklist block.
/// Day 197: 200-day release checklist (Section A-D), quality gates
///           (crash rate, latency, size, battery).
/// Day 198: Final QA pass, build signing, APK/IPA size, block sign-off.
///
/// 🟢 FRONTEND-ONLY — release readiness documentation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d197TabProvider      = StateProvider<int>((ref) => 0);
final _checkedProvider      = StateProvider<Set<String>>((ref) => {});
final _gateRunProvider      = StateProvider<_GateState>((ref) => _GateState.idle);
final _gateResultsProvider  = StateProvider<List<_GateResult>>((ref) => []);
final _expandedSecProvider  = StateProvider<String?>((ref) => 'A'); // open section A by default

enum _GateState { idle, running, pass, fail }

// ── Checklist items ───────────────────────────────────────────────────────────
class _CheckItem {
  final String   id, section, feature, screen, description;
  final bool     critical;
  const _CheckItem({
    required this.id, required this.section, required this.feature,
    required this.screen, required this.description,
    this.critical = false,
  });
}

const _kChecklist = [
  // Section A — Privacy & Legal
  _CheckItem(id:'a1', section:'A', feature:'Privacy Policy screen', screen:'Day 151',
      description:'Scrollable policy, 7 sections, DPDP+GDPR badges, Accept bar.',
      critical: true),
  _CheckItem(id:'a2', section:'A', feature:'Policy Consent Service', screen:'Day 152',
      description:'Hive schema, GoRouter redirect, PolicyUpdateBanner widget.'),
  _CheckItem(id:'a3', section:'A', feature:'Terms of Service', screen:'Day 153',
      description:'7 sections, Section 3 emergency disclaimer, Accept bar.'),
  _CheckItem(id:'a4', section:'A', feature:'Legal Hub', screen:'Day 154',
      description:'Certificate, history, links. SHA-256 consent fingerprint.'),
  _CheckItem(id:'a5', section:'A', feature:'Consent Management', screen:'Day 155',
      description:'6 toggles (1 locked), audit log, API contract.',
      critical: true),
  _CheckItem(id:'a6', section:'A', feature:'Consent Gates', screen:'Day 156',
      description:'ConsentGate widget, SOS feature map, QuickConsentSheet.'),
  _CheckItem(id:'a7', section:'A', feature:'Privacy Settings Hub', screen:'Day 157',
      description:'Privacy Health Score, review reminder, 3-tab.'),
  _CheckItem(id:'a8', section:'A', feature:'App Permissions', screen:'Day 158',
      description:'8 OS permissions, scan, expandable cards, simulate.'),
  _CheckItem(id:'a9', section:'A', feature:'Permission Flow', screen:'Day 159',
      description:'3-step request flow, SOS availability map, status badge.'),
  _CheckItem(id:'a10', section:'A', feature:'Permission Recovery', screen:'Day 160',
      description:'5 OEM guides, timing map, health dashboard.'),
  _CheckItem(id:'a11', section:'A', feature:'Consent Gate (first launch)', screen:'Day 161',
      description:'Checkbox gate, GoRouter redirect, policy update mode.',
      critical: true),
  _CheckItem(id:'a12', section:'A', feature:'Analytics Preferences', screen:'Day 163',
      description:'Sentry toggle, usage analytics, iOS ATT mock.'),
  _CheckItem(id:'a13', section:'A', feature:'Data Safety Labels', screen:'Day 164',
      description:'Play Data Safety, events reference, Apple Privacy Label.',
      critical: true),
  _CheckItem(id:'a14', section:'A', feature:'Analytics Hub sign-off', screen:'Day 165',
      description:'Hub, GDPR 15/15, Section A complete card.'),

  // Section B — Data Rights
  _CheckItem(id:'b1', section:'B', feature:'Data Export Request', screen:'Day 166',
      description:'8-category checkboxes, format picker, mock request flow.',
      critical: true),
  _CheckItem(id:'b2', section:'B', feature:'Export Download & Integrity', screen:'Day 167',
      description:'5-phase pipeline, SHA-256, file browser.'),
  _CheckItem(id:'b3', section:'B', feature:'Export Edge Cases', screen:'Day 168',
      description:'Rate limit, 6 edge cases, GDPR Art.20 6-point.'),
  _CheckItem(id:'b4', section:'B', feature:'Account Deletion Request', screen:'Day 169',
      description:'4-step wizard, OTP re-auth, 30-day grace start.',
      critical: true),
  _CheckItem(id:'b5', section:'B', feature:'Grace Period UI', screen:'Day 170',
      description:'Countdown ring, contact notifications, cancel flow.'),
  _CheckItem(id:'b6', section:'B', feature:'Permanent Deletion', screen:'Day 171',
      description:'Day-30 walkthrough, wipe animation, wiped state.'),
  _CheckItem(id:'b7', section:'B', feature:'Deletion Edge Cases', screen:'Day 172',
      description:'6 cases, DPDP §13 6-point compliance.'),
  _CheckItem(id:'b8', section:'B', feature:'Data Access Audit Log', screen:'Day 173',
      description:'30 events, multi-filter, actor summary.'),
  _CheckItem(id:'b9', section:'B', feature:'Audit Drill-Down & Export', screen:'Day 174',
      description:'Forensic detail, CSV/PDF export, sessions.'),
  _CheckItem(id:'b10', section:'B', feature:'Third-Party Access', screen:'Day 175',
      description:'5 parties, revoke flow, DPDP §11 6-point.'),
  _CheckItem(id:'b11', section:'B', feature:'Data Retention Settings', screen:'Day 176',
      description:'7 category pickers, vault timers, GPS purge.',
      critical: true),
  _CheckItem(id:'b12', section:'B', feature:'Retention Scheduler', screen:'Day 177',
      description:'Next 7 days, scheduler, change history.'),
  _CheckItem(id:'b13', section:'B', feature:'Retention Edge Cases', screen:'Day 178',
      description:'6 cases, DPDP §8 compliance.'),
  _CheckItem(id:'b14', section:'B', feature:'Active Sessions', screen:'Day 179',
      description:'4 devices, geo anomaly, remote sign-out.'),
  _CheckItem(id:'b15', section:'B', feature:'Session Security', screen:'Day 180',
      description:'Trusted devices, JWT expiry, security alerts.'),

  // Section C — Security Hardening
  _CheckItem(id:'c1', section:'C', feature:'Certificate Pinning', screen:'Day 181',
      description:'SHA-256 SPKI, Dio interceptor, rotation plan.',
      critical: true),
  _CheckItem(id:'c2', section:'C', feature:'Network Security Config', screen:'Day 182',
      description:'Android NSC, iOS ATS, proxy detection.'),
  _CheckItem(id:'c3', section:'C', feature:'Biometric Lock & LP18', screen:'Day 183',
      description:'Auto-lock, local_auth, 6 LP18 gates.',
      critical: true),
  _CheckItem(id:'c4', section:'C', feature:'Biometric Hardening', screen:'Day 184',
      description:'Keystore/Enclave crypto binding, Frida-proof.'),
  _CheckItem(id:'c5', section:'C', feature:'Root/Jailbreak Detection', screen:'Day 185',
      description:'6 iOS + 6 Android checks, 3 response modes.',
      critical: true),
  _CheckItem(id:'c6', section:'C', feature:'Tamper Alert UI', screen:'Day 186',
      description:'Safe Mode + Block screens, weighted scoring.'),
  _CheckItem(id:'c7', section:'C', feature:'Secure Storage Audit', screen:'Day 187',
      description:'4 stores, data map, 8-point audit scan.',
      critical: true),
  _CheckItem(id:'c8', section:'C', feature:'Hive Key Rotation', screen:'Day 188',
      description:'3 triggers, 7-step pipeline, rotation history.'),
  _CheckItem(id:'c9', section:'C', feature:'Security Dashboard', screen:'Day 189',
      description:'Score ring, 4 feature cards, full scan.'),

  // Section D — Store Prep
  _CheckItem(id:'d1', section:'D', feature:'App Store Screenshots', screen:'Day 191',
      description:'6 hero screens, device frames, store specs.'),
  _CheckItem(id:'d2', section:'D', feature:'Screenshot Frames & Export', screen:'Day 192',
      description:'3 frame tools, localisation, 16-item checklist.'),
  _CheckItem(id:'d3', section:'D', feature:'Store Listing Copy', screen:'Day 193',
      description:'Title, short desc, full desc, 8 ASO keywords.',
      critical: true),
  _CheckItem(id:'d4', section:'D', feature:'Promo & Hindi Listing', screen:'Day 194',
      description:'Promo text, What\'s New, Hindi translation, 4 A/B tests.'),
  _CheckItem(id:'d5', section:'D', feature:'Privacy Policy & IARC', screen:'Day 195',
      description:'Policy URL, IARC PEGI 12, 13-item compliance list.',
      critical: true),
  _CheckItem(id:'d6', section:'D', feature:'Privacy Alignment', screen:'Day 196',
      description:'3-way alignment, Data Safety 7 Qs.'),
];

// ── Section metadata ──────────────────────────────────────────────────────────
const _kSections = {
  'A': ('Privacy & Legal',     'Days 151-165', Color(0xFF3B82F6)),
  'B': ('Data Rights',         'Days 166-180', Color(0xFF8B5CF6)),
  'C': ('Security Hardening',  'Days 181-190', Color(0xFF10B981)),
  'D': ('Store Prep & Polish', 'Days 191-197', Color(0xFFF59E0B)),
};

// ── Quality gates ─────────────────────────────────────────────────────────────
class _Gate {
  final String   name, description, target, unit;
  final double   measured;
  final bool     passes;
  final IconData icon;
  final Color    color;
  const _Gate({
    required this.name, required this.description,
    required this.target, required this.unit,
    required this.measured, required this.passes,
    required this.icon, required this.color,
  });
}

class _GateResult {
  final String name; final bool passed;
  const _GateResult({required this.name, required this.passed});
}

const _kGates = [
  _Gate(
    name: 'Crash-free session rate',
    description: 'Percentage of sessions with no unhandled exceptions. '
        'Measured via Sentry. Store requires ≥ 99%.',
    target: '≥ 99.0%', unit: '%',
    measured: 99.4, passes: true,
    icon: Icons.bug_report_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'p99 detection latency',
    description: 'End-to-end latency from sensor input to DCS score output '
        'at the 99th percentile. ZapSafe budget: ≤ 530 ms.',
    target: '≤ 530 ms', unit: 'ms',
    measured: 487, passes: true,
    icon: Icons.speed_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'SOS dispatch latency',
    description: 'Time from SOS trigger to first contact notification '
        'being sent. Target: ≤ 3 seconds (end-to-end including network).',
    target: '≤ 3000 ms', unit: 'ms',
    measured: 1840, passes: true,
    icon: Icons.bolt_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'Cold start time',
    description: 'Time from app launch to first interactive screen. '
        'Day 145 cold start optimisation target.',
    target: '≤ 2000 ms', unit: 'ms',
    measured: 1420, passes: true,
    icon: Icons.rocket_launch_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'APK download size',
    description: 'Compressed APK download size on Play Store. '
        'Target: ≤ 30 MB (Day 141-144 optimisations).',
    target: '≤ 30 MB', unit: 'MB',
    measured: 27.4, passes: true,
    icon: Icons.android_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'IPA download size',
    description: 'App Store download size for iPhone. '
        'Target: ≤ 35 MB.',
    target: '≤ 35 MB', unit: 'MB',
    measured: 29.1, passes: true,
    icon: Icons.apple_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'Battery drain (1-hour SOS active)',
    description: 'Battery % consumed with SOS active, GPS streaming, '
        'and audio recording running for 1 hour.',
    target: '≤ 15%', unit: '%',
    measured: 11.2, passes: true,
    icon: Icons.battery_charging_full_rounded, color: Color(0xFF10B981)),
  _Gate(
    name: 'Memory (steady state)',
    description: 'RAM usage after 10 minutes of normal use. '
        'Day 130-132 memory leak fixes applied.',
    target: '≤ 180 MB', unit: 'MB',
    measured: 142, passes: true,
    icon: Icons.memory_rounded, color: Color(0xFF10B981)),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day197ReleaseChecklistScreen extends ConsumerWidget {
  const Day197ReleaseChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d197TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Release Checklist'),
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
                onSelect: (t) => ref.read(_d197TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ChecklistTab(),
            if (tab == 1) const _GatesTab(),
            if (tab == 2) const _ReadinessTab(),
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
            colors: [Color(0xFF080A14), Color(0xFF050812), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 197',              const Color(0xFF3B82F6)),
          _badge('🟢 FRONTEND-ONLY',         const Color(0xFF10B981)),
          _badge('Section D  ·  Day 7/10',   const Color(0xFF8B5CF6)),
          _badge('Checklist  ·  Day 1/2',    const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Release Checklist\n& Quality Gates',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '38 release items across Sections A-D. '
          '8 quality gates (crash rate ≥99%, latency ≤530ms, '
          'APK ≤30MB, battery ≤15%). All simulated as passing.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('38', '38 checklist items', Color(0xFF3B82F6)),
          _HStat('12', '12 critical',         Color(0xFFEF4444)),
          _HStat('8',  '8 quality gates',     Color(0xFF10B981)),
          _HStat('✅', 'All passing',          Color(0xFF10B981)),
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
      (Icons.checklist_rounded,   Color(0xFF3B82F6), 'Checklist'),
      (Icons.speed_rounded,       Color(0xFF10B981), 'Quality Gates'),
      (Icons.rocket_launch_rounded,Color(0xFF8B5CF6), 'Readiness'),
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
// TAB 1 — Release Checklist
// ══════════════════════════════════════════════════════════════════════════════
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked     = ref.watch(_checkedProvider);
    final expandedSec = ref.watch(_expandedSecProvider);
    final total       = _kChecklist.length;
    final done        = checked.length;
    final critTotal   = _kChecklist.where((c) => c.critical).length;
    final critDone    = _kChecklist.where(
        (c) => c.critical && checked.contains(c.id)).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Global progress
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            _pStat('$done/$total', 'Items', const Color(0xFF3B82F6)),
            _pStat('$critDone/$critTotal', 'Critical ✅', const Color(0xFFEF4444)),
            _pStat('${total - done}', 'Remaining', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                      done == total ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                  minHeight: 7)),
          if (done == total) ...[
            const SizedBox(height: ZapSpacing.sm),
            const Text('All 38 items checked — ready for Day 198 QA pass ✅',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 11,
                    fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ],
        ])),
      const SizedBox(height: ZapSpacing.lg),

      // Mark all / clear all
      Row(children: [
        Expanded(child: _outlineBtn('Mark all', const Color(0xFF10B981), () {
          ref.read(_checkedProvider.notifier).state =
              _kChecklist.map((c) => c.id).toSet();
        })),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: _outlineBtn('Clear all', const Color(0xFF6B7280), () {
          ref.read(_checkedProvider.notifier).state = {};
        })),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Sections
      ..._kSections.entries.map((secEntry) {
        final secId = secEntry.key;
        final (secName, secDays, secColor) = secEntry.value;
        final secItems = _kChecklist.where((c) => c.section == secId).toList();
        final secDone  = secItems.where((c) => checked.contains(c.id)).length;
        final isExp    = expandedSec == secId;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Section header
          GestureDetector(
            onTap: () => ref.read(_expandedSecProvider.notifier).state =
                isExp ? null : secId,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                  color: isExp ? secColor.withOpacity(0.08) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExp ? secColor.withOpacity(0.4) : const Color(0xFF2A2A2A),
                      width: isExp ? 2 : 1)),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                      color: secColor.withOpacity(0.12), shape: BoxShape.circle,
                      border: Border.all(color: secColor.withOpacity(0.4))),
                  child: Center(child: Text(secId, style: TextStyle(
                      color: secColor, fontSize: 12, fontWeight: FontWeight.w900)))),
                const SizedBox(width: ZapSpacing.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Section $secId — $secName',
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text('$secDays  ·  $secDone/${secItems.length} checked',
                      style: TextStyle(color: secColor, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ])),
                // Mini progress
                SizedBox(width: 60, child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: secItems.isEmpty ? 0 : secDone / secItems.length,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation(secColor),
                        minHeight: 4))),
                const SizedBox(width: ZapSpacing.sm),
                Icon(isExp ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF4B5563), size: 16),
              ])),
          ),

          // Items
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: isExp
                ? Container(
                    margin: const EdgeInsets.only(top: 2, bottom: ZapSpacing.lg),
                    decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                        border: Border.all(color: const Color(0xFF1E1E1E))),
                    child: Column(children: secItems.asMap().entries.map((e) {
                      final i   = e.key;
                      final item= e.value;
                      final isDone = checked.contains(item.id);
                      return Column(children: [
                        GestureDetector(
                          onTap: () {
                            final updated = Set<String>.from(checked);
                            if (isDone) {
                              updated.remove(item.id);
                            } else {
                              updated.add(item.id);
                            }
                            ref.read(_checkedProvider.notifier).state = updated;
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(ZapSpacing.md),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                    color: isDone ? secColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: isDone ? secColor : const Color(0xFF3A3A3A),
                                        width: 2)),
                                child: isDone
                                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                                    : null),
                              const SizedBox(width: ZapSpacing.md),
                              Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(item.feature,
                                      style: TextStyle(
                                          color: isDone
                                              ? const Color(0xFF6B7280) : Colors.white,
                                          fontSize: 11, fontWeight: FontWeight.w600,
                                          decoration: isDone
                                              ? TextDecoration.lineThrough : null))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: secColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(item.screen,
                                        style: TextStyle(color: secColor, fontSize: 8,
                                            fontWeight: FontWeight.w700))),
                                  if (item.critical && !isDone) ...[
                                    const SizedBox(width: ZapSpacing.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6)),
                                      child: const Text('!',
                                          style: TextStyle(color: Color(0xFFEF4444),
                                              fontSize: 9, fontWeight: FontWeight.w800))),
                                  ],
                                ]),
                                Text(item.description, style: const TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 10, height: 1.3)),
                              ])),
                            ])),
                        ),
                        if (i < secItems.length - 1)
                          const Divider(height: 1, color: Color(0xFF1E1E1E)),
                      ]);
                    }).toList()))
                : const SizedBox(height: ZapSpacing.md),
          ),
        ]);
      }),
    ]);
  }

  Widget _pStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Quality Gates
// ══════════════════════════════════════════════════════════════════════════════
class _GatesTab extends ConsumerWidget {
  const _GatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateState = ref.watch(_gateRunProvider);
    final results   = ref.watch(_gateResultsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.speed_rounded, color: const Color(0xFF10B981),
          text: '8 quantitative gates that must pass before shipping. '
              'Values are from the mock metrics established in Days 129-150. '
              'All 8 pass in simulation.'),
      const SizedBox(height: ZapSpacing.lg),

      // Run button
      if (gateState == _GateState.idle)
        _primaryBtn(
          label: 'Run Quality Gates Check',
          color: const Color(0xFF10B981),
          onTap: () => _runGates(ref),
        )
      else if (gateState == _GateState.running)
        _GatesRunning(results: results)
      else
        _GatesDone(results: results, ref: ref),

      const SizedBox(height: ZapSpacing.xl),

      // Gate detail cards
      const _SectionLabel('8 QUALITY GATES  ·  METRICS & TARGETS'),
      const SizedBox(height: ZapSpacing.md),
      ..._kGates.map((gate) => Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: gate.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: gate.color.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(gate.icon, color: gate.color, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(gate.name, style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${gate.measured}${gate.unit}',
                    style: TextStyle(color: gate.color, fontSize: 14,
                        fontWeight: FontWeight.w900)),
                Text(gate.target, style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 9)),
              ]),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            // Progress bar (visual only)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: _gateProgress(gate),
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(gate.color),
                  minHeight: 5)),
            const SizedBox(height: 6),
            Text(gate.description, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
          ]))),
    ]);
  }

  static double _gateProgress(_Gate gate) {
    // Normalize to 0-1 where 1.0 = hitting the target exactly
    // For "≤ N" gates, progress = min(target/measured, 1.0)
    // For "≥ N" gates, progress = min(measured/target, 1.0)
    final name = gate.name.toLowerCase();
    if (name.contains('crash') || name.contains('battery')) {
      // Higher is better for crash rate; lower is better for battery
      return name.contains('crash')
          ? (gate.measured / 100).clamp(0.0, 1.0)
          : 1 - (gate.measured / 20).clamp(0.0, 1.0);
    }
    // For latency/size/memory: lower is better, progress shows how close to max
    final maxVal = switch (gate.name) {
      String s when s.contains('detection') => 530.0,
      String s when s.contains('SOS') => 3000.0,
      String s when s.contains('cold') => 2000.0,
      String s when s.contains('APK') => 30.0,
      String s when s.contains('IPA') => 35.0,
      String s when s.contains('Memory') => 180.0,
      _ => gate.measured * 1.5,
    };
    return (1 - gate.measured / maxVal).clamp(0.0, 1.0);
  }

  Future<void> _runGates(WidgetRef ref) async {
    ref.read(_gateRunProvider.notifier).state = _GateState.running;
    ref.read(_gateResultsProvider.notifier).state = [];
    final list = <_GateResult>[];
    for (final gate in _kGates) {
      await Future.delayed(const Duration(milliseconds: 400));
      list.add(_GateResult(name: gate.name, passed: gate.passes));
      ref.read(_gateResultsProvider.notifier).state = List.from(list);
    }
    final allPass = _kGates.every((g) => g.passes);
    ref.read(_gateRunProvider.notifier).state =
        allPass ? _GateState.pass : _GateState.fail;
  }
}

class _GatesRunning extends StatelessWidget {
  final List<_GateResult> results;
  const _GatesRunning({required this.results});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              color: Color(0xFF10B981), strokeWidth: 2)),
          SizedBox(width: ZapSpacing.sm),
          Text('Running quality gates…', style: TextStyle(
              color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        if (results.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: r.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(r.name, style: const TextStyle(
                    color: Colors.white, fontSize: 10))),
              ]))),
        ],
      ]));
}

class _GatesDone extends StatelessWidget {
  final List<_GateResult> results; final WidgetRef ref;
  const _GatesDone({required this.results, required this.ref});

  @override
  Widget build(BuildContext context) {
    final allPass = results.every((r) => r.passed);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: (allPass ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                .withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: (allPass ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                    .withOpacity(0.35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(allPass ? Icons.verified_rounded : Icons.cancel_rounded,
                color: allPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(allPass
                ? 'All 8 gates PASSED ✅ — cleared for release'
                : 'Gates FAILED — fix before shipping',
                style: TextStyle(
                    color: allPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          ...results.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Icon(r.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: r.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 13),
                const SizedBox(width: 6),
                Expanded(child: Text(r.name, style: const TextStyle(
                    color: Colors.white, fontSize: 10))),
                Text(r.passed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                        color: r.passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 9, fontWeight: FontWeight.w800)),
              ]))),
        ])),
      const SizedBox(height: ZapSpacing.sm),
      GestureDetector(
        onTap: () {
          ref.read(_gateRunProvider.notifier).state = _GateState.idle;
          ref.read(_gateResultsProvider.notifier).state = [];
        },
        child: const Text('Run again', style: TextStyle(
            color: Color(0xFF3B82F6), fontSize: 11,
            decoration: TextDecoration.underline))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Release Readiness
// ══════════════════════════════════════════════════════════════════════════════
class _ReadinessTab extends ConsumerWidget {
  const _ReadinessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_checkedProvider);
    final total   = _kChecklist.length;
    final done    = checked.length;
    final pct     = total > 0 ? done / total : 0.0;
    final allGatesPass = _kGates.every((g) => g.passes);
    final critDone = _kChecklist.where(
        (c) => c.critical && checked.contains(c.id)).length;
    final critTotal = _kChecklist.where((c) => c.critical).length;

    // Overall readiness
    final overallReady = pct >= 1.0 && allGatesPass;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Big readiness card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            (overallReady ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                .withOpacity(0.12),
            (overallReady ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                .withOpacity(0.03),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: (overallReady ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                  .withOpacity(0.5), width: 2),
        ),
        child: Column(children: [
          Text(overallReady ? '🚀' : '⏳', style: const TextStyle(fontSize: 44)),
          const SizedBox(height: ZapSpacing.md),
          Text(
            overallReady
                ? 'READY FOR RELEASE 🚀'
                : 'COMPLETE CHECKLIST TO PROCEED',
            style: TextStyle(
                color: overallReady ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                fontSize: 16, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            overallReady
                ? 'All 38 items checked. 8 quality gates pass. '
                  'Proceed to Day 198 final QA.'
                : '$done/$total items checked. '
                  'Mark all items in the Checklist tab to enable.',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
            textAlign: TextAlign.center),
        ])),
      const SizedBox(height: ZapSpacing.xl),

      // Status summary
      const _SectionLabel('READINESS SUMMARY'),
      const SizedBox(height: ZapSpacing.md),
      ...[
        ('Release checklist',
            '$done / $total items checked',
            pct >= 1.0,
            Icons.checklist_rounded,
            const Color(0xFF3B82F6)),
        ('Critical items',
            '$critDone / $critTotal critical items checked',
            critDone == critTotal,
            Icons.priority_high_rounded,
            const Color(0xFFEF4444)),
        ('Quality gates',
            allGatesPass ? '8 / 8 gates pass' : 'Run gates in Tab 2',
            allGatesPass,
            Icons.speed_rounded,
            const Color(0xFF10B981)),
        ('Section A (Privacy & Legal)',
            '${_kChecklist.where((c) => c.section == "A" && checked.contains(c.id)).length}/${_kChecklist.where((c) => c.section == "A").length} items',
            _kChecklist.where((c) => c.section == 'A').every((c) => checked.contains(c.id)),
            Icons.policy_rounded,
            const Color(0xFF3B82F6)),
        ('Section B (Data Rights)',
            '${_kChecklist.where((c) => c.section == "B" && checked.contains(c.id)).length}/${_kChecklist.where((c) => c.section == "B").length} items',
            _kChecklist.where((c) => c.section == 'B').every((c) => checked.contains(c.id)),
            Icons.download_rounded,
            const Color(0xFF8B5CF6)),
        ('Section C (Security)',
            '${_kChecklist.where((c) => c.section == "C" && checked.contains(c.id)).length}/${_kChecklist.where((c) => c.section == "C").length} items',
            _kChecklist.where((c) => c.section == 'C').every((c) => checked.contains(c.id)),
            Icons.shield_rounded,
            const Color(0xFF10B981)),
        ('Section D (Store Prep)',
            '${_kChecklist.where((c) => c.section == "D" && checked.contains(c.id)).length}/${_kChecklist.where((c) => c.section == "D").length} items',
            _kChecklist.where((c) => c.section == 'D').every((c) => checked.contains(c.id)),
            Icons.store_rounded,
            const Color(0xFFF59E0B)),
      ].map((s) {
        final (label, sublabel, passes, icon, color) = s;
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: passes ? color.withOpacity(0.06) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: passes ? color.withOpacity(0.3) : const Color(0xFF2A2A2A))),
          child: Row(children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w600)),
              Text(sublabel, style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10)),
            ])),
            Icon(passes ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: passes ? color : const Color(0xFF3A3A3A), size: 16),
          ]));
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF8B5CF6),
          text: 'Day 198 completes the checklist block: '
              'manual user flow tests, build signing, '
              'APK/IPA size verification, and the Days 197-198 sign-off. '
              'Then only Days 199-200 remain! 🏆'),
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

Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
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
