import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/device_tier_service.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/device_providers.dart';
import '../../domain/providers/inference_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 52 — Phone Capability Screen.
///
/// Route: /phone-capability
///
/// Shows the measured inference speed probe result, the AI vs heuristic
/// routing tier, and how that maps to the on-device detection pipeline.
class Day52PhoneCapabilityScreen extends ConsumerStatefulWidget {
  const Day52PhoneCapabilityScreen({super.key});

  @override
  ConsumerState<Day52PhoneCapabilityScreen> createState() =>
      _Day52PhoneCapabilityScreenState();
}

class _Day52PhoneCapabilityScreenState
    extends ConsumerState<Day52PhoneCapabilityScreen> {
  bool _retesting = false;

  Future<void> _retest() async {
    setState(() => _retesting = true);
    try {
      await PhoneCapabilityDetector().detect(forceReprobe: true);
      ref.invalidate(phoneCapabilityProvider);
    } finally {
      if (mounted) setState(() => _retesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capAsync = ref.watch(phoneCapabilityProvider);
    final tierAsync = ref.watch(deviceTierProvider);

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
            const Text('Phone Capability',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 52',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: capAsync.when(
        loading: () => SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('DETECTION MODE'),
              const SizedBox(height: ZapSpacing.sm),
              const _SkeletonCard(height: 160),
              const SizedBox(height: ZapSpacing.xl),
              const _SectionLabel('INFERENCE SPEED'),
              const SizedBox(height: ZapSpacing.sm),
              ZapCard(
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: _retesting
                        ? const CircularProgressIndicator(
                            color: ZapColors.warning)
                        : const CircularProgressIndicator(
                            color: ZapColors.info),
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),
              const _SectionLabel('TIER THRESHOLDS'),
              const SizedBox(height: ZapSpacing.sm),
              const _SkeletonCard(height: 140),
            ],
          ),
        ),
        error: (err, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: ZapColors.danger, size: 32),
                    const SizedBox(height: ZapSpacing.sm),
                    Text('Probe failed',
                        style: ZapTypography.labelLarge
                            .copyWith(color: ZapColors.danger)),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(err.toString(),
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),
              _RetestButton(
                loading: _retesting,
                onPressed: _retesting ? null : _retest,
              ),
            ],
          ),
        ),
        data: (result) => SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('DETECTION MODE'),
              const SizedBox(height: ZapSpacing.sm),
              _DetectionModeCard(result: result),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('INFERENCE SPEED'),
              const SizedBox(height: ZapSpacing.sm),
              _InferenceSpeedCard(result: result),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('TIER THRESHOLDS'),
              const SizedBox(height: ZapSpacing.sm),
              _TierThresholdsCard(currentTier: result.tier),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('WHAT THIS MEANS'),
              const SizedBox(height: ZapSpacing.sm),
              _WhatThisMeansCard(
                result: result,
                deviceTier: tierAsync.valueOrNull,
              ),
              const SizedBox(height: ZapSpacing.xl),

              _RetestButton(
                loading: _retesting || capAsync.isLoading,
                onPressed: _retesting ? null : _retest,
              ),
              const SizedBox(height: ZapSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

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
            height: 16,
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

// ─── Detection mode card ──────────────────────────────────────────────────────

class _DetectionModeCard extends StatelessWidget {
  const _DetectionModeCard({required this.result});
  final CapabilityProbeResult result;

  IconData get _icon {
    switch (result.tier) {
      case PhoneCapabilityTier.high:
        return Icons.bolt_rounded;
      case PhoneCapabilityTier.medium:
        return Icons.speed_rounded;
      case PhoneCapabilityTier.low:
        return Icons.memory_rounded;
    }
  }

  Color get _tierColor {
    switch (result.tier) {
      case PhoneCapabilityTier.high:
        return ZapColors.safe;
      case PhoneCapabilityTier.medium:
        return ZapColors.info;
      case PhoneCapabilityTier.low:
        return ZapColors.warning;
    }
  }

  String get _tierBadge {
    switch (result.tier) {
      case PhoneCapabilityTier.high:
        return 'HIGH';
      case PhoneCapabilityTier.medium:
        return 'MEDIUM';
      case PhoneCapabilityTier.low:
        return 'LOW';
    }
  }

  String get _modeLabel =>
      result.shouldUseAi ? 'AI Mode Active' : 'Heuristic Mode Active';

  Color get _modeColor =>
      result.shouldUseAi ? ZapColors.safe : ZapColors.warning;

  String get _subtitle {
    switch (result.tier) {
      case PhoneCapabilityTier.high:
        return 'On-device TFLite models running in real time';
      case PhoneCapabilityTier.medium:
        return 'AI models active with acceptable latency';
      case PhoneCapabilityTier.low:
        return 'Rule-based detection — no AI latency overhead';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          Icon(_icon, size: 48, color: _tierColor),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: _tierColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _tierBadge,
              style: ZapTypography.labelSmall.copyWith(
                color: _tierColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            _modeLabel,
            style: ZapTypography.headlineSmall.copyWith(
              color: _modeColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            _subtitle,
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Inference speed card ─────────────────────────────────────────────────────

class _InferenceSpeedCard extends StatelessWidget {
  const _InferenceSpeedCard({required this.result});
  final CapabilityProbeResult result;

  Color get _barColor {
    final ms = result.inferenceMs;
    if (ms < 100) return ZapColors.safe;
    if (ms < 500) return ZapColors.info;
    return ZapColors.warning;
  }

  _SpeedBracket get _bracket {
    final ms = result.inferenceMs;
    if (ms < 100) return _SpeedBracket.fast;
    if (ms < 500) return _SpeedBracket.ok;
    return _SpeedBracket.slow;
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          Text(
            '${result.inferenceMs.toStringAsFixed(1)} ms',
            style: ZapTypography.headlineMedium.copyWith(
              fontFamily: 'IBMPlexMono',
              color: _barColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'median inference latency (5-sample probe)',
            style: ZapTypography.bodySmall
                .copyWith(color: ZapColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (result.inferenceMs / 1000.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: ZapColors.bgElevated,
              color: _barColor,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SpeedMarker(
                  label: '<100 ms',
                  sublabel: 'FAST',
                  active: _bracket == _SpeedBracket.fast,
                  color: ZapColors.safe,
                ),
              ),
              Expanded(
                child: _SpeedMarker(
                  label: '100–500 ms',
                  sublabel: 'OK',
                  active: _bracket == _SpeedBracket.ok,
                  color: ZapColors.info,
                ),
              ),
              Expanded(
                child: _SpeedMarker(
                  label: '>500 ms',
                  sublabel: 'SLOW',
                  active: _bracket == _SpeedBracket.slow,
                  color: ZapColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SpeedBracket { fast, ok, slow }

class _SpeedMarker extends StatelessWidget {
  const _SpeedMarker({
    required this.label,
    required this.sublabel,
    required this.active,
    required this.color,
  });

  final String label;
  final String sublabel;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : ZapColors.bgElevated,
            border: Border.all(
              color: active ? color : ZapColors.textSecondary.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: active ? color : ZapColors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          sublabel,
          style: ZapTypography.labelSmall.copyWith(
            color: active ? color : ZapColors.textSecondary.withOpacity(0.6),
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── Tier thresholds table ────────────────────────────────────────────────────

class _TierThresholdsCard extends StatelessWidget {
  const _TierThresholdsCard({required this.currentTier});
  final PhoneCapabilityTier currentTier;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _TierRow(
            tier: 'HIGH',
            threshold: '< 100 ms',
            mode: 'AI models (<100 ms)',
            highlight: currentTier == PhoneCapabilityTier.high,
            color: ZapColors.safe,
          ),
          const Divider(height: 1, color: ZapColors.bgElevated),
          _TierRow(
            tier: 'MEDIUM',
            threshold: '< 500 ms',
            mode: 'AI models (<500 ms)',
            highlight: currentTier == PhoneCapabilityTier.medium,
            color: ZapColors.info,
          ),
          const Divider(height: 1, color: ZapColors.bgElevated),
          _TierRow(
            tier: 'LOW',
            threshold: '≥ 500 ms',
            mode: 'Heuristic fallback',
            highlight: currentTier == PhoneCapabilityTier.low,
            color: ZapColors.warning,
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.threshold,
    required this.mode,
    required this.highlight,
    required this.color,
  });

  final String tier;
  final String threshold;
  final String mode;
  final bool highlight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.08) : null,
        border: highlight
            ? Border(left: BorderSide(color: color, width: 3))
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md,
        vertical: ZapSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              tier,
              style: ZapTypography.labelSmall.copyWith(
                color: highlight ? color : ZapColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              threshold,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
                fontFamily: 'IBMPlexMono',
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              mode,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ),
          if (highlight)
            Icon(Icons.check_circle_rounded, color: color, size: 18)
          else
            const SizedBox(width: 18),
        ],
      ),
    );
  }
}

// ─── What this means ──────────────────────────────────────────────────────────

class _WhatThisMeansCard extends StatelessWidget {
  const _WhatThisMeansCard({
    required this.result,
    required this.deviceTier,
  });

  final CapabilityProbeResult result;
  final DeviceTierResult? deviceTier;

  @override
  Widget build(BuildContext context) {
    final aiMode = result.shouldUseAi;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deviceTier != null) ...[
            Text(
              'Device tier (OS API): ${deviceTier!.tier.shortLabel}',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
          ],
          if (aiMode) ...[
            const _PipelineRow(
              icon: Icons.check_circle_outline_rounded,
              color: ZapColors.safe,
              text: 'Scream classifier — TFLite running',
            ),
            const _PipelineRow(
              icon: Icons.check_circle_outline_rounded,
              color: ZapColors.safe,
              text: 'Motion anomaly — TFLite running',
            ),
            const _PipelineRow(
              icon: Icons.check_circle_outline_rounded,
              color: ZapColors.safe,
              text: 'DCS fusion — full pipeline active',
            ),
            const _PipelineRow(
              icon: Icons.info_outline_rounded,
              color: ZapColors.info,
              text: 'Scene analyzer — heuristic (image pipeline not yet built)',
            ),
          ] else ...[
            const _PipelineRow(
              icon: Icons.bolt_rounded,
              color: ZapColors.warning,
              text: 'Scream classifier — threshold-based, <5 ms',
            ),
            const _PipelineRow(
              icon: Icons.bolt_rounded,
              color: ZapColors.warning,
              text: 'Motion anomaly — threshold-based, <5 ms',
            ),
            const _PipelineRow(
              icon: Icons.bolt_rounded,
              color: ZapColors.warning,
              text: 'DCS fusion — weighted stub',
            ),
            const _PipelineRow(
              icon: Icons.info_outline_rounded,
              color: ZapColors.info,
              text: 'Scene analyzer — threshold-based',
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Re-test button ───────────────────────────────────────────────────────────

class _RetestButton extends StatelessWidget {
  const _RetestButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ZapButton(
      label: loading ? 'Testing…' : 'Re-test Device Speed',
      icon: loading ? null : Icons.refresh_rounded,
      onPressed: onPressed,
      variant: ZapButtonVariant.elevated,
      intent: ZapButtonIntent.warning,
      isLoading: loading,
    );
  }
}
