/// Day 333 — Platform Parity Audit: Execution
///
/// Section I (Days 331-340): reads Day 296's Android vs iOS parity matrix
/// (`day296_platform_parity_audit_screen.dart`) and builds a real execution
/// layer on top of it — per-row PASS/FAIL/PENDING marks with free-text
/// device notes, real local persistence via SharedPreferences (matching
/// this project's established non-Hive precedent, see Day 306's header),
/// and an auto-derived blockers list.
///
/// The 16 feature rows below restate Day 296's own real matrix content
/// (feature/platform notes/parity level) rather than re-deriving it, since
/// Day 296's row list is private to that screen's library. What's new
/// here is the EXECUTION layer: every row's actual mark defaults to and
/// stays PENDING — this environment has no physical Android or iOS
/// device, so this screen cannot honestly claim PASS or FAIL for any row
/// on its own. A human running this on real hardware can tap through and
/// record the real result; their marks persist locally.
///
/// Tag: 🟢 FRONTEND-ONLY · real local execution log · no device farm, no
/// fabricated PASS/FAIL marks.
///
/// Route: [AppRoutes.platformParityExecution] → `/day-333-platform-parity-execution`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6366F1);
const _kTabs = ['Matrix', 'Blockers', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day333_parity_execution_v1';

enum _ExecCategory { background, flagSecure, widgets, shortcuts, sos }

enum _ExecMark { pending, pass, fail }

class _ParityFeature {
  const _ParityFeature({
    required this.id,
    required this.category,
    required this.feature,
    required this.android,
    required this.ios,
    required this.dayRef,
  });

  final String id;
  final _ExecCategory category;
  final String feature;
  final String android;
  final String ios;
  final String dayRef;
}

// Restates Day 296's real 16-row matrix content (feature/android/ios/day)
// as the execution target — not re-invented data.
const _kFeatures = [
  _ParityFeature(id: 'bg_location_sos', category: _ExecCategory.background,
    feature: 'Background location during SOS',
    android: 'Foreground service + FGS notification',
    ios: 'UIBackgroundModes location + blue bar', dayRef: 'Day 21 / 76'),
  _ParityFeature(id: 'bg_audio_sos', category: _ExecCategory.background,
    feature: 'Background audio recording (SOS)',
    android: 'Microphone FGS type microphone',
    ios: 'Audio background mode + silent buffer', dayRef: 'Day 82'),
  _ParityFeature(id: 'bg_monitoring', category: _ExecCategory.background,
    feature: 'MONITORING mode (passive)',
    android: 'WorkManager + geofence callbacks',
    ios: 'Region monitoring + significant-change', dayRef: 'Day 21'),
  _ParityFeature(id: 'bg_watchdog', category: _ExecCategory.background,
    feature: 'Process watchdog / relaunch',
    android: 'AlarmManager + boot receiver',
    ios: 'BGAppRefreshTask (best effort)', dayRef: 'Day 24'),
  _ParityFeature(id: 'secure_alert_pending', category: _ExecCategory.flagSecure,
    feature: 'FLAG_SECURE on ALERT_PENDING',
    android: 'WindowManager.LayoutParams.FLAG_SECURE',
    ios: 'UITextField secure overlay + blur', dayRef: 'Day 71'),
  _ParityFeature(id: 'secure_sos_active', category: _ExecCategory.flagSecure,
    feature: 'Screen capture blocked (SOS_ACTIVE)',
    android: 'FLAG_SECURE on SOS screens',
    ios: 'isCaptured / screen shield API', dayRef: 'Day 76'),
  _ParityFeature(id: 'secure_vault', category: _ExecCategory.flagSecure,
    feature: 'Vault preview thumbnails',
    android: 'FLAG_SECURE on vault player',
    ios: 'Secure field overlay on preview', dayRef: 'Day 82 / 187'),
  _ParityFeature(id: 'secure_recents', category: _ExecCategory.flagSecure,
    feature: 'Recents / app switcher blur',
    android: 'setRecentsScreenshotEnabled(false)',
    ios: 'UIApplication.shared.isProtectedDataAvailable', dayRef: 'Day 187'),
  _ParityFeature(id: 'widget_sos', category: _ExecCategory.widgets,
    feature: 'Home widget — SOS quick trigger',
    android: 'Glance AppWidget 2x2', ios: 'WidgetKit SOS intent', dayRef: 'Day 256'),
  _ParityFeature(id: 'widget_score', category: _ExecCategory.widgets,
    feature: 'Home widget — protection score',
    android: 'Glance 2x1 score ring', ios: 'WidgetKit circular gauge', dayRef: 'Day 257'),
  _ParityFeature(id: 'widget_live_activity', category: _ExecCategory.widgets,
    feature: 'Live journey map widget',
    android: 'Not available (no Live Activity)',
    ios: 'Live Activity + Dynamic Island', dayRef: 'Day 241'),
  _ParityFeature(id: 'shortcut_siri', category: _ExecCategory.shortcuts,
    feature: 'Voice — Hey Siri trigger SOS',
    android: 'Google Assistant routine (beta)',
    ios: 'App Intents + Siri phrase', dayRef: 'Day 248'),
  _ParityFeature(id: 'shortcut_quick', category: _ExecCategory.shortcuts,
    feature: 'Quick Actions / long-press icon',
    android: 'manifest shortcuts.xml',
    ios: 'UIApplicationShortcutItem', dayRef: 'Day 248'),
  _ParityFeature(id: 'shortcut_tile', category: _ExecCategory.shortcuts,
    feature: 'Quick Settings tile (SOS)',
    android: 'TileService one-tap arm',
    ios: 'N/A — Control Center not extensible', dayRef: 'Day 23'),
  _ParityFeature(id: 'sos_haptic', category: _ExecCategory.sos,
    feature: 'SOS haptic countdown pattern',
    android: 'VibrationEffect waveform',
    ios: 'Core Haptics CHHapticPattern', dayRef: 'Day 247'),
  _ParityFeature(id: 'sos_offline', category: _ExecCategory.sos,
    feature: 'Offline SOS queue + SMS fallback',
    android: 'Dual-SIM SMS + WorkManager flush',
    ios: 'SMS compose + background URLSession', dayRef: 'Day 245'),
];

String _categoryLabel(_ExecCategory c) => switch (c) {
      _ExecCategory.background => 'Background',
      _ExecCategory.flagSecure => 'FLAG_SECURE',
      _ExecCategory.widgets => 'Widgets',
      _ExecCategory.shortcuts => 'Shortcuts',
      _ExecCategory.sos => 'SOS extras',
    };

Color _categoryColor(_ExecCategory c) => switch (c) {
      _ExecCategory.background => const Color(0xFF06B6D4),
      _ExecCategory.flagSecure => const Color(0xFFEF4444),
      _ExecCategory.widgets => const Color(0xFF8B5CF6),
      _ExecCategory.shortcuts => const Color(0xFFF59E0B),
      _ExecCategory.sos => const Color(0xFF10B981),
    };

String _markKey(_ExecMark m) => switch (m) {
      _ExecMark.pending => 'pending',
      _ExecMark.pass => 'pass',
      _ExecMark.fail => 'fail',
    };

_ExecMark _markFromKey(String? k) => switch (k) {
      'pass' => _ExecMark.pass,
      'fail' => _ExecMark.fail,
      _ => _ExecMark.pending,
    };

Color _markColor(_ExecMark m) => switch (m) {
      _ExecMark.pending => ZapColors.textMuted,
      _ExecMark.pass => ZapColors.safe,
      _ExecMark.fail => ZapColors.danger,
    };

class _ExecutionState {
  const _ExecutionState({
    required this.marks,
    required this.notes,
    required this.deviceLabel,
  });

  final Map<String, String> marks; // feature id -> mark key
  final Map<String, String> notes; // feature id -> device note
  final String deviceLabel;

  factory _ExecutionState.initial() => const _ExecutionState(
        marks: {}, notes: {}, deviceLabel: '',
      );

  factory _ExecutionState.fromJson(Map<String, dynamic> j) => _ExecutionState(
        marks: (j['marks'] as Map?)?.cast<String, String>() ?? {},
        notes: (j['notes'] as Map?)?.cast<String, String>() ?? {},
        deviceLabel: j['device_label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'marks': marks, 'notes': notes, 'device_label': deviceLabel,
      };

  _ExecutionState copyWith({
    Map<String, String>? marks,
    Map<String, String>? notes,
    String? deviceLabel,
  }) =>
      _ExecutionState(
        marks: marks ?? this.marks,
        notes: notes ?? this.notes,
        deviceLabel: deviceLabel ?? this.deviceLabel,
      );
}

// ── Persistence (real SharedPreferences, no Hive — Day 306 precedent) ─────────
class _ExecutionNotifier extends StateNotifier<_ExecutionState> {
  _ExecutionNotifier() : super(_ExecutionState.initial()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        state = _ExecutionState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Best-effort — an empty log is a safe fallback, not a fatal error.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
    } catch (_) {
      // Persistence failure shouldn't block the UI interaction.
    }
  }

  void setMark(String id, _ExecMark mark) {
    state = state.copyWith(marks: {...state.marks, id: _markKey(mark)});
    _persist();
  }

  void setNote(String id, String note) {
    state = state.copyWith(notes: {...state.notes, id: note});
    _persist();
  }

  void setDevice(String label) {
    state = state.copyWith(deviceLabel: label);
    _persist();
  }

  void reset() {
    state = _ExecutionState.initial();
    _persist();
  }
}

final _d333ExecutionProvider =
    StateNotifierProvider<_ExecutionNotifier, _ExecutionState>(
  (ref) => _ExecutionNotifier(),
);
final _d333TabProvider = StateProvider<int>((ref) => 0);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day333PlatformParityExecutionScreen extends ConsumerWidget {
  const Day333PlatformParityExecutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execState = ref.watch(_d333ExecutionProvider);
    final pass = execState.marks.values.where((v) => v == 'pass').length;
    final fail = execState.marks.values.where((v) => v == 'fail').length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.parity_exec_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  '$pass pass · $fail fail',
                  style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d333TabProvider),
            onSelect: (i) => ref.read(_d333TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d333TabProvider)) {
              0 => const _MatrixTab(),
              1 => const _BlockersTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Matrix ─────────────────────────────────────────────────────────────
class _MatrixTab extends ConsumerWidget {
  const _MatrixTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execState = ref.watch(_d333ExecutionProvider);
    final notifier = ref.read(_d333ExecutionProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'No physical Android or iOS device is available in this '
            'environment. Every row below stays PENDING until a real '
            'person runs it on real hardware and taps PASS/FAIL — marks '
            'persist locally on this device via SharedPreferences.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          onChanged: notifier.setDevice,
          controller: TextEditingController(text: execState.deviceLabel)
            ..selection = TextSelection.collapsed(offset: execState.deviceLabel.length),
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Executing device (e.g. Pixel 8 / iPhone 15)',
            filled: true,
            fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        ..._kFeatures.map((f) {
          final mark = _markFromKey(execState.marks[f.id]);
          final catColor = _categoryColor(f.category);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _markColor(mark).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_categoryLabel(f.category), style: TextStyle(
                        color: catColor, fontSize: 9, fontWeight: FontWeight.w800,
                      )),
                    ),
                    const Spacer(),
                    Text(f.dayRef, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(f.feature, style: const TextStyle(
                  color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                )),
                const SizedBox(height: 4),
                Text('Android: ${f.android}', style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10)),
                Text('iOS: ${f.ios}', style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MarkBtn(label: 'PASS', selected: mark == _ExecMark.pass, color: ZapColors.safe,
                      onTap: () => notifier.setMark(f.id, _ExecMark.pass)),
                    const SizedBox(width: 6),
                    _MarkBtn(label: 'FAIL', selected: mark == _ExecMark.fail, color: ZapColors.danger,
                      onTap: () => notifier.setMark(f.id, _ExecMark.fail)),
                    const SizedBox(width: 6),
                    _MarkBtn(label: 'PENDING', selected: mark == _ExecMark.pending, color: ZapColors.textMuted,
                      onTap: () => notifier.setMark(f.id, _ExecMark.pending)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (v) => notifier.setNote(f.id, v),
                  controller: TextEditingController(text: execState.notes[f.id] ?? '')
                    ..selection = TextSelection.collapsed(offset: (execState.notes[f.id] ?? '').length),
                  style: const TextStyle(color: ZapColors.textPrimary, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Device notes…',
                    hintStyle: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
                    isDense: true,
                    filled: true,
                    fillColor: ZapColors.bgElevated,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () {
            notifier.reset();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Execution log reset.')),
            );
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset execution log'),
        ),
      ],
    );
  }
}

class _MarkBtn extends StatelessWidget {
  const _MarkBtn({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : ZapColors.bgElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? color : ZapColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? color : ZapColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700,
        )),
      ),
    );
  }
}

// ── Tab 1: Blockers ───────────────────────────────────────────────────────────
class _BlockersTab extends ConsumerWidget {
  const _BlockersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execState = ref.watch(_d333ExecutionProvider);
    final blockers = _kFeatures.where((f) {
      final mark = _markFromKey(execState.marks[f.id]);
      return mark == _ExecMark.fail || mark == _ExecMark.pending;
    }).toList();
    final failCount = _kFeatures.where((f) => execState.marks[f.id] == 'fail').length;
    final pendingCount = _kFeatures.where((f) => (execState.marks[f.id] ?? 'pending') == 'pending').length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Launch blockers (auto-derived)', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Any row not marked PASS counts as a blocker — FAIL is a real '
          'regression, PENDING means "not yet run on real hardware".',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Fail', count: failCount, color: ZapColors.danger)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Pending', count: pendingCount, color: ZapColors.textMuted)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(
              label: 'Pass', count: _kFeatures.length - blockers.length, color: ZapColors.safe,
            )),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (blockers.isEmpty)
          const Text('No blockers — everything is marked PASS.',
              style: TextStyle(color: ZapColors.safe))
        else
          ...blockers.map((f) {
            final mark = _markFromKey(execState.marks[f.id]);
            return Container(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _markColor(mark).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(mark == _ExecMark.fail ? Icons.cancel_rounded : Icons.hourglass_empty_rounded,
                      color: _markColor(mark), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.feature, style: const TextStyle(
                          color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                        )),
                        if ((execState.notes[f.id] ?? '').isNotEmpty)
                          Text(execState.notes[f.id]!, style: const TextStyle(
                            color: ZapColors.textSecondary, fontSize: 10,
                          )),
                      ],
                    ),
                  ),
                  Text(_markKey(mark).toUpperCase(), style: TextStyle(
                    color: _markColor(mark), fontSize: 9, fontWeight: FontWeight.w900,
                  )),
                ],
              ),
            );
          }),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () {
            final buf = StringBuffer('ZapSafe Platform Parity — Execution Blockers\n');
            buf.writeln('Device: ${execState.deviceLabel.isEmpty ? '(not set)' : execState.deviceLabel}\n');
            for (final f in blockers) {
              final mark = _markFromKey(execState.marks[f.id]);
              buf.writeln('[${_markKey(mark).toUpperCase()}] ${f.feature} (${f.dayRef})');
              if ((execState.notes[f.id] ?? '').isNotEmpty) buf.writeln('  Note: ${execState.notes[f.id]}');
            }
            Clipboard.setData(ClipboardData(text: buf.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Blockers list copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy blockers list'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execState = ref.watch(_d333ExecutionProvider);
    final payload = {
      'endpoint': 'POST /api/v1/qa/platform-parity-execution/ (mock)',
      'features_total': _kFeatures.length,
      'pass': execState.marks.values.where((v) => v == 'pass').length,
      'fail': execState.marks.values.where((v) => v == 'fail').length,
      'pending': _kFeatures.length -
          execState.marks.values.where((v) => v == 'pass' || v == 'fail').length,
      'persistence': 'SharedPreferences (local, real, key: $_kPrefsKey)',
      'device_farm': false,
      'wire_note': 'Real execution log; no device farm integration exists.',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Platform parity — execution', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 3/10 · executes Day 296\'s matrix on real hardware '
          '(when available) instead of just previewing it.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('API contract (mock) + local persistence', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 296 Parity Matrix'),
              onPressed: () => context.push(AppRoutes.platformParityAudit),
            ),
            ActionChip(
              label: const Text('Day 331 Gate v2'),
              onPressed: () => context.push(AppRoutes.gonogoGateV2),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2)),
                ),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(
                  color: selected ? _kAccent : ZapColors.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
