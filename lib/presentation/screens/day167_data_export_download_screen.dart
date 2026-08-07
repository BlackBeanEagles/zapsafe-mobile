/// Day 167 — Data Export: Download, Integrity & File Browser
///
/// Second day of the Days 166-168 Data Export block.
/// Day 166: Request form + history + API contract ✅
/// Day 167: Download progress indicator + SHA-256 integrity check
///           + file-save flow (path_provider + open_file) + export browser.
/// Day 168: Rate-limit enforcement + edge cases + GDPR deep dive.
///
/// 🟡 MOCK-NOW — path_provider and open_file_plus are real packages
///    but actual file I/O is simulated. When backend is ready:
///    1. Replace _MockDownloader with a real http.Client stream download.
///    2. Compute SHA-256 over the actual bytes with crypto package.
///    3. Call OpenFile.open(path) to open in the system file manager.
///
/// Packages this screen documents:
///   path_provider: ^2.1.3   — getApplicationDocumentsDirectory()
///   open_file_plus: ^3.4.1  — OpenFile.open(filePath)
///   crypto: ^3.0.3          — sha256.convert(bytes)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _downloadStateProvider  = StateProvider<_DlState>((ref) => _DlState.idle);
final _downloadProgressProvider = StateProvider<double>((ref) => 0.0);   // 0.0–1.0
final _downloadSpeedProvider  = StateProvider<double>((ref) => 0.0);     // KB/s
final _integrityStateProvider = StateProvider<_IntegrityState>((ref) => _IntegrityState.idle);
final _selectedFileProvider   = StateProvider<_ExportFile?>((ref) => null);
final _expandedFolderProvider = StateProvider<String?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _DlState  { idle, connecting, downloading, verifying, saving, done, error }
enum _IntegrityState { idle, computing, pass, fail }

// ── Data ───────────────────────────────────────────────────────────────────────
const _kExportId        = 'exp_20260530_abc123';
const _kServerChecksum  = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
const _kLocalChecksum   = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // matches → pass
const _kFileSize        = 52428800; // 50 MB in bytes
const _kSavePathAndroid = '/storage/emulated/0/Downloads/zapsafe_export_20260530.zip';
const _kSavePathiOS     = '/var/mobile/Containers/Data/Application/.../Documents/zapsafe_export_20260530.zip';

class _ExportFile {
  final String   name;
  final String   path;
  final int      sizeBytes;
  final IconData icon;
  final Color    color;
  final String   preview; // text snippet shown in file viewer
  const _ExportFile({
    required this.name, required this.path, required this.sizeBytes,
    required this.icon, required this.color, required this.preview,
  });
}

class _ExportFolder {
  final String         name;
  final IconData       icon;
  final Color          color;
  final List<_ExportFile> files;
  const _ExportFolder({
    required this.name, required this.icon,
    required this.color, required this.files});
}

final _kExportStructure = [
  _ExportFolder(
    name: 'profile/', icon: Icons.account_circle_rounded, color: const Color(0xFF3B82F6),
    files: [
      _ExportFile(name: 'profile.json', path: 'profile/profile.json', sizeBytes: 1800,
          icon: Icons.data_object_rounded, color: const Color(0xFF3B82F6),
          preview: '{\n  "name": "Priya Sharma",\n  "phone": "+91 98765 43210",\n  "member_since": "2025-01-15",\n  "subscription": "premium",\n  "device_tier": "A"\n}'),
    ],
  ),
  _ExportFolder(
    name: 'contacts/', icon: Icons.people_rounded, color: const Color(0xFF10B981),
    files: [
      _ExportFile(name: 'emergency_contacts.json', path: 'contacts/emergency_contacts.json', sizeBytes: 4200,
          icon: Icons.data_object_rounded, color: const Color(0xFF10B981),
          preview: '[\n  {\n    "tier": 1,\n    "name": "Rahul Sharma",\n    "phone": "+91 98111 22333",\n    "verified": true\n  },\n  {\n    "tier": 2,\n    "name": "Aarti Patel",\n    "phone": "+91 99000 11222",\n    "verified": true\n  }\n]'),
    ],
  ),
  _ExportFolder(
    name: 'sos_events/', icon: Icons.warning_rounded, color: const Color(0xFFEF4444),
    files: [
      _ExportFile(name: 'events_index.json', path: 'sos_events/events_index.json', sizeBytes: 12000,
          icon: Icons.data_object_rounded, color: const Color(0xFFEF4444),
          preview: '{\n  "total_events": 3,\n  "date_range": {\n    "from": "2025-02-01",\n    "to": "2026-05-30"\n  },\n  "events": [\n    { "id": "sos_001", "triggered_at": "2025-09-14T22:45:00Z", "resolved": true },\n    { "id": "sos_002", "triggered_at": "2026-01-03T11:22:00Z", "resolved": true }\n  ]\n}'),
      _ExportFile(name: 'sos_001/', path: 'sos_events/sos_001/', sizeBytes: 24000000,
          icon: Icons.folder_rounded, color: const Color(0xFFEF4444),
          preview: '📁 Contains: audio.aac, gps_trace.json, dcs_scores.json, contacts_notified.json'),
    ],
  ),
  _ExportFolder(
    name: 'location/', icon: Icons.location_on_rounded, color: const Color(0xFF10B981),
    files: [
      _ExportFile(name: 'safe_zones.json', path: 'location/safe_zones.json', sizeBytes: 3200,
          icon: Icons.data_object_rounded, color: const Color(0xFF10B981),
          preview: '[\n  { "name": "Home", "lat": 19.0760, "lng": 72.8777, "radius_m": 100 },\n  { "name": "Work", "lat": 18.9220, "lng": 72.8347, "radius_m": 50 }\n]'),
      _ExportFile(name: 'gps_history.json', path: 'location/gps_history.json', sizeBytes: 320000,
          icon: Icons.data_object_rounded, color: const Color(0xFF10B981),
          preview: '// 14-day GPS history (pruned for export).\n// Contains 1,247 location samples.\n// Accuracy ≤ 50 m only (high-quality gate).\n[\n  { "lat": 19.0760, "lng": 72.8777, "ts": "2026-05-29T08:12:00Z", "acc": 12 }\n  // ...1246 more\n]'),
    ],
  ),
  _ExportFolder(
    name: 'settings/', icon: Icons.tune_rounded, color: const Color(0xFF6B7280),
    files: [
      _ExportFile(name: 'preferences.json', path: 'settings/preferences.json', sizeBytes: 3900,
          icon: Icons.data_object_rounded, color: const Color(0xFF6B7280),
          preview: '{\n  "language": "en",\n  "notification_prefs": { "sos_alert": true, "drill": true },\n  "dnd": { "enabled": false, "start": 22, "end": 7 },\n  "analytics_consent": false,\n  "crash_consent": true\n}'),
      _ExportFile(name: 'consents.json', path: 'settings/consents.json', sizeBytes: 900,
          icon: Icons.data_object_rounded, color: const Color(0xFF6B7280),
          preview: '{\n  "privacy_policy_version": "2.0",\n  "accepted_at": "2026-01-15T09:00:00Z",\n  "tos_version": "1.0",\n  "analytics": false,\n  "crash_reporting": true\n}'),
    ],
  ),
  _ExportFolder(
    name: 'audit_log/', icon: Icons.history_rounded, color: const Color(0xFF3B82F6),
    files: [
      _ExportFile(name: 'activity_log.json', path: 'audit_log/activity_log.json', sizeBytes: 225000,
          icon: Icons.data_object_rounded, color: const Color(0xFF3B82F6),
          preview: '// 322 activity events across 6 months.\n[\n  {\n    "event": "sos_triggered",\n    "ts": "2026-05-29T22:45:00Z",\n    "device": "Samsung Galaxy S24",\n    "ip": "103.*.*.* (redacted)"\n  }\n  // ...321 more\n]'),
    ],
  ),
  _ExportFolder(
    name: '_meta/', icon: Icons.info_rounded, color: const Color(0xFFF59E0B),
    files: [
      _ExportFile(name: 'manifest.json', path: '_meta/manifest.json', sizeBytes: 1100,
          icon: Icons.data_object_rounded, color: const Color(0xFFF59E0B),
          preview: '{\n  "export_id": "$_kExportId",\n  "generated_at": "2026-05-30T14:30:00Z",\n  "schema_version": "1.0",\n  "categories": ["profile","contacts","sos_events","location","settings","audit_log"],\n  "format": "zip",\n  "total_size_bytes": $_kFileSize,\n  "checksum_sha256": "$_kServerChecksum"\n}'),
      _ExportFile(name: 'README.txt', path: '_meta/README.txt', sizeBytes: 680,
          icon: Icons.text_snippet_rounded, color: const Color(0xFFF59E0B),
          preview: 'ZapSafe Personal Data Export\nGenerated: May 30, 2026\n\nThis archive contains all personal data ZapSafe holds for your account, as required by DPDP Act 2023 §11 and GDPR Art. 20.\n\nTo verify file integrity:\n  sha256sum zapsafe_export_20260530.zip\n  Expected: e3b0c442...b855\n\nQuestions? privacy@zapsafe.app'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day167DataExportDownloadScreen extends ConsumerWidget {
  const Day167DataExportDownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Export: Download & Verify'),
        elevation: 0,
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
            if (tab == 0) const _DownloadTab(),
            if (tab == 1) const _IntegrityTab(),
            if (tab == 2) const _FileBrowserTab(),
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF080A14), Color(0xFF050508), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5), width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _badge('⚡  DAY 167', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟡 MOCK-NOW', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Data Export  ·  Day 2/3', const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text('Download, Verify\n& Browse Export',
              style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Animated download with live speed/ETA. SHA-256 integrity check '
            'against server checksum. path_provider save flow. File browser '
            'showing the full export package structure.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('3',     '3 phases', Color(0xFF3B82F6)),
            _HStat('SHA256','Integrity',Color(0xFF10B981)),
            _HStat('7',     '7 folders',Color(0xFF8B5CF6)),
            _HStat('13',    '13 files', Color(0xFFF59E0B)),
          ]),
        ]),
      );

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
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
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
      (Icons.download_rounded,      Color(0xFF3B82F6), 'Download'),
      (Icons.verified_rounded,      Color(0xFF10B981), 'Integrity'),
      (Icons.folder_zip_rounded,    Color(0xFF8B5CF6), 'File Browser'),
    ];
    return Row(
      children: List.generate(3, (i) {
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
      }),
    );
  }
}

// ── Download Tab ───────────────────────────────────────────────────────────────
class _DownloadTab extends ConsumerStatefulWidget {
  const _DownloadTab();
  @override
  ConsumerState<_DownloadTab> createState() => _DownloadTabState();
}

class _DownloadTabState extends ConsumerState<_DownloadTab> {
  bool _cancelled = false;

  @override
  Widget build(BuildContext context) {
    final dlState  = ref.watch(_downloadStateProvider);
    final progress = ref.watch(_downloadProgressProvider);
    final speed    = ref.watch(_downloadSpeedProvider);

    final downloaded = (progress * _kFileSize).round();
    final eta = speed > 0
        ? (((_kFileSize - downloaded) / 1024) / speed).ceil()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
            text: 'Simulates the real download flow: '
                'connect → stream bytes → verify SHA-256 → save via path_provider → open_file_plus. '
                'Tap "Start Download" to watch the animated pipeline.'),
        const SizedBox(height: ZapSpacing.lg),

        // ── File info card ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(children: [
            _kv('Export ID',  _kExportId),
            _kv('File',       'zapsafe_export_20260530.zip'),
            _kv('Size',       '50.0 MB (${_kFileSize} bytes)'),
            _kv('Expires',    'June 29, 2026'),
            _kv('Checksum',   '${_kServerChecksum.substring(0, 16)}…'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Phase pipeline ─────────────────────────────────────────────
        const _SectionLabel('DOWNLOAD PIPELINE  ·  5 PHASES'),
        const SizedBox(height: ZapSpacing.md),
        _PhasePipeline(state: dlState),
        const SizedBox(height: ZapSpacing.xl),

        // ── Progress section ───────────────────────────────────────────
        if (dlState == _DlState.downloading || dlState == _DlState.connecting) ...[
          _ProgressBlock(
            progress: progress, speed: speed,
            downloaded: downloaded, eta: eta,
          ),
          const SizedBox(height: ZapSpacing.md),
          _outlineButton(
            label: 'Cancel Download',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFEF4444),
            onTap: () {
              setState(() => _cancelled = true);
              ref.read(_downloadStateProvider.notifier).state = _DlState.idle;
              ref.read(_downloadProgressProvider.notifier).state = 0.0;
              ref.read(_downloadSpeedProvider.notifier).state = 0.0;
            },
          ),
        ],

        if (dlState == _DlState.verifying) ...[
          _statusCard(Icons.verified_rounded, const Color(0xFF10B981),
              'Verifying integrity…',
              'Computing SHA-256 of downloaded bytes.\n'
              'Comparing against server checksum.',
              loading: true),
        ],

        if (dlState == _DlState.saving) ...[
          _statusCard(Icons.save_rounded, const Color(0xFF8B5CF6),
              'Saving file…',
              'getApplicationDocumentsDirectory() → writing bytes.\n'
              'Android: also copying to /Downloads via MediaStore.',
              loading: true),
        ],

        if (dlState == _DlState.done) ...[
          _DoneCard(onOpenFile: () => _openFile(context)),
          const SizedBox(height: ZapSpacing.md),
          _outlineButton(
            label: 'Download Again',
            icon: Icons.refresh_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () {
              ref.read(_downloadStateProvider.notifier).state = _DlState.idle;
              ref.read(_downloadProgressProvider.notifier).state = 0.0;
              ref.read(_downloadSpeedProvider.notifier).state = 0.0;
            },
          ),
        ],

        if (dlState == _DlState.error) ...[
          _statusCard(Icons.error_outline_rounded, const Color(0xFFEF4444),
              'Download failed',
              'Network error or integrity mismatch.\n'
              'Tap "Retry" to request a fresh presigned URL.',
              loading: false),
          const SizedBox(height: ZapSpacing.md),
          _actionButton(
            label: 'Retry Download',
            icon: Icons.refresh_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () {
              ref.read(_downloadStateProvider.notifier).state = _DlState.idle;
              ref.read(_downloadProgressProvider.notifier).state = 0.0;
            },
          ),
        ],

        if (dlState == _DlState.idle) ...[
          if (_cancelled)
            Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF6B7280),
                  text: 'Download cancelled. Your export link is still valid until June 29, 2026.'),
            ),
          _actionButton(
            label: 'Start Download  (Mock)',
            icon: Icons.download_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => _startDownload(context),
          ),
        ],

        const SizedBox(height: ZapSpacing.xl),
        const _SectionLabel('INTEGRATION CODE'),
        const SizedBox(height: ZapSpacing.md),
        _codeBlock(context, _kDownloadCode),
      ],
    );
  }

  Future<void> _startDownload(BuildContext context) async {
    _cancelled = false;
    final dl = ref.read(_downloadStateProvider.notifier);
    final prog = ref.read(_downloadProgressProvider.notifier);
    final spd  = ref.read(_downloadSpeedProvider.notifier);

    // Phase 1: Connect
    dl.state = _DlState.connecting;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _cancelled) return;

    // Phase 2: Download with progress
    dl.state = _DlState.downloading;
    const totalMs = 4000;
    const steps   = 80;
    for (int i = 1; i <= steps; i++) {
      if (!mounted || _cancelled) return;
      await Future.delayed(const Duration(milliseconds: totalMs ~/ steps));
      final p = i / steps;
      // Simulate variable speed
      final noise = (math.Random().nextDouble() - 0.5) * 400;
      prog.state = p;
      spd.state  = math.max(200, 1800 + noise); // KB/s
    }
    if (!mounted || _cancelled) return;

    // Phase 3: Verify
    dl.state = _DlState.verifying;
    spd.state = 0;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted || _cancelled) return;

    // Phase 4: Save
    dl.state = _DlState.saving;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || _cancelled) return;

    // Phase 5: Done
    dl.state = _DlState.done;
    ref.read(_integrityStateProvider.notifier).state = _IntegrityState.pass;
  }

  void _openFile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Mock: OpenFile.open() — system file manager would launch'),
      backgroundColor: Color(0xFF10B981),
      duration: Duration(seconds: 2)));
  }
}

// ── Phase pipeline widget ──────────────────────────────────────────────────────
class _PhasePipeline extends StatelessWidget {
  final _DlState state;
  const _PhasePipeline({required this.state});

  @override
  Widget build(BuildContext context) {
    const phases = [
      (Icons.wifi_rounded,          'Connect',  'GET presigned URL'),
      (Icons.download_rounded,      'Download', 'Stream bytes to disk'),
      (Icons.verified_rounded,      'Verify',   'SHA-256 check'),
      (Icons.save_rounded,          'Save',     'path_provider write'),
      (Icons.folder_open_rounded,   'Open',     'open_file_plus'),
    ];
    final activeIdx = switch (state) {
      _DlState.connecting  => 0,
      _DlState.downloading => 1,
      _DlState.verifying   => 2,
      _DlState.saving      => 3,
      _DlState.done        => 5, // all done
      _DlState.error       => -1,
      _DlState.idle        => -1,
    };

    return Row(
      children: List.generate(phases.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final phaseIdx = i ~/ 2;
          final passed = activeIdx > phaseIdx;
          return Expanded(child: Container(
            height: 2,
            color: passed ? const Color(0xFF10B981) : const Color(0xFF2A2A2A)));
        }
        final phaseIdx = i ~/ 2;
        final (icon, label, _) = phases[phaseIdx];
        final isDone    = activeIdx > phaseIdx;
        final isActive  = activeIdx == phaseIdx;
        final color = isDone ? const Color(0xFF10B981)
            : isActive ? const Color(0xFF3B82F6) : const Color(0xFF2A2A2A);

        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle,
                border: Border.all(color: color, width: isActive ? 2 : 1)),
            child: isActive
                ? Center(child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: color, strokeWidth: 2)))
                : Icon(isDone ? Icons.check_rounded : icon,
                    color: color, size: 14)),
          const SizedBox(height: ZapSpacing.xs),
          Text(label, style: TextStyle(color: color, fontSize: 8,
              fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]);
      }),
    );
  }
}

// ── Progress block ────────────────────────────────────────────────────────────
class _ProgressBlock extends StatelessWidget {
  final double progress, speed;
  final int downloaded;
  final int? eta;
  const _ProgressBlock({
    required this.progress, required this.speed,
    required this.downloaded, required this.eta});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(1);
    final dlMb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (_kFileSize / (1024 * 1024)).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('$dlMb / $totalMb MB', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
            minHeight: 8)),
        const SizedBox(height: ZapSpacing.sm),
        Row(children: [
          _statChip(Icons.speed_rounded, '${speed.toStringAsFixed(0)} KB/s', const Color(0xFF3B82F6)),
          const SizedBox(width: ZapSpacing.sm),
          if (eta != null)
            _statChip(Icons.timer_rounded, '~${eta}s remaining', const Color(0xFFF59E0B)),
        ]),
      ]),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: ZapSpacing.xs),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]));
}

// ── Done card ─────────────────────────────────────────────────────────────────
class _DoneCard extends StatelessWidget {
  final VoidCallback onOpenFile;
  const _DoneCard({required this.onOpenFile});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          SizedBox(width: ZapSpacing.sm),
          Text('Download Complete! ✅', style: TextStyle(color: Color(0xFF10B981),
              fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        const Text('Saved to Documents/zapsafe_export_20260530.zip\n'
            'Integrity verified ✅  ·  SHA-256 match confirmed',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(child: _miniBtn('Open File', Icons.folder_open_rounded,
              const Color(0xFF10B981), onOpenFile)),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _miniBtn('Share', Icons.share_rounded,
              const Color(0xFF3B82F6), () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mock: Share sheet would open'))))),
        ]),
      ]));

  Widget _miniBtn(String label, IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.35))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ])));
}

// ── Integrity Tab ──────────────────────────────────────────────────────────────
class _IntegrityTab extends ConsumerWidget {
  const _IntegrityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_integrityStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.verified_rounded, color: const Color(0xFF10B981),
            text: 'SHA-256 verification ensures the downloaded file was not '
                'corrupted in transit and matches exactly what ZapSafe generated. '
                'Compare the server checksum with the locally computed hash.'),
        const SizedBox(height: ZapSpacing.lg),

        // ── Server checksum ────────────────────────────────────────────
        const _SectionLabel('SERVER CHECKSUM (from API)'),
        const SizedBox(height: ZapSpacing.md),
        _checksumCard(
          label: 'From GET /api/v1/data-export/status/{id}',
          checksum: _kServerChecksum,
          color: const Color(0xFF3B82F6),
          context: context,
        ),
        const SizedBox(height: ZapSpacing.lg),

        // ── Local computed ─────────────────────────────────────────────
        const _SectionLabel('LOCAL COMPUTED (after download)'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _IntegrityState.idle)
          _checksumCard(label: 'Not yet computed — run download first',
              checksum: '—', color: const Color(0xFF4B5563), context: context)
        else if (state == _IntegrityState.computing)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Row(children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
                  color: Color(0xFF10B981), strokeWidth: 2)),
              SizedBox(width: ZapSpacing.md),
              Text('Computing SHA-256…', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ]))
        else
          _checksumCard(label: 'sha256.convert(downloadedBytes)',
              checksum: _kLocalChecksum, color: const Color(0xFF10B981), context: context),

        const SizedBox(height: ZapSpacing.lg),

        // ── Result ────────────────────────────────────────────────────
        const _SectionLabel('VERIFICATION RESULT'),
        const SizedBox(height: ZapSpacing.md),
        if (state == _IntegrityState.idle)
          _infoBox(icon: Icons.hourglass_top_rounded, color: const Color(0xFF4B5563),
              text: 'Complete a download to see the verification result.')
        else if (state == _IntegrityState.computing)
          _statusCard(Icons.radar_rounded, const Color(0xFF10B981),
              'Checking…', 'Byte-by-byte comparison in progress', loading: true)
        else if (state == _IntegrityState.pass)
          _ResultCard(pass: true)
        else
          _ResultCard(pass: false),

        const SizedBox(height: ZapSpacing.xl),

        // ── Manual verify ─────────────────────────────────────────────
        if (state != _IntegrityState.idle) ...[
          _actionButton(
            label: 'Re-run Verification (Mock)',
            icon: Icons.replay_rounded,
            color: const Color(0xFF10B981),
            onTap: () async {
              ref.read(_integrityStateProvider.notifier).state = _IntegrityState.computing;
              await Future.delayed(const Duration(milliseconds: 1200));
              ref.read(_integrityStateProvider.notifier).state = _IntegrityState.pass;
            },
          ),
          const SizedBox(height: ZapSpacing.xl),
        ],

        // ── SHA256 code ────────────────────────────────────────────────
        const _SectionLabel('INTEGRATION CODE  ·  crypto package'),
        const SizedBox(height: ZapSpacing.md),
        _codeBlock(context, _kIntegrityCode),
        const SizedBox(height: ZapSpacing.lg),

        // ── Tamper scenario ────────────────────────────────────────────
        const _SectionLabel('EDGE CASE: TAMPERED FILE'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.security_rounded, color: Color(0xFFEF4444), size: 16),
              SizedBox(width: ZapSpacing.sm),
              Text('What if checksums don\'t match?',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              '1. Immediately delete the corrupted local file.\n'
              '2. Show "Integrity check failed" error to user.\n'
              '3. Offer retry — fetches a fresh presigned URL from server.\n'
              '4. Log the failure to Sentry with export_id + checksum_received.\n'
              '5. If failure persists, direct user to privacy@zapsafe.app.',
              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.7)),
            const SizedBox(height: ZapSpacing.md),
            GestureDetector(
              onTap: () async {
                ref.read(_integrityStateProvider.notifier).state = _IntegrityState.computing;
                await Future.delayed(const Duration(milliseconds: 1200));
                if (context.mounted) {
                  ref.read(_integrityStateProvider.notifier).state = _IntegrityState.fail;
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 14),
                  SizedBox(width: 6),
                  Text('Simulate tampered file → FAIL',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ])),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _checksumCard({required String label, required String checksum,
      required Color color, required BuildContext context}) =>
      GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: checksum));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Checksum copied'), duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF1A1A1A)));
        },
        child: Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            const SizedBox(height: ZapSpacing.sm),
            Text(checksum, style: TextStyle(color: color, fontSize: 11,
                fontFamily: 'monospace', fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: ZapSpacing.xs),
            const Text('long-press to copy',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
          ])),
      );
}

class _ResultCard extends StatelessWidget {
  final bool pass;
  const _ResultCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    final color = pass ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.4), width: 2)),
      child: Column(children: [
        Icon(pass ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            color: color, size: 36),
        const SizedBox(height: ZapSpacing.sm),
        Text(pass ? 'Integrity Check PASSED ✅' : 'Integrity Check FAILED ❌',
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          pass
              ? 'SHA-256 matches server checksum.\nFile is authentic and unmodified.'
              : 'SHA-256 does NOT match server checksum.\nFile may be corrupted. Delete and re-download.',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5),
          textAlign: TextAlign.center),
        if (pass) ...[
          const SizedBox(height: ZapSpacing.md),
          Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: const [
            _Chip('Not corrupted ✓', Color(0xFF10B981)),
            _Chip('Not tampered ✓',  Color(0xFF10B981)),
            _Chip('50.0 MB ✓',       Color(0xFF10B981)),
          ]),
        ],
      ]),
    );
  }
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

// ── File Browser Tab ───────────────────────────────────────────────────────────
class _FileBrowserTab extends ConsumerWidget {
  const _FileBrowserTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedFolder = ref.watch(_expandedFolderProvider);
    final selectedFile   = ref.watch(_selectedFileProvider);

    final totalFiles = _kExportStructure.fold(0, (s, f) => s + f.files.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.folder_zip_rounded, color: const Color(0xFF8B5CF6),
            text: 'Browse the structure of your ZIP export package. '
                'Tap any folder to expand, tap any file to preview its content.'),
        const SizedBox(height: ZapSpacing.lg),

        // Stats
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Row(children: [
            _statBox('7', 'Folders', const Color(0xFF8B5CF6)),
            _statBox('$totalFiles', 'Files', const Color(0xFF3B82F6)),
            _statBox('50.0 MB', 'Total', const Color(0xFFF59E0B)),
            _statBox('ZIP', 'Format', const Color(0xFF10B981)),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Breadcrumb
        const _SectionLabel('EXPORT PACKAGE STRUCTURE'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: const Row(children: [
            Icon(Icons.folder_zip_rounded, color: Color(0xFF8B5CF6), size: 14),
            SizedBox(width: 6),
            Text('zapsafe_export_20260530.zip',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: ZapSpacing.sm),

        // Folder tree
        ..._kExportStructure.map((folder) {
          final isExpanded = expandedFolder == folder.name;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => ref.read(_expandedFolderProvider.notifier).state =
                  isExpanded ? null : folder.name,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? folder.color.withOpacity(0.08) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: isExpanded
                          ? folder.color.withOpacity(0.35) : const Color(0xFF2A2A2A),
                      width: isExpanded ? 2 : 1)),
                child: Row(children: [
                  Icon(
                    isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                    color: folder.color, size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(folder.name,
                      style: TextStyle(
                          color: isExpanded ? folder.color : Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600,
                          fontFamily: 'monospace'))),
                  Text('${folder.files.length} file${folder.files.length == 1 ? "" : "s"}',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(isExpanded ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 14),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: ZapSpacing.lg, bottom: ZapSpacing.sm),
                      child: Column(children: folder.files.map((file) {
                        final isSel = selectedFile?.path == file.path;
                        return GestureDetector(
                          onTap: () => ref
                              .read(_selectedFileProvider.notifier)
                              .state = isSel ? null : file,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: ZapSpacing.md, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? file.color.withOpacity(0.1)
                                  : const Color(0xFF141414),
                              borderRadius:
                                  BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(
                                  color: isSel
                                      ? file.color.withOpacity(0.4)
                                      : const Color(0xFF222222))),
                            child: Row(children: [
                              Icon(file.icon, color: file.color, size: 14),
                              const SizedBox(width: ZapSpacing.sm),
                              Expanded(child: Text(file.name,
                                  style: const TextStyle(
                                      color: Color(0xFFD1D5DB), fontSize: 11,
                                      fontFamily: 'monospace'))),
                              Text(_fmtSize(file.sizeBytes),
                                  style: const TextStyle(
                                      color: Color(0xFF6B7280), fontSize: 10)),
                            ]),
                          ),
                        );
                      }).toList()),
                    )
                  : const SizedBox.shrink(),
            ),
          ]);
        }),

        // File preview
        if (selectedFile != null) ...[
          const SizedBox(height: ZapSpacing.lg),
          const _SectionLabel('FILE PREVIEW'),
          const SizedBox(height: ZapSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Icon(selectedFile.icon, color: selectedFile.color, size: 16),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(selectedFile.path,
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10,
                          fontFamily: 'monospace'))),
                  Text(_fmtSize(selectedFile.sizeBytes),
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                ])),
              const Divider(height: 1, color: Color(0xFF1E1E1E)),
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Text(selectedFile.preview,
                    style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 10,
                        fontFamily: 'monospace', height: 1.6))),
            ]),
          ),
        ],

        const SizedBox(height: ZapSpacing.xl),
        const _SectionLabel('SAVE PATH CODE'),
        const SizedBox(height: ZapSpacing.md),
        _codeBlock(context, _kSaveCode),
      ],
    );
  }

  Widget _statBox(String v, String l, Color c) => Expanded(child: Column(children: [
    Text(v, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800),
        textAlign: TextAlign.center),
    Text(l, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
        textAlign: TextAlign.center),
  ]));

  static String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024)        return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 90, child: Text(k,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10))),
      Expanded(child: Text(v, style: const TextStyle(
          color: Color(0xFFD1D5DB), fontSize: 10, fontFamily: 'monospace'))),
    ]));

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

Widget _actionButton({required String label, required IconData icon,
    required Color color, required VoidCallback? onTap}) =>
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w700)),
        ])));

Widget _outlineButton({required String label, required IconData icon,
    required Color color, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w600)),
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

Widget _codeBlock(BuildContext context, String code) => GestureDetector(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
          duration: Duration(seconds: 1)));
    },
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
        Text(code, style: const TextStyle(
            color: Color(0xFF86EFAC), fontSize: 10,
            fontFamily: 'monospace', height: 1.6)),
      ])));

// ── Code snippets ──────────────────────────────────────────────────────────────
const _kDownloadCode = '''
// pubspec.yaml
// path_provider: ^2.1.3
// open_file_plus: ^3.4.1
// crypto: ^3.0.3

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:http/http.dart' as http;

Future<String> downloadAndVerify({
  required String presignedUrl,
  required String expectedSha256,
  required String fileName,
}) async {
  // 1. Stream download with progress
  final request = http.Request('GET', Uri.parse(presignedUrl));
  final response = await http.Client().send(request);
  final total = response.contentLength ?? 0;

  final bytes = <int>[];
  int received = 0;
  await for (final chunk in response.stream) {
    bytes.addAll(chunk);
    received += chunk.length;
    onProgress(received / total); // update provider
  }

  // 2. Verify SHA-256
  final digest = sha256.convert(bytes);
  if (digest.toString() != expectedSha256) {
    throw IntegrityException('Checksum mismatch');
  }

  // 3. Save to Documents dir (+ Android Downloads)
  final dir = await getApplicationDocumentsDirectory();
  final file = File('\${dir.path}/\$fileName');
  await file.writeAsBytes(bytes);

  // On Android also copy to public Downloads via MediaStore
  // (requires storage permission on API < 29)

  return file.path;
}

// 4. Open with system file manager
await OpenFile.open(savedPath);
''';

const _kIntegrityCode = '''
// crypto: ^3.0.3

import 'package:crypto/crypto.dart';

bool verifyIntegrity({
  required List<int> downloadedBytes,
  required String serverChecksum,
}) {
  final localDigest = sha256.convert(downloadedBytes);
  return localDigest.toString() == serverChecksum;
}

// Example usage:
final bytes = await file.readAsBytes();
final isValid = verifyIntegrity(
  downloadedBytes: bytes,
  serverChecksum: exportRecord.checksumSha256,
);

if (!isValid) {
  await file.delete();           // delete corrupted file
  Sentry.captureEvent(          // log to crash reporting
    SentryEvent(message: SentryMessage(
      'Export integrity failure: export_id=\$exportId')));
  throw IntegrityException();
}
''';

const _kSaveCode = '''
// path_provider: ^2.1.3
// Docs: https://pub.dev/packages/path_provider

import 'package:path_provider/path_provider.dart';

// Cross-platform save path
Future<String> getSavePath(String fileName) async {
  // iOS: /var/mobile/.../Documents/  (sandboxed, Files app visible)
  // Android: /data/data/com.zapsafe.app/files/  (internal)
  final dir = await getApplicationDocumentsDirectory();
  return '\${dir.path}/\$fileName';
}

// Android: also write to public Downloads (user-accessible)
// Requires READ_EXTERNAL_STORAGE on API < 29
// API 29+: use MediaStore (no permission needed)
Future<void> copyToPublicDownloads(String sourcePath, String fileName) async {
  // Use platform channel → MediaStore.Images.insertImage()
  // or: path_provider_ex package for external storage
}

// iOS: make visible in Files app
// set UIFileSharingEnabled = YES in Info.plist
// set LSSupportsOpeningDocumentsInPlace = YES
''';
