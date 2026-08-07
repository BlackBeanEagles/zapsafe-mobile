/// Day 334 — Battery & Thermal Soak: Production Log
///
/// Section I (Days 331-340): reads Day 297's soak log template
/// (`day297_battery_soak_log_screen.dart`) and replaces its accelerated
/// timer simulation with a real, manually-entered production log.
///
/// Day 297 deliberately simulated an 8-hour soak with a 120x accelerated
/// timer and formula-generated battery/thermal numbers (honestly labelled
/// "mock" in its own header). This screen does none of that: it is a
/// plain form + list. A person actually running the 8-hour MONITORING
/// soak on a real device types in what they observe — start %, end %,
/// drain rate, thermal throttling yes/no, free-text notes — and each
/// entry is persisted for real via SharedPreferences (no Hive, matching
/// this project's established precedent). The log starts empty and stays
/// empty until a human fills it in; nothing here invents an 8-hour run
/// that never happened.
///
/// Tag: 🟢 FRONTEND-ONLY · real empty log, real local persistence · no
/// fabricated soak data, no device telemetry API.
///
/// Route: [AppRoutes.batterySoakProduction] → `/day-334-battery-soak-production`
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
const _kAccent = Color(0xFFF97316);
const _kTabs = ['Log entry', 'Entries', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day334_battery_soak_production_v1';
const _kMaxDrainGatePct = 25;

class _SoakEntry {
  const _SoakEntry({
    required this.id,
    required this.recordedAt,
    required this.deviceLabel,
    required this.elapsedHours,
    required this.batteryPct,
    required this.thermalThrottled,
    required this.notes,
  });

  final String id;
  final DateTime recordedAt;
  final String deviceLabel;
  final double elapsedHours;
  final int batteryPct;
  final bool thermalThrottled;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recorded_at': recordedAt.toIso8601String(),
        'device_label': deviceLabel,
        'elapsed_hours': elapsedHours,
        'battery_pct': batteryPct,
        'thermal_throttled': thermalThrottled,
        'notes': notes,
      };

  factory _SoakEntry.fromJson(Map<String, dynamic> j) => _SoakEntry(
        id: j['id'] as String,
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        deviceLabel: j['device_label'] as String? ?? '',
        elapsedHours: (j['elapsed_hours'] as num?)?.toDouble() ?? 0,
        batteryPct: (j['battery_pct'] as num?)?.toInt() ?? 0,
        thermalThrottled: j['thermal_throttled'] as bool? ?? false,
        notes: j['notes'] as String? ?? '',
      );
}

class _SoakLogNotifier extends StateNotifier<List<_SoakEntry>> {
  _SoakLogNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPrefsKey);
      if (raw != null) {
        state = raw
            .map((s) => _SoakEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Best-effort load — an empty log is a safe fallback.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kPrefsKey,
        state.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {
      // Non-fatal — the in-memory state is still correct for this session.
    }
  }

  void add(_SoakEntry entry) {
    state = [...state, entry]
      ..sort((a, b) => a.elapsedHours.compareTo(b.elapsedHours));
    _persist();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final _d334LogProvider = StateNotifierProvider<_SoakLogNotifier, List<_SoakEntry>>(
  (ref) => _SoakLogNotifier(),
);
final _d334TabProvider = StateProvider<int>((ref) => 0);

({int? drain, bool anyThrottle, double? hours}) _computeSummary(List<_SoakEntry> entries) {
  if (entries.length < 2) return (drain: null, anyThrottle: false, hours: null);
  final first = entries.first;
  final last = entries.last;
  return (
    drain: first.batteryPct - last.batteryPct,
    anyThrottle: entries.any((e) => e.thermalThrottled),
    hours: last.elapsedHours - first.elapsedHours,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day334BatterySoakProductionScreen extends ConsumerWidget {
  const Day334BatterySoakProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d334LogProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.soak_prod_title'.tr()),
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
                child: Text('${entries.length} entries', style: const TextStyle(
                  color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900,
                )),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d334TabProvider),
            onSelect: (i) => ref.read(_d334TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d334TabProvider)) {
              0 => const _EntryFormTab(),
              1 => const _EntriesTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Log entry form ──────────────────────────────────────────────────────
class _EntryFormTab extends ConsumerStatefulWidget {
  const _EntryFormTab();

  @override
  ConsumerState<_EntryFormTab> createState() => _EntryFormTabState();
}

class _EntryFormTabState extends ConsumerState<_EntryFormTab> {
  final _deviceController = TextEditingController();
  final _hoursController = TextEditingController();
  final _batteryController = TextEditingController();
  final _notesController = TextEditingController();
  bool _throttled = false;

  @override
  void dispose() {
    _deviceController.dispose();
    _hoursController.dispose();
    _batteryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = double.tryParse(_hoursController.text);
    final battery = int.tryParse(_batteryController.text);
    if (hours == null || battery == null || _deviceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter device, elapsed hours, and battery %.')),
      );
      return;
    }
    ref.read(_d334LogProvider.notifier).add(_SoakEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          recordedAt: DateTime.now(),
          deviceLabel: _deviceController.text.trim(),
          elapsedHours: hours,
          batteryPct: battery.clamp(0, 100),
          thermalThrottled: _throttled,
          notes: _notesController.text.trim(),
        ));
    _hoursController.clear();
    _batteryController.clear();
    _notesController.clear();
    setState(() => _throttled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checkpoint logged.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text(
            'Real form, no simulation. Run the actual 8-hour MONITORING '
            'soak on a real device (screen off, pocket carry) and log '
            'what you actually observe hour by hour — nothing here is '
            'auto-generated.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        TextField(
          controller: _deviceController,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Device (e.g. Pixel 8 · Android 14)',
            filled: true, fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Elapsed hours',
                  filled: true, fillColor: ZapColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: TextField(
                controller: _batteryController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Battery %',
                  filled: true, fillColor: ZapColors.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Thermal throttling observed?',
              style: TextStyle(color: ZapColors.textPrimary, fontSize: 12)),
          value: _throttled,
          activeColor: ZapColors.danger,
          onChanged: (v) => setState(() => _throttled = v),
        ),
        TextField(
          controller: _notesController,
          maxLines: 2,
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Notes (screen state, app foreground/background, etc.)',
            filled: true, fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Log checkpoint'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Entries ────────────────────────────────────────────────────────────
class _EntriesTab extends ConsumerWidget {
  const _EntriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d334LogProvider);
    final summary = _computeSummary(entries);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Text(
              'No checkpoints logged yet. This soak has not been run in '
              'this environment — use the Log entry tab once you have a '
              'real device running the 8-hour MONITORING soak.',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          )
        else ...[
          if (summary.drain != null)
            Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              margin: const EdgeInsets.only(bottom: ZapSpacing.md),
              decoration: BoxDecoration(
                color: (summary.drain! <= _kMaxDrainGatePct && !summary.anyThrottle)
                    ? ZapColors.safe.withOpacity(0.12)
                    : ZapColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (summary.drain! <= _kMaxDrainGatePct && !summary.anyThrottle)
                      ? ZapColors.safe.withOpacity(0.4)
                      : ZapColors.warning.withOpacity(0.4),
                ),
              ),
              child: Text(
                'Drain across logged range: ${summary.drain}% over '
                '${summary.hours?.toStringAsFixed(1)}h (gate ≤ $_kMaxDrainGatePct%)'
                '${summary.anyThrottle ? ' · thermal throttle observed' : ''}',
                style: TextStyle(
                  color: (summary.drain! <= _kMaxDrainGatePct && !summary.anyThrottle)
                      ? ZapColors.safe : ZapColors.warning,
                  fontWeight: FontWeight.w700, fontSize: 12,
                ),
              ),
            ),
          ...entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (e.thermalThrottled ? ZapColors.danger : ZapColors.border),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('T+${e.elapsedHours}h · ${e.batteryPct}% · ${e.deviceLabel}',
                              style: const TextStyle(
                                color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12,
                              )),
                          Text('Logged ${e.recordedAt.toIso8601String()}',
                              style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
                          if (e.notes.isNotEmpty)
                            Text(e.notes, style: const TextStyle(
                              color: ZapColors.textSecondary, fontSize: 10, height: 1.3,
                            )),
                          if (e.thermalThrottled)
                            const Text('THROTTLED', style: TextStyle(
                              color: ZapColors.danger, fontSize: 9, fontWeight: FontWeight.w800,
                            )),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      onPressed: () => ref.read(_d334LogProvider.notifier).remove(e.id),
                    ),
                  ],
                ),
              )),
        ],
        const SizedBox(height: ZapSpacing.md),
        if (entries.isNotEmpty) ...[
          FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer('ZapSafe Battery Soak Production Log\n\n');
              for (final e in entries) {
                buf.writeln('T+${e.elapsedHours}h · ${e.batteryPct}% · ${e.deviceLabel} · '
                    '${e.thermalThrottled ? 'THROTTLED' : 'normal'}');
                if (e.notes.isNotEmpty) buf.writeln('  ${e.notes}');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy log'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d334LogProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Clear all entries'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d334LogProvider);
    final payload = {
      'endpoint': 'POST /api/v1/qa/battery-soak-log/ (mock, matches Day 297 contract)',
      'mode': 'MONITORING',
      'entries_logged': entries.length,
      'persistence': 'SharedPreferences (local, real, key: $_kPrefsKey)',
      'max_drain_gate_pct': _kMaxDrainGatePct,
      'simulation': false,
      'wire_note': 'Production log — replaces Day 297\'s accelerated-timer '
          'simulation with real manual entries.',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Battery soak — production log', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 4/10 · replaces Day 297\'s simulated 8-hour timer '
          'with a real, empty, ready-to-fill log for an actual device run.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('API contract + local persistence', style: TextStyle(
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
              label: const Text('Day 297 Soak Template'),
              onPressed: () => context.push(AppRoutes.batterySoakLog),
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
