/// Day 321 — SOS Trigger Production Refactor
///
/// Demonstrates the new [SosTriggerController] (`lib/domain/sos/
/// sos_trigger_controller.dart`) — a single entry point covering all four
/// real SOS trigger surfaces: manual, fall, DCS auto, and the LP3
/// duress-PIN cancel path. The controller is a thin extract-and-delegate
/// wrapper around the existing Day 39 `TriggerOrchestrator` +
/// `AppStateNotifier` — every button on this screen dispatches through the
/// exact same real production call the SOS long-press button (Day 307) and
/// the DCS/fall stream bootstrap already use. No second trigger path was
/// created.
///
/// File moves / additions this day:
///   • NEW  lib/domain/sos/sos_trigger_controller.dart
///   • NEW  lib/domain/providers/sos_trigger_controller_providers.dart
///   • NEW  test/unit/sos_trigger_controller_test.dart
///   • NEW  this screen
///   • NOTHING was deleted or moved out of `trigger_orchestrator.dart`,
///     `app_state_provider.dart`, or `sos_trigger_button.dart` — see the
///     controller's own file header for the honest reason those three
///     stable/tested call sites were not rewritten to depend on it yet.
///
/// Tag: 🔗
///
/// Route: AppRoutes.sosTriggerRefactor
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/app_state.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/trigger_event.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/sos_trigger_controller_providers.dart';
import '../../domain/sos/sos_trigger_controller.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

class Day321SosTriggerRefactorScreen extends ConsumerStatefulWidget {
  const Day321SosTriggerRefactorScreen({super.key});

  @override
  ConsumerState<Day321SosTriggerRefactorScreen> createState() =>
      _Day321SosTriggerRefactorScreenState();
}

class _Day321SosTriggerRefactorScreenState
    extends ConsumerState<Day321SosTriggerRefactorScreen> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  ZapBadgeIntent _stateIntent(AppState s) => switch (s) {
        AppState.idle => ZapBadgeIntent.neutral,
        AppState.monitoring => ZapBadgeIntent.safe,
        AppState.elevated => ZapBadgeIntent.warning,
        AppState.alertPending ||
        AppState.sosActive ||
        AppState.escalating =>
          ZapBadgeIntent.danger,
        AppState.postIncident => ZapBadgeIntent.info,
      };

  void _reset() {
    // Real production reset path — same method
    // `month2_runner.dart`'s state-machine phase uses, not a test-only hook.
    ref.read(appStateProvider.notifier).returnToMonitoring(
        cause: 'Day 321 demo reset');
    setState(() {});
  }

  void _triggerManual(SosTriggerController ctrl) {
    ctrl.triggerManual(cause: 'Day 321 demo · manual');
    setState(() {});
    ZapSnackbar.info(context, 'Manual → ${ctrl.state.label}');
  }

  void _triggerFall(SosTriggerController ctrl) {
    ctrl.triggerFall(const FallEvent(
      timestampMs: 0,
      peakAccelMagnitude: 28.4,
      freefallDurationMs: 320,
    ));
    setState(() {});
    ZapSnackbar.warning(context, 'Fall → ${ctrl.state.label}');
  }

  void _triggerDcsAlert(SosTriggerController ctrl) {
    ctrl.triggerDcs(_dcsEvent(TriggerKind.alertPending, scream: 0.78));
    setState(() {});
    ZapSnackbar.warning(context, 'DCS ALERT_PENDING → ${ctrl.state.label}');
  }

  void _triggerDcsAutoSos(SosTriggerController ctrl) {
    ctrl.triggerDcs(_dcsEvent(TriggerKind.autoSos, scream: 0.92));
    setState(() {});
    ZapSnackbar.danger(context, 'DCS AUTO_SOS → ${ctrl.state.label}');
  }

  void _submitPin(SosTriggerController ctrl) {
    final pin = _pinController.text;
    final outcome = ctrl.submitCancelPin(pin, cause: 'Day 321 demo');
    setState(() {});
    switch (outcome) {
      case SosCancelOutcome.realCancel:
        ZapSnackbar.success(context, 'Cancelled · returned to MONITORING');
        break;
      case SosCancelOutcome.duressCancel:
        // LP3 — identical user-visible message to realCancel on purpose.
        ZapSnackbar.success(context, 'Cancelled · returned to MONITORING');
        break;
      case SosCancelOutcome.wrongPin:
        ZapSnackbar.danger(context, 'Wrong PIN');
        break;
    }
    _pinController.clear();
  }

  TriggerEvent _dcsEvent(TriggerKind kind, {required double scream}) {
    final fusion = InferenceResult(
      label: scream >= 0.5 ? 'scream' : 'normal',
      score: scream,
      classScores: {'scream': scream, 'normal': 1 - scream},
      latencyMs: 1,
      timestampMs: 0,
    );
    return TriggerEvent(
      kind: kind,
      score: DCSScore(timestampMs: 0, audio: fusion, fusion: fusion),
      passive: true,
      consecutiveWindows: kind == TriggerKind.alertPending ? 3 : 0,
      timestampMs: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(sosTriggerControllerProvider);
    final appState = ref.watch(appStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('day321_330.sos_trigger_refactor_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to MONITORING',
            onPressed: _reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: ZapColors.info, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Text('day321_330.sos_trigger_refactor_heading'.tr(),
                        style: ZapTypography.labelSmall.copyWith(
                          color: ZapColors.textSecondary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'SosTriggerController wraps the real Day 39 '
                  'TriggerOrchestrator + AppStateNotifier — extract-and-'
                  'delegate, not a fork. Every button below calls the exact '
                  'same production method the SOS long-press button (Day '
                  '307) and the DCS/fall stream bootstrap already use.',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),

          Center(
            child: ZapBadge(
              label: 'STATE · ${appState.label}',
              intent: _stateIntent(appState),
              size: ZapBadgeSize.medium,
              pulse: appState == AppState.sosActive ||
                  appState == AppState.escalating,
            ),
          ),
          if (ctrl.silentlyEscalating) ...[
            const SizedBox(height: ZapSpacing.sm),
            Center(
              child: ZapBadge(
                label: 'LP3 · SILENTLY ESCALATING',
                intent: ZapBadgeIntent.danger,
                size: ZapBadgeSize.small,
              ),
            ),
          ],
          const SizedBox(height: ZapSpacing.xl),

          Text('ENTRY POINT 1 · MANUAL',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.elevated(
            label: 'Dispatch manual trigger',
            icon: Icons.touch_app_rounded,
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: () => _triggerManual(ctrl),
          ),
          const SizedBox(height: ZapSpacing.lg),

          Text('ENTRY POINT 2 · FALL',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Inject synthetic FallEvent',
            icon: Icons.elderly_rounded,
            intent: ZapButtonIntent.warning,
            fullWidth: true,
            onPressed: () => _triggerFall(ctrl),
          ),
          const SizedBox(height: ZapSpacing.lg),

          Text('ENTRY POINT 3 · DCS AUTO',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ZapButton.outlined(
                  label: 'ALERT_PENDING',
                  intent: ZapButtonIntent.warning,
                  onPressed: () => _triggerDcsAlert(ctrl),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'AUTO_SOS',
                  intent: ZapButtonIntent.danger,
                  onPressed: () => _triggerDcsAutoSos(ctrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),

          Text('ENTRY POINT 4 · DURESS PIN CANCEL (LP3)',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Demo PINs · real = ${'1234'} · duress = ${'9999'} — cancel only '
            'does something while an alert/SOS is active.',
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'PIN',
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              ZapButton.tonal(
                label: 'Submit',
                onPressed: () => _submitPin(ctrl),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('CONTROLLER LOG',
              style: ZapTypography.labelLarge.copyWith(
                  color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              _CounterChip(label: 'Manual', value: ctrl.manualCount),
              const SizedBox(width: ZapSpacing.sm),
              _CounterChip(label: 'Fall', value: ctrl.fallCount),
              const SizedBox(width: ZapSpacing.sm),
              _CounterChip(
                  label: 'DCS',
                  value: ctrl.dcsAlertCount + ctrl.dcsAutoSosCount),
              const SizedBox(width: ZapSpacing.sm),
              _CounterChip(label: 'PIN', value: ctrl.duressCancelCount),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (ctrl.log.isEmpty)
            ZapCard(
              child: Text('No events yet.',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textMuted)),
            )
          else
            for (final e in ctrl.log.reversed.take(12))
              ZapCard(
                margin: const EdgeInsets.only(bottom: ZapSpacing.xs),
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.toString(),
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textPrimary),
                      ),
                    ),
                    Text(
                      '${e.at.hour.toString().padLeft(2, '0')}:'
                      '${e.at.minute.toString().padLeft(2, '0')}:'
                      '${e.at.second.toString().padLeft(2, '0')}',
                      style: ZapTypography.labelSmall
                          .copyWith(color: ZapColors.textMuted),
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

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ZapCard(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        child: Column(
          children: [
            Text('$value',
                style: ZapTypography.headlineSmall
                    .copyWith(color: ZapColors.info, fontWeight: FontWeight.w800)),
            Text(label,
                style: ZapTypography.labelSmall
                    .copyWith(color: ZapColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
