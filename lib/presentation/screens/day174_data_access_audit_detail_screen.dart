/// Day 174 — Data Access Audit Log: Drill-Down, Export & Sessions
///
/// Second day of the Days 173-175 Data Access Audit Log block.
/// Day 173: Full timeline — 30 events, multi-filter, summary stats  ✅
/// Day 174: Per-event forensic drill-down, session detail cards,
///           audit log CSV/PDF export flow.
/// Day 175: Third-party access log + revoke access + block sign-off.
///
/// 🟡 MOCK-NOW — no audit-detail or session API yet.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
// Shared symbols copied from day173 (private symbols can't cross library boundaries)
enum _EventType  { read, write, delete, export, login, failed }
enum _DataCat    { sos, contacts, evidence, location, profile, settings, analytics }

class _AuditEvent {
  final String    id;
  final DateTime  ts;
  final _EventType type;
  final _DataCat   cat;
  final String    actor;
  final String    action;
  final String    detail;
  final String    device;
  final String    location;
  final bool      suspicious;
  const _AuditEvent({
    required this.id, required this.ts, required this.type, required this.cat,
    required this.actor, required this.action, required this.detail,
    required this.device, required this.location, this.suspicious = false,
  });
}

final _kMockEvents = <_AuditEvent>[
  _AuditEvent(id: 'ae001', ts: DateTime(2026, 5, 30, 14, 25),
      type: _EventType.export, cat: _DataCat.profile,
      actor: 'You', action: 'Requested full data export (ZIP)',
      detail: 'All 8 data categories selected. Format: ZIP. Request ID: exp_20260530_abc123.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae002', ts: DateTime(2026, 5, 30, 14, 15),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Toggled analytics consent → OFF',
      detail: 'analytics_consent changed from true to false. Sentry SDK stopped immediately.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae003', ts: DateTime(2026, 5, 29, 22, 45),
      type: _EventType.read, cat: _DataCat.sos,
      actor: 'ZapSafe System', action: 'SOS dispatch read emergency contacts',
      detail: 'Automated read of 3 emergency contacts during SOS event sos_20260529.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae004', ts: DateTime(2026, 5, 29, 22, 44),
      type: _EventType.write, cat: _DataCat.sos,
      actor: 'You', action: 'SOS triggered — event created',
      detail: 'SOS event sos_20260529 created. Method: power-button x 5.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae005', ts: DateTime(2026, 5, 28, 10, 12),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Signed in via OTP',
      detail: 'Successful OTP authentication. JWT issued, expires in 30 days.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae006', ts: DateTime(2026, 5, 27, 18, 05),
      type: _EventType.write, cat: _DataCat.contacts,
      actor: 'You', action: 'Added emergency contact — Sunita Rao (Tier 2)',
      detail: 'New contact Sunita Rao added at Tier 2. Verification SMS sent.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae007', ts: DateTime(2026, 5, 26, 9, 00),
      type: _EventType.read, cat: _DataCat.evidence,
      actor: 'You', action: 'Opened Evidence Vault — SOS event sos_20260515',
      detail: 'Read access to vault for sos_20260515. Integrity hash verified: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae008', ts: DateTime(2026, 5, 25, 16, 30),
      type: _EventType.failed, cat: _DataCat.evidence,
      actor: 'Unknown', action: 'Failed vault PIN attempt (3 of 5)',
      detail: 'Incorrect vault PIN entered 3 times. Warning threshold reached.',
      device: 'iPad Air', location: 'Pune, India', suspicious: true),
  _AuditEvent(id: 'ae009', ts: DateTime(2026, 5, 24, 11, 45),
      type: _EventType.read, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'GPS batch uploaded to server',
      detail: 'Automated GPS batch upload — 47 location points. Retained for 14 days.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae010', ts: DateTime(2026, 5, 24, 8, 00),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Biometric sign-in',
      detail: 'Fingerprint authentication successful on app cold start.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae011', ts: DateTime(2026, 5, 22, 14, 00),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Updated DCS sensitivity → High',
      detail: 'dcs_sensitivity changed from Medium to High.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae012', ts: DateTime(2026, 5, 21, 9, 30),
      type: _EventType.read, cat: _DataCat.profile,
      actor: 'Trust & Safety', action: 'Manual account review initiated',
      detail: 'ZapSafe Trust & Safety team reviewed account. No data copied.',
      device: 'Internal Tools', location: 'ZapSafe HQ'),
  _AuditEvent(id: 'ae013', ts: DateTime(2026, 5, 20, 20, 15),
      type: _EventType.delete, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'Auto-deleted expired GPS batch',
      detail: 'GPS location batch from May 6 auto-deleted after 14-day retention.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae014', ts: DateTime(2026, 5, 19, 17, 50),
      type: _EventType.write, cat: _DataCat.contacts,
      actor: 'You', action: 'Changed Tier 1 contact — Rahul Sharma updated',
      detail: 'Phone number updated for Rahul Sharma (Tier 1). Verification re-sent.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae015', ts: DateTime(2026, 5, 18, 12, 00),
      type: _EventType.read, cat: _DataCat.analytics,
      actor: 'ZapSafe System', action: 'Crash report submitted to Sentry',
      detail: 'Unhandled exception in AudioCaptureService.dart. No PII included.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae016', ts: DateTime(2026, 5, 17, 14, 30),
      type: _EventType.export, cat: _DataCat.profile,
      actor: 'You', action: 'Downloaded data export (ZIP) — exp_20260517',
      detail: 'ZIP export downloaded. File: 49.8 MB. SHA-256 integrity verified: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae017', ts: DateTime(2026, 5, 16, 8, 45),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Signed in via OTP — new device',
      detail: 'OTP authentication from unrecognised device (iPad Air). Push notification sent.',
      device: 'iPad Air', location: 'Pune, India'),
  _AuditEvent(id: 'ae018', ts: DateTime(2026, 5, 15, 23, 10),
      type: _EventType.write, cat: _DataCat.sos,
      actor: 'You', action: 'SOS triggered — event sos_20260515',
      detail: 'SOS event created. Method: app button. 3 contacts notified.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae019', ts: DateTime(2026, 5, 14, 11, 00),
      type: _EventType.delete, cat: _DataCat.contacts,
      actor: 'You', action: 'Removed contact — Meera Singh (Tier 3)',
      detail: 'Contact Meera Singh permanently removed. No outstanding SOS dependencies.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae020', ts: DateTime(2026, 5, 13, 7, 30),
      type: _EventType.read, cat: _DataCat.evidence,
      actor: 'You', action: 'Opened Evidence Vault — SOS sos_20260515',
      detail: 'Read access to vault. Viewed all 6 streams. Integrity: PASS.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae021', ts: DateTime(2026, 5, 10, 15, 00),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Added safe zone — Home',
      detail: 'Safe zone "Home" created. Radius: 100 m.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae022', ts: DateTime(2026, 5, 8, 9, 15),
      type: _EventType.login, cat: _DataCat.profile,
      actor: 'You', action: 'Biometric sign-in',
      detail: 'Face ID authentication successful.',
      device: 'iPad Air', location: 'Pune, India'),
  _AuditEvent(id: 'ae023', ts: DateTime(2026, 5, 5, 14, 20),
      type: _EventType.failed, cat: _DataCat.profile,
      actor: 'Unknown', action: 'Failed OTP — incorrect code (2 attempts)',
      detail: 'Two consecutive OTP failures. Third failure would lock for 1 hour.',
      device: 'Unknown device', location: 'Hyderabad, India', suspicious: true),
  _AuditEvent(id: 'ae024', ts: DateTime(2026, 5, 3, 10, 00),
      type: _EventType.read, cat: _DataCat.location,
      actor: 'ZapSafe System', action: 'GPS batch uploaded to server',
      detail: 'Automated GPS batch — 63 points. 14-day retention.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae025', ts: DateTime(2026, 5, 1, 18, 30),
      type: _EventType.write, cat: _DataCat.analytics,
      actor: 'You', action: 'Crash reporting consent → ON',
      detail: 'crash_reporting changed from false to true. Sentry SDK initialised.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae026', ts: DateTime(2026, 4, 28, 12, 00),
      type: _EventType.delete, cat: _DataCat.evidence,
      actor: 'You', action: 'Extended evidence expiry — SOS sos_20260401',
      detail: 'Vault expiry extended by 30 days. New expiry: June 1, 2026.',
      device: 'Samsung Galaxy S24', location: 'Mumbai, India'),
  _AuditEvent(id: 'ae027', ts: DateTime(2026, 4, 15, 9, 00),
      type: _EventType.read, cat: _DataCat.sos,
      actor: 'ZapSafe System', action: 'Check-in timer auto-escalated',
      detail: 'Check-in timer "Evening walk" expired. Tier 1 contact notified.',
      device: 'Backend (automated)', location: 'ZapSafe Infrastructure'),
  _AuditEvent(id: 'ae028', ts: DateTime(2026, 4, 10, 16, 45),
      type: _EventType.write, cat: _DataCat.settings,
      actor: 'You', action: 'Language changed → Hindi',
      detail: 'App language changed from English to Hindi. Locale: hi_IN.',
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

// ── Providers ──────────────────────────────────────────────────────────────────
final _d174TabProvider        = StateProvider<int>((ref) => 0);
final _selectedEventProvider  = StateProvider<_AuditEvent?>((ref) =>
    _kMockEvents.first);
final _selectedSessionProvider= StateProvider<_SessionRecord?>((ref) =>
    _kSessions.first);
final _exportFormatProvider   = StateProvider<_ExportFmt>((ref) => _ExportFmt.csv);
final _exportRangeProvider    = StateProvider<_ExportRange>((ref) => _ExportRange.days30);
final _exportTypeProvider     = StateProvider<_EventType?>((ref) => null);
final _exportStateProvider    = StateProvider<_ExportState>((ref) => _ExportState.idle);
final _csvPreviewProvider     = StateProvider<bool>((ref) => false);
final _pdfPreviewProvider     = StateProvider<bool>((ref) => false);
final _revokeStateProvider    = StateProvider<bool>((ref) => false);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _ExportFmt   { csv, pdf }
enum _ExportRange { days7, days30, days90, all }
enum _ExportState { idle, processing, done, error }

// ── Session data model ─────────────────────────────────────────────────────────
class _SessionRecord {
  final String   sessionId;
  final String   device;
  final String   os;
  final String   appVersion;
  final String   city;
  final DateTime startedAt;
  final DateTime lastActive;
  final int      eventCount;
  final bool     isCurrent;
  final bool     suspicious;
  final List<String> linkedEventIds;
  const _SessionRecord({
    required this.sessionId, required this.device, required this.os,
    required this.appVersion, required this.city,
    required this.startedAt, required this.lastActive,
    required this.eventCount, this.isCurrent = false,
    this.suspicious = false, required this.linkedEventIds,
  });
}

final _kSessions = [
  _SessionRecord(
    sessionId: 'sess_s24_may28',
    device: 'Samsung Galaxy S24',
    os: 'Android 14  (API 34)',
    appVersion: 'ZapSafe v1.0.0 (build 150)',
    city: 'Mumbai, India',
    startedAt: DateTime(2026, 5, 28, 10, 12),
    lastActive: DateTime(2026, 5, 30, 14, 30),
    eventCount: 18,
    isCurrent: true,
    linkedEventIds: ['ae001','ae002','ae003','ae004','ae005','ae006',
                     'ae007','ae010','ae011','ae015','ae016','ae017'],
  ),
  _SessionRecord(
    sessionId: 'sess_ipad_may16',
    device: 'iPad Air (5th gen)',
    os: 'iPadOS 17.4',
    appVersion: 'ZapSafe v1.0.0 (build 150)',
    city: 'Pune, India',
    startedAt: DateTime(2026, 5, 16, 8, 45),
    lastActive: DateTime(2026, 5, 25, 16, 30),
    eventCount: 4,
    suspicious: true,
    linkedEventIds: ['ae008','ae017','ae022'],
  ),
  _SessionRecord(
    sessionId: 'sess_s24_apr05',
    device: 'Samsung Galaxy S24',
    os: 'Android 14  (API 34)',
    appVersion: 'ZapSafe v0.9.8 (build 135)',
    city: 'Mumbai, India',
    startedAt: DateTime(2026, 4, 5, 11, 20),
    lastActive: DateTime(2026, 5, 14, 11, 00),
    eventCount: 8,
    linkedEventIds: ['ae019','ae020','ae021','ae024','ae025','ae026','ae027','ae029'],
  ),
];

// ── Mock export service ────────────────────────────────────────────────────────
class _MockExportService {
  static Future<String> exportAuditLog({
    required _ExportFmt format, required _ExportRange range,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    return 'audit_export_20260530.${format.name}';
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day174DataAccessAuditDetailScreen extends ConsumerWidget {
  const Day174DataAccessAuditDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d174TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Audit: Drill-Down & Export'),
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
            child: const Text('DAY 174',
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
                onSelect: (t) => ref.read(_d174TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _DrillDownTab(),
            if (tab == 1) const _ExportTab(),
            if (tab == 2) const _SessionTab(),
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
            colors: [Color(0xFF080E14), Color(0xFF050A10), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 174',             const Color(0xFF3B82F6)),
          _badge('🟡 MOCK-NOW',             const Color(0xFFF59E0B)),
          _badge('Audit Log  ·  Day 2/3',   const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Forensic Drill-Down\nExport & Sessions',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Full forensic detail for any event — device fingerprint, '
          'session linkage, suspicious analysis. Export the audit log '
          'as CSV or PDF. Explore session-level event grouping.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('30',   'Events selectable', Color(0xFF3B82F6)),
          _HStat('3',    'Active sessions',   Color(0xFF10B981)),
          _HStat('CSV+PDF', 'Export formats', Color(0xFF8B5CF6)),
          _HStat('90d',  'Retention',         Color(0xFFF59E0B)),
        ]),
      ]),
    );
  }

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
      (Icons.manage_search_rounded, Color(0xFF3B82F6), 'Drill-Down'),
      (Icons.file_download_rounded, Color(0xFF10B981), 'Export'),
      (Icons.devices_rounded,       Color(0xFF8B5CF6), 'Sessions'),
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
// TAB 1 — Forensic Drill-Down
// ══════════════════════════════════════════════════════════════════════════════
class _DrillDownTab extends ConsumerWidget {
  const _DrillDownTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedEventProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.manage_search_rounded, color: const Color(0xFF3B82F6),
          text: 'Full forensic detail for any event — beyond what Day 173\'s '
              'timeline tap-expand shows. Includes device fingerprint, '
              'session linkage, and suspicious-activity analysis.'),
      const SizedBox(height: ZapSpacing.lg),

      // Event picker
      const _SectionLabel('SELECT EVENT (30 available)'),
      const SizedBox(height: ZapSpacing.md),
      SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _kMockEvents.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final e        = _kMockEvents[i];
            final isActive = selected?.id == e.id;
            final color    = e.suspicious
                ? const Color(0xFFEF4444)
                : _typeColor[e.type]!;
            return GestureDetector(
              onTap: () => ref.read(_selectedEventProvider.notifier).state = e,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: isActive ? color.withOpacity(0.6) : const Color(0xFF2A2A2A),
                        width: isActive ? 2 : 1)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_typeIcon[e.type]!, color: color, size: 12),
                  const SizedBox(width: 5),
                  Text(e.id, style: TextStyle(color: color, fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: 'monospace')),
                  if (e.suspicious) ...[
                    const SizedBox(width: ZapSpacing.xs),
                    const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 10),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: ZapSpacing.xl),

      if (selected != null) _ForensicCard(event: selected),
    ]);
  }
}

class _ForensicCard extends StatelessWidget {
  final _AuditEvent event;
  const _ForensicCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.suspicious
        ? const Color(0xFFEF4444) : _typeColor[event.type]!;

    // Find related events (same session / same category within ±1 hour)
    final related = _kMockEvents.where((e) =>
        e.id != event.id &&
        e.cat == event.cat &&
        (e.ts.difference(event.ts).inMinutes.abs() < 60)).toList();

    // Find the session this event belongs to
    final session = _kSessions.firstWhere(
        (s) => s.linkedEventIds.contains(event.id),
        orElse: () => _kSessions.first);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Event identity header ────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: color.withOpacity(0.45), width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(_typeIcon[event.type]!, color: color, size: 20)),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.action, style: const TextStyle(color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Wrap(spacing: 6, children: [
                _chip(_typeLabel[event.type]!, color),
                _chip(_catLabel[event.cat]!, _catColor[event.cat]!),
                if (event.suspicious) _chip('⚠ SUSPICIOUS', const Color(0xFFEF4444)),
              ]),
            ])),
          ]),
          const SizedBox(height: ZapSpacing.md),
          Text(event.detail, style: const TextStyle(color: Color(0xFFD1D5DB),
              fontSize: 12, height: 1.6)),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // ── Forensic metadata ────────────────────────────────────────
      const _SectionLabel('FORENSIC METADATA'),
      const SizedBox(height: ZapSpacing.md),
      _metaCard(children: [
        _mRow('Event ID',   event.id, copy: true),
        _mRow('Timestamp',  _fmtFull(event.ts)),
        _mRow('Type',       _typeLabel[event.type]!),
        _mRow('Category',   _catLabel[event.cat]!),
        _mRow('Actor',      event.actor),
        _mRow('Location',   event.location),
        _mRow('IP address', 'Redacted (DPDP §11 — city-level only)'),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // ── Device fingerprint ───────────────────────────────────────
      const _SectionLabel('DEVICE FINGERPRINT'),
      const SizedBox(height: ZapSpacing.md),
      _metaCard(children: [
        _mRow('Device',      event.device),
        _mRow('OS',          _osFor(event.device)),
        _mRow('App version', 'ZapSafe v1.0.0 (build 150)'),
        _mRow('Session ID',  session.sessionId, copy: true, mono: true),
        _mRow('Timezone',    'Asia/Kolkata  (UTC+5:30)'),
        _mRow('Fingerprint', _fakeFingerprint(event.id), mono: true, truncate: true),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // ── Suspicious analysis (only for flagged events) ────────────
      if (event.suspicious) ...[
        const _SectionLabel('SUSPICIOUS ACTIVITY ANALYSIS'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 16),
              SizedBox(width: ZapSpacing.sm),
              Text('Why was this flagged?', style: TextStyle(
                  color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            ..._suspiciousReasons(event).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.circle, color: Color(0xFFEF4444), size: 5),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(r, style: const TextStyle(
                      color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5))),
                ]))),
            const SizedBox(height: ZapSpacing.md),
            Row(children: [
              Expanded(child: _actionBtn(
                  'Mark as Reviewed', const Color(0xFF10B981), () =>
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Event marked as reviewed'),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 2))))),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: _actionBtn(
                  'Report to ZapSafe', const Color(0xFFEF4444), () =>
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Report sent to Trust & Safety'),
                      backgroundColor: Color(0xFFEF4444),
                      duration: Duration(seconds: 2))))),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),
      ],

      // ── Related events ───────────────────────────────────────────
      if (related.isNotEmpty) ...[
        const _SectionLabel('RELATED EVENTS  ·  SAME CATEGORY ± 1 HOUR'),
        const SizedBox(height: ZapSpacing.md),
        ...related.map((r) {
          final c = _typeColor[r.type]!;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: Row(children: [
              Icon(_typeIcon[r.type]!, color: c, size: 14),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(r.action, style: const TextStyle(
                  color: Colors.white, fontSize: 11), maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
              Text(r.id, style: TextStyle(color: c, fontSize: 9,
                  fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ]),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
      ],

      // ── Session context ──────────────────────────────────────────
      const _SectionLabel('SESSION CONTEXT'),
      const SizedBox(height: ZapSpacing.md),
      _SessionMiniCard(session: session),
    ]);
  }

  static Widget _chip(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(l, style: TextStyle(color: c, fontSize: 9,
          fontWeight: FontWeight.w700)));

  static Widget _metaCard({required List<Widget> children}) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));

  static Widget _mRow(String k, String v, {bool copy = false,
      bool mono = false, bool truncate = false}) =>
      GestureDetector(
        onTap: copy ? () => Clipboard.setData(ClipboardData(text: v)) : null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(children: [
            SizedBox(width: 96, child: Text(k, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10))),
            Expanded(child: Text(
              truncate && v.length > 32 ? '${v.substring(0, 32)}…' : v,
              style: TextStyle(
                  color: copy ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
                  fontSize: 10,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis)),
            if (copy) const Icon(Icons.copy_rounded,
                color: Color(0xFF4B5563), size: 11),
          ]),
        ));

  static Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: Text(label, style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)))));

  static String _fmtFull(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')} IST';
  }

  static String _osFor(String device) =>
      device.contains('iPad') ? 'iPadOS 17.4'
          : device.contains('Samsung') ? 'Android 14 (API 34)'
          : 'Android 13 (API 33)';

  static String _fakeFingerprint(String id) {
    // Deterministic fake hash based on event id
    final seed = id.codeUnits.fold(0, (a, b) => a + b);
    final hex  = seed.toRadixString(16).padLeft(8, '0');
    return 'fp_$hex${hex}a2b3c4d5e6f7';
  }

  static List<String> _suspiciousReasons(_AuditEvent e) {
    if (e.type == _EventType.failed && e.cat == _DataCat.evidence) {
      return [
        'Multiple vault PIN failures from a device not previously associated with this account.',
        'Device: iPad Air — no successful login from this device in the last 30 days.',
        'Location: Pune, India — primary device always shows Mumbai.',
        'Action required: if this was not you, change your vault PIN immediately.',
      ];
    }
    return [
      'OTP authentication failure from an unrecognised location (Hyderabad, India).',
      'Primary device city is Mumbai — this request came from a different city.',
      'Two consecutive failures within 3 minutes suggest a brute-force attempt.',
      'Action required: if this was not you, contact privacy@zapsafe.app.',
    ];
  }
}

class _SessionMiniCard extends StatelessWidget {
  final _SessionRecord session;
  const _SessionMiniCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.devices_rounded, color: Color(0xFF8B5CF6), size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(session.sessionId, style: const TextStyle(
              color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w700,
              fontFamily: 'monospace')),
          if (session.isCurrent) ...[
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('CURRENT', style: TextStyle(
                  color: Color(0xFF10B981), fontSize: 8, fontWeight: FontWeight.w800))),
          ],
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text('${session.device}  ·  ${session.city}  ·  '
            '${session.eventCount} events in this session',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        const SizedBox(height: ZapSpacing.xs),
        Text('Started: ${_fmtShort(session.startedAt)}  '
            '·  Last active: ${_fmtShort(session.lastActive)}',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
      ]),
    );
  }

  static String _fmtShort(DateTime d) =>
      '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:'
      '${d.minute.toString().padLeft(2,'0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Audit Log Export
// ══════════════════════════════════════════════════════════════════════════════
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format      = ref.watch(_exportFormatProvider);
    final range       = ref.watch(_exportRangeProvider);
    final typeFilter  = ref.watch(_exportTypeProvider);
    final exportState = ref.watch(_exportStateProvider);
    final csvPreview  = ref.watch(_csvPreviewProvider);
    final pdfPreview  = ref.watch(_pdfPreviewProvider);

    final rangeCount  = switch (range) {
      _ExportRange.days7  => _kMockEvents.where((e) =>
          e.ts.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length,
      _ExportRange.days30 => _kMockEvents.where((e) =>
          e.ts.isAfter(DateTime.now().subtract(const Duration(days: 30)))).length,
      _ExportRange.days90 => _kMockEvents.length,
      _ExportRange.all    => _kMockEvents.length,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.file_download_rounded, color: const Color(0xFF10B981),
          text: 'Export your complete data access audit log as CSV '
              '(machine-readable) or PDF (human-readable report). '
              'GDPR Art. 15(3) grants the right to receive a copy.'),
      const SizedBox(height: ZapSpacing.lg),

      // Format picker
      const _SectionLabel('EXPORT FORMAT'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        Expanded(child: _fmtCard(
            _ExportFmt.csv, '{ } CSV',
            'Machine-readable\n2 KB – 20 KB',
            const Color(0xFF10B981), format, ref)),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: _fmtCard(
            _ExportFmt.pdf, '📄 PDF',
            'Human-readable report\n50 KB – 200 KB',
            const Color(0xFF3B82F6), format, ref)),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // Time range
      const _SectionLabel('TIME RANGE'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        _rangeBtn('7 days',  _ExportRange.days7,  range, ref),
        const SizedBox(width: ZapSpacing.xs),
        _rangeBtn('30 days', _ExportRange.days30, range, ref),
        const SizedBox(width: ZapSpacing.xs),
        _rangeBtn('90 days', _ExportRange.days90, range, ref),
        const SizedBox(width: ZapSpacing.xs),
        _rangeBtn('All',     _ExportRange.all,    range, ref),
      ]),
      const SizedBox(height: ZapSpacing.lg),

      // Event type filter
      const _SectionLabel('FILTER BY TYPE (OPTIONAL)'),
      const SizedBox(height: ZapSpacing.md),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _typeBtn(null, 'All types', typeFilter, ref),
          ..._EventType.values.map((t) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _typeBtn(t, _typeLabel[t]!, typeFilter, ref))),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Summary
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Row(children: [
          const Icon(Icons.summarize_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Export summary', style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 10)),
            Text('${typeFilter == null ? "All types" : _typeLabel[typeFilter]!}  ·  '
                '$rangeCount events  ·  ${format.name.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Export button / state
      if (exportState == _ExportState.idle)
        _primaryBtn(
          label: 'Export Audit Log  (Mock)',
          color: const Color(0xFF10B981),
          onTap: () async {
            ref.read(_exportStateProvider.notifier).state = _ExportState.processing;
            try {
              await _MockExportService.exportAuditLog(format: format, range: range);
              if (context.mounted) {
                ref.read(_exportStateProvider.notifier).state = _ExportState.done;
              }
            } catch (_) {
              if (context.mounted) {
                ref.read(_exportStateProvider.notifier).state = _ExportState.error;
              }
            }
          },
        )
      else if (exportState == _ExportState.processing)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFF10B981),
            'Generating export…',
            'POST /api/v1/data-access/audit-log/export → 202\n'
            'Processing $rangeCount events…', loading: true)
      else if (exportState == _ExportState.done)
        _ExportDoneCard(format: format, rangeCount: rangeCount, ref: ref)
      else
        _statusCard(Icons.error_outline_rounded, const Color(0xFFEF4444),
            'Export failed', 'Try again.', loading: false),

      const SizedBox(height: ZapSpacing.xl),

      // Format previews
      const _SectionLabel('FORMAT PREVIEWS  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),
      _PreviewCard(
        title: 'CSV format preview',
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF10B981),
        expanded: csvPreview,
        onToggle: () => ref.read(_csvPreviewProvider.notifier).state = !csvPreview,
        content: _kCsvPreview,
      ),
      const SizedBox(height: ZapSpacing.sm),
      _PreviewCard(
        title: 'PDF format preview  (rendered as text)',
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFF3B82F6),
        expanded: pdfPreview,
        onToggle: () => ref.read(_pdfPreviewProvider.notifier).state = !pdfPreview,
        content: _kPdfPreview,
      ),
    ]);
  }

  static Widget _fmtCard(_ExportFmt fmt, String label, String sub, Color color,
      _ExportFmt current, WidgetRef ref) {
    final isOn = fmt == current;
    return GestureDetector(
      onTap: () => ref.read(_exportFormatProvider.notifier).state = fmt,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: isOn ? 2 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: isOn ? color : Colors.white,
              fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(sub, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
              height: 1.4)),
        ])));
  }

  static Widget _rangeBtn(String label, _ExportRange r,
      _ExportRange current, WidgetRef ref) {
    final isOn = r == current;
    return Expanded(child: GestureDetector(
      onTap: () => ref.read(_exportRangeProvider.notifier).state = r,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: isOn ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isOn ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFF2A2A2A))),
        child: Text(label, style: TextStyle(
            color: isOn ? const Color(0xFF10B981) : const Color(0xFF6B7280),
            fontSize: 10, fontWeight: isOn ? FontWeight.w700 : FontWeight.w400),
            textAlign: TextAlign.center))));
  }

  static Widget _typeBtn(_EventType? t, String label,
      _EventType? current, WidgetRef ref) {
    final isOn = t == current;
    final color= t != null ? _typeColor[t]! : const Color(0xFF6B7280);
    return GestureDetector(
      onTap: () => ref.read(_exportTypeProvider.notifier).state = isOn ? null : t,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: isOn ? 2 : 1)),
        child: Text(label, style: TextStyle(
            color: isOn ? color : const Color(0xFF6B7280),
            fontSize: 10,
            fontWeight: isOn ? FontWeight.w700 : FontWeight.w400))));
  }
}

const _kCsvPreview = '''event_id,timestamp,type,category,actor,action,device,city
ae001,2026-05-30T14:25:00Z,export,profile,user,Requested full data export (ZIP),Samsung Galaxy S24,Mumbai
ae002,2026-05-30T14:15:00Z,write,settings,user,Toggled analytics consent → OFF,Samsung Galaxy S24,Mumbai
ae003,2026-05-29T22:45:00Z,read,sos,system,SOS dispatch read emergency contacts,Backend,ZapSafe Infra
ae004,2026-05-29T22:44:00Z,write,sos,user,SOS triggered — event created,Samsung Galaxy S24,Mumbai
ae005,2026-05-28T10:12:00Z,login,profile,user,Signed in via OTP,Samsung Galaxy S24,Mumbai
…(25 more rows)''';

const _kPdfPreview = '''━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ZapSafe  ·  Data Access Audit Log Report
  Generated: May 30, 2026  14:35 IST
  Account: +91 98765 43210
  Period: Last 30 days  (May 1 – May 30, 2026)
  Total events: 30
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY
  Read events:    12 (40%)
  Write events:    8 (27%)
  Login events:    5 (17%)
  Delete events:   3 (10%)
  Export events:   3 (10%)
  Failed attempts: 2 (7%)
  Suspicious:      2 — review recommended

EVENTS
  2026-05-30 14:25 | EXPORT | Profile | You
    Requested full data export (ZIP). Samsung Galaxy S24 · Mumbai

  2026-05-30 14:15 | WRITE  | Settings | You
    Toggled analytics consent OFF. Samsung Galaxy S24 · Mumbai

  … (28 more events)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  GDPR Art. 15(3) — copy of data provided.
  IP addresses redacted per DPDP §11.
  Retain this document for your records.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''';

class _ExportDoneCard extends StatelessWidget {
  final _ExportFmt format; final int rangeCount; final WidgetRef ref;
  const _ExportDoneCard({required this.format, required this.rangeCount, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          SizedBox(width: ZapSpacing.sm),
          Text('Export Ready! ✅', style: TextStyle(color: Color(0xFF10B981),
              fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text('audit_export_20260530.${format.name}  ·  $rangeCount events',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(child: _miniBtn('Download', Icons.download_rounded,
              const Color(0xFF10B981), () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mock: file download started'),
                      backgroundColor: Color(0xFF10B981))))),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _miniBtn('Share', Icons.share_rounded,
              const Color(0xFF3B82F6), () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mock: share sheet opened'))))),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        GestureDetector(
          onTap: () => ref.read(_exportStateProvider.notifier).state = _ExportState.idle,
          child: const Text('Export again', style: TextStyle(
              color: Color(0xFF6B7280), fontSize: 10,
              decoration: TextDecoration.underline))),
      ]));
  }

  Widget _miniBtn(String l, IconData icon, Color c, VoidCallback onTap) =>
      GestureDetector(onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: c.withOpacity(0.4))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: c, size: 14),
              const SizedBox(width: 5),
              Text(l, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
            ])));
}

class _PreviewCard extends StatelessWidget {
  final String title, content;
  final IconData icon; final Color color;
  final bool expanded; final VoidCallback onToggle;
  const _PreviewCard({required this.title, required this.content,
      required this.icon, required this.color,
      required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            color: expanded ? color.withOpacity(0.06) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: expanded ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                width: expanded ? 2 : 1)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(title, style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
              Icon(expanded ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF4B5563), size: 16),
            ])),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: expanded ? Padding(
              padding: const EdgeInsets.fromLTRB(
                  ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                child: Text(content, style: const TextStyle(
                    color: Color(0xFF86EFAC), fontSize: 9,
                    fontFamily: 'monospace', height: 1.6))),
            ) : const SizedBox.shrink(),
          ),
        ]),
      ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Sessions
// ══════════════════════════════════════════════════════════════════════════════
class _SessionTab extends ConsumerWidget {
  const _SessionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected  = ref.watch(_selectedSessionProvider);
    final revoking  = ref.watch(_revokeStateProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.devices_rounded, color: const Color(0xFF8B5CF6),
          text: 'Each login creates a session. All audit events from that '
              'session are linked. Day 175 adds session revocation to '
              'the Active Sessions screen (Settings → Account → Sessions).'),
      const SizedBox(height: ZapSpacing.lg),

      // Session selector
      const _SectionLabel('3 SESSIONS  ·  SELECT TO INSPECT'),
      const SizedBox(height: ZapSpacing.md),
      ..._kSessions.map((s) {
        final isSelected = selected?.sessionId == s.sessionId;
        final color      = s.suspicious
            ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6);
        return GestureDetector(
          onTap: () {
            ref.read(_selectedSessionProvider.notifier).state = s;
            ref.read(_revokeStateProvider.notifier).state = false;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isSelected ? color.withOpacity(0.45) : const Color(0xFF2A2A2A),
                    width: isSelected ? 2 : 1)),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(s.suspicious ? Icons.warning_rounded : Icons.devices_rounded,
                    color: color, size: 16)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.device, style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${s.city}  ·  ${s.eventCount} events',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (s.isCurrent)
                  _smallChip('CURRENT', const Color(0xFF10B981))
                else if (s.suspicious)
                  _smallChip('⚠ SUSPICIOUS', const Color(0xFFEF4444))
                else
                  _smallChip('ENDED', const Color(0xFF4B5563)),
              ]),
            ]),
          ),
        );
      }),
      const SizedBox(height: ZapSpacing.xl),

      if (selected != null) ...[
        // Full session detail
        const _SectionLabel('SESSION DETAIL'),
        const SizedBox(height: ZapSpacing.md),
        _SessionDetailCard(session: selected, revoking: revoking, ref: ref),
        const SizedBox(height: ZapSpacing.lg),

        // Events in this session
        const _SectionLabel('EVENTS IN THIS SESSION'),
        const SizedBox(height: ZapSpacing.md),
        ..._kMockEvents
            .where((e) => selected.linkedEventIds.contains(e.id))
            .take(5)
            .map((e) {
          final c = _typeColor[e.type]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: Row(children: [
              Icon(_typeIcon[e.type]!, color: c, size: 13),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(e.action, style: const TextStyle(
                  color: Colors.white, fontSize: 11), maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_typeLabel[e.type]!, style: TextStyle(
                    color: c, fontSize: 8, fontWeight: FontWeight.w700))),
            ]),
          );
        }),
        if (selected.linkedEventIds.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: ZapSpacing.sm),
            child: Center(child: Text(
                '+${selected.linkedEventIds.length - 5} more — see Day 173 timeline',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)))),
      ],
    ]);
  }

  static Widget _smallChip(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(l, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w800)));
}

class _SessionDetailCard extends StatelessWidget {
  final _SessionRecord session;
  final bool revoking;
  final WidgetRef ref;
  const _SessionDetailCard({required this.session, required this.revoking, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = session.suspicious ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6);
    final duration = session.lastActive.difference(session.startedAt);
    final durationLabel = duration.inDays > 0
        ? '${duration.inDays}d ${duration.inHours % 24}h'
        : '${duration.inHours}h ${duration.inMinutes % 60}m';

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Icon(Icons.devices_rounded, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(session.device, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          if (session.isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('● CURRENT', style: TextStyle(
                  color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: ZapSpacing.md),
        // Metadata grid
        _kv('Session ID', session.sessionId, mono: true),
        _kv('OS',         session.os),
        _kv('App version',session.appVersion),
        _kv('City',       '${session.city}  (IP redacted per DPDP §11)'),
        _kv('Started',    _fmtFull(session.startedAt)),
        _kv('Last active',_fmtFull(session.lastActive)),
        _kv('Duration',   durationLabel),
        _kv('Events',     '${session.eventCount} in this session'),
        if (session.suspicious)
          _kv('⚠ Status', 'Suspicious — unrecognised location'),
        const SizedBox(height: ZapSpacing.md),
        // Revoke button
        if (!session.isCurrent)
          revoking
              ? _statusCard(Icons.hourglass_top_rounded, const Color(0xFFEF4444),
                  'Revoking session…',
                  'DELETE /api/v1/account/sessions/${session.sessionId}',
                  loading: true)
              : GestureDetector(
                  onTap: () async {
                    ref.read(_revokeStateProvider.notifier).state = true;
                    await Future.delayed(const Duration(milliseconds: 1000));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Session ${session.sessionId} revoked'),
                        backgroundColor: const Color(0xFF10B981)));
                      ref.read(_revokeStateProvider.notifier).state = false;
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 14),
                      SizedBox(width: 6),
                      Text('Revoke this session (mock)',
                          style: TextStyle(color: Color(0xFFEF4444), fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ])))
        else
          const Text('Current session cannot be revoked here. '
              'Sign out from Settings → Account.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, height: 1.4)),
      ]),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 96, child: Text(k, style: const TextStyle(
            color: Color(0xFF6B7280), fontSize: 10))),
        Expanded(child: Text(v, style: TextStyle(
            color: const Color(0xFFD1D5DB), fontSize: 10,
            fontFamily: mono ? 'monospace' : null, height: 1.4))),
      ]));

  static String _fmtFull(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:'
        '${d.minute.toString().padLeft(2,'0')}';
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                offset: const Offset(0, 4))]),
        child: Center(child: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)))));

Widget _statusCard(IconData icon, Color color, String title, String body,
    {required bool loading}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          loading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(title, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
            fontSize: 11, height: 1.5)),
      ]));

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
