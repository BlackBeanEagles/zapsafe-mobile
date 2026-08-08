/// Day 61 — Inference Log Screen
///
/// Three panels in a scrollable view:
///   1. SUBMIT LOG — manual telemetry entry (simulates what the on-device
///      inference pipeline would auto-submit in production).
///   2. RECENT LOGS — filterable list with period chips + model-type chips.
///   3. LATENCY STATS — global p50/p95 + per-model breakdown cards.
///
/// POST /api/v1/ml/inference-logs/        → {id}  (201)
/// GET  /api/v1/ml/inference-logs/        → count + logs
/// GET  /api/v1/ml/inference-logs/stats/  → global + by_model latency stats
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/inference_log_service.dart';
import '../../domain/providers/inference_log_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day61InferenceLogScreen extends ConsumerStatefulWidget {
  const Day61InferenceLogScreen({super.key});

  @override
  ConsumerState<Day61InferenceLogScreen> createState() =>
      _Day61InferenceLogScreenState();
}

class _Day61InferenceLogScreenState
    extends ConsumerState<Day61InferenceLogScreen> {
  // ── Submit form state ─────────────────────────────────────────────────────
  InfModelType    _modelType     = InfModelType.scream;
  InfDetectionMode _detectMode   = InfDetectionMode.ai;
  InfTier         _tier          = InfTier.high;
  double          _inferenceMs   = 50.0;
  double          _confidence    = 0.82;
  bool            _triggeredSos  = false;
  final _modelNameCtrl  = TextEditingController(text: 'scream_v1');
  final _labelCtrl      = TextEditingController(text: 'scream');

  String? _submitError;
  String? _lastSubmittedId;
  bool    _submitting = false;

  // ── Filter state ──────────────────────────────────────────────────────────
  int    _histDays      = 7;
  String _histModelType = '';   // '' = all
  int    _statsDays     = 7;
  String _statsModelType = '';

  @override
  void dispose() {
    _modelNameCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _submitting     = true;
      _submitError    = null;
      _lastSubmittedId = null;
    });
    try {
      final svc = ref.read(inferenceLogServiceProvider);
      final id  = await svc.submit(
        deviceId:     'dev-emulator-001',
        modelName:    _modelNameCtrl.text.trim().isEmpty
            ? _modelType.value
            : _modelNameCtrl.text.trim(),
        modelType:    _modelType.value,
        detectionMode: _detectMode.value,
        tier:         _tier.value,
        inferenceMs:  _inferenceMs,
        confidence:   _confidence,
        label:        _labelCtrl.text.trim(),
        triggeredSos: _triggeredSos,
        appVersion:   '1.0.0',
      );
      setState(() => _lastSubmittedId = id);
      // Invalidate both caches so the new entry shows
      ref.invalidate(inferenceLogHistoryProvider);
      ref.invalidate(inferenceLogStatsProvider);
    } catch (e) {
      setState(() => _submitError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final histKey  = (days: _histDays,  modelType: _histModelType);
    final statsKey = (days: _statsDays, modelType: _statsModelType);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Inference Log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(inferenceLogHistoryProvider);
              ref.invalidate(inferenceLogStatsProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Submit section ─────────────────────────────────────────────
            const _SectionLabel('SUBMIT INFERENCE LOG'),
            const SizedBox(height: ZapSpacing.sm),
            _SubmitCard(
              modelType:     _modelType,
              detectMode:    _detectMode,
              tier:          _tier,
              inferenceMs:   _inferenceMs,
              confidence:    _confidence,
              triggeredSos:  _triggeredSos,
              modelNameCtrl: _modelNameCtrl,
              labelCtrl:     _labelCtrl,
              submitting:    _submitting,
              onModelType:   (v) => setState(() { _modelType = v; }),
              onDetectMode:  (v) => setState(() { _detectMode = v; }),
              onTier:        (v) => setState(() { _tier = v; }),
              onInferenceMs: (v) => setState(() { _inferenceMs = v; }),
              onConfidence:  (v) => setState(() { _confidence = v; }),
              onSosToggle:   (v) => setState(() { _triggeredSos = v; }),
              onSubmit:      _submitting ? null : _submit,
            ),
            if (_submitError != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              _ErrorBanner(message: _submitError!),
            ],
            if (_lastSubmittedId != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              _SuccessBanner(id: _lastSubmittedId!),
            ],

            // ── Recent logs ────────────────────────────────────────────────
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('RECENT LOGS'),
            const SizedBox(height: ZapSpacing.sm),
            _PeriodChips(
              selected: _histDays,
              onChanged: (d) => setState(() => _histDays = d),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _ModelTypeChips(
              selected:  _histModelType,
              onChanged: (t) => setState(() => _histModelType = t),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _LogsSection(cacheKey: histKey),

            // ── Latency stats ──────────────────────────────────────────────
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('LATENCY STATS'),
            const SizedBox(height: ZapSpacing.sm),
            _PeriodChips(
              selected:  _statsDays,
              onChanged: (d) => setState(() => _statsDays = d),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _ModelTypeChips(
              selected:  _statsModelType,
              onChanged: (t) => setState(() => _statsModelType = t),
            ),
            const SizedBox(height: ZapSpacing.sm),
            _StatsSection(cacheKey: statsKey),

            const SizedBox(height: ZapSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 0.8,
        ),
      );
}

// ─── Period chips ─────────────────────────────────────────────────────────────

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.selected, required this.onChanged});
  final int                  selected;
  final ValueChanged<int>    onChanged;

  static const _options = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((d) {
        final isSelected = d == selected;
        return Padding(
          padding: const EdgeInsets.only(right: ZapSpacing.xs),
          child: GestureDetector(
            onTap: () => onChanged(d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? ZapColors.info.withOpacity(0.15)
                    : ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? ZapColors.info
                      : ZapColors.bgElevated,
                ),
              ),
              child: Text(
                '${d}d',
                style: ZapTypography.labelSmall.copyWith(
                  color: isSelected ? ZapColors.info : ZapColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Model type chips ─────────────────────────────────────────────────────────

class _ModelTypeChips extends StatelessWidget {
  const _ModelTypeChips({required this.selected, required this.onChanged});
  final String                  selected;
  final ValueChanged<String>    onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      ('', 'All'),
      ...InfModelType.values.map((t) => (t.value, t.label)),
    ];

    return Wrap(
      spacing: ZapSpacing.xs,
      children: options.map(((String, String) opt) {
        final (value, label) = opt;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZapSpacing.xs),
            margin: const EdgeInsets.only(bottom: ZapSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected
                  ? ZapColors.warning.withOpacity(0.15)
                  : ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? ZapColors.warning
                    : ZapColors.bgElevated,
              ),
            ),
            child: Text(
              label,
              style: ZapTypography.labelSmall.copyWith(
                color: isSelected
                    ? ZapColors.warning
                    : ZapColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Submit card ──────────────────────────────────────────────────────────────

class _SubmitCard extends StatelessWidget {
  const _SubmitCard({
    required this.modelType,
    required this.detectMode,
    required this.tier,
    required this.inferenceMs,
    required this.confidence,
    required this.triggeredSos,
    required this.modelNameCtrl,
    required this.labelCtrl,
    required this.submitting,
    required this.onModelType,
    required this.onDetectMode,
    required this.onTier,
    required this.onInferenceMs,
    required this.onConfidence,
    required this.onSosToggle,
    required this.onSubmit,
  });

  final InfModelType          modelType;
  final InfDetectionMode      detectMode;
  final InfTier               tier;
  final double                inferenceMs;
  final double                confidence;
  final bool                  triggeredSos;
  final TextEditingController modelNameCtrl;
  final TextEditingController labelCtrl;
  final bool                  submitting;
  final ValueChanged<InfModelType>     onModelType;
  final ValueChanged<InfDetectionMode> onDetectMode;
  final ValueChanged<InfTier>         onTier;
  final ValueChanged<double>          onInferenceMs;
  final ValueChanged<double>          onConfidence;
  final ValueChanged<bool>            onSosToggle;
  final VoidCallback?                 onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model name
          const _FieldLabel('Model name'),
          const SizedBox(height: ZapSpacing.xs),
          TextField(
            controller: modelNameCtrl,
            style: ZapTypography.bodySmall,
            decoration: InputDecoration(
              filled: true,
              fillColor: ZapColors.bgElevated,
              hintText: 'scream_v1',
              hintStyle: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm,
                vertical: ZapSpacing.xs,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          // Model type
          const _FieldLabel('Model type'),
          const SizedBox(height: ZapSpacing.xs),
          _EnumDropdown<InfModelType>(
            value:    modelType,
            items:    InfModelType.values,
            label:    (t) => t.label,
            onChanged: (v) { if (v != null) onModelType(v); },
          ),
          const SizedBox(height: ZapSpacing.md),

          // Detection mode + Tier (side by side)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Detection mode'),
                    const SizedBox(height: ZapSpacing.xs),
                    _EnumDropdown<InfDetectionMode>(
                      value:    detectMode,
                      items:    InfDetectionMode.values,
                      label:    (m) => m.label,
                      onChanged: (v) { if (v != null) onDetectMode(v); },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Device tier'),
                    const SizedBox(height: ZapSpacing.xs),
                    _EnumDropdown<InfTier>(
                      value:    tier,
                      items:    InfTier.values,
                      label:    (t) => t.label,
                      onChanged: (v) { if (v != null) onTier(v); },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // Inference ms slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _FieldLabel('Inference latency'),
              Text(
                '${inferenceMs.toStringAsFixed(0)} ms',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.info,
                ),
              ),
            ],
          ),
          Slider(
            value:    inferenceMs.clamp(1.0, 1000.0),
            min:      1.0,
            max:      1000.0,
            divisions: 99,
            activeColor: ZapColors.info,
            onChanged:   onInferenceMs,
          ),

          // Confidence slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _FieldLabel('Confidence'),
              Text(
                confidence.toStringAsFixed(2),
                style: ZapTypography.labelSmall.copyWith(
                  color: _confColor(confidence),
                ),
              ),
            ],
          ),
          Slider(
            value:    confidence,
            min:      0.0,
            max:      1.0,
            divisions: 100,
            activeColor: _confColor(confidence),
            onChanged:   onConfidence,
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Label
          const _FieldLabel('Output label (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          TextField(
            controller: labelCtrl,
            style: ZapTypography.bodySmall,
            decoration: InputDecoration(
              filled: true,
              fillColor: ZapColors.bgElevated,
              hintText: 'e.g. scream, fall, no_event',
              hintStyle: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm,
                vertical: ZapSpacing.xs,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Triggered SOS toggle
          Row(
            children: [
              const Icon(Icons.crisis_alert_rounded,
                  size: 16, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.sm),
              const Text('Triggered SOS', style: ZapTypography.labelMedium),
              const Spacer(),
              Switch(
                value:     triggeredSos,
                onChanged: onSosToggle,
                activeColor: ZapColors.danger,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: submitting
                    ? ZapColors.bgElevated
                    : ZapColors.info,
                foregroundColor: submitting
                    ? ZapColors.textSecondary
                    : ZapColors.bgPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZapColors.textSecondary,
                      ),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: Text(
                submitting ? 'Submitting…' : 'Submit Log',
                style: ZapTypography.labelMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _confColor(double v) {
    if (v >= 0.8) return ZapColors.safe;
    if (v >= 0.5) return ZapColors.warning;
    return ZapColors.danger;
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
        ),
      );
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T                      value;
  final List<T>                items;
  final String Function(T)     label;
  final ValueChanged<T?>       onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value:       value,
          isExpanded:  true,
          dropdownColor: ZapColors.bgCard,
          style: ZapTypography.bodySmall,
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(label(item), style: ZapTypography.bodySmall),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Banners ──────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: ZapColors.danger),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.safe.withOpacity(0.1),
        border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: ZapColors.safe),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Logged  ·  id: ${id.substring(0, 8)}…',
              style:
                  ZapTypography.bodySmall.copyWith(color: ZapColors.safe),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logs section ─────────────────────────────────────────────────────────────

class _LogsSection extends ConsumerWidget {
  const _LogsSection({required this.cacheKey});
  final ({int days, String modelType}) cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inferenceLogHistoryProvider(cacheKey));

    return async.when(
      loading: () => const _Spinner(),
      error: (e, _) => _ErrorBanner(
        message: e.toString().replaceFirst('Exception: ', ''),
      ),
      data: (history) {
        if (history.logs.isEmpty) {
          return _EmptyBox(
            icon: Icons.memory_rounded,
            message: 'No inference logs in the last ${cacheKey.days} days.',
          );
        }
        return Column(
          children: history.logs
              .take(20)
              .map((log) => _LogCard(log: log))
              .toList(),
        );
      },
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.log});
  final InferenceLogEntry log;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm:ss');
    final confColor = log.confidence >= 0.8
        ? ZapColors.safe
        : log.confidence >= 0.5
            ? ZapColors.warning
            : ZapColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Row(
        children: [
          // Model type badge
          _TypeBadge(type: log.modelType),
          const SizedBox(width: ZapSpacing.sm),

          // Middle: model name + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.modelName, style: ZapTypography.labelMedium),
                Text(
                  fmt.format(log.createdAt),
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Right column: latency + confidence
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${log.inferenceMs.toStringAsFixed(0)} ms',
                style: ZapTypography.labelSmall.copyWith(color: ZapColors.info),
              ),
              Text(
                'conf ${log.confidence.toStringAsFixed(2)}',
                style:
                    ZapTypography.labelSmall.copyWith(color: confColor),
              ),
            ],
          ),

          // SOS dot
          if (log.triggeredSos) ...[
            const SizedBox(width: ZapSpacing.sm),
            const Icon(Icons.crisis_alert_rounded,
                size: 14, color: ZapColors.danger),
          ],
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  static const _colors = {
    'scream': ZapColors.danger,
    'motion': ZapColors.warning,
    'scene':  ZapColors.info,
    'dcs':    ZapColors.safe,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? ZapColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Stats section ────────────────────────────────────────────────────────────

class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.cacheKey});
  final ({int days, String modelType}) cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inferenceLogStatsProvider(cacheKey));

    return async.when(
      loading: () => const _Spinner(),
      error: (e, _) => _ErrorBanner(
        message: e.toString().replaceFirst('Exception: ', ''),
      ),
      data: (stats) {
        if (stats.totalCount == 0) {
          return _EmptyBox(
            icon: Icons.bar_chart_rounded,
            message: 'No stats for the last ${cacheKey.days} days.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Global summary card
            _GlobalStatsCard(stats: stats),
            const SizedBox(height: ZapSpacing.sm),
            // Per-model breakdown
            ...stats.byModel.map((m) => _ModelStatCard(entry: m)),
          ],
        );
      },
    );
  }
}

class _GlobalStatsCard extends StatelessWidget {
  const _GlobalStatsCard({required this.stats});
  final InferenceLogStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded,
                  size: 16, color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              Text('GLOBAL  ·  ${stats.totalCount} runs',
                  style: ZapTypography.labelMedium.copyWith(
                    color: ZapColors.info,
                  )),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              _StatPill(
                  label: 'avg',
                  value: _fmtMs(stats.globalAvgMs),
                  color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              _StatPill(
                  label: 'p50',
                  value: _fmtMs(stats.globalP50Ms),
                  color: ZapColors.safe),
              const SizedBox(width: ZapSpacing.sm),
              _StatPill(
                  label: 'p95',
                  value: _fmtMs(stats.globalP95Ms),
                  color: ZapColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtMs(double? v) => v == null ? '–' : '${v.toStringAsFixed(1)} ms';
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: color,
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          Text(
            value,
            style: ZapTypography.labelMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ModelStatCard extends StatelessWidget {
  const _ModelStatCard({required this.entry});
  final ModelStatEntry entry;

  @override
  Widget build(BuildContext context) {
    String fmtMs(double? v) =>
        v == null ? '–' : '${v.toStringAsFixed(1)} ms';

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _TypeBadge(type: entry.modelType),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(entry.modelName,
                    style: ZapTypography.labelMedium),
              ),
              Text(
                '${entry.count} runs',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Latency row
          Row(
            children: [
              _StatPill(
                  label: 'avg',
                  value: fmtMs(entry.avgMs),
                  color: ZapColors.info),
              const SizedBox(width: ZapSpacing.xs),
              _StatPill(
                  label: 'p50',
                  value: fmtMs(entry.p50Ms),
                  color: ZapColors.safe),
              const SizedBox(width: ZapSpacing.xs),
              _StatPill(
                  label: 'p95',
                  value: fmtMs(entry.p95Ms),
                  color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.xs),
              _StatPill(
                  label: 'max',
                  value: fmtMs(entry.maxMs),
                  color: ZapColors.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Confidence + SOS rate
          Row(
            children: [
              const Icon(Icons.percent_rounded,
                  size: 13, color: ZapColors.textSecondary),
              const SizedBox(width: ZapSpacing.xs),
              Text(
                'Confidence avg: ${entry.avgConfidence != null ? entry.avgConfidence!.toStringAsFixed(2) : "–"}',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.crisis_alert_rounded,
                  size: 13, color: ZapColors.danger),
              const SizedBox(width: ZapSpacing.xs),
              Text(
                'SOS: ${(entry.sosRate * 100).toStringAsFixed(1)}%',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Shared utils ─────────────────────────────────────────────────────────────

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(ZapSpacing.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.message});
  final IconData icon;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28,
              color: ZapColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            message,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
