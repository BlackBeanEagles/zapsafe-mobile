import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/app_state.dart';
import '../../data/models/dcs_score.dart';
import '../../data/models/fall_event.dart';
import '../../data/models/inference_result.dart';
import '../../data/models/trigger_event.dart';
import '../../data/services/pin_policy.dart';
import '../../domain/integration/trigger_orchestrator.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/trigger_orchestrator_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_pin_entry.dart';
import '../widgets/zap_snackbar.dart';

/// Day 39 — State machine wiring screen.
///
/// Demonstrates the trigger pipeline end-to-end:
///   DCS watcher / IMU falls / manual SOS  →  TriggerOrchestrator
///                                          →  AppStateNotifier
///                                          →  GPS profile rotation
///                                          (via Day 38's bridge).
///
/// Plus the LP3 duress-PIN cancel path: the PIN entry pad is wired to
/// either `onCancelWithRealPIN` (1234) or `onCancelWithDuressPIN` (9999).
class Day39StateWiringScreen extends ConsumerStatefulWidget {
  const Day39StateWiringScreen({super.key});

  @override
  ConsumerState<Day39StateWiringScreen> createState() =>
      _Day39StateWiringScreenState();
}

class _Day39StateWiringScreenState
    extends ConsumerState<Day39StateWiringScreen> {
  Timer? _ticker;
  final _pinPolicy = PinPolicy();
  final _pinController = TextEditingController();
  bool _pinError = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wire side effects (GPS profile + legacy mirror).
    ref.watch(appStateGpsBridgeProvider);
    // Bootstrap the orchestrator (subscribes to upstream streams).
    final orch = ref.watch(triggerOrchestratorBootstrapProvider);
    final appState = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 39 · State Machine Wiring'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              // ─── Current state + countdown ────────────────────────────
              const _SectionLabel('LIVE STATE'),
              const SizedBox(height: ZapSpacing.md),
              _StateCard(
                appState: appState,
                countdownStartedAt: notifier.alertCountdownStartedAt,
                silentlyEscalating: notifier.silentlyEscalating,
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Trigger pipeline counters ───────────────────────────
              const _SectionLabel('TRIGGER PIPELINE'),
              const SizedBox(height: ZapSpacing.md),
              _PipelineCard(orch: orch),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Inject synthetic events ─────────────────────────────
              const _SectionLabel('INJECT SYNTHETIC EVENTS'),
              const SizedBox(height: ZapSpacing.md),
              _injectButtons(orch),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Manual SOS ─────────────────────────────────────────
              const _SectionLabel('MANUAL SOS'),
              const SizedBox(height: ZapSpacing.md),
              _manualSosButtons(orch),

              const SizedBox(height: ZapSpacing.xl),

              // ─── PIN cancel ─────────────────────────────────────────
              const _SectionLabel('PIN CANCEL · LP3 DURESS'),
              const SizedBox(height: ZapSpacing.md),
              _PinCancelCard(
                controller: _pinController,
                error: _pinError,
                enabled: appState == AppState.alertPending ||
                    appState == AppState.sosActive ||
                    appState == AppState.escalating,
                onConfirm: () => _onPinConfirm(),
                onClear: () {
                  _pinController.clear();
                  setState(() => _pinError = false);
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Orchestrator log ───────────────────────────────────
              const _SectionLabel('ORCHESTRATOR LOG'),
              const SizedBox(height: ZapSpacing.md),
              _OrchHistoryCard(history: orch.history),

              const SizedBox(height: ZapSpacing.md),

              // ─── Underlying state transition log ────────────────────
              const _SectionLabel('STATE TRANSITIONS · BACKING'),
              const SizedBox(height: ZapSpacing.md),
              _TransitionHistoryCard(history: notifier.history),

              const SizedBox(height: ZapSpacing.xxl),
              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _injectButtons(TriggerOrchestrator orch) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ZapButton.elevated(
                label: 'DCS · ALERT_PENDING',
                icon: Icons.psychology_rounded,
                intent: ZapButtonIntent.warning,
                onPressed: () => _injectDcs(orch,
                    kind: TriggerKind.alertPending, scream: 0.78),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: ZapButton.elevated(
                label: 'DCS · AUTO_SOS',
                icon: Icons.bolt_rounded,
                intent: ZapButtonIntent.danger,
                onPressed: () => _injectDcs(orch,
                    kind: TriggerKind.autoSos, scream: 0.91),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ZapButton.outlined(
          label: 'IMU · FALL DETECTED',
          icon: Icons.airline_seat_individual_suite_rounded,
          fullWidth: true,
          intent: ZapButtonIntent.warning,
          onPressed: () => _injectFall(orch),
        ),
      ],
    );
  }

  Widget _manualSosButtons(TriggerOrchestrator orch) {
    return Column(
      children: [
        ZapButton.elevated(
          label: 'TRIGGER MANUAL SOS',
          icon: Icons.warning_amber_rounded,
          intent: ZapButtonIntent.danger,
          fullWidth: true,
          onPressed: () {
            orch.dispatchManual(TriggerMethod.manual,
                cause: 'manual SOS button');
            if (mounted) {
              ZapSnackbar.warning(
                  context, 'Manual SOS — 15 s countdown started.');
            }
          },
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ZapButton.outlined(
                label: 'DOUBLE-TAP',
                icon: Icons.touch_app_rounded,
                onPressed: () => orch.dispatchManual(TriggerMethod.doubleTap),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: ZapButton.outlined(
                label: 'VOICE CUE',
                icon: Icons.mic_rounded,
                onPressed: () => orch.dispatchManual(TriggerMethod.voiceCue),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _injectDcs(TriggerOrchestrator orch,
      {required TriggerKind kind, required double scream}) {
    final fusion = InferenceResult(
      label: scream >= 0.5 ? 'scream' : 'normal',
      score: scream,
      classScores: {
        'scream': scream,
        'normal': 1 - scream,
        'shout': 0,
      },
      latencyMs: 1,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    const neutral = InferenceResult(
      label: 'normal',
      score: 0.05,
      classScores: {'normal': 0.05},
      latencyMs: 1,
      timestampMs: 0,
    );
    final score = DCSScore(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      audio: fusion,
      motion: neutral,
      scene: neutral,
      fusion: fusion,
    );
    final ev = TriggerEvent(
      kind: kind,
      score: score,
      passive: true,
      consecutiveWindows: kind == TriggerKind.alertPending ? 3 : 0,
      timestampMs: score.timestampMs,
    );
    orch.dispatchDcs(ev);
    if (mounted) {
      ZapSnackbar.info(context, 'Dispatched ${kind.label} (scream=$scream)');
    }
  }

  void _injectFall(TriggerOrchestrator orch) {
    final ev = FallEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      peakAccelMagnitude: 28.4,
      freefallDurationMs: 320,
    );
    orch.dispatchFall(ev);
    if (mounted) ZapSnackbar.warning(context, 'Fall dispatched');
  }

  void _onPinConfirm() {
    final pin = _pinController.text;
    final match = _pinPolicy.classify(pin);
    final notifier = ref.read(appStateProvider.notifier);
    if (match == PinMatch.real) {
      notifier.onCancelWithRealPIN(cause: 'PIN cancel (real) · $pin');
      _pinController.clear();
      setState(() => _pinError = false);
      if (mounted) ZapSnackbar.success(context, 'Cancelled · returned to MONITORING');
    } else if (match == PinMatch.duress) {
      // LP3 — the user sees the same "cancelled" message; the silent
      // escalation flag flips on under the hood.
      notifier.onCancelWithDuressPIN(cause: 'PIN cancel (duress) · $pin');
      _pinController.clear();
      setState(() => _pinError = false);
      if (mounted) ZapSnackbar.success(context, 'Cancelled · returned to MONITORING');
    } else {
      setState(() => _pinError = true);
      if (mounted) ZapSnackbar.danger(context, 'Wrong PIN');
    }
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.danger.withOpacity(0.14),
            ZapColors.warning.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 8 · DAY 39',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Trigger Pipeline · Wired',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'DCS watcher · IMU falls · manual SOS — all route through the '
            'TriggerOrchestrator into AppStateNotifier. AUTO_SOS bypasses '
            'the 15 s alert countdown (LP25). Duress PIN cancels the UI '
            'while LP3 silent escalation keeps backend dispatch alive.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── State card ──────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final AppState appState;
  final DateTime? countdownStartedAt;
  final bool silentlyEscalating;

  const _StateCard({
    required this.appState,
    required this.countdownStartedAt,
    required this.silentlyEscalating,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(appState);
    final remaining = countdownStartedAt == null
        ? null
        : (15 - DateTime.now().difference(countdownStartedAt!).inSeconds)
            .clamp(0, 15);
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent.withOpacity(0.5)),
                ),
                child: Text(
                  appState.label,
                  style: ZapTypography.headlineSmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              if (silentlyEscalating)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: ZapColors.danger.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LP3 · SILENT',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.danger,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          if (appState == AppState.alertPending) ...[
            const SizedBox(height: ZapSpacing.md),
            Row(
              children: [
                const Icon(Icons.timer_rounded,
                    color: ZapColors.warning, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  'Countdown · ${remaining ?? 0}s until SOS_ACTIVE',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.warning),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _accentFor(AppState s) {
    return switch (s) {
      AppState.idle          => ZapColors.textSecondary,
      AppState.monitoring    => ZapColors.safe,
      AppState.elevated      => ZapColors.warning,
      AppState.alertPending  => ZapColors.warning,
      AppState.sosActive     => ZapColors.danger,
      AppState.escalating    => ZapColors.danger,
      AppState.postIncident  => ZapColors.info,
    };
  }
}

// ─── Pipeline card ───────────────────────────────────────────────────────────

class _PipelineCard extends StatelessWidget {
  final TriggerOrchestrator orch;
  const _PipelineCard({required this.orch});

  @override
  Widget build(BuildContext context) {
    final accent =
        orch.isAttached ? ZapColors.safe : ZapColors.textSecondary;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                orch.isAttached
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                orch.isAttached
                    ? 'ORCHESTRATOR ATTACHED'
                    : 'ORCHESTRATOR DETACHED',
                style: ZapTypography.labelMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _Kv(k: 'DCS · ALERT_PENDING fired',
              v: orch.dcsAlertCount.toString()),
          _Kv(k: 'DCS · AUTO_SOS fired',
              v: orch.dcsAutoSosCount.toString()),
          _Kv(k: 'IMU · FALL dispatched',
              v: orch.fallCount.toString()),
          _Kv(k: 'MANUAL · button / chord',
              v: orch.manualCount.toString()),
          const SizedBox(height: ZapSpacing.sm),
          _Kv(k: 'Total dispatched',
              v: orch.totalDispatched.toString()),
        ],
      ),
    );
  }
}

// ─── PIN card ────────────────────────────────────────────────────────────────

class _PinCancelCard extends StatelessWidget {
  final TextEditingController controller;
  final bool error;
  final bool enabled;
  final VoidCallback onConfirm;
  final VoidCallback onClear;

  const _PinCancelCard({
    required this.controller,
    required this.error,
    required this.enabled,
    required this.onConfirm,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled
                ? 'Enter PIN to cancel — wrong PIN is rejected, duress '
                    'PIN cancels visibly while keeping LP3 silent escalation.'
                : 'PIN cancel is only active while the state is '
                    'ALERT_PENDING / SOS_ACTIVE / ESCALATING.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Center(
            child: AbsorbPointer(
              absorbing: !enabled,
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: ZapPinEntry(
                  controller: controller,
                  length: 4,
                  error: error,
                  onComplete: (_) => onConfirm(),
                ),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'CONFIRM PIN',
                  icon: Icons.check_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed: enabled ? onConfirm : null,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'CLEAR',
                  icon: Icons.backspace_rounded,
                  onPressed: enabled ? onClear : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Demo PINs · real = 1234 · duress = 9999',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History cards ───────────────────────────────────────────────────────────

class _OrchHistoryCard extends StatelessWidget {
  final List<OrchestratorEvent> history;
  const _OrchHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${history.length} dispatched',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (history.isEmpty)
            Text(
              'No events yet — inject a synthetic event above.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                reverse: true,
                itemCount: history.length,
                itemBuilder: (_, i) {
                  final e = history[history.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_fmtTime(e.at)}  [${e.source}] ${e.label}  → ${e.resultingState.label}',
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class _TransitionHistoryCard extends StatelessWidget {
  final List<AppStateTransition> history;
  const _TransitionHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${history.length} transitions',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (history.isEmpty)
            Text(
              'No transitions yet.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                reverse: true,
                itemCount: history.length,
                itemBuilder: (_, i) {
                  final t = history[history.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_fmtTime(t.at)}  ${t.from.label} → ${t.to.label}  · ${t.cause}',
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

// ─── shared ──────────────────────────────────────────────────────────────────

class _Kv extends StatelessWidget {
  final String k;
  final String v;
  const _Kv({required this.k, required this.v});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: ZapTypography.monoSmall
                    .copyWith(color: ZapColors.textPrimary),
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
