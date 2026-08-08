/// Day 56 — Model Download Tracker Screen
///
/// Route: /model-downloads
///
/// Demonstrates and tests the model download tracker endpoint
/// (POST + GET /api/v1/ml/model-downloads/).
///
/// Two sections:
///   1. REPORT DOWNLOAD — submit a .tflite download record to the backend.
///      Device tier is sourced from Day 52's [phoneCapabilityProvider].
///
///   2. DOWNLOAD HISTORY — live list of the user's download records with
///      client-side filter chips (All / Scream / Motion / Scene / DCS +
///      SHA256 Verified / Unverified).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/model_download_service.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/inference_providers.dart';
import '../../domain/providers/model_download_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class Day56ModelDownloadScreen extends ConsumerStatefulWidget {
  const Day56ModelDownloadScreen({super.key});

  @override
  ConsumerState<Day56ModelDownloadScreen> createState() =>
      _Day56ModelDownloadScreenState();
}

class _Day56ModelDownloadScreenState
    extends ConsumerState<Day56ModelDownloadScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  DownloadModelType _modelType     = DownloadModelType.scream;
  bool              _sha256Verified = true;

  final _modelNameCtrl    = TextEditingController(text: 'scream_classifier_v1');
  final _modelVersionCtrl = TextEditingController(text: '1.0.0');
  final _sizeBytesCtrl    = TextEditingController(text: '3145728');
  final _durationCtrl     = TextEditingController();

  // ── Submit state ──────────────────────────────────────────────────────────
  AsyncValue<ModelDownloadRecord>? _submitState;

  // ── History filter state ──────────────────────────────────────────────────
  DownloadModelType? _typeFilter;
  bool?              _verifiedFilter;

  @override
  void dispose() {
    _modelNameCtrl.dispose();
    _modelVersionCtrl.dispose();
    _sizeBytesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _submit(CapabilityProbeResult probe) async {
    final modelName    = _modelNameCtrl.text.trim();
    final modelVersion = _modelVersionCtrl.text.trim();
    final sizeText     = _sizeBytesCtrl.text.trim();

    if (modelName.isEmpty || modelVersion.isEmpty || sizeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Model name, version and size are required.')),
      );
      return;
    }
    final sizeBytes = int.tryParse(sizeText);
    if (sizeBytes == null || sizeBytes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Size must be a positive integer (bytes).')),
      );
      return;
    }

    final durationText = _durationCtrl.text.trim();
    final duration =
        durationText.isNotEmpty ? double.tryParse(durationText) : null;

    setState(() => _submitState = const AsyncLoading());
    try {
      final svc    = ref.read(modelDownloadServiceProvider);
      final record = await svc.submit(
        modelName:         modelName,
        modelVersion:      modelVersion,
        modelType:         _modelType,
        downloadSizeBytes: sizeBytes,
        sha256Verified:    _sha256Verified,
        tier:              probe.tier.name,
        installDurationMs: duration,
      );
      if (!mounted) return;
      setState(() => _submitState = AsyncData(record));
      ref.invalidate(modelDownloadHistoryProvider);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _submitState = AsyncError(e, st));
    }
  }

  void _resetSubmit() => setState(() => _submitState = null);

  // ── Filter ─────────────────────────────────────────────────────────────────

  List<ModelDownloadRecord> _applyFilter(List<ModelDownloadRecord> all) {
    var list = all;
    if (_typeFilter != null) {
      list = list.where((r) => r.modelType == _typeFilter).toList();
    }
    if (_verifiedFilter != null) {
      list = list.where((r) => r.sha256Verified == _verifiedFilter).toList();
    }
    return list;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final capAsync     = ref.watch(phoneCapabilityProvider);
    final historyAsync = ref.watch(modelDownloadHistoryProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Model Downloads',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 56',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.safe,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: ZapColors.textSecondary, size: 20),
            tooltip: 'Refresh history',
            onPressed: () => ref.invalidate(modelDownloadHistoryProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Report download form ───────────────────────────────────────
            const _SectionLabel('REPORT DOWNLOAD'),
            const SizedBox(height: ZapSpacing.sm),
            _ReportForm(
              modelType:      _modelType,
              sha256Verified: _sha256Verified,
              modelNameCtrl:    _modelNameCtrl,
              modelVersionCtrl: _modelVersionCtrl,
              sizeBytesCtrl:    _sizeBytesCtrl,
              durationCtrl:     _durationCtrl,
              submitState:    _submitState,
              capAsync:       capAsync,
              onTypeChanged: (t) => setState(() {
                _modelType   = t;
                _submitState = null;
              }),
              onVerifiedChanged: (v) => setState(() => _sha256Verified = v),
              onSubmit: () => capAsync.whenData(_submit),
              onReset:  _resetSubmit,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ── History ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('DOWNLOAD HISTORY'),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: ZapColors.textSecondary, size: 18),
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () =>
                      ref.invalidate(modelDownloadHistoryProvider),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // Filter chips
            _FilterBar(
              typeFilter:       _typeFilter,
              verifiedFilter:   _verifiedFilter,
              onTypeFilter: (t) => setState(() {
                _typeFilter     = t;
                _verifiedFilter = null;
              }),
              onVerifiedFilter: (v) => setState(() {
                _typeFilter     = null;
                _verifiedFilter = v;
              }),
              onClearAll: () => setState(() {
                _typeFilter     = null;
                _verifiedFilter = null;
              }),
            ),
            const SizedBox(height: ZapSpacing.sm),

            // History list
            historyAsync.when(
              loading: () => const Column(
                children: [
                  _SkeletonCard(height: 80),
                  SizedBox(height: ZapSpacing.sm),
                  _SkeletonCard(height: 80),
                  SizedBox(height: ZapSpacing.sm),
                  _SkeletonCard(height: 80),
                ],
              ),
              error: (e, _) => _HistoryError(
                error:   e.toString(),
                onRetry: () => ref.invalidate(modelDownloadHistoryProvider),
              ),
              data: (history) {
                final filtered = _applyFilter(history.downloads);
                if (filtered.isEmpty) {
                  return _EmptyHistory(
                      hasFilter: _typeFilter != null ||
                          _verifiedFilter != null);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Count badge
                    _CountBadge(
                        shown: filtered.length, total: history.count),
                    const SizedBox(height: ZapSpacing.sm),
                    ...filtered.map((r) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: ZapSpacing.sm),
                          child: _DownloadCard(record: r),
                        )),
                  ],
                );
              },
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton card
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: SizedBox(
        height: height,
        child: Center(
          child: Container(
            width: double.infinity,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Form
// ─────────────────────────────────────────────────────────────────────────────

class _ReportForm extends StatelessWidget {
  const _ReportForm({
    required this.modelType,
    required this.sha256Verified,
    required this.modelNameCtrl,
    required this.modelVersionCtrl,
    required this.sizeBytesCtrl,
    required this.durationCtrl,
    required this.submitState,
    required this.capAsync,
    required this.onTypeChanged,
    required this.onVerifiedChanged,
    required this.onSubmit,
    required this.onReset,
  });

  final DownloadModelType modelType;
  final bool sha256Verified;
  final TextEditingController modelNameCtrl;
  final TextEditingController modelVersionCtrl;
  final TextEditingController sizeBytesCtrl;
  final TextEditingController durationCtrl;
  final AsyncValue<ModelDownloadRecord>? submitState;
  final AsyncValue<CapabilityProbeResult?> capAsync;
  final ValueChanged<DownloadModelType> onTypeChanged;
  final ValueChanged<bool> onVerifiedChanged;
  final VoidCallback onSubmit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Probe row (read-only tier from Day 52) ─────────────────────
            capAsync.when(
              loading: () => const _ProbeRow(tier: '…', mode: '…'),
              error:   (_, __) => const _ProbeRow(tier: 'high', mode: 'ai'),
              data:    (p) => _ProbeRow(
                tier: p?.tier.name ?? 'high',
                mode: p != null
                    ? (p.shouldUseAi ? 'ai' : 'heuristic')
                    : 'ai',
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            const Divider(color: ZapColors.border, height: 1),
            const SizedBox(height: ZapSpacing.md),

            // ── Model type chips ───────────────────────────────────────────
            Text('MODEL TYPE',
                style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary, letterSpacing: 1.0)),
            const SizedBox(height: ZapSpacing.sm),
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.xs,
              children: DownloadModelType.values.map((t) {
                final selected = t == modelType;
                final color    = _typeColor(t);
                return GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? color
                            : ZapColors.textSecondary.withOpacity(0.3),
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: ZapTypography.labelSmall.copyWith(
                        color: selected ? color : ZapColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: ZapSpacing.md),

            // ── Model name ─────────────────────────────────────────────────
            const _FieldLabel('MODEL NAME'),
            const SizedBox(height: 6),
            TextField(
              controller: modelNameCtrl,
              decoration: _inputDeco('e.g. scream_classifier_v1'),
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
            ),
            const SizedBox(height: ZapSpacing.sm),

            // ── Version + size row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('VERSION'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: modelVersionCtrl,
                        decoration: _inputDeco('1.0.0'),
                        style: ZapTypography.bodyMedium
                            .copyWith(color: ZapColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('SIZE (BYTES)'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: sizeBytesCtrl,
                        decoration: _inputDeco('3145728'),
                        style: ZapTypography.bodyMedium
                            .copyWith(color: ZapColors.textPrimary),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // ── Install duration ───────────────────────────────────────────
            const _FieldLabel('INSTALL DURATION MS  (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: durationCtrl,
              decoration: _inputDeco('e.g. 2340'),
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: ZapSpacing.md),

            // ── SHA256 verified toggle ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: sha256Verified
                    ? ZapColors.safe.withOpacity(0.07)
                    : ZapColors.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sha256Verified
                      ? ZapColors.safe.withOpacity(0.35)
                      : ZapColors.border,
                ),
              ),
              child: SwitchListTile(
                value: sha256Verified,
                onChanged: onVerifiedChanged,
                activeColor: ZapColors.safe,
                dense: true,
                title: Text('SHA256 Verified',
                    style: ZapTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ZapColors.textPrimary)),
                subtitle: Text(
                  sha256Verified
                      ? 'Hash checked — download is authentic'
                      : 'Hash not checked — unverified install',
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
                secondary: Icon(
                  sha256Verified
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: sha256Verified
                      ? ZapColors.safe
                      : ZapColors.warning,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),

            // ── Submit / result ────────────────────────────────────────────
            _SubmitArea(
              submitState: submitState,
              capAsync:    capAsync,
              onSubmit:    onSubmit,
              onReset:     onReset,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary.withOpacity(0.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: ZapSpacing.md),
        filled: true,
        fillColor: ZapColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: ZapColors.safe, width: 1.5),
        ),
      );

  Color _typeColor(DownloadModelType t) {
    switch (t) {
      case DownloadModelType.scream: return ZapColors.danger;
      case DownloadModelType.motion: return ZapColors.warning;
      case DownloadModelType.scene:  return ZapColors.info;
      case DownloadModelType.dcs:    return ZapColors.safe;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Probe row (read-only tier info)
// ─────────────────────────────────────────────────────────────────────────────

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.tier, required this.mode});
  final String tier;
  final String mode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.smartphone_rounded,
            color: ZapColors.textSecondary, size: 16),
        const SizedBox(width: ZapSpacing.xs),
        Text('Tier: ',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary)),
        Text(tier.toUpperCase(),
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.safe, fontWeight: FontWeight.w700)),
        const SizedBox(width: ZapSpacing.md),
        const Icon(Icons.memory_rounded,
            color: ZapColors.textSecondary, size: 16),
        const SizedBox(width: ZapSpacing.xs),
        Text('Mode: ',
            style: ZapTypography.labelSmall
                .copyWith(color: ZapColors.textSecondary)),
        Text(mode.toUpperCase(),
            style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.info, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit area (idle / loading / success / error)
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitArea extends StatelessWidget {
  const _SubmitArea({
    required this.submitState,
    required this.capAsync,
    required this.onSubmit,
    required this.onReset,
  });

  final AsyncValue<ModelDownloadRecord>? submitState;
  final AsyncValue<CapabilityProbeResult?> capAsync;
  final VoidCallback onSubmit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (submitState == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: capAsync.isLoading ? null : onSubmit,
          icon: const Icon(Icons.cloud_upload_rounded),
          label: const Text('Report Download'),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.safe,
            foregroundColor: ZapColors.textInverse,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: ZapTypography.bodyMedium
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (submitState!.isLoading) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ZapColors.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ZapColors.safe),
            ),
            SizedBox(width: ZapSpacing.sm),
            Text('Reporting download…',
                style: TextStyle(color: ZapColors.textSecondary)),
          ],
        ),
      );
    }

    if (submitState!.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: ZapColors.danger.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ZapColors.danger, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    submitState!.error.toString(),
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    // ── Success ──────────────────────────────────────────────────────────────
    final record = submitState!.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SuccessCard(record: record),
        const SizedBox(height: ZapSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Report another'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZapColors.safe,
              side: const BorderSide(color: ZapColors.safe),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success card
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.record});
  final ModelDownloadRecord record;

  @override
  Widget build(BuildContext context) {
    final sizeMb =
        (record.downloadSizeBytes / 1024 / 1024).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.safe.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ZapColors.safe.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: ZapColors.safe, size: 20),
              const SizedBox(width: ZapSpacing.sm),
              Text('Download reported!',
                  style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          _KV('Model',  '${record.modelName}  v${record.modelVersion}'),
          _KV('Type',   record.modelTypeDisplay),
          _KV('Size',   '$sizeMb MB'),
          _KV('SHA256', record.sha256Verified ? '✓ Verified' : '✗ Not verified'),
          if (record.installDurationMs != null)
            _KV('Install',
                '${record.installDurationMs!.toStringAsFixed(0)} ms'),
          _KV('Tier', record.tierDisplay),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);
  final String k, v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(k,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary)),
          ),
          Expanded(
            child: Text(v,
                style: ZapTypography.labelSmall
                    .copyWith(fontWeight: FontWeight.w600,
                        color: ZapColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.verifiedFilter,
    required this.onTypeFilter,
    required this.onVerifiedFilter,
    required this.onClearAll,
  });

  final DownloadModelType? typeFilter;
  final bool? verifiedFilter;
  final ValueChanged<DownloadModelType?> onTypeFilter;
  final ValueChanged<bool?> onVerifiedFilter;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final allSelected = typeFilter == null && verifiedFilter == null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FChip(
            label: 'All',
            selected: allSelected,
            color: ZapColors.info,
            onTap: onClearAll,
          ),
          const SizedBox(width: ZapSpacing.xs),
          ...DownloadModelType.values.map((t) => Padding(
                padding: const EdgeInsets.only(left: ZapSpacing.xs),
                child: _FChip(
                  label: t.label,
                  selected: typeFilter == t,
                  color: _typeColor(t),
                  onTap: () => onTypeFilter(typeFilter == t ? null : t),
                ),
              )),
          const SizedBox(width: ZapSpacing.xs),
          _FChip(
            label: '✓ Verified',
            selected: verifiedFilter == true,
            color: ZapColors.safe,
            onTap: () =>
                onVerifiedFilter(verifiedFilter == true ? null : true),
          ),
          const SizedBox(width: ZapSpacing.xs),
          _FChip(
            label: '✗ Unverified',
            selected: verifiedFilter == false,
            color: ZapColors.warning,
            onTap: () =>
                onVerifiedFilter(verifiedFilter == false ? null : false),
          ),
        ],
      ),
    );
  }

  Color _typeColor(DownloadModelType t) {
    switch (t) {
      case DownloadModelType.scream: return ZapColors.danger;
      case DownloadModelType.motion: return ZapColors.warning;
      case DownloadModelType.scene:  return ZapColors.info;
      case DownloadModelType.dcs:    return ZapColors.safe;
    }
  }
}

class _FChip extends StatelessWidget {
  const _FChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool   selected;
  final Color  color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: selected ? color : ZapColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Download card
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.record});
  final ModelDownloadRecord record;

  @override
  Widget build(BuildContext context) {
    final sizeMb =
        (record.downloadSizeBytes / 1024 / 1024).toStringAsFixed(2);
    final fmt = DateFormat('MMM d · HH:mm');

    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ─────────────────────────────────────────────────
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(record.modelType).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.modelType.label.toUpperCase(),
                    style: ZapTypography.labelSmall.copyWith(
                      color: _typeColor(record.modelType),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                // SHA256 badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: record.sha256Verified
                        ? ZapColors.safe.withOpacity(0.10)
                        : ZapColors.warning.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        record.sha256Verified
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        size: 11,
                        color: record.sha256Verified
                            ? ZapColors.safe
                            : ZapColors.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        record.sha256Verified ? 'SHA256 ✓' : 'SHA256 ✗',
                        style: ZapTypography.labelSmall.copyWith(
                          color: record.sha256Verified
                              ? ZapColors.safe
                              : ZapColors.warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  record.tier.toUpperCase(),
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),

            // ── Model name + version ──────────────────────────────────────
            Text(
              '${record.modelName}  v${record.modelVersion}',
              style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: ZapSpacing.xs),

            // ── Metrics row ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.storage_rounded,
                    size: 13, color: ZapColors.textSecondary),
                const SizedBox(width: 3),
                Text('$sizeMb MB',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary)),
                if (record.installDurationMs != null) ...[
                  const SizedBox(width: ZapSpacing.sm),
                  const Icon(Icons.timer_outlined,
                      size: 13, color: ZapColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    '${record.installDurationMs!.toStringAsFixed(0)} ms',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                ],
                const Spacer(),
                Text(
                  fmt.format(record.createdAt),
                  style: ZapTypography.labelSmall
                      .copyWith(color: ZapColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(DownloadModelType t) {
    switch (t) {
      case DownloadModelType.scream: return ZapColors.danger;
      case DownloadModelType.motion: return ZapColors.warning;
      case DownloadModelType.scene:  return ZapColors.info;
      case DownloadModelType.dcs:    return ZapColors.safe;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary, letterSpacing: 0.8),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.shown, required this.total});
  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZapSpacing.xs),
      decoration: BoxDecoration(
        color: ZapColors.info.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        shown == total
            ? '$total record${total == 1 ? '' : 's'}'
            : 'Showing $shown of $total',
        style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.info, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        child: Column(
          children: [
            Icon(
              hasFilter
                  ? Icons.filter_list_off_rounded
                  : Icons.download_rounded,
              size: 40,
              color: ZapColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              hasFilter
                  ? 'No records match this filter'
                  : 'No downloads reported yet',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textSecondary),
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              hasFilter
                  ? 'Try clearing the filter'
                  : 'Use the form above to report your first .tflite install',
              style: ZapTypography.labelSmall
                  .copyWith(color: ZapColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: ZapColors.danger, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(error,
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
