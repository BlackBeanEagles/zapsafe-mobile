/// Day 296 — Cross-Platform Parity Audit
///
/// Section E (Days 281-300): Android vs iOS feature matrix covering background
/// services, FLAG_SECURE, home widgets, and Siri/shortcut integrations.
///
/// Tag: 🟢 FRONTEND-ONLY · parity checklist · no device farm integration.
///
/// Route: [AppRoutes.platformParityAudit] → `/platform-parity-audit`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kAndroid = Color(0xFF34A853);
const _kIos = Color(0xFF007AFF);
const _kTabs = ['Matrix', 'Gaps', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _ParityCategory { background, flagSecure, widgets, shortcuts, sos }

enum _ParityLevel { parity, partial, gap, androidOnly, iosOnly }

enum _AuditStatus { pass, warn, fail, unchecked }

class _ParityRow {
  const _ParityRow({
    required this.id,
    required this.category,
    required this.feature,
    required this.android,
    required this.ios,
    required this.level,
    required this.notes,
    required this.dayRef,
    this.route,
  });

  final String id;
  final _ParityCategory category;
  final String feature;
  final String android;
  final String ios;
  final _ParityLevel level;
  final String notes;
  final String dayRef;
  final String? route;
}

const _kParityRows = [
  _ParityRow(
    id: 'bg_location_sos',
    category: _ParityCategory.background,
    feature: 'Background location during SOS',
    android: 'Foreground service + FGS notification',
    ios: 'UIBackgroundModes location + blue bar',
    level: _ParityLevel.parity,
    notes: 'Both platforms keep GPS during active SOS only.',
    dayRef: 'Day 21 / 76',
    route: AppRoutes.backgroundEngine,
  ),
  _ParityRow(
    id: 'bg_audio_sos',
    category: _ParityCategory.background,
    feature: 'Background audio recording (SOS)',
    android: 'Microphone FGS type microphone',
    ios: 'Audio background mode + silent buffer',
    level: _ParityLevel.parity,
    notes: 'Evidence vault upload when session ends.',
    dayRef: 'Day 82',
  ),
  _ParityRow(
    id: 'bg_monitoring',
    category: _ParityCategory.background,
    feature: 'MONITORING mode (passive)',
    android: 'WorkManager + geofence callbacks',
    ios: 'Region monitoring + significant-change',
    level: _ParityLevel.partial,
    notes: 'iOS throttles more aggressively on low power.',
    dayRef: 'Day 21',
    route: AppRoutes.backgroundEngine,
  ),
  _ParityRow(
    id: 'bg_watchdog',
    category: _ParityCategory.background,
    feature: 'Process watchdog / relaunch',
    android: 'AlarmManager + boot receiver',
    ios: 'BGAppRefreshTask (best effort)',
    level: _ParityLevel.gap,
    notes: 'Android can restart service; iOS cannot guarantee relaunch.',
    dayRef: 'Day 24',
  ),
  _ParityRow(
    id: 'secure_alert_pending',
    category: _ParityCategory.flagSecure,
    feature: 'FLAG_SECURE on ALERT_PENDING',
    android: 'WindowManager.LayoutParams.FLAG_SECURE',
    ios: 'UITextField secure overlay + blur',
    level: _ParityLevel.parity,
    notes: 'LP27 blank-screen panic mode on both.',
    dayRef: 'Day 71',
  ),
  _ParityRow(
    id: 'secure_sos_active',
    category: _ParityCategory.flagSecure,
    feature: 'Screen capture blocked (SOS_ACTIVE)',
    android: 'FLAG_SECURE on SOS screens',
    ios: 'isCaptured / screen shield API',
    level: _ParityLevel.parity,
    notes: 'Screenshot blocked during live alert.',
    dayRef: 'Day 76',
  ),
  _ParityRow(
    id: 'secure_vault',
    category: _ParityCategory.flagSecure,
    feature: 'Vault preview thumbnails',
    android: 'FLAG_SECURE on vault player',
    ios: 'Secure field overlay on preview',
    level: _ParityLevel.partial,
    notes: 'iOS PiP preview needs extra QA on iOS 18.',
    dayRef: 'Day 82 / 187',
    route: AppRoutes.secureStorage,
  ),
  _ParityRow(
    id: 'secure_recents',
    category: _ParityCategory.flagSecure,
    feature: 'Recents / app switcher blur',
    android: 'setRecentsScreenshotEnabled(false)',
    ios: 'UIApplication.shared.isProtectedDataAvailable',
    level: _ParityLevel.partial,
    notes: 'OEM Android skins vary; Samsung tested.',
    dayRef: 'Day 187',
    route: AppRoutes.secureStorage,
  ),
  _ParityRow(
    id: 'widget_sos',
    category: _ParityCategory.widgets,
    feature: 'Home widget — SOS quick trigger',
    android: 'Glance AppWidget 2x2',
    ios: 'WidgetKit SOS intent',
    level: _ParityLevel.parity,
    notes: 'Both deep-link to SOS pre-arm state.',
    dayRef: 'Day 256',
    route: AppRoutes.homeWidgetSos,
  ),
  _ParityRow(
    id: 'widget_score',
    category: _ParityCategory.widgets,
    feature: 'Home widget — protection score',
    android: 'Glance 2x1 score ring',
    ios: 'WidgetKit circular gauge',
    level: _ParityLevel.parity,
    notes: 'Refresh cadence 15 min on both.',
    dayRef: 'Day 257',
    route: AppRoutes.homeWidgetScore,
  ),
  _ParityRow(
    id: 'widget_live_activity',
    category: _ParityCategory.widgets,
    feature: 'Live journey map widget',
    android: 'Not available (no Live Activity)',
    ios: 'Live Activity + Dynamic Island',
    level: _ParityLevel.iosOnly,
    notes: 'Android uses persistent notification instead.',
    dayRef: 'Day 241',
  ),
  _ParityRow(
    id: 'shortcut_siri',
    category: _ParityCategory.shortcuts,
    feature: 'Voice — Hey Siri trigger SOS',
    android: 'Google Assistant routine (beta)',
    ios: 'App Intents + Siri phrase',
    level: _ParityLevel.partial,
    notes: 'iOS mature; Android Assistant coverage uneven.',
    dayRef: 'Day 248',
    route: AppRoutes.siriShortcuts,
  ),
  _ParityRow(
    id: 'shortcut_quick',
    category: _ParityCategory.shortcuts,
    feature: 'Quick Actions / long-press icon',
    android: 'manifest shortcuts.xml',
    ios: 'UIApplicationShortcutItem',
    level: _ParityLevel.parity,
    notes: '3 shortcuts: SOS · Journey · Drill.',
    dayRef: 'Day 248',
    route: AppRoutes.siriShortcuts,
  ),
  _ParityRow(
    id: 'shortcut_tile',
    category: _ParityCategory.shortcuts,
    feature: 'Quick Settings tile (SOS)',
    android: 'TileService one-tap arm',
    ios: 'N/A — Control Center not extensible',
    level: _ParityLevel.androidOnly,
    notes: 'iOS users rely on widget + Siri.',
    dayRef: 'Day 23',
    route: AppRoutes.platformChannels,
  ),
  _ParityRow(
    id: 'sos_haptic',
    category: _ParityCategory.sos,
    feature: 'SOS haptic countdown pattern',
    android: 'VibrationEffect waveform',
    ios: 'Core Haptics CHHapticPattern',
    level: _ParityLevel.parity,
    notes: 'Day 247 patterns mapped 1:1.',
    dayRef: 'Day 247',
  ),
  _ParityRow(
    id: 'sos_offline',
    category: _ParityCategory.sos,
    feature: 'Offline SOS queue + SMS fallback',
    android: 'Dual-SIM SMS + WorkManager flush',
    ios: 'SMS compose + background URLSession',
    level: _ParityLevel.partial,
    notes: 'India dual-SIM path stronger on Android.',
    dayRef: 'Day 245',
  ),
];

String _categoryKey(_ParityCategory c) => switch (c) {
      _ParityCategory.background => 'background',
      _ParityCategory.flagSecure => 'flag_secure',
      _ParityCategory.widgets => 'widgets',
      _ParityCategory.shortcuts => 'shortcuts',
      _ParityCategory.sos => 'sos',
    };

String _categoryLabel(_ParityCategory c) => switch (c) {
      _ParityCategory.background => 'Background',
      _ParityCategory.flagSecure => 'FLAG_SECURE',
      _ParityCategory.widgets => 'Widgets',
      _ParityCategory.shortcuts => 'Shortcuts',
      _ParityCategory.sos => 'SOS extras',
    };

Color _categoryColor(_ParityCategory c) => switch (c) {
      _ParityCategory.background => const Color(0xFF06B6D4),
      _ParityCategory.flagSecure => const Color(0xFFEF4444),
      _ParityCategory.widgets => const Color(0xFF8B5CF6),
      _ParityCategory.shortcuts => const Color(0xFFF59E0B),
      _ParityCategory.sos => const Color(0xFF10B981),
    };

String _levelLabel(_ParityLevel l) => switch (l) {
      _ParityLevel.parity => 'Parity',
      _ParityLevel.partial => 'Partial',
      _ParityLevel.gap => 'Gap',
      _ParityLevel.androidOnly => 'Android only',
      _ParityLevel.iosOnly => 'iOS only',
    };

Color _levelColor(_ParityLevel l) => switch (l) {
      _ParityLevel.parity => ZapColors.safe,
      _ParityLevel.partial => ZapColors.warning,
      _ParityLevel.gap => ZapColors.danger,
      _ParityLevel.androidOnly => _kAndroid,
      _ParityLevel.iosOnly => _kIos,
    };

_AuditStatus _auditFromKey(String? key) => switch (key) {
      'pass' => _AuditStatus.pass,
      'warn' => _AuditStatus.warn,
      'fail' => _AuditStatus.fail,
      _ => _AuditStatus.unchecked,
    };

String _auditKey(_AuditStatus s) => switch (s) {
      _AuditStatus.pass => 'pass',
      _AuditStatus.warn => 'warn',
      _AuditStatus.fail => 'fail',
      _AuditStatus.unchecked => 'unchecked',
    };

Color _auditColor(_AuditStatus s) => switch (s) {
      _AuditStatus.pass => ZapColors.safe,
      _AuditStatus.warn => ZapColors.warning,
      _AuditStatus.fail => ZapColors.danger,
      _AuditStatus.unchecked => ZapColors.textMuted,
    };

_AuditStatus _defaultAudit(_ParityLevel level) => switch (level) {
      _ParityLevel.parity => _AuditStatus.pass,
      _ParityLevel.partial => _AuditStatus.warn,
      _ParityLevel.gap => _AuditStatus.fail,
      _ParityLevel.androidOnly => _AuditStatus.warn,
      _ParityLevel.iosOnly => _AuditStatus.warn,
    };

_AuditStatus _nextAuditStatus(_AuditStatus current) => switch (current) {
      _AuditStatus.unchecked => _AuditStatus.pass,
      _AuditStatus.pass => _AuditStatus.warn,
      _AuditStatus.warn => _AuditStatus.fail,
      _AuditStatus.fail => _AuditStatus.unchecked,
    };

bool _isGap(_ParityLevel level) => level != _ParityLevel.parity;

Map<String, dynamic> _parityPayload(Map<String, String> audits) {
  final pass = audits.values.where((v) => v == 'pass').length;
  final gaps = _kParityRows.where((r) => _isGap(r.level)).length;
  return {
    'endpoint': 'GET /api/v1/qa/platform-parity/',
    'features_total': _kParityRows.length,
    'audit_pass': pass,
    'known_gaps': gaps,
    'categories': _ParityCategory.values.map(_categoryKey).toList(),
    'wire_note': 'Android vs iOS matrix · manual audit cycle',
  };
}

String _buildParityReport(Map<String, String> audits) {
  final buf = StringBuffer('ZapSafe Cross-Platform Parity Audit\n\n');
  for (final row in _kParityRows) {
    final audit = _auditFromKey(audits[row.id]);
    buf.writeln(
      '[${_auditKey(audit).toUpperCase()}] ${row.feature} '
      '(${_levelLabel(row.level)})',
    );
    buf.writeln('  Android: ${row.android}');
    buf.writeln('  iOS: ${row.ios}');
    buf.writeln('  Notes: ${row.notes}');
    buf.writeln();
  }
  return buf.toString();
}

String _buildCsv(Map<String, String> audits) {
  final buf =
      StringBuffer('feature,category,android,ios,level,audit,day_ref\n');
  for (final row in _kParityRows) {
    final audit = _auditFromKey(audits[row.id]);
    buf.writeln(
      '"${row.feature}","${_categoryLabel(row.category)}",'
      '"${row.android}","${row.ios}","${_levelLabel(row.level)}",'
      '"${_auditKey(audit)}","${row.dayRef}"',
    );
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d296TabProvider = StateProvider<int>((ref) => 0);
final _d296CategoryFilterProvider = StateProvider<String>((ref) => 'all');
final _d296GapsOnlyProvider = StateProvider<bool>((ref) => false);
final _d296AuditProvider = StateProvider<Map<String, String>>((ref) {
  return {
    for (final r in _kParityRows) r.id: _auditKey(_defaultAudit(r.level)),
  };
});

List<_ParityRow> _filteredRows({
  required String category,
  required bool gapsOnly,
}) {
  return _kParityRows.where((r) {
    if (gapsOnly && !_isGap(r.level)) return false;
    if (category != 'all' && _categoryKey(r.category) != category) {
      return false;
    }
    return true;
  }).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day296PlatformParityAuditScreen extends ConsumerWidget {
  const Day296PlatformParityAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(_d296AuditProvider);
    final pass = audits.values.where((v) => v == 'pass').length;
    final gaps = _kParityRows.where((r) => _isGap(r.level)).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 296 · Platform Parity'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$pass/${_kParityRows.length} pass',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d296TabProvider),
            onSelect: (i) => ref.read(_d296TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d296TabProvider)) {
              0 => const _MatrixTab(),
              1 => const _GapsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        color: ZapColors.bgCard,
        child: Text(
          '$gaps known parity gaps · tap audit chip to cycle pass/warn/fail',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
      ),
    );
  }
}

// ── Tab 0: Matrix ─────────────────────────────────────────────────────────────
class _MatrixTab extends ConsumerWidget {
  const _MatrixTab();

  void _cycleAudit(WidgetRef ref, String id) {
    final current = _auditFromKey(ref.read(_d296AuditProvider)[id]);
    ref.read(_d296AuditProvider.notifier).state = {
      ...ref.read(_d296AuditProvider),
      id: _auditKey(_nextAuditStatus(current)),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(_d296CategoryFilterProvider);
    final gapsOnly = ref.watch(_d296GapsOnlyProvider);
    final audits = ref.watch(_d296AuditProvider);
    final rows = _filteredRows(category: category, gapsOnly: gapsOnly);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Android vs iOS matrix',
          subtitle: 'Background · FLAG_SECURE · widgets · shortcuts',
        ),
        const Row(
          children: [
            Icon(Icons.android_rounded, color: _kAndroid, size: 18),
            SizedBox(width: ZapSpacing.xs),
            Text('Android', style: TextStyle(fontSize: 10, color: _kAndroid)),
            Spacer(),
            Icon(Icons.apple_rounded, color: _kIos, size: 18),
            SizedBox(width: ZapSpacing.xs),
            Text('iOS', style: TextStyle(fontSize: 10, color: _kIos)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Show gaps only',
            style: TextStyle(fontSize: 12, color: ZapColors.textPrimary),
          ),
          value: gapsOnly,
          activeColor: _kAccent,
          onChanged: (v) => ref.read(_d296GapsOnlyProvider.notifier).state = v,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              selected: category == 'all',
              onTap: () =>
                  ref.read(_d296CategoryFilterProvider.notifier).state = 'all',
            ),
            ..._ParityCategory.values.map(
              (c) => _FilterChip(
                label: _categoryLabel(c),
                selected: category == _categoryKey(c),
                color: _categoryColor(c),
                onTap: () => ref
                    .read(_d296CategoryFilterProvider.notifier)
                    .state = _categoryKey(c),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        ...rows.map((row) {
          final audit = _auditFromKey(audits[row.id]);
          final catColor = _categoryColor(row.category);
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: catColor.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _categoryLabel(row.category),
                          style: TextStyle(
                            color: catColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _levelColor(row.level).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _levelLabel(row.level),
                          style: TextStyle(
                            color: _levelColor(row.level),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _cycleAudit(ref, row.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _auditColor(audit).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _auditColor(audit).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _auditKey(audit).toUpperCase(),
                            style: TextStyle(
                              color: _auditColor(audit),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    row.feature,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.android_rounded,
                          color: _kAndroid, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          row.android,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.apple_rounded, color: _kIos, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          row.ios,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 10,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${row.dayRef} · ${row.notes}',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                  if (row.route != null) ...[
                    const SizedBox(height: 6),
                    ActionChip(
                      label: Text('Open ${row.dayRef}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(row.route!),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Tab 1: Gaps ───────────────────────────────────────────────────────────────
class _GapsTab extends ConsumerWidget {
  const _GapsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(_d296AuditProvider);
    final gapRows = _kParityRows.where((r) => _isGap(r.level)).toList();

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Parity gaps & remediation',
          subtitle: 'Non-parity features · prioritized for v9.2',
        ),
        if (gapRows.isEmpty)
          const Text(
            'No gaps — full parity achieved.',
            style: TextStyle(color: ZapColors.safe),
          )
        else
          ...gapRows.map((row) {
            final audit = _auditFromKey(audits[row.id]);
            return Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: _levelColor(row.level).withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _levelColor(row.level),
                        size: 18,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          row.feature,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        _auditKey(audit).toUpperCase(),
                        style: TextStyle(
                          color: _auditColor(audit),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _levelLabel(row.level),
                    style: TextStyle(
                      color: _levelColor(row.level),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    row.notes,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildParityReport(audits)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Parity report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy parity report'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildCsv(audits)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV exported.')),
            );
          },
          icon: const Icon(Icons.table_chart_rounded, size: 16),
          label: const Text('Export CSV'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _parityPayload(ref.watch(_d296AuditProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Platform parity audit',
          subtitle:
              'Pre-launch Android vs iOS checklist · Day 295 Phase 2 Week 8.',
        ),
        const _PolicyRow(
          icon: Icons.layers_rounded,
          title: 'Background services',
          subtitle: 'FGS · location · audio · MONITORING throttle differences.',
        ),
        const _PolicyRow(
          icon: Icons.security_rounded,
          title: 'FLAG_SECURE',
          subtitle: 'SOS screens · vault · recents blur · LP27 panic mode.',
        ),
        const _PolicyRow(
          icon: Icons.widgets_rounded,
          title: 'Widgets',
          subtitle:
              'Glance vs WidgetKit · Live Activity iOS-only gap documented.',
        ),
        const _PolicyRow(
          icon: Icons.shortcut_rounded,
          title: 'Shortcuts',
          subtitle: 'Siri App Intents · Quick Settings tile Android-only.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Parity spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 23 Channels'),
              onPressed: () => context.push(AppRoutes.platformChannels),
            ),
            ActionChip(
              label: const Text('Day 248 Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 256 SOS Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetSos),
            ),
            ActionChip(
              label: const Text('Day 257 Score Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetScore),
            ),
            ActionChip(
              label: const Text('Day 295 Roadmap'),
              onPressed: () => context.push(AppRoutes.phase2Roadmap),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _kAccent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: selected ? color : ZapColors.textSecondary,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
