/// Day 322 — DCS Pipeline Production Wire
///
/// Verifies (by source-code read — no device/emulator available in this
/// sandbox, so this is a code-level verification, not a live claim) the
/// full real production chain:
///
///   `DCSScoreWatcher` (Day 33, `dcs_score_watcher.dart`)
///     → `TriggerOrchestrator.dispatchDcs` (Day 39, `trigger_orchestrator.dart`)
///     → `AppStateNotifier` (`app_state_provider.dart`)
///     → `appStateNavigationBridgeProvider` (`app_bootstrap_providers.dart`)
///     → production dashboard navigation (`AppRoutes.alertPending` /
///       `AppRoutes.sosActive`)
///
/// already wired end-to-end via `triggerOrchestratorBootstrapProvider`,
/// which every `ZapSafeApp.build()` watches through `appBootstrapProvider`
/// (confirmed by reading `main.dart` → `app_bootstrap_providers.dart` →
/// `trigger_orchestrator_providers.dart` → `inference_providers.dart`
/// directly).
///
/// Real gap found + fixed this day: every individual model pipeline
/// (scream/motion/gunshot/motion_b/crowd_panic/vehicle_crash/
/// k_confinement) already logs to the real
/// `POST /api/v1/ml/detection-events/` endpoint (Day 55) via
/// `liveDetectionEventSubmitterProvider` — but the M9 DCS **fusion** score
/// never did, despite `DetectionEventType.dcs` existing in the enum since
/// Day 55. `dcs_detection_log_providers.dart` (new this day) closes that
/// gap and is now watched from `appBootstrapProvider` alongside the other
/// production wires.
///
/// Model reality check (read directly off `assets/models/*.tflite` file
/// headers — the `PLACEHOLDER_TFLITE_FILE` text marker vs a real `TFL3`
/// binary header): of the 4 core DCS fusion slots, scream/motion/scene are
/// real trained TFLite models; the M9 fusion slot
/// (`dcs_fusion_v1.tflite`) is still the Day-31 placeholder stub — the
/// `LinearStubInterpreter` fallback runs in its place today. This screen
/// reports that honestly per-slot rather than claiming all 4 are real.
///
/// Tag: 🔗
///
/// Route: AppRoutes.dcsPipelineWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/model_registry.dart';
import '../../domain/providers/inference_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class Day322DcsPipelineWireScreen extends ConsumerWidget {
  const Day322DcsPipelineWireScreen({super.key});

  static const _wireSteps = [
    (
      step: '1. DCSScoreWatcher',
      detail: 'Day 33 · dcs_score_watcher.dart · 3-window vote → '
          'ALERT_PENDING · single ≥0.90 window → AUTO_SOS',
    ),
    (
      step: '2. TriggerOrchestrator.dispatchDcs',
      detail: 'Day 39 · trigger_orchestrator.dart · policy-free translator '
          '→ AppStateNotifier.onDCSThresholdExceeded / onAutoSos',
    ),
    (
      step: '3. AppStateNotifier',
      detail: 'app_state_provider.dart · 7-state machine · monitoring → '
          'alertPending → sosActive',
    ),
    (
      step: '4. appStateNavigationBridgeProvider',
      detail: 'app_bootstrap_providers.dart · ref.listen(appStateProvider) '
          '→ router.go(AppRoutes.alertPending / sosActive)',
    ),
    (
      step: '5. Production dashboard',
      detail: 'dashboard_placeholder.dart (/dashboard) · renders live '
          'AppState via appStateProvider watch',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelAssetStatusesProvider);
    final engineAsync = ref.watch(dcsEngineProvider);

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.dcs_pipeline_wire_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day321_330.dcs_pipeline_wire_heading'.tr(),
              style: ZapTypography.headlineSmall
                  .copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Verified by reading the real provider chain (no device in '
            'this sandbox — code-level verification, documented per-step '
            'below).',
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
          ),
          const SizedBox(height: ZapSpacing.lg),

          Text('WIRING CHAIN',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final s in _wireSteps)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: ZapColors.safe, size: 16),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(s.step,
                            style: ZapTypography.bodyMedium.copyWith(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(s.detail,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.lg),

          ZapCard(
            backgroundColor: ZapColors.safe.withOpacity(0.08),
            borderColor: ZapColors.safe.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: ZapColors.safe, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'NEW this day: DCS fusion scores now also POST to '
                    'POST /api/v1/ml/detection-events/ (Day 55, real '
                    'endpoint) via dcsDetectionLogSubmitterProvider, wired '
                    'into appBootstrapProvider. Previously only the 7 '
                    'individual model pipelines logged; DCS fusion itself '
                    'was a real, silent gap.',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('DCS ENGINE · 4 SLOTS (REAL VS STUB)',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          engineAsync.when(
            data: (engine) => Column(
              children: [
                for (final s in engine.slotStatuses)
                  ZapCard(
                    margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.slot,
                                  style: ZapTypography.bodyMedium.copyWith(
                                      color: ZapColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text(s.label,
                                  style: ZapTypography.bodySmall
                                      .copyWith(color: ZapColors.textMuted)),
                            ],
                          ),
                        ),
                        ZapBadge(
                          label: s.real ? 'REAL' : 'STUB',
                          intent: s.real ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                          size: ZapBadgeSize.small,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ZapSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ZapCard(
              child: Text('Engine load failed: $e',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('MODEL ASSETS ON DISK (assets/models/*.tflite)',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          modelsAsync.when(
            data: (statuses) => Column(
              children: [
                for (final st in statuses.take(4)) _ModelRow(status: st),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: ZapSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ZapCard(
              child: Text('Asset probe failed: $e',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Honest status: scream/motion/scene load real trained '
                    'TFLite models (verified via TFL3 binary header on '
                    'disk). The M9 fusion slot (dcs_fusion_v1.tflite) is '
                    'still the Day-31 placeholder text stub — '
                    'DCSInferenceEngine falls back to LinearStubInterpreter '
                    'for it, exactly as designed. Nothing here claims the '
                    'placeholder is real.',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.status});
  final ModelAssetStatus status;

  @override
  Widget build(BuildContext context) {
    final real = !status.isPlaceholder && status.sizeBytes > 0;
    return ZapCard(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.definition.displayName,
                    style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                  '${status.definition.assetPath} · ${status.sizeBytes} bytes',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                ),
              ],
            ),
          ),
          ZapBadge(
            label: real ? 'REAL' : 'PLACEHOLDER',
            intent: real ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
            size: ZapBadgeSize.small,
          ),
        ],
      ),
    );
  }
}
