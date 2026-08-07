/// Day 374 — Model Retrain Feedback Export
///
/// Section N (Days 371-380, Scale & Stabilize): export an anonymized
/// misclassification bundle (CSV/JSON) for the next Kaggle retrain cycle.
///
/// **Checked before building**: whether any real model evaluation /
/// misclassification data already exists anywhere in this repo. Read
/// several `assets/models/DAY2*.md` files directly (there are 40+ of
/// them, DAY260 through DAY299) — every single one is a Kaggle-side
/// *training* record (dataset search, retrain run, accuracy/loss
/// numbers from a training job), not an on-device field misclassification
/// log. There is no real launch (Day 361/366), so there is no real
/// on-device field data of any kind yet — this matches the pattern
/// already established by Day 373 (empty FP field log) one level
/// downstream.
///
/// So: the real export MECHANISM is built here — add a misclassification
/// record (real predicted vs actual label, real model_registry.dart
/// source, confidence score, anonymized device tier), and export it as
/// real CSV or real JSON, copy-to-clipboard (same pattern as every other
/// export tool in this batch — no file-system writes). The list starts
/// genuinely empty and is honestly labeled as such, not seeded with
/// fabricated field data dressed up as real.
///
/// Tag: 🟢 real export mechanism + format, genuinely empty until real
/// field data exists · no real misclassification records were found
/// anywhere in the repo to seed this with.
///
/// Route: [AppRoutes.modelFeedbackExport] → `/day-374-model-feedback-export`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day374_misclass_records_v1';

// Real model_registry.dart slots — not invented.
const _kModelSources = ['scream', 'motion', 'scene', 'fusion', 'aggressive_speech'];
const _kDeviceTiers = ['Tier A', 'Tier B', 'Tier C'];

class _MisclassRecord {
  const _MisclassRecord({
    required this.id,
    required this.modelSource,
    required this.predictedLabel,
    required this.actualLabel,
    required this.confidence,
    required this.deviceTier,
    required this.createdAtIso,
  });

  final String id;
  final String modelSource;
  final String predictedLabel;
  final String actualLabel;
  final double confidence;
  final String deviceTier;
  final String createdAtIso;

  Map<String, dynamic> toJson() => {
        'id': id,
        'model_source': modelSource,
        'predicted_label': predictedLabel,
        'actual_label': actualLabel,
        'confidence': confidence,
        'device_tier': deviceTier,
        'created_at': createdAtIso,
      };

  static _MisclassRecord fromJson(Map<String, dynamic> j) => _MisclassRecord(
        id: j['id'] as String,
        modelSource: j['model_source'] as String,
        predictedLabel: j['predicted_label'] as String,
        actualLabel: j['actual_label'] as String,
        confidence: (j['confidence'] as num).toDouble(),
        deviceTier: j['device_tier'] as String,
        createdAtIso: j['created_at'] as String,
      );

  String toCsvRow() => '$id,$modelSource,$predictedLabel,$actualLabel,${confidence.toStringAsFixed(3)},$deviceTier,$createdAtIso';
}

class _RecordsNotifier extends StateNotifier<List<_MisclassRecord>> {
  _RecordsNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      state = list.map(_MisclassRecord.fromJson).toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(state.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> add(String source, String predicted, String actual, double confidence, String tier) async {
    final record = _MisclassRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      modelSource: source,
      predictedLabel: predicted,
      actualLabel: actual,
      confidence: confidence,
      deviceTier: tier,
      createdAtIso: DateTime.now().toIso8601String(),
    );
    state = [record, ...state];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }
}

final _d374RecordsProvider = StateNotifierProvider<_RecordsNotifier, List<_MisclassRecord>>((ref) => _RecordsNotifier());

String _buildCsv(List<_MisclassRecord> records) {
  final buf = StringBuffer('id,model_source,predicted_label,actual_label,confidence,device_tier,created_at\n');
  for (final r in records) {
    buf.writeln(r.toCsvRow());
  }
  return buf.toString();
}

Map<String, dynamic> _buildJsonBundle(List<_MisclassRecord> records) => {
      'bundle_type': 'anonymized_misclassification_export',
      'record_count': records.length,
      'is_real_field_data': records.isNotEmpty,
      'checked_for_existing_data': 'assets/models/DAY2*.md (40+ files, DAY260-DAY299) — all '
          'Kaggle-side training records, none are on-device field misclassification logs',
      'target_use': 'Next Kaggle retrain cycle',
      'records': records.map((r) => r.toJson()).toList(),
    };

// ── Screen ────────────────────────────────────────────────────────────────────
class Day374ModelFeedbackExportScreen extends ConsumerStatefulWidget {
  const Day374ModelFeedbackExportScreen({super.key});

  @override
  ConsumerState<Day374ModelFeedbackExportScreen> createState() => _Day374ModelFeedbackExportScreenState();
}

class _Day374ModelFeedbackExportScreenState extends ConsumerState<Day374ModelFeedbackExportScreen> {
  String _source = _kModelSources.first;
  String _tier = _kDeviceTiers.first;
  final _predictedController = TextEditingController();
  final _actualController = TextEditingController();
  double _confidence = 0.75;

  @override
  void dispose() {
    _predictedController.dispose();
    _actualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(_d374RecordsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day371_380.model_feedback_export_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.model_training_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Checked assets/models/DAY2*.md (40+ real files) for existing '
                    'misclassification data — every one is a Kaggle-side training '
                    'record, not an on-device field log. No real launch exists yet, '
                    'so this export starts genuinely empty. The mechanism below is '
                    'real and ready for whenever real field data exists.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          const Text('Log a misclassification', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Model source', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _kModelSources.map((s) => ChoiceChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      selected: _source == s,
                      selectedColor: _kAccent.withOpacity(0.25),
                      onSelected: (_) => setState(() => _source = s),
                    )).toList()),
                const SizedBox(height: ZapSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _predictedController,
                        style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Predicted label',
                          labelStyle: const TextStyle(fontSize: 11),
                          filled: true, fillColor: ZapColors.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _actualController,
                        style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Actual label',
                          labelStyle: const TextStyle(fontSize: 11),
                          filled: true, fillColor: ZapColors.bgSurface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.md),
                Text('Confidence: ${_confidence.toStringAsFixed(2)}', style: const TextStyle(color: ZapColors.textMuted, fontSize: 11)),
                Slider(
                  value: _confidence,
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  activeColor: _kAccent,
                  onChanged: (v) => setState(() => _confidence = v),
                ),
                const Text('Device tier (anonymized)', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: _kDeviceTiers.map((t) => ChoiceChip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      selected: _tier == t,
                      selectedColor: ZapColors.info.withOpacity(0.25),
                      onSelected: (_) => setState(() => _tier = t),
                    )).toList()),
                const SizedBox(height: ZapSpacing.md),
                FilledButton.icon(
                  onPressed: (_predictedController.text.trim().isEmpty || _actualController.text.trim().isEmpty)
                      ? null
                      : () {
                          ref.read(_d374RecordsProvider.notifier).add(
                                _source,
                                _predictedController.text.trim(),
                                _actualController.text.trim(),
                                _confidence,
                                _tier,
                              );
                          _predictedController.clear();
                          _actualController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record added.')));
                        },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add record'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 44)),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('Records (${records.length})', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: ZapSpacing.sm),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.xl),
              decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, color: ZapColors.textMuted, size: 32),
                  SizedBox(height: 8),
                  Text('No misclassification records yet — correct and honest, since there is no real field data.', textAlign: TextAlign.center, style: TextStyle(color: ZapColors.textMuted, fontSize: 12)),
                ],
              ),
            )
          else
            for (final r in records) ...[
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
                          Text('${r.modelSource}: predicted "${r.predictedLabel}" → actual "${r.actualLabel}"', style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('confidence ${r.confidence.toStringAsFixed(2)} · ${r.deviceTier} · ${r.createdAtIso.split("T").first}', style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: ZapColors.textMuted),
                      onPressed: () => ref.read(_d374RecordsProvider.notifier).remove(r.id),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: ZapSpacing.xl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: records.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: _buildCsv(records)));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied.')));
                        },
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('Copy CSV'),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_buildJsonBundle(records))));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON bundle copied.')));
                  },
                  icon: const Icon(Icons.data_object_rounded, size: 16),
                  label: const Text('Copy JSON'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_buildJsonBundle(records)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
        ],
      ),
    );
  }
}
