import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/model_bundle_service.dart';
import '../../domain/providers/inference_providers.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 45 — Model Bundle screen.
///
/// Route: /model-bundle
///
/// Shows which TFLite models loaded successfully, which fell back to the
/// heuristic engine (Day 44), and the total model footprint in MB.
/// Verifies the app is well within the <50 MB size target.
class Day45ModelBundleScreen extends ConsumerWidget {
  const Day45ModelBundleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(detectionEngineProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: Row(
          children: [
            const Text('Model Bundle',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 45',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: bundleAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: ZapColors.safe),
              SizedBox(height: ZapSpacing.md),
              Text('Loading model bundle…',
                  style: TextStyle(color: ZapColors.textSecondary)),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Text(
              'Bundle load error: $err',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.danger),
            ),
          ),
        ),
        data: (bundle) => _BundleView(
          bundle: bundle,
          onReload: () => ref.refresh(detectionEngineProvider),
        ),
      ),
    );
  }
}

// ─── Bundle view ──────────────────────────────────────────────────────────────

class _BundleView extends StatelessWidget {
  const _BundleView({required this.bundle, required this.onReload});
  final ModelBundleResult bundle;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final engine = bundle.engine;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary banner ──────────────────────────────────────────
          ZapCard(
            child: Row(
              children: [
                _CircleStat(
                  value: '${bundle.loadedAiCount}',
                  label: 'AI',
                  color: ZapColors.safe,
                ),
                const SizedBox(width: ZapSpacing.md),
                _CircleStat(
                  value: '${bundle.heuristicCount}',
                  label: 'Heuristic',
                  color: ZapColors.warning,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      bundle.totalSizeLabel,
                      style: ZapTypography.labelLarge.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'model footprint',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // ── Routing mode ────────────────────────────────────────────
          ZapCard(
            child: Row(
              children: [
                Icon(
                  engine.isAiMode
                      ? Icons.memory_rounded
                      : Icons.tune_rounded,
                  color: engine.isAiMode ? ZapColors.safe : ZapColors.warning,
                  size: 18,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Routing: ${engine.modeLabel}',
                    style: ZapTypography.bodySmall.copyWith(
                      color: engine.isAiMode
                          ? ZapColors.safe
                          : ZapColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ── Per-model slots ─────────────────────────────────────────
          _SectionLabel('MODEL SLOTS'),
          const SizedBox(height: ZapSpacing.sm),
          ...bundle.slots.map((slot) => Padding(
                padding:
                    const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: _SlotCard(slot: slot),
              )),
          const SizedBox(height: ZapSpacing.xl),

          // ── App size check ──────────────────────────────────────────
          _SectionLabel('APP SIZE CHECK'),
          const SizedBox(height: ZapSpacing.sm),
          _AppSizeCard(modelBytes: bundle.totalModelBytes),
          const SizedBox(height: ZapSpacing.xl),

          // ── Re-load button ──────────────────────────────────────────
          ZapButton(
            label: 'Reload Bundle',
            onPressed: onReload,
            variant: ZapButtonVariant.outlined,
          ),
          const SizedBox(height: ZapSpacing.xxxl),
        ],
      ),
    );
  }
}

// ─── Slot card ────────────────────────────────────────────────────────────────

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.slot});
  final ModelSlotResult slot;

  Color get _statusColor {
    switch (slot.status) {
      case ModelLoadStatus.realLoaded:
        return ZapColors.safe;
      case ModelLoadStatus.placeholder:
        return ZapColors.textSecondary;
      case ModelLoadStatus.realLoadFailed:
        return ZapColors.warning;
      case ModelLoadStatus.skippedImageModel:
        return ZapColors.info;
    }
  }

  IconData get _statusIcon {
    switch (slot.status) {
      case ModelLoadStatus.realLoaded:
        return Icons.check_circle_rounded;
      case ModelLoadStatus.placeholder:
        return Icons.hourglass_empty_rounded;
      case ModelLoadStatus.realLoadFailed:
        return Icons.swap_horiz_rounded;
      case ModelLoadStatus.skippedImageModel:
        return Icons.image_not_supported_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon, color: _statusColor, size: 18),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  slot.displayName,
                  style: ZapTypography.labelMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  slot.statusLabel,
                  style: ZapTypography.labelSmall.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Row(
            children: [
              Text(
                slot.assetPath.split('/').last,
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
              const Spacer(),
              Text(
                slot.sizeMbLabel,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Active: ${slot.activeInterpreter.modelLabel}',
            style: ZapTypography.labelSmall.copyWith(
              color: slot.usesAi ? ZapColors.safe : ZapColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── App size card ────────────────────────────────────────────────────────────

class _AppSizeCard extends StatelessWidget {
  const _AppSizeCard({required this.modelBytes});
  final int modelBytes;

  static const int _targetBytes = 50 * 1024 * 1024; // 50 MB
  static const int _estimatedNonModelBytes = 35 * 1024 * 1024; // Flutter + fonts ~35 MB

  int get _estimatedTotal => modelBytes + _estimatedNonModelBytes;
  double get _fillFraction =>
      (_estimatedTotal / _targetBytes).clamp(0.0, 1.0);
  bool get _withinTarget => _estimatedTotal < _targetBytes;

  @override
  Widget build(BuildContext context) {
    final totalMb = _estimatedTotal / (1024 * 1024);
    final color = _withinTarget ? ZapColors.safe : ZapColors.danger;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _withinTarget
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                _withinTarget
                    ? 'Within 50 MB target'
                    : 'EXCEEDS 50 MB target',
                style: ZapTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '~${totalMb.toStringAsFixed(1)} MB',
                style: ZapTypography.labelLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          LinearProgressIndicator(
            value: _fillFraction,
            backgroundColor: ZapColors.bgSurface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Row(
            children: [
              Text(
                'Models: ${(modelBytes / (1024 * 1024)).toStringAsFixed(2)} MB  '
                '·  Flutter + fonts: ~35 MB',
                style: ZapTypography.bodySmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '/ 50 MB',
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _CircleStat extends StatelessWidget {
  const _CircleStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              value,
              style: ZapTypography.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          label,
          style: ZapTypography.labelSmall
              .copyWith(color: ZapColors.textSecondary),
        ),
      ],
    );
  }
}
