/// Day 173 — Data Access Audit Log: Timeline
///
/// First day of the Days 173-175 Data Access Audit Log block.
/// Day 173: Full audit timeline — 30 events, date-group, multi-filter.
/// Day 174: Per-event drill-down + IP handling + CSV/PDF export.
/// Day 175: Third-party access log + revoke access + block sign-off.
///
/// 🟡 MOCK-NOW — backend at Day 78. No audit-log API yet.
///    Replace _kMockEvents with GET /api/v1/data-access/audit-log when ready.
///    Full API contract in Tab 3.
///
/// Legal basis:
///   DPDP Act 2023 §11(1)(a) — right to know what data is processed.
///   GDPR Art. 15(1)(c)      — right to know who has accessed personal data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _typeFilterProvider   = StateProvider<_EventType?>((ref) => null);
final _timeFilterProvider   = StateProvider<_TimeRange>((ref) => _TimeRange.days30);
final _catFilterProvider    = StateProvider<_DataCat?>((ref) => null);
final _expandedProvider     = StateProvider<String?>((ref) => null);  // event id
final _searchQueryProvider  = StateProvider<String>((ref) => '');
final _statExpandedProvider = StateProvider<int?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _EventType  { read, write, delete, export, login, failed }
enum _TimeRange  { days7, days30, days90, all }
enum _DataCat    { sos, contacts, evidence, location, profile, settings, analytics }

// ── Data model ─────────────────────────────────────────────────────────────────
class _AuditEvent {
  final String    id;
  final DateTime  ts;
  final _EventType type;
  final _DataCat   cat;
  final String    actor;        // 'You', 'ZapSafe System', 'Trust & Safety', etc.
  final String    action;       // human-readable one-liner
  final String    detail;       // expanded detail text
  final String    device;
  final String    location;     // city-level only; IP redacted per DPDP
  final bool      suspicious;
  const _AuditEvent({
    required this.id, required this.ts, required this.type, required this.cat,
    required this.actor, required this.action, required this.detail,
    required this.device, required this.location, this.suspicious = false,
  });
}

// ── 30 mock events spanning ~35 days ──────────────────────────────────────────
final _kMockEvents = <_AuditEvent>[
  _AuditEvent(id: 'ae001', ts: DateTime(2026, 5, 30, 14, 25),
      type: _EventType.export, cat: _DataCat.profile,
      actor: 'You', action: 'Requested full data export (ZIP)',
      detail: 'All 8 data categories selected. Format: ZIP. '
          'Request ID: exp_20260530_abc123. Triggered from Settings → Download My Data.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae002', ts: DateTime(2026, 5, 30, 14, 15),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Toggled analytics consent → OFF',
      detail: 'analytics_consent changed from true to false. '
          'Sentry SDK stopped immediately. Consent record updated in Hive.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae003', ts: DateTime(2026, 5, 29, 22, 45),
      type: _EventType.read, cat: _DataCat.sos,
      actor: 'ZapSafe System', action: 'SOS dispatch read emergency contacts',
      detail: 'Automated read of 3 emergency contacts during SOS event sos_20260529. '
          'Read scope: phone, tier, verification_status only.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae004', ts: DateTime(2026, 5, 29, 22, 44),
      type: _EventType.write, cat: _DataCat.sos,
      actor: 'You', action: 'SOS triggered — event created',
      detail: 'SOS event sos_20260529 created. Method: power-button × 5. '
          'Location included: YES. DCS score: 0.91.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae005', ts: DateTime(2026, 5, 28, 10, 12),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Signed in via OTP',
      detail: 'Successful OTP authentication. '
          'JWT issued, expires in 30 days. Device registered.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae006', ts: DateTime(2026, 5, 27, 18, 05),
      type: _EventType.write, cat: _DataCat.contacts,
      actor: 'You', action: 'Added emergency contact — Sunita Rao (Tier 2)',
      detail: 'New contact Sunita Rao added at Tier 2. '
          'Phone: +91 97700 ****. Verification SMS sent.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae007', ts: DateTime(2026, 5, 26, 9, 00),
      type: _EventType.read, cat: _DataCat.evidence,
      actor: 'You', action: 'Opened Evidence Vault — SOS event sos_20260515',
      detail: 'Read access to vault for sos_20260515. '
          'Viewed: audio.aac, gps_trace.json. PIN verified (vault_pin). '
          'Integrity hash verified: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae008', ts: DateTime(2026, 5, 25, 16, 30),
      type: _EventType.failed, cat: _DataCat.evidence,
      actor: 'Unknown', action: 'Failed vault PIN attempt (3 of 5)',
      detail: 'Incorrect vault PIN entered 3 times. '
          'Warning threshold reached. Next 2 failures trigger key rotation. '
          'Device: iPad Air (unrecognised session).',
      device: 'iPad Air', location: 'Pune, India', suspicious: true),
  _AuditEvent(id: 'ae009', ts: DateTime(2026, 5, 24, 11, 45),
      type: _EventType.read, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'GPS batch uploaded to server',
      detail: 'Automated GPS batch upload — 47 location points. '
          'Accuracy filter applied (≤ 50 m only). '
          'Retained for 14 days, then auto-deleted.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae010', ts: DateTime(2026, 5, 24, 8, 00),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Biometric sign-in',
      detail: 'Fingerprint authentication successful on app cold start.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae011', ts: DateTime(2026, 5, 22, 14, 00),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Updated DCS sensitivity → High',
      detail: 'dcs_sensitivity changed from Medium to High. '
          'Scream threshold: 0.70 → 0.60. Motion threshold: 0.75 → 0.65.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae012', ts: DateTime(2026, 5, 21, 9, 30),
      type: _EventType.read, cat: _DataCat.profile,
      actor: 'Trust & Safety', action: 'Manual account review initiated',
      detail: 'ZapSafe Trust & Safety team reviewed account following '
          '3 failed vault PIN attempts on May 25. '
          'Review scope: account status, login history. No data copied.',
      device: 'Internal Tools', location: 'ZapSafe HQ'),
  _AuditEvent(id: 'ae013', ts: DateTime(2026, 5, 20, 20, 15),
      type: _EventType.delete, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'Auto-deleted expired GPS batch',
      detail: 'GPS location batch from May 6 auto-deleted after 14-day retention. '
          '312 location points removed. DPDP data-minimisation policy.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae014', ts: DateTime(2026, 5, 19, 17, 50),
      type: _EventType.write, cat: _DataCat.contacts,
      actor: 'You', action: 'Changed Tier 1 contact — Rahul Sharma updated',
      detail: 'Phone number updated for Rahul Sharma (Tier 1). '
          'Verification re-sent. Old phone: +91 98111 ****. New: +91 98222 ****.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae015', ts: DateTime(2026, 5, 18, 12, 00),
      type: _EventType.read, cat: _DataCat.analytics,
      actor: 'ZapSafe System', action: 'Crash report submitted to Sentry',
      detail: 'Unhandled exception in AudioCaptureService.dart (line 142). '
          'Stack trace sent. No PII included. Consent: crash_reporting = true.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae016', ts: DateTime(2026, 5, 17, 14, 30),
      type: _EventType.export, cat: _DataCat.profile,
      actor: 'You', action: 'Downloaded data export (ZIP) — exp_20260517',
      detail: 'ZIP export downloaded. File: 49.8 MB. '
          'SHA-256 integrity verified: PASS. '
          'Download URL fetched from: GET /api/v1/data-export/download/exp_20260517.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae017', ts: DateTime(2026, 5, 16, 8, 45),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Signed in via OTP — new device',
      detail: 'OTP authentication from unrecognised device (iPad Air). '
          'New session created. Push notification sent to primary device.',
      device: 'iPad Air', location: 'Pune, India'),
  _AuditEvent(id: 'ae018', ts: DateTime(2026, 5, 15, 23, 10),
      type: _EventType.write, cat: _DataCat.sos,
      actor: 'You', action: 'SOS triggered — event sos_20260515',
      detail: 'SOS event created. Method: app button. '
          'Location: YES. DCS score: 0.88. 3 contacts notified.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae019', ts: DateTime(2026, 5, 14, 11, 00),
      type: _EventType.delete, cat: _DataCat.contacts,
      actor: 'You', action: 'Removed contact — Meera Singh (Tier 3)',
      detail: 'Contact Meera Singh permanently removed. '
          'LP18 biometric gate: PASSED. No outstanding SOS dependencies.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae020', ts: DateTime(2026, 5, 13, 7, 30),
      type: _EventType.read, cat: _DataCat.evidence,
      actor: 'You', action: 'Opened Evidence Vault — SOS sos_20260515',
      detail: 'Read access to vault. Viewed all 6 streams. '
          'Audio playback: 3m 42s. PIN verified. Integrity: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae021', ts: DateTime(2026, 5, 10, 15, 00),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Added safe zone — Home',
      detail: 'Safe zone "Home" created. Centre: 19.0760°N 72.8777°E. '
          'Radius: 100 m.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae022', ts: DateTime(2026, 5, 8, 9, 15),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Biometric sign-in',
      detail: 'Face ID authentication successful.',
      device: 'iPad Air', location: 'Pune, India'),
  _AuditEvent(id: 'ae023', ts: DateTime(2026, 5, 5, 14, 20),
      type: _EventType.failed, cat: _DataCat.profile,
      actor: 'Unknown', action: 'Failed OTP — incorrect code (2 attempts)',
      detail: 'Two consecutive OTP failures. Phone: +91 98765 43210. '
          'Third failure would lock the phone for 1 hour.',
      device: 'Unknown device', location: 'Hyderabad, India', suspicious: true),
  _AuditEvent(id: 'ae024', ts: DateTime(2026, 5, 3, 10, 00),
      type: _EventType.read, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'GPS batch uploaded to server',
      detail: 'Automated GPS batch — 63 points. 14-day retention.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae025', ts: DateTime(2026, 5, 1, 18, 30),
      type: _EventType.write, cat: _DataCat.analytics,
      actor: 'You', action: 'Crash reporting consent → ON',
      detail: 'crash_reporting changed from false to true. '
          'Sentry SDK initialised. Consent timestamp stored in Hive.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae026', ts: DateTime(2026, 4, 28, 12, 00),
      type: _EventType.delete, cat: _DataCat.evidence,
      actor: 'You', action: 'Extended evidence expiry — SOS sos_20260401',
      detail: 'Vault expiry for sos_20260401 extended by 30 days. '
          'New expiry: June 1, 2026.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae027', ts: DateTime(2026, 4, 15, 9, 00),
      type: _EventType.read, cat: _DataCat.sos,
      actor: 'ZapSafe System', action: 'Check-in timer auto-escalated',
      detail: 'Check-in timer "Evening walk" expired without response. '
          'Tier 1 contact (Rahul Sharma) notified via push + SMS.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae028', ts: DateTime(2026, 4, 10, 16, 45),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Language changed → Hindi',
      detail: 'App language changed from English to Hindi. '
          'Locale: hi_IN. Took effect immediately.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae029', ts: DateTime(2026, 4, 5, 11, 20),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Signed in via OTP',
      detail: 'Successful OTP sign-in on app reinstall.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae030', ts: DateTime(2026, 4, 2, 9, 15),
      type: _EventType.export, cat: _DataCat.profile,
      actor: 'You', action: 'Downloaded data export (JSON) — exp_20260402',
      detail: 'JSON export downloaded. File: 1.3 MB. Integrity: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
];

// ── Helper maps ────────────────────────────────────────────────────────────────
const _typeLabel = {
  _EventType.read:   'Read',
  _EventType.write:  'Write',
  _EventType.delete: 'Delete',
  _EventType.export: 'Export',
  _EventType.login:  'Login',
  _EventType.failed: 'Failed',
};

const _typeColor = {
  _EventType.read:   Color(0xFF10B981),
  _EventType.write:  Color(0xFF3B82F6),
  _EventType.delete: Color(0xFFEF4444),
  _EventType.export: Color(0xFF8B5CF6),
  _EventType.login:  Color(0xFFF59E0B),
  _EventType.failed: Color(0xFFEF4444),
};

const _typeIcon = {
  _EventType.read:   Icons.visibility_rounded,
  _EventType.write:  Icons.edit_rounded,
  _EventType.delete: Icons.delete_rounded,
  _EventType.export: Icons.download_rounded,
  _EventType.login:  Icons.login_rounded,
  _EventType.failed: Icons.block_rounded,
};

const _catLabel = {
  _DataCat.sos:       'SOS Events',
  _DataCat.contacts:  'Contacts',
  _DataCat.evidence:  'Evidence',
  _DataCat.location:  'Location',
  _DataCat.profile:   'Profile',
  _DataCat.settings:  'Settings',
  _DataCat.analytics: 'Analytics',
};

const _catColor = {
  _DataCat.sos:       Color(0xFFEF4444),
  _DataCat.contacts:  Color(0xFF10B981),
  _DataCat.evidence:  Color(0xFFF59E0B),
  _DataCat.location:  Color(0xFF10B981),
  _DataCat.profile:   Color(0xFF3B82F6),
  _DataCat.settings:  Color(0xFF6B7280),
  _DataCat.analytics: Color(0xFF8B5CF6),
};

const _catIcon = {
  _DataCat.sos:       Icons.warning_rounded,
  _DataCat.contacts:  Icons.people_rounded,
  _DataCat.evidence:  Icons.lock_rounded,
  _DataCat.location:  Icons.location_on_rounded,
  _DataCat.profile:   Icons.account_circle_rounded,
  _DataCat.settings:  Icons.settings_rounded,
  _DataCat.analytics: Icons.bar_chart_rounded,
};

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day173DataAccessAuditScreen extends ConsumerWidget {
  const Day173DataAccessAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Data Access Audit Log'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
            ),
            child: const Text('DPDP §11',
                style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10,
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
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _TimelineTab(),
            if (tab == 1) const _SummaryTab(),
            if (tab == 2) const _ApiContractTab(),
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
            colors: [Color(0xFF080E14), Color(0xFF040810), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 173',          const Color(0xFF3B82F6)),
          _badge('🟡 MOCK-NOW',          const Color(0xFFF59E0B)),
          _badge('Data Rights  ·  Day 1/3', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Data Access\nAudit Log',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'DPDP §11(1)(a) + GDPR Art. 15(1)(c) — your right to know '
          'who accessed your data, what was accessed, and when. '
          '30 events across 6 types, filterable by type, time, and category.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('30',   '30 events',      Color(0xFF3B82F6)),
          _HStat('6',    '6 event types',  Color(0xFF10B981)),
          _HStat('4',    '4 actors',       Color(0xFFF59E0B)),
          _HStat('2',    '2 suspicious',   Color(0xFFEF4444)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
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
      (Icons.timeline_rounded,   Color(0xFF3B82F6), 'Timeline'),
      (Icons.bar_chart_rounded,  Color(0xFF10B981), 'Summary'),
      (Icons.code_rounded,       Color(0xFFF59E0B), 'API Contract'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(
        child: GestureDetector(
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
                  color: isActive ? color : const Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Timeline
// ══════════════════════════════════════════════════════════════════════════════
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeFilter  = ref.watch(_typeFilterProvider);
    final timeFilter  = ref.watch(_timeFilterProvider);
    final catFilter   = ref.watch(_catFilterProvider);
    final searchQuery = ref.watch(_searchQueryProvider).toLowerCase();
    final expanded    = ref.watch(_expandedProvider);

    // Apply filters
    final cutoff = switch (timeFilter) {
      _TimeRange.days7  => DateTime.now().subtract(const Duration(days: 7)),
      _TimeRange.days30 => DateTime.now().subtract(const Duration(days: 30)),
      _TimeRange.days90 => DateTime.now().subtract(const Duration(days: 90)),
      _TimeRange.all    => DateTime(2000),
    };

    final filtered = _kMockEvents.where((e) {
      if (e.ts.isBefore(cutoff)) return false;
      if (typeFilter != null && e.type != typeFilter) return false;
      if (catFilter != null && e.cat != catFilter) return false;
      if (searchQuery.isNotEmpty &&
          !e.action.toLowerCase().contains(searchQuery) &&
          !e.actor.toLowerCase().contains(searchQuery) &&
          !_catLabel[e.cat]!.toLowerCase().contains(searchQuery)) return false;
      return true;
    }).toList();

    // Group by date
    final groups = <String, List<_AuditEvent>>{};
    for (final e in filtered) {
      final key = _dateKey(e.ts);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'Every read, write, delete, export, login, and failed attempt '
              'is recorded. Tap any event to see full details. '
              'Search or filter to find specific events.'),
      const SizedBox(height: ZapSpacing.lg),

      // Search bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
              hintText: 'Search events…',
              hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
              border: InputBorder.none,
              icon: Icon(Icons.search_rounded, color: Color(0xFF4B5563), size: 18)),
          onChanged: (v) => ref.read(_searchQueryProvider.notifier).state = v,
        ),
      ),
      const SizedBox(height: ZapSpacing.md),

      // Time range filter
      const _SectionLabel('TIME RANGE'),
      const SizedBox(height: ZapSpacing.sm),
      _TimeRangeBar(current: timeFilter,
          onSelect: (t) => ref.read(_timeFilterProvider.notifier).state = t),
      const SizedBox(height: ZapSpacing.md),

      // Type filter chips
      const _SectionLabel('EVENT TYPE'),
      const SizedBox(height: ZapSpacing.sm),
      _TypeFilterRow(current: typeFilter,
          onSelect: (t) => ref.read(_typeFilterProvider.notifier).state = t),
      const SizedBox(height: ZapSpacing.md),

      // Category filter chips
      const _SectionLabel('DATA CATEGORY'),
      const SizedBox(height: ZapSpacing.sm),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _FilterChip(
              label: 'All', color: const Color(0xFF6B7280),
              selected: catFilter == null,
              onTap: () => ref.read(_catFilterProvider.notifier).state = null),
          ..._DataCat.values.map((c) => Padding(
                padding: const EdgeInsets.only(left: ZapSpacing.sm),
                child: _FilterChip(
                    label: _catLabel[c]!,
                    color: _catColor[c]!,
                    selected: catFilter == c,
                    onTap: () {
                      ref.read(_catFilterProvider.notifier).state =
                          catFilter == c ? null : c;
                    }),
              )),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Results count
      Row(children: [
        Text('${filtered.length} events',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        if (filtered.any((e) => e.suspicious)) ...[
          const SizedBox(width: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('⚠  suspicious activity detected',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 9,
                    fontWeight: FontWeight.w700))),
        ],
      ]),
      const SizedBox(height: ZapSpacing.md),

      // Date-grouped timeline
      if (filtered.isEmpty)
        _emptyState()
      else
        ...groups.entries.map((g) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2A2A2A))),
                      child: Text(g.key, style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 10,
                          fontWeight: FontWeight.w600))),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(child: Container(
                        height: 1, color: const Color(0xFF1E1E1E))),
                  ]),
                ),
                // Events for this day
                ...g.value.map((e) => _EventRow(
                      event: e,
                      isExpanded: expanded == e.id,
                      onTap: () {
                        ref.read(_expandedProvider.notifier).state =
                            expanded == e.id ? null : e.id;
                      })),
                const SizedBox(height: ZapSpacing.md),
              ],
            )),
    ]);
  }

  static String _dateKey(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date  = DateTime(d.year, d.month, d.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xl),
          child: Column(children: [
            const Icon(Icons.search_off_rounded,
                color: Color(0xFF2A2A2A), size: 40),
            const SizedBox(height: ZapSpacing.md),
            const Text('No events match your filters',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: ZapSpacing.sm),
            const Text('Try changing the time range or clearing filters.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
          ]),
        ));
}

// ── Event row ──────────────────────────────────────────────────────────────────
class _EventRow extends StatelessWidget {
  final _AuditEvent event;
  final bool        isExpanded;
  final VoidCallback onTap;
  const _EventRow({required this.event, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final typeColor = event.suspicious
        ? const Color(0xFFEF4444)
        : _typeColor[event.type]!;
    final typeIcon  = event.suspicious
        ? Icons.warning_rounded
        : _typeIcon[event.type]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
            color: isExpanded
                ? typeColor.withOpacity(0.07) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isExpanded
                    ? typeColor.withOpacity(0.4) : const Color(0xFF2A2A2A),
                width: isExpanded ? 2 : 1),
            // Red left border for suspicious
            boxShadow: event.suspicious
                ? [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 4, spreadRadius: 0,
                    offset: const Offset(-3, 0))]
                : null),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              // Type icon
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(typeIcon, color: typeColor, size: 15)),
              const SizedBox(width: ZapSpacing.md),
              // Content
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(event.action,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (event.suspicious)
                    const Icon(Icons.warning_rounded,
                        color: Color(0xFFEF4444), size: 13),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  _miniChip(_typeLabel[event.type]!, typeColor),
                  const SizedBox(width: ZapSpacing.xs),
                  _miniChip(_catLabel[event.cat]!, _catColor[event.cat]!),
                  const Spacer(),
                  Text(_fmtTime(event.ts),
                      style: const TextStyle(
                          color: Color(0xFF4B5563), fontSize: 9)),
                ]),
              ])),
              const SizedBox(width: ZapSpacing.sm),
              Icon(isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF4B5563), size: 14),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: _EventDetail(event: event))
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  static Widget _miniChip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8,
          fontWeight: FontWeight.w700)));

  static String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EventDetail extends StatelessWidget {
  final _AuditEvent event;
  const _EventDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (event.suspicious)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
            child: const Row(children: [
              Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 13),
              SizedBox(width: 6),
              Expanded(child: Text('Suspicious activity — review this event. '
                  'If this wasn\'t you, change your OTP and contact privacy@zapsafe.app.',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, height: 1.4))),
            ])),
        _kv('Detail',   event.detail),
        _kv('Actor',    event.actor),
        _kv('Device',   event.device),
        _kv('Location', '${event.location}  (IP redacted per DPDP §11)'),
        _kv('Event ID', event.id),
        _kv('Type',     _typeLabel[event.type]!),
        _kv('Category', _catLabel[event.cat]!),
      ]));
  }

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 10, height: 1.4))),
      ]));
}

// ── Filter widgets ─────────────────────────────────────────────────────────────
class _TimeRangeBar extends StatelessWidget {
  final _TimeRange current; final ValueChanged<_TimeRange> onSelect;
  const _TimeRangeBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_TimeRange.days7,  '7 days'),
      (_TimeRange.days30, '30 days'),
      (_TimeRange.days90, '90 days'),
      (_TimeRange.all,    'All time'),
    ];
    return Row(children: items.map((t) {
      final (range, label) = t;
      final isActive = current == range;
      return Expanded(child: GestureDetector(
          onTap: () => onSelect(range),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: EdgeInsets.only(right: range != _TimeRange.all ? 4 : 0),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF3B82F6).withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive
                        ? const Color(0xFF3B82F6).withOpacity(0.5)
                        : const Color(0xFF2A2A2A))),
            child: Text(label, style: TextStyle(
                color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF6B7280),
                fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                textAlign: TextAlign.center),
          )));
    }).toList());
  }
}

class _TypeFilterRow extends StatelessWidget {
  final _EventType? current; final ValueChanged<_EventType?> onSelect;
  const _TypeFilterRow({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(label: 'All', color: const Color(0xFF6B7280),
            selected: current == null,
            onTap: () => onSelect(null)),
        ..._EventType.values.map((t) => Padding(
              padding: const EdgeInsets.only(left: ZapSpacing.sm),
              child: _FilterChip(
                  label: _typeLabel[t]!,
                  color: _typeColor[t]!,
                  selected: current == t,
                  onTap: () => onSelect(current == t ? null : t)),
            )),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final Color color;
  final bool selected; final VoidCallback onTap;
  const _FilterChip({required this.label, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: selected ? 2 : 1)),
        child: Text(label, style: TextStyle(
            color: selected ? color : const Color(0xFF6B7280),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400))));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Summary Stats
// ══════════════════════════════════════════════════════════════════════════════
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compute stats from full event list
    final typeCounts  = <_EventType, int>{};
    final catCounts   = <_DataCat, int>{};
    final actorCounts = <String, int>{};
    for (final e in _kMockEvents) {
      typeCounts[e.type]  = (typeCounts[e.type]  ?? 0) + 1;
      catCounts[e.cat]    = (catCounts[e.cat]    ?? 0) + 1;
      actorCounts[e.actor]= (actorCounts[e.actor]?? 0) + 1;
    }
    final suspiciousCount = _kMockEvents.where((e) => e.suspicious).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.bar_chart_rounded, color: const Color(0xFF10B981),
          text: 'Aggregate view of all 30 access events. '
              'See which data categories are accessed most and who is doing the accessing.'),
      const SizedBox(height: ZapSpacing.lg),

      // Top-line stats
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          _topStat('30',  'Total events',    const Color(0xFF3B82F6)),
          _topStat('$suspiciousCount', 'Suspicious', const Color(0xFFEF4444)),
          _topStat('${_kMockEvents.where((e) => e.actor == "You").length}',
              'By you',  const Color(0xFF10B981)),
          _topStat('${_kMockEvents.where((e) => e.actor.startsWith("ZapSafe")).length}',
              'Automated', const Color(0xFF8B5CF6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // By event type
      const _SectionLabel('BY EVENT TYPE'),
      const SizedBox(height: ZapSpacing.md),
      ...typeCounts.entries.map((e) {
        final color = _typeColor[e.key]!;
        final frac  = e.value / _kMockEvents.length;
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_typeIcon[e.key]!, color: color, size: 13),
              const SizedBox(width: 6),
              Text(_typeLabel[e.key]!, style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${e.value} events',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              const SizedBox(width: ZapSpacing.sm),
              Text('${(frac * 100).round()}%',
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: ZapSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: frac,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5)),
          ]));
      }),
      const SizedBox(height: ZapSpacing.xl),

      // By data category
      const _SectionLabel('BY DATA CATEGORY'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(
          children: catCounts.entries
              .toList()
              .sorted((a, b) => b.value - a.value)
              .asMap()
              .entries
              .map((e) {
            final isLast = e.key == catCounts.length - 1;
            final entry  = e.value;
            final color  = _catColor[entry.key]!;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Icon(_catIcon[entry.key]!, color: color, size: 14),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_catLabel[entry.key]!, style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: entry.value / _kMockEvents.length,
                          backgroundColor: const Color(0xFF2A2A2A),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 4)),
                  ])),
                  const SizedBox(width: ZapSpacing.md),
                  Text('${entry.value}', style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // By actor
      const _SectionLabel('BY ACTOR'),
      const SizedBox(height: ZapSpacing.md),
      ...actorCounts.entries
          .toList()
          .sorted((a, b) => b.value - a.value)
          .map((e) {
        final isYou     = e.key == 'You';
        final isSystem  = e.key.startsWith('ZapSafe');
        final isTrust   = e.key == 'Trust & Safety';
        final isUnknown = e.key == 'Unknown';
        final color = isYou ? const Color(0xFF3B82F6)
            : isSystem ? const Color(0xFF8B5CF6)
            : isTrust  ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444); // Unknown = suspicious
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: color.withOpacity(0.25))),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(child: Text(e.key[0], style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)))),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.key, style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              Text(isUnknown ? '⚠️ Suspicious — review required'
                  : isSystem ? 'Automated backend processing'
                  : isTrust  ? 'ZapSafe staff — manual review'
                  : 'Your own access',
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
            ])),
            Text('${e.value}', style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ]));
      }),
    ]);
  }

  Widget _topStat(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w900),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — API Contract
// ══════════════════════════════════════════════════════════════════════════════
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFFF59E0B),
          text: 'Backend at Day 78. No audit-log endpoint exists yet. '
              'Document here for zero-conflict implementation. '
              'Replace _kMockEvents with the live API call when backend is ready.'),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('ENDPOINT 1 — GET AUDIT LOG'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// GET /api/v1/data-access/audit-log
// Auth: Bearer JWT required
// DPDP §11(1)(a) + GDPR Art. 15(1)(c) — right to know processing

// QUERY PARAMS
// ?days=30            (7 | 30 | 90 | all)
// ?type=read          (read|write|delete|export|login|failed)
// ?category=evidence  (sos|contacts|evidence|location|profile|settings|analytics)
// ?page=1&per_page=20

// RESPONSE 200 OK
{
  "events": [
    {
      "id": "ae001",
      "timestamp": "2026-05-30T14:25:00Z",
      "type": "export",              // read|write|delete|export|login|failed
      "category": "profile",         // data category affected
      "actor": "user",               // "user"|"system"|"trust_safety"|"unknown"
      "action": "Requested full data export (ZIP)",
      "detail": "All 8 data categories selected. Format: ZIP.",
      "device_type": "Android",
      "city": "Mumbai",              // city-level only — IP NOT returned (DPDP §11)
      "suspicious": false
    }
  ],
  "total": 30,
  "page": 1,
  "per_page": 20,
  "suspicious_count": 2
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 2 — GET SINGLE EVENT'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// GET /api/v1/data-access/audit-log/{event_id}
// Auth: Bearer JWT required
// Returns full detail for Day 174 drill-down screen

// RESPONSE 200 OK
{
  "id": "ae001",
  "timestamp": "2026-05-30T14:25:00Z",
  "type": "export",
  "category": "profile",
  "actor": "user",
  "action": "Requested full data export (ZIP)",
  "detail": "All 8 categories. Format: ZIP. Request ID: exp_20260530_abc123.",
  "device_type": "Android",
  "device_model": "Samsung Galaxy S24",
  "city": "Mumbai",
  "country": "India",
  "session_id": "sess_abc123",       // for Day 174 session link
  "suspicious": false,
  "related_events": ["ae016"]        // export download event
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 3 — EXPORT AUDIT LOG'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// POST /api/v1/data-access/audit-log/export
// Auth: Bearer JWT required
// Day 174: Export the audit log itself as CSV or PDF

// REQUEST
{ "format": "csv", "days": 90 }     // "csv" | "pdf"

// RESPONSE 202 Accepted
{
  "export_id": "auditexp_20260530_xyz",
  "status": "processing",
  "estimated_ready_at": "2026-05-30T14:35:00Z"
}'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('IP ADDRESS POLICY  ·  DPDP COMPLIANCE'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
        child: Column(children: [
          _policyRow(const Color(0xFF10B981), 'City returned',
              'Audit log shows city-level location only (e.g. "Mumbai, India").'),
          const Divider(height: 12, color: Color(0xFF1A1A1A)),
          _policyRow(const Color(0xFFEF4444), 'Full IP NOT returned',
              'Raw IP addresses are not surfaced to users per DPDP §11. '
              'ZapSafe stores masked IPs internally for fraud detection only.'),
          const Divider(height: 12, color: Color(0xFF1A1A1A)),
          _policyRow(const Color(0xFF8B5CF6), 'Internal logs have full IP',
              'Backend audit table stores full IP (masked in API response). '
              'Trust & Safety can access for security investigations only.'),
          const Divider(height: 12, color: Color(0xFF1A1A1A)),
          _policyRow(const Color(0xFFF59E0B), 'Retention: 90 days',
              'Audit log events retained for 90 days then auto-purged. '
              'Suspicious events flagged for Trust & Safety retained 1 year.'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'Day 174 adds per-event drill-down detail screen, '
              'session linking, and CSV/PDF audit export. '
              'Day 175 adds the third-party access log and revoke-access flow.'),
    ]);
  }

  static Widget _policyRow(Color color, String label, String body) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w600)),
          Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
              fontSize: 10, height: 1.4)),
        ])),
      ]);
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _code(BuildContext context, String code) => GestureDetector(
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

// ── Extension: sort list ───────────────────────────────────────────────────────
extension _ListSort<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}
