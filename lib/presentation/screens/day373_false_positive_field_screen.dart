/// Day 373 — False Positive Field Analysis
///
/// Section N (Days 371-380, Scale & Stabilize): a user-reported false
/// positive categorization tool.
///
/// **No real users exist yet, so this starts genuinely empty.** There is
/// no real launch (see Day 361's war room, Day 366's live SOS dashboard),
/// so there are no real field reports of the DCS model triggering a
/// false alarm. Rather than fabricating sample reports, this screen ships
/// as a real, working, currently-empty log — add a report, pick a
/// category (loud noise / phone drop / pocket muffled / other), pick a
/// trigger source (scream / motion / scene / fusion — the real
/// `model_registry.dart` slots), and it persists via SharedPreferences,
/// same established pattern as Day 369's support triage board.
///
/// Read Day 329 first (`day329_false_positive_tuning_production_screen.dart`)
/// — the real, already-wired DCS sensitivity slider
/// (`PATCH /api/v1/alert-thresholds/<uuid>/`, `min_confidence`). This
/// screen does not duplicate that slider or call that endpoint; it is
/// upstream of it. A real aggregate FP rate computed from real field
/// reports here is what would eventually justify a real
/// `min_confidence` adjustment on Day 329's screen — that feedback loop
/// does not exist yet because there is no real field data yet.
///
/// Tag: 🟢 FRONTEND-ONLY · real, genuinely empty categorization tool ·
/// links to Day 329 as the downstream consumer of a real FP rate.
///
/// Route: [AppRoutes.falsePositiveField] → `/day-373-false-positive-field`
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
const _kAccent = ZapColors.warning;
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day373_fp_reports_v1';

// Real model_registry.dart slots — not invented.
const _kTriggerSources = ['scream', 'motion', 'scene', 'fusion', 'aggressive_speech', 'unknown'];
const _kCategories = ['Loud ambient noise', 'Phone drop / impact', 'Pocket / muffled false trigger', 'App bug / UI misfire', 'Other'];

class _FpReport {
  const _FpReport({required this.id, required this.category, required this.source, required this.notes, required this.createdAtIso});

  final String id;
  final String category;
  final String source;
  final String notes;
  final String createdAtIso;

  Map<String, dynamic> toJson() => {'id': id, 'category': category, 'source': source, 'notes': notes, 'created_at': createdAtIso};

  static _FpReport fromJson(Map<String, dynamic> j) => _FpReport(
        id: j['id'] as String,
        category: j['category'] as String,
        source: j['source'] as String,
        notes: j['notes'] as String? ?? '',
        createdAtIso: j['created_at'] as String,
      );
}

class _FpReportsNotifier extends StateNotifier<List<_FpReport>> {
  _FpReportsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      state = list.map(_FpReport.fromJson).toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(state.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> add(String category, String source, String notes) async {
    final report = _FpReport(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: category,
      source: source,
      notes: notes,
      createdAtIso: DateTime.now().toIso8601String(),
    );
    state = [report, ...state];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }
}

final _d373ReportsProvider = StateNotifierProvider<_FpReportsNotifier, List<_FpReport>>((ref) => _FpReportsNotifier());

Map<String, dynamic> _payload(List<_FpReport> reports) {
  final byCategory = <String, int>{};
  final bySource = <String, int>{};
  for (final r in reports) {
    byCategory[r.category] = (byCategory[r.category] ?? 0) + 1;
    bySource[r.source] = (bySource[r.source] ?? 0) + 1;
  }
  return {
    'total_reports': reports.length,
    'is_real_field_data': reports.isNotEmpty,
    'by_category': byCategory,
    'by_trigger_source': bySource,
    'feeds_into': 'day329_false_positive_tuning_production_screen.dart (min_confidence)',
    'wire_note': 'Real, empty-until-real-users categorization log. No real '
        'launch exists yet, so this list starts genuinely empty.',
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day373FalsePositiveFieldScreen extends ConsumerStatefulWidget {
  const Day373FalsePositiveFieldScreen({super.key});

  @override
  ConsumerState<Day373FalsePositiveFieldScreen> createState() => _Day373FalsePositiveFieldScreenState();
}

class _Day373FalsePositiveFieldScreenState extends ConsumerState<Day373FalsePositiveFieldScreen> {
  String _category = _kCategories.first;
  String _source = _kTriggerSources.first;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(_d373ReportsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.fp_field_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.report_problem_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'No real users exist yet, so this list starts genuinely '
                    'empty — nothing fabricated. A real aggregate FP rate '
                    'computed here is what would eventually justify a real '
                    'sensitivity adjustment on Day 329\'s screen.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('Log a field report', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _kCategories.map((c) => ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 11)),
                      selected: _category == c,
                      selectedColor: _kAccent.withOpacity(0.25),
                      onSelected: (_) => setState(() => _category = c),
                    )).toList()),
                const SizedBox(height: ZapSpacing.md),
                const Text('Trigger source (DCS model)', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _kTriggerSources.map((s) => ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      selected: _source == s,
                      selectedColor: ZapColors.info.withOpacity(0.25),
                      onSelected: (_) => setState(() => _source = s),
                    )).toList()),
                const SizedBox(height: ZapSpacing.md),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Notes (optional)',
                    hintStyle: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
                    filled: true, fillColor: ZapColors.bgSurface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(_d373ReportsProvider.notifier).add(_category, _source, _notesController.text);
                    _notesController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report logged.')));
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add report'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 44)),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Row(
            children: [
              Text('Reports (${reports.length})', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (reports.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.xl),
              decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, color: ZapColors.textMuted, size: 32),
                  SizedBox(height: 8),
                  Text('No field reports yet — correct and honest, since there is no real launch.', textAlign: TextAlign.center, style: TextStyle(color: ZapColors.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            for (final r in reports) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.category, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('source: ${r.source} · ${r.createdAtIso.split("T").first}', style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
                          if (r.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.notes, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ZapColors.textMuted),
                      onPressed: () => ref.read(_d373ReportsProvider.notifier).remove(r.id),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_payload(reports)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 329 DCS Sensitivity'), onPressed: () => context.push(AppRoutes.falsePositiveTuningProd)),
          ]),
        ],
      ),
    );
  }
}
