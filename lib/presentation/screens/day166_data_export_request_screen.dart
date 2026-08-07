/// Day 166 — Data Export Request ("Download My Data")
///
/// First day of the Days 166-168 Data Export block.
/// Day 167: download flow + progress + file handling.
/// Day 168: GDPR Art. 20 deep dive + request limits + edge cases.
///
/// 🟡 MOCK-NOW — backend API does not yet exist (backend at Day 78).
///    All requests are simulated locally. When backend implements:
///      POST /api/v1/data-export/request
///      GET  /api/v1/data-export/status/{id}
///      GET  /api/v1/data-export/download/{id}
///      GET  /api/v1/data-export/history
///    replace the _MockExportService calls with real http calls.
///    Full contract documented in Tab 3 (API Contract).
///
/// Legal basis:
///   DPDP Act 2023, Section 11 — right to access personal data.
///   GDPR Art. 20  — right to data portability.
///   Timeline: export ready within 30 days (DPDP), 1 month (GDPR).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _selectedCategoriesProvider =
    StateProvider<Set<String>>((ref) => _kAllCategories.toSet());
final _selectedFormatProvider = StateProvider<_ExportFormat>((ref) => _ExportFormat.zip);
final _requestStateProvider   = StateProvider<_RequestState>((ref) => _RequestState.idle);
final _currentExportProvider  = StateProvider<_ExportRecord?>((ref) => null);
final _exportHistoryProvider  = StateProvider<List<_ExportRecord>>((ref) => _kMockHistory);
final _expandedCardProvider   = StateProvider<int?>((ref) => null);

// ── Enums & data ───────────────────────────────────────────────────────────────
enum _ExportFormat { json, zip, pdf }
enum _RequestState { idle, requesting, processing, ready, downloading, error }

const _kAllCategories = [
  'Profile & Account',
  'Emergency Contacts',
  'SOS Events',
  'Evidence Vault',
  'Location & Safe Zones',
  'Analytics & Usage',
  'Settings & Preferences',
  'Activity Audit Log',
];

const _kCategoryIcons = {
  'Profile & Account':    Icons.account_circle_rounded,
  'Emergency Contacts':   Icons.people_rounded,
  'SOS Events':           Icons.warning_rounded,
  'Evidence Vault':       Icons.lock_rounded,
  'Location & Safe Zones':Icons.location_on_rounded,
  'Analytics & Usage':    Icons.bar_chart_rounded,
  'Settings & Preferences': Icons.tune_rounded,
  'Activity Audit Log':   Icons.history_rounded,
};

const _kCategoryColors = {
  'Profile & Account':    Color(0xFF3B82F6),
  'Emergency Contacts':   Color(0xFF10B981),
  'SOS Events':           Color(0xFFEF4444),
  'Evidence Vault':       Color(0xFFF59E0B),
  'Location & Safe Zones':Color(0xFF10B981),
  'Analytics & Usage':    Color(0xFF8B5CF6),
  'Settings & Preferences': Color(0xFF6B7280),
  'Activity Audit Log':   Color(0xFF3B82F6),
};

const _kCategorySizes = {
  'Profile & Account':    '2 KB',
  'Emergency Contacts':   '8 KB',
  'SOS Events':           '1.2 MB',
  'Evidence Vault':       '48 MB',
  'Location & Safe Zones':'320 KB',
  'Analytics & Usage':    '14 KB',
  'Settings & Preferences': '4 KB',
  'Activity Audit Log':   '220 KB',
};

class _ExportRecord {
  final String  id;
  final DateTime requestedAt;
  final List<String> categories;
  final _ExportFormat format;
  final _RequestState status;
  final String? fileSize;
  final String? expiresAt;
  const _ExportRecord({
    required this.id,
    required this.requestedAt,
    required this.categories,
    required this.format,
    required this.status,
    this.fileSize,
    this.expiresAt,
  });
}

final _kMockHistory = [
  _ExportRecord(
    id: 'exp_20260517_001',
    requestedAt: DateTime(2026, 5, 17, 14, 30),
    categories: _kAllCategories,
    format: _ExportFormat.zip,
    status: _RequestState.ready,
    fileSize: '49.8 MB',
    expiresAt: 'June 17, 2026',
  ),
  _ExportRecord(
    id: 'exp_20260402_001',
    requestedAt: DateTime(2026, 4, 2, 9, 15),
    categories: ['Profile & Account', 'Emergency Contacts', 'SOS Events'],
    format: _ExportFormat.json,
    status: _RequestState.ready,
    fileSize: '1.3 MB',
    expiresAt: 'May 2, 2026',
  ),
  _ExportRecord(
    id: 'exp_20260215_001',
    requestedAt: DateTime(2026, 2, 15, 18, 45),
    categories: _kAllCategories,
    format: _ExportFormat.pdf,
    status: _RequestState.ready,
    fileSize: '3.2 MB',
    expiresAt: 'Expired',
  ),
];

// ── Mock service ───────────────────────────────────────────────────────────────
class _MockExportService {
  /// Simulates POST /api/v1/data-export/request
  /// Real: returns { export_id, status: "processing", estimated_ready_at }
  static Future<String> requestExport({
    required List<String> categories,
    required _ExportFormat format,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return 'exp_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Simulates GET /api/v1/data-export/status/{id}
  /// Real: returns { status, progress_pct, file_size_bytes, download_url, expires_at }
  static Future<Map<String, dynamic>> checkStatus(String exportId) async {
    await Future.delayed(const Duration(seconds: 3));
    return {
      'status': 'ready',
      'progress_pct': 100,
      'file_size_bytes': 52428800,
      'expires_at': 'June 30, 2026',
    };
  }

  /// Simulates GET /api/v1/data-export/download/{id}
  /// Real: returns presigned S3 URL valid for 15 minutes
  static Future<String> getDownloadUrl(String exportId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'https://exports.zapsafe.app/$exportId/data.zip?token=mock_presigned';
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day166DataExportRequestScreen extends ConsumerWidget {
  const Day166DataExportRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Download My Data'),
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
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _RequestTab(),
            if (tab == 1) const _HistoryTab(),
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
          colors: [Color(0xFF0A0814), Color(0xFF05050A), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 166', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟡 MOCK-NOW', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Section B Start', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text('Download\nMy Data',
              style: TextStyle(color: Colors.white, fontSize: 26,
                  fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'DPDP Act 2023 §11 + GDPR Art. 20 right to data portability. '
            'Request a complete export of all your ZapSafe data in JSON, '
            'ZIP, or PDF format. Ready within 30 days.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('8',    '8 data categories', Color(0xFF8B5CF6)),
            _HStat('3',    'Export formats',     Color(0xFF10B981)),
            _HStat('30d',  'Max wait (DPDP)',     Color(0xFFF59E0B)),
            _HStat('Free', 'No cost to you',     Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.construction_rounded, color: Color(0xFFF59E0B), size: 14),
              SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(
                'MOCK-NOW: UI built with mock data. '
                'Backend API contract documented in Tab 3. '
                'Backend at Day 78 — replace _MockExportService calls when ready.',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, height: 1.5))),
            ]),
          ),
        ],
      ),
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
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
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
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.download_rounded,        Color(0xFF8B5CF6), 'Request Export'),
      (Icons.history_rounded,         Color(0xFF3B82F6), 'My Exports'),
      (Icons.code_rounded,            Color(0xFFF59E0B), 'API Contract'),
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

// ── Request Tab ────────────────────────────────────────────────────────────────
class _RequestTab extends ConsumerWidget {
  const _RequestTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected     = ref.watch(_selectedCategoriesProvider);
    final format       = ref.watch(_selectedFormatProvider);
    final reqState     = ref.watch(_requestStateProvider);
    final currentExport= ref.watch(_currentExportProvider);

    // Calculate estimated size
    final sizeBytes = selected.fold(0.0, (sum, cat) {
      final s = _kCategorySizes[cat] ?? '0 KB';
      return sum + _parseSize(s);
    });
    final estSize = _formatSize(sizeBytes);

    final canRequest = selected.isNotEmpty &&
        reqState != _RequestState.requesting &&
        reqState != _RequestState.processing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF8B5CF6),
            text: 'Select the data categories you want included in your export. '
                'You can request one export every 30 days. Export link is valid for 30 days.'),
        const SizedBox(height: ZapSpacing.lg),

        // ── Category selector ──────────────────────────────────────────
        const _SectionLabel('DATA CATEGORIES'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          const Expanded(child: Text('Select all / none',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11))),
          GestureDetector(
            onTap: () {
              if (selected.length == _kAllCategories.length) {
                ref.read(_selectedCategoriesProvider.notifier).state = {};
              } else {
                ref.read(_selectedCategoriesProvider.notifier)
                    .state = _kAllCategories.toSet();
              }
            },
            child: Text(
              selected.length == _kAllCategories.length ? 'Deselect All' : 'Select All',
              style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11,
                  fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ..._kAllCategories.map((cat) {
          final isOn  = selected.contains(cat);
          final icon  = _kCategoryIcons[cat]!;
          final color = _kCategoryColors[cat]!;
          final size  = _kCategorySizes[cat]!;
          return GestureDetector(
            onTap: () {
              final updated = Set<String>.from(selected);
              if (isOn) { updated.remove(cat); } else { updated.add(cat); }
              ref.read(_selectedCategoriesProvider.notifier).state = updated;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: isOn ? color.withOpacity(0.07) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isOn ? color.withOpacity(0.35) : const Color(0xFF2A2A2A),
                    width: isOn ? 2 : 1)),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16)),
                const SizedBox(width: ZapSpacing.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat, style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w500)),
                  Text(size, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                ])),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: isOn ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isOn ? color : const Color(0xFF3A3A3A), width: 2)),
                  child: isOn ? const Icon(Icons.check, color: Colors.white, size: 12) : null),
              ]),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),

        // ── Format selector ────────────────────────────────────────────
        const _SectionLabel('EXPORT FORMAT'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          _formatCard(_ExportFormat.zip,  '📦 ZIP',  'All files bundled',    const Color(0xFF8B5CF6), format, ref),
          const SizedBox(width: ZapSpacing.sm),
          _formatCard(_ExportFormat.json, '{ } JSON', 'Machine-readable',    const Color(0xFF3B82F6), format, ref),
          const SizedBox(width: ZapSpacing.sm),
          _formatCard(_ExportFormat.pdf,  '📄 PDF',  'Human-readable report', const Color(0xFF10B981), format, ref),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // ── Size estimate ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Row(children: [
            const Icon(Icons.folder_zip_rounded, color: Color(0xFF8B5CF6), size: 18),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated export size',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              Text(selected.isEmpty ? '—' : '~$estSize',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ])),
            Text('${selected.length}/${_kAllCategories.length} categories',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ── Request button / state ─────────────────────────────────────
        if (reqState == _RequestState.idle || reqState == _RequestState.error) ...[
          if (reqState == _RequestState.error)
            Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _infoBox(icon: Icons.error_outline_rounded, color: const Color(0xFFEF4444),
                  text: 'Request failed (mock). In production, retry or contact support@zapsafe.app.'),
            ),
          _actionButton(
            label: 'Request Export',
            icon: Icons.download_rounded,
            color: canRequest ? const Color(0xFF8B5CF6) : const Color(0xFF2A2A2A),
            onTap: canRequest
                ? () => _doRequest(context, ref, selected.toList(), format)
                : null,
          ),
        ],

        if (reqState == _RequestState.requesting)
          _statusCard(Icons.send_rounded, const Color(0xFF8B5CF6),
              'Sending request…', 'Contacting server — POST /api/v1/data-export/request',
              showLoader: true),

        if (reqState == _RequestState.processing)
          _progressCard(currentExport),

        if (reqState == _RequestState.ready && currentExport != null) ...[
          _statusCard(Icons.check_circle_rounded, const Color(0xFF10B981),
              'Export Ready! 🎉',
              'ID: ${currentExport.id}\nSize: ~${currentExport.fileSize ?? "?"}\nExpires: ${currentExport.expiresAt ?? "30 days"}',
              showLoader: false),
          const SizedBox(height: ZapSpacing.md),
          _actionButton(
            label: 'Download Export',
            icon: Icons.download_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _doDownload(context, ref),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Center(child: GestureDetector(
            onTap: () {
              ref.read(_requestStateProvider.notifier).state = _RequestState.idle;
              ref.read(_currentExportProvider.notifier).state = null;
            },
            child: const Text('Make another request',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12,
                    decoration: TextDecoration.underline)),
          )),
        ],

        if (reqState == _RequestState.downloading)
          _statusCard(Icons.download_rounded, const Color(0xFF3B82F6),
              'Downloading…', 'Fetching presigned URL — GET /api/v1/data-export/download/{id}',
              showLoader: true),

        const SizedBox(height: ZapSpacing.xl),

        // ── Legal note ─────────────────────────────────────────────────
        _infoBox(icon: Icons.gavel_rounded, color: const Color(0xFF6B7280),
            text: 'Under DPDP Act 2023 §11 and GDPR Art. 20, you have the right to receive '
                'your personal data in a structured, commonly used, machine-readable format. '
                'ZapSafe processes this request within 30 days at no charge.'),
      ],
    );
  }

  Widget _formatCard(_ExportFormat fmt, String label, String sub, Color color,
      _ExportFormat current, WidgetRef ref) {
    final isOn = fmt == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(_selectedFormatProvider.notifier).state = fmt,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: isOn ? 2 : 1)),
          child: Column(children: [
            Text(label, style: TextStyle(color: isOn ? color : Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 3),
            Text(sub, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _progressCard(_ExportRecord? record) => Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6), strokeWidth: 2)),
            const SizedBox(width: ZapSpacing.sm),
            const Text('Processing your export…',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text('ZapSafe is compiling and encrypting your data. '
              'This may take a few moments.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5)),
          const SizedBox(height: ZapSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
              backgroundColor: Color(0xFF2A2A2A),
              valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
              minHeight: 5)),
          if (record != null) ...[
            const SizedBox(height: ZapSpacing.sm),
            Text('Request ID: ${record.id}',
                style: const TextStyle(color: Color(0xFF6B7280),
                    fontSize: 10, fontFamily: 'monospace')),
          ],
        ]),
      );

  Widget _statusCard(IconData icon, Color color, String title, String body,
      {required bool showLoader}) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            showLoader
                ? SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(icon, color: color, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text(title, style: TextStyle(color: color, fontSize: 13,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
              fontSize: 11, height: 1.5)),
        ]),
      );

  static double _parseSize(String s) {
    final parts = s.trim().split(' ');
    final num   = double.tryParse(parts[0]) ?? 0;
    final unit  = parts.length > 1 ? parts[1].toUpperCase() : 'KB';
    if (unit.startsWith('G')) return num * 1024 * 1024 * 1024;
    if (unit.startsWith('M')) return num * 1024 * 1024;
    if (unit.startsWith('K')) return num * 1024;
    return num;
  }

  static String _formatSize(double bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024)        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024)               return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Future<void> _doRequest(BuildContext context, WidgetRef ref,
      List<String> categories, _ExportFormat format) async {
    ref.read(_requestStateProvider.notifier).state = _RequestState.requesting;
    try {
      final id = await _MockExportService.requestExport(
          categories: categories, format: format);
      if (!context.mounted) return;
      ref.read(_requestStateProvider.notifier).state = _RequestState.processing;

      final statusData = await _MockExportService.checkStatus(id);
      if (!context.mounted) return;

      final record = _ExportRecord(
        id: id,
        requestedAt: DateTime.now(),
        categories: categories,
        format: format,
        status: _RequestState.ready,
        fileSize: _formatSize(
            (statusData['file_size_bytes'] as num?)?.toDouble() ?? 0),
        expiresAt: statusData['expires_at'] as String? ?? '30 days',
      );

      ref.read(_currentExportProvider.notifier).state = record;
      ref.read(_requestStateProvider.notifier).state = _RequestState.ready;

      // Add to history
      final history = [...ref.read(_exportHistoryProvider)];
      history.insert(0, record);
      ref.read(_exportHistoryProvider.notifier).state = history;
    } catch (_) {
      if (!context.mounted) return;
      ref.read(_requestStateProvider.notifier).state = _RequestState.error;
    }
  }

  Future<void> _doDownload(BuildContext context, WidgetRef ref) async {
    final record = ref.read(_currentExportProvider);
    if (record == null) return;
    ref.read(_requestStateProvider.notifier).state = _RequestState.downloading;
    final url = await _MockExportService.getDownloadUrl(record.id);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Mock download started: $url'),
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 3),
    ));
    ref.read(_requestStateProvider.notifier).state = _RequestState.idle;
    ref.read(_currentExportProvider.notifier).state = null;
  }
}

// ── History Tab ────────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history  = ref.watch(_exportHistoryProvider);
    final expanded = ref.watch(_expandedCardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.history_rounded, color: const Color(0xFF3B82F6),
            text: 'Your past export requests. Export files are stored server-side '
                'for 30 days then automatically deleted. Expired exports must be re-requested.'),
        const SizedBox(height: ZapSpacing.lg),

        // Stats strip
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Row(children: [
            _statBox('${history.length}', 'Total requests', const Color(0xFF3B82F6)),
            _statBox('${history.where((e) => e.status == _RequestState.ready && e.expiresAt != "Expired").length}', 'Available', const Color(0xFF10B981)),
            _statBox('${history.where((e) => e.expiresAt == "Expired").length}', 'Expired', const Color(0xFF6B7280)),
            _statBox('30d', 'Retention', const Color(0xFFF59E0B)),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('EXPORT HISTORY'),
        const SizedBox(height: ZapSpacing.md),
        ...history.asMap().entries.map((e) {
          final i       = e.key;
          final record  = e.value;
          final isExp   = expanded == i;
          final isReady = record.status == _RequestState.ready && record.expiresAt != 'Expired';
          final isExpired = record.expiresAt == 'Expired';

          return GestureDetector(
            onTap: () => ref.read(_expandedCardProvider.notifier).state =
                isExp ? null : i,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              decoration: BoxDecoration(
                color: isExp ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp
                        ? const Color(0xFF3B82F6).withOpacity(0.4)
                        : const Color(0xFF2A2A2A))),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _formatColor(record.format).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                      child: Icon(_formatIcon(record.format),
                          color: _formatColor(record.format), size: 18)),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_formatLabel(record.format),
                          style: const TextStyle(color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${_fmtDate(record.requestedAt)}  ·  '
                        '${record.categories.length} categories  ·  '
                        '${record.fileSize ?? "—"}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                    ])),
                    _statusChipSmall(isExpired
                        ? 'Expired' : isReady ? 'Available ✅' : 'Processing',
                        isExpired ? const Color(0xFF4B5563)
                            : isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(isExp ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 16),
                  ]),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: isExp
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                          child: _ExportDetail(record: record, isReady: isReady))
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(
          icon: Icons.schedule_rounded,
          color: const Color(0xFF6B7280),
          text: 'You can request one new export every 30 days. '
              'Expired exports are permanently deleted from ZapSafe servers. '
              'To re-download, submit a new request.',
        ),
      ],
    );
  }

  Widget _statBox(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9),
              textAlign: TextAlign.center),
        ]));

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_kMonths[d.month - 1]} ${d.year}';

  static const _kMonths = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  static Color _formatColor(_ExportFormat f) => switch (f) {
    _ExportFormat.zip  => const Color(0xFF8B5CF6),
    _ExportFormat.json => const Color(0xFF3B82F6),
    _ExportFormat.pdf  => const Color(0xFF10B981),
  };

  static IconData _formatIcon(_ExportFormat f) => switch (f) {
    _ExportFormat.zip  => Icons.folder_zip_rounded,
    _ExportFormat.json => Icons.data_object_rounded,
    _ExportFormat.pdf  => Icons.picture_as_pdf_rounded,
  };

  static String _formatLabel(_ExportFormat f) => switch (f) {
    _ExportFormat.zip  => 'ZIP Archive',
    _ExportFormat.json => 'JSON Export',
    _ExportFormat.pdf  => 'PDF Report',
  };

  static Widget _statusChipSmall(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.w700)));
}

class _ExportDetail extends StatelessWidget {
  final _ExportRecord record;
  final bool isReady;
  const _ExportDetail({required this.record, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kv('Request ID', record.id),
        _kv('Requested', '${record.requestedAt.day}/${record.requestedAt.month}/${record.requestedAt.year}  ${_twoDigit(record.requestedAt.hour)}:${_twoDigit(record.requestedAt.minute)}'),
        _kv('Format', record.format.name.toUpperCase()),
        _kv('File Size', record.fileSize ?? '—'),
        _kv('Expires', record.expiresAt ?? '—'),
        _kv('Categories', '${record.categories.length} selected'),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(spacing: 4, runSpacing: 4, children: record.categories.map((c) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2A2A2A))),
              child: Text(c, style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9)))).toList()),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: isReady
              ? GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mock: fetching download URL from server…'),
                      backgroundColor: Color(0xFF10B981))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 16),
                      SizedBox(width: 6),
                      Text('Download', style: TextStyle(color: Color(0xFF10B981),
                          fontSize: 12, fontWeight: FontWeight.w700)),
                    ])),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A))),
                  child: const Center(child: Text('Unavailable',
                      style: TextStyle(color: Color(0xFF4B5563), fontSize: 12)))),
        ),
      ]),
    );
  }

  Widget _kv(String key, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(key,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10))),
      Expanded(child: Text(value,
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10,
              fontFamily: 'monospace'))),
    ]),
  );

  static String _twoDigit(int n) => n.toString().padLeft(2, '0');
}

// ── API Contract Tab ───────────────────────────────────────────────────────────
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.code_rounded, color: const Color(0xFFF59E0B),
            text: 'Backend is at Day 78. These endpoints do not exist yet. '
                'Document here so backend can implement with zero contract conflicts. '
                'Replace _MockExportService calls in _RequestTab._doRequest()'),
        const SizedBox(height: ZapSpacing.lg),

        // ── Endpoint 1: POST request ────────────────────────────────────
        const _SectionLabel('ENDPOINT 1 — REQUEST EXPORT'),
        const SizedBox(height: ZapSpacing.md),
        _codeCard(context, '''// POST /api/v1/data-export/request
// Auth: Bearer JWT required
// Rate limit: 1 per 30 days per user

// REQUEST BODY
{
  "categories": [
    "profile",        // Profile & Account
    "contacts",       // Emergency Contacts
    "sos_events",     // SOS Events
    "evidence",       // Evidence Vault
    "location",       // Location & Safe Zones
    "analytics",      // Analytics & Usage
    "settings",       // Settings & Preferences
    "audit_log"       // Activity Audit Log
  ],
  "format": "zip"     // "zip" | "json" | "pdf"
}

// RESPONSE 202 Accepted
{
  "export_id": "exp_20260530_abc123",
  "status": "processing",
  "estimated_ready_at": "2026-05-30T14:30:00Z",
  "created_at": "2026-05-30T14:25:00Z"
}

// RESPONSE 429 Too Many Requests
{
  "error": "rate_limit_exceeded",
  "next_allowed_at": "2026-06-29T14:25:00Z"
}'''),
        const SizedBox(height: ZapSpacing.lg),

        // ── Endpoint 2: GET status ──────────────────────────────────────
        const _SectionLabel('ENDPOINT 2 — CHECK STATUS'),
        const SizedBox(height: ZapSpacing.md),
        _codeCard(context, '''// GET /api/v1/data-export/status/{export_id}
// Auth: Bearer JWT required
// Poll every 10s while status == "processing"

// RESPONSE 200 OK (processing)
{
  "export_id": "exp_20260530_abc123",
  "status": "processing",    // "processing" | "ready" | "failed"
  "progress_pct": 65,
  "categories_done": ["profile", "contacts", "sos_events"],
  "estimated_ready_at": "2026-05-30T14:30:00Z"
}

// RESPONSE 200 OK (ready)
{
  "export_id": "exp_20260530_abc123",
  "status": "ready",
  "progress_pct": 100,
  "file_size_bytes": 52428800,
  "file_name": "zapsafe_export_20260530.zip",
  "expires_at": "2026-06-29T14:30:00Z",
  "download_token": "tok_abc123xyz"
}'''),
        const SizedBox(height: ZapSpacing.lg),

        // ── Endpoint 3: GET download URL ────────────────────────────────
        const _SectionLabel('ENDPOINT 3 — GET DOWNLOAD URL'),
        const SizedBox(height: ZapSpacing.md),
        _codeCard(context, '''// GET /api/v1/data-export/download/{export_id}
// Auth: Bearer JWT required
// Returns presigned S3 URL valid for 15 minutes

// RESPONSE 200 OK
{
  "export_id": "exp_20260530_abc123",
  "download_url": "https://exports.zapsafe.app/abc123/data.zip?X-Amz-Signature=...",
  "url_expires_at": "2026-05-30T14:45:00Z",  // 15 min presigned
  "file_size_bytes": 52428800,
  "checksum_sha256": "e3b0c44298fc1c149afb..."
}

// RESPONSE 410 Gone
{
  "error": "export_expired",
  "expired_at": "2026-06-29T14:30:00Z",
  "message": "Export has expired. Please request a new export."
}'''),
        const SizedBox(height: ZapSpacing.lg),

        // ── Endpoint 4: GET history ─────────────────────────────────────
        const _SectionLabel('ENDPOINT 4 — EXPORT HISTORY'),
        const SizedBox(height: ZapSpacing.md),
        _codeCard(context, '''// GET /api/v1/data-export/history
// Auth: Bearer JWT required

// RESPONSE 200 OK
{
  "exports": [
    {
      "export_id": "exp_20260530_abc123",
      "status": "ready",             // "processing"|"ready"|"failed"|"expired"
      "format": "zip",
      "categories": ["profile", "contacts"],
      "file_size_bytes": 52428800,
      "requested_at": "2026-05-30T14:25:00Z",
      "expires_at": "2026-06-29T14:30:00Z",
      "is_expired": false
    }
  ],
  "next_allowed_at": "2026-06-29T14:25:00Z"
}'''),
        const SizedBox(height: ZapSpacing.lg),

        // ── Frontend integration points ─────────────────────────────────
        const _SectionLabel('FRONTEND INTEGRATION POINTS'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
          child: Column(children: [
            _integRow(const Color(0xFF8B5CF6), '_MockExportService.requestExport()',
                'POST /api/v1/data-export/request'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _integRow(const Color(0xFF3B82F6), '_MockExportService.checkStatus()',
                'GET /api/v1/data-export/status/{id}'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _integRow(const Color(0xFF10B981), '_MockExportService.getDownloadUrl()',
                'GET /api/v1/data-export/download/{id}'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _integRow(const Color(0xFFF59E0B), '_exportHistoryProvider initial value',
                'GET /api/v1/data-export/history'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
            text: 'Day 167 will add: download progress indicator, file integrity '
                'SHA-256 verification, and the actual file-save flow using '
                'path_provider + open_file. Day 168 adds the 30-day rate-limit '
                'enforcement UI and the "request denied" edge case.'),
      ],
    );
  }

  Widget _integRow(Color color, String mock, String real) => Padding(
    padding: const EdgeInsets.all(ZapSpacing.md),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(mock, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      const SizedBox(height: 3),
      Text('→ Replace with: $real',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
    ]),
  );

  Widget _codeCard(BuildContext context, String code) => GestureDetector(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard'),
            backgroundColor: Color(0xFF1A1A1A),
            duration: Duration(seconds: 1)));
    },
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          const Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(
            color: Color(0xFF86EFAC), fontSize: 10,
            fontFamily: 'monospace', height: 1.6)),
      ]),
    ),
  );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({required String label, required IconData icon,
    required Color color, required VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: onTap != null
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: onTap == null ? const Color(0xFF1A1A1A) : null,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: onTap != null
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                  offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: onTap != null ? Colors.white : const Color(0xFF4B5563), size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label, style: TextStyle(
              color: onTap != null ? Colors.white : const Color(0xFF4B5563),
              fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

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
      ]),
    );
