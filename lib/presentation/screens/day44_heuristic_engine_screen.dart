import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/motion_features.dart';
import '../../data/models/scene_features.dart';
import '../../data/services/heuristic_detection_engine.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../native/audio_features.dart';
import '../widgets/zap_card.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _tierProvider =
    StateProvider<PhoneCapabilityTier>((ref) => PhoneCapabilityTier.low);

final _screamResultProvider =
    StateProvider<InferenceResult?>((ref) => null);

final _motionResultProvider =
    StateProvider<InferenceResult?>((ref) => null);

final _sceneResultProvider =
    StateProvider<InferenceResult?>((ref) => null);

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Day 44 — Heuristic Detection Engine demo screen.
///
/// Route: /heuristic-engine
///
/// Lets the developer simulate all three detector types in both AI-mode and
/// heuristic-fallback mode, with safe and threat fixture inputs, so the
/// routing logic can be verified on the emulator without a real sensor stream.
class Day44HeuristicEngineScreen extends ConsumerWidget {
  const Day44HeuristicEngineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(_tierProvider);
    final engine = HeuristicDetectionEngine(tier: tier);
    final screamResult = ref.watch(_screamResultProvider);
    final motionResult = ref.watch(_motionResultProvider);
    final sceneResult  = ref.watch(_sceneResultProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: Row(
          children: [
            const Text('Heuristic Engine',
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
                'DAY 44',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode switcher ──────────────────────────────────────────
            _SectionLabel('CAPABILITY TIER'),
            const SizedBox(height: ZapSpacing.sm),
            _TierSelector(
              selected: tier,
              onChanged: (t) => ref.read(_tierProvider.notifier).state = t,
            ),
            const SizedBox(height: ZapSpacing.xs),
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
                      'Active mode: ${engine.modeLabel}',
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

            // ── Scream ─────────────────────────────────────────────────
            _SectionLabel('SCREAM DETECTOR  ·  ${engine.scream.modelLabel}'),
            const SizedBox(height: ZapSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _FixtureButton(
                    label: 'Safe audio',
                    color: ZapColors.safe,
                    onPressed: () async {
                      final feat = AudioFeatures(
                        timestampMs: DateTime.now().millisecondsSinceEpoch,
                        mfcc: List.generate(13, (i) => i == 0 ? -45.0 : 0.0),
                        zcr: 0.05,
                        spectralCentroidHz: 800.0,
                      );
                      final result = await engine.scream.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_screamResultProvider.notifier).state = result;
                    },
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: _FixtureButton(
                    label: 'Scream audio',
                    color: ZapColors.danger,
                    onPressed: () async {
                      final feat = AudioFeatures(
                        timestampMs: DateTime.now().millisecondsSinceEpoch,
                        mfcc: List.generate(13, (i) => i == 0 ? -10.0 : 0.0),
                        zcr: 0.25,
                        spectralCentroidHz: 3200.0,
                      );
                      final result = await engine.scream.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_screamResultProvider.notifier).state = result;
                    },
                  ),
                ),
              ],
            ),
            if (screamResult != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              _ResultCard(result: screamResult),
            ],
            const SizedBox(height: ZapSpacing.xl),

            // ── Motion ─────────────────────────────────────────────────
            _SectionLabel('MOTION DETECTOR  ·  ${engine.motion.modelLabel}'),
            const SizedBox(height: ZapSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _FixtureButton(
                    label: 'At rest',
                    color: ZapColors.safe,
                    onPressed: () async {
                      final feat = MotionFeatures.atRest();
                      final result = await engine.motion.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_motionResultProvider.notifier).state = result;
                    },
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: _FixtureButton(
                    label: 'Fall/impact',
                    color: ZapColors.danger,
                    onPressed: () async {
                      final feat = MotionFeatures.impact();
                      final result = await engine.motion.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_motionResultProvider.notifier).state = result;
                    },
                  ),
                ),
              ],
            ),
            if (motionResult != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              _ResultCard(result: motionResult),
            ],
            const SizedBox(height: ZapSpacing.xl),

            // ── Scene ──────────────────────────────────────────────────
            _SectionLabel('SCENE DETECTOR  ·  ${engine.scene.modelLabel}'),
            const SizedBox(height: ZapSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _FixtureButton(
                    label: 'Well-lit scene',
                    color: ZapColors.safe,
                    onPressed: () async {
                      final feat = SceneFeatures.wellLit();
                      final result = await engine.scene.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_sceneResultProvider.notifier).state = result;
                    },
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: _FixtureButton(
                    label: 'Dark scene',
                    color: ZapColors.danger,
                    onPressed: () async {
                      final feat = SceneFeatures.dark();
                      final result = await engine.scene.infer(
                        feat.toFloat32Tensor(),
                        timestampMs: feat.timestampMs,
                      );
                      ref.read(_sceneResultProvider.notifier).state = result;
                    },
                  ),
                ),
              ],
            ),
            if (sceneResult != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              _ResultCard(result: sceneResult),
            ],
            const SizedBox(height: ZapSpacing.xl),

            // ── Info card ──────────────────────────────────────────────
            ZapCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: ZapColors.info, size: 18),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        'How it works',
                        style: ZapTypography.labelMedium.copyWith(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    'HeuristicDetectionEngine routes each detector modality '
                    '(scream / motion / scene) to either the TFLite AI model '
                    'or a pure-Dart threshold classifier, based on the phone\'s '
                    'PhoneCapabilityTier.\n\n'
                    '• High / Medium tier → AI models (TFLite INT8)\n'
                    '• Low tier → Heuristic fallback (no GPU needed)\n\n'
                    'Both paths return the same InferenceResult shape so '
                    'upstream code (DCS engine, trigger orchestrator) never '
                    'needs to know which path is active.',
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
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

class _TierSelector extends StatelessWidget {
  const _TierSelector({
    required this.selected,
    required this.onChanged,
  });

  final PhoneCapabilityTier selected;
  final ValueChanged<PhoneCapabilityTier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PhoneCapabilityTier.values.map((t) {
        final isSelected = t == selected;
        final color = t == PhoneCapabilityTier.high
            ? ZapColors.safe
            : t == PhoneCapabilityTier.medium
                ? ZapColors.info
                : ZapColors.warning;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(t),
            child: Container(
              margin: EdgeInsets.only(
                right: t != PhoneCapabilityTier.low ? ZapSpacing.xs : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.18)
                    : ZapColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : ZapColors.border,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    t.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: ZapTypography.labelSmall.copyWith(
                      color: isSelected ? color : ZapColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    t == PhoneCapabilityTier.high
                        ? '<100 ms'
                        : t == PhoneCapabilityTier.medium
                            ? '<500 ms'
                            : 'heuristic',
                    textAlign: TextAlign.center,
                    style: ZapTypography.labelSmall.copyWith(
                      color: isSelected
                          ? color.withOpacity(0.8)
                          : ZapColors.textSecondary.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FixtureButton extends StatelessWidget {
  const _FixtureButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.6)),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.sm, horizontal: ZapSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final InferenceResult result;

  Color get _severityColor {
    switch (result.severity) {
      case InferenceSeverity.high:
        return ZapColors.danger;
      case InferenceSeverity.medium:
        return ZapColors.warning;
      case InferenceSeverity.low:
        return ZapColors.info;
      case InferenceSeverity.none:
        return ZapColors.safe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: _severityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      result.label.toUpperCase(),
                      style: ZapTypography.labelMedium.copyWith(
                        color: _severityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(result.score * 100).toStringAsFixed(1)}%',
                      style: ZapTypography.labelLarge.copyWith(
                        color: _severityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                LinearProgressIndicator(
                  value: result.score,
                  backgroundColor: ZapColors.bgSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(_severityColor),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  '${result.latencyMs} ms  ·  '
                  '${result.isConfident ? "✓ TRIGGER" : "below threshold"}',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.textSecondary,
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
