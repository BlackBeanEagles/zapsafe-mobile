import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/app_state.dart';
import '../../data/models/battery_profile.dart';
import '../../data/models/gps_sample.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/battery_providers.dart';
import '../../domain/providers/gps_fallback_providers.dart';
import '../../domain/providers/gps_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 38 — three live surfaces in one screen:
///   1. GPS fallback (cell-tower / WiFi merge when accuracy > 50 m)
///   2. Central 7-state app state machine + transition log
///   3. Battery threshold profile + 3-tier table
class Day38FallbackAndStateScreen extends ConsumerStatefulWidget {
  const Day38FallbackAndStateScreen({super.key});

  @override
  ConsumerState<Day38FallbackAndStateScreen> createState() =>
      _Day38FallbackAndStateScreenState();
}

class _Day38FallbackAndStateScreenState
    extends ConsumerState<Day38FallbackAndStateScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 1 Hz refresh so counters + countdown clocks tick.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wire side-effects (GPS profile rotation + legacy mirror).
    ref.watch(appStateGpsBridgeProvider);
    // Attach the fallback coordinator to the GPS stream.
    final coord = ref.watch(gpsFallbackBootstrapProvider);
    final batteryProfile = ref.watch(batteryProfileProvider);
    final appState = ref.watch(appStateProvider);
    final cell = ref.watch(cellLocationServiceProvider);
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 38 · Fallback + State + Battery'),
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

              // ─── Section 1 · GPS fallback ────────────────────────────
              const _SectionLabel('1 · GPS FALLBACK · CELL / WIFI MERGE'),
              const SizedBox(height: ZapSpacing.md),
              _FallbackCard(
                lastEvaluated: coord.lastEvaluated,
                emissions: coord.fallbackEmissions,
                lowQualityTriggers: coord.gpsLowQualityTriggers,
                staleTriggers: coord.staleTriggers,
                recoveries: coord.gpsRecoveries,
                cellAttempts: cell.attempts,
                cellSuccesses: cell.successes,
                cellFailures: cell.failures,
                isAttached: coord.isAttached,
              ),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'INJECT GOOD GPS',
                      icon: Icons.location_on_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed: () => _injectGpsFix(accuracy: 8),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'INJECT BAD GPS',
                      icon: Icons.location_off_rounded,
                      intent: ZapButtonIntent.warning,
                      onPressed: () => _injectGpsFix(accuracy: 220),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'FORCE CELL ESTIMATE NOW',
                icon: Icons.cell_tower_rounded,
                fullWidth: true,
                intent: ZapButtonIntent.info,
                onPressed: () => _forceCell(),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'STUB NEXT CELL FIX (synthetic 800 m)',
                icon: Icons.bolt_rounded,
                fullWidth: true,
                onPressed: () => _stubCell(),
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Section 2 · App State Machine ───────────────────────
              const _SectionLabel('2 · APP STATE MACHINE · 7 STATES'),
              const SizedBox(height: ZapSpacing.md),
              _AppStateCard(
                appState: appState,
                countdownStartedAt: notifier.alertCountdownStartedAt,
                silentlyEscalating: notifier.silentlyEscalating,
              ),
              const SizedBox(height: ZapSpacing.md),
              _AppStateTransitionButtons(
                appState: appState,
                onDcs: () => notifier.onDCSThresholdExceeded(),
                onManual: () =>
                    notifier.onManualTrigger(TriggerMethod.manual),
                onCancelReal: () => notifier.onCancelWithRealPIN(),
                onCancelDuress: () => notifier.onCancelWithDuressPIN(),
                onExpired: () => notifier.onAlertPendingExpired(),
                onTier1Ack: () => notifier.onTier1Acknowledged(),
                onResolve: () => notifier.onSosResolved(),
                onReturnMonitor: () => notifier.returnToMonitoring(),
                onElevate: () => notifier.onElevatedSignal(),
                onPowerOff: () => notifier.powerOff(),
                onPowerOn: () => notifier.powerOn(),
              ),
              const SizedBox(height: ZapSpacing.md),
              _HistoryCard(history: notifier.history),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Section 3 · Battery ─────────────────────────────────
              const _SectionLabel('3 · BATTERY THRESHOLD HANDLER'),
              const SizedBox(height: ZapSpacing.md),
              _BatteryCard(profile: batteryProfile),
              const SizedBox(height: ZapSpacing.md),
              _BatteryTierTable(active: batteryProfile.tier),
              const SizedBox(height: ZapSpacing.md),
              _BatteryControls(
                onLevel: (lvl) =>
                    ref.read(batteryServiceProvider).injectLevel(lvl),
                onRefresh: () async {
                  await ref.read(batteryServiceProvider).refresh();
                  if (mounted) ZapSnackbar.info(context, 'Battery polled');
                },
                onStart: () async {
                  await ref.read(batteryServiceProvider).start();
                  if (mounted) {
                    ZapSnackbar.success(context, 'Battery service started');
                  }
                },
              ),

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

  void _injectGpsFix({required double accuracy}) {
    ref.read(gpsServiceProvider).injectSample(GpsSample(
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          lat: 12.9716,
          lng: 77.5946,
          accuracyM: accuracy,
        ));
    if (mounted) {
      final tag = accuracy <= 50 ? 'good' : 'bad';
      ZapSnackbar.info(context, 'Injected $tag GPS (±${accuracy.toStringAsFixed(0)} m)');
    }
  }

  Future<void> _forceCell() async {
    final sample = await ref
        .read(gpsFallbackCoordinatorProvider)
        .requestFallback(force: true);
    if (!mounted) return;
    if (sample == null) {
      ZapSnackbar.warning(context,
          'Cell estimate unavailable — stub one with the button below.');
    } else {
      ZapSnackbar.success(context,
          'Merged ${sample.provider.wire.toUpperCase()} fix '
          '(±${sample.accuracyM.toStringAsFixed(0)} m)');
    }
  }

  void _stubCell() {
    final svc = ref.read(cellLocationServiceProvider);
    svc.stubNext(svc.syntheticEstimate(
      radiusM: 800,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (mounted) {
      ZapSnackbar.info(context,
          'Next cell estimate will return a synthetic 800 m fix.');
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
            ZapColors.warning.withOpacity(0.14),
            ZapColors.info.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cell_tower_rounded,
                    color: ZapColors.warning, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 8 · DAY 38',
                  intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Fallback · State · Battery',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Cell-tower / WiFi merges into the GPS stream behind a provider tag '
            'when accuracy > 50 m or no fix lands within 90 s. Central 7-state '
            'machine drives every downstream service. Battery breakpoints '
            '(≤ 20 % / ≤ 15 % / ≤ 10 %) selectively disable camera, GPS, and '
            'finally everything except mic VAD.',
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

// ─── Section 1: Fallback ─────────────────────────────────────────────────────

class _FallbackCard extends StatelessWidget {
  final GpsSample? lastEvaluated;
  final int emissions;
  final int lowQualityTriggers;
  final int staleTriggers;
  final int recoveries;
  final int cellAttempts;
  final int cellSuccesses;
  final int cellFailures;
  final bool isAttached;

  const _FallbackCard({
    required this.lastEvaluated,
    required this.emissions,
    required this.lowQualityTriggers,
    required this.staleTriggers,
    required this.recoveries,
    required this.cellAttempts,
    required this.cellSuccesses,
    required this.cellFailures,
    required this.isAttached,
  });

  @override
  Widget build(BuildContext context) {
    final s = lastEvaluated;
    final attachColor = isAttached ? ZapColors.safe : ZapColors.textSecondary;
    final providerColor = s == null
        ? ZapColors.textSecondary
        : (s.provider == GpsProvider.gps
            ? (s.isHighQuality ? ZapColors.safe : ZapColors.warning)
            : ZapColors.info);
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAttached
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                color: attachColor,
                size: 22,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                isAttached ? 'COORDINATOR ATTACHED' : 'COORDINATOR DETACHED',
                style: ZapTypography.labelMedium.copyWith(
                  color: attachColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (s != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: providerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.provider.wire.toUpperCase(),
                    style: ZapTypography.labelSmall.copyWith(
                      color: providerColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          if (s == null)
            Text(
              'No sample evaluated yet — inject a fix or start GPS.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            )
          else ...[
            _kv('Latest', '${s.lat.toStringAsFixed(5)}, ${s.lng.toStringAsFixed(5)}'),
            _kv('Accuracy', '±${s.accuracyM.toStringAsFixed(0)} m'),
            _kv('Quality', s.isHighQuality ? 'HIGH (≤ 50 m)' : 'LOW (> 50 m)'),
            _kv('Provider', s.provider.wire),
          ],
          const SizedBox(height: ZapSpacing.md),
          _kv('Fallback emissions', emissions.toString()),
          _kv('Low-quality triggers', lowQualityTriggers.toString()),
          _kv('Stale-timeout triggers', staleTriggers.toString()),
          _kv('GPS recoveries', recoveries.toString()),
          const SizedBox(height: ZapSpacing.sm),
          _kv('Cell attempts', cellAttempts.toString()),
          _kv('Cell successes', cellSuccesses.toString()),
          _kv('Cell failures', cellFailures.toString()),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => _Kv(k: k, v: v);
}

// ─── Section 2: App State ────────────────────────────────────────────────────

class _AppStateCard extends StatelessWidget {
  final AppState appState;
  final DateTime? countdownStartedAt;
  final bool silentlyEscalating;

  const _AppStateCard({
    required this.appState,
    required this.countdownStartedAt,
    required this.silentlyEscalating,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(appState);
    final remaining = countdownStartedAt == null
        ? null
        : (15 -
                DateTime.now()
                    .difference(countdownStartedAt!)
                    .inSeconds)
            .clamp(0, 15);
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    'LP3 · SILENT SOS',
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
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.warning,
                  ),
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

class _AppStateTransitionButtons extends StatelessWidget {
  final AppState appState;
  final VoidCallback onDcs;
  final VoidCallback onManual;
  final VoidCallback onCancelReal;
  final VoidCallback onCancelDuress;
  final VoidCallback onExpired;
  final VoidCallback onTier1Ack;
  final VoidCallback onResolve;
  final VoidCallback onReturnMonitor;
  final VoidCallback onElevate;
  final VoidCallback onPowerOff;
  final VoidCallback onPowerOn;

  const _AppStateTransitionButtons({
    required this.appState,
    required this.onDcs,
    required this.onManual,
    required this.onCancelReal,
    required this.onCancelDuress,
    required this.onExpired,
    required this.onTier1Ack,
    required this.onResolve,
    required this.onReturnMonitor,
    required this.onElevate,
    required this.onPowerOff,
    required this.onPowerOn,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <_TransitionButton>[
      _TransitionButton('ELEVATE SIGNAL', Icons.signal_cellular_alt_rounded,
          ZapButtonIntent.warning, onElevate),
      _TransitionButton('DCS THRESHOLD', Icons.psychology_rounded,
          ZapButtonIntent.warning, onDcs),
      _TransitionButton('MANUAL TRIGGER', Icons.touch_app_rounded,
          ZapButtonIntent.warning, onManual),
      _TransitionButton('CANCEL · REAL PIN', Icons.password_rounded,
          ZapButtonIntent.safe, onCancelReal),
      _TransitionButton('CANCEL · DURESS PIN', Icons.policy_rounded,
          ZapButtonIntent.danger, onCancelDuress),
      _TransitionButton('ALERT EXPIRED', Icons.timer_off_rounded,
          ZapButtonIntent.danger, onExpired),
      _TransitionButton('TIER-1 ACK', Icons.verified_user_rounded,
          ZapButtonIntent.info, onTier1Ack),
      _TransitionButton('RESOLVE SOS', Icons.health_and_safety_rounded,
          ZapButtonIntent.safe, onResolve),
      _TransitionButton('RETURN TO MONITOR', Icons.refresh_rounded,
          ZapButtonIntent.safe, onReturnMonitor),
      _TransitionButton('POWER OFF', Icons.power_settings_new_rounded,
          ZapButtonIntent.neutral, onPowerOff),
      _TransitionButton('POWER ON', Icons.flash_on_rounded,
          ZapButtonIntent.safe, onPowerOn),
    ];
    return Wrap(
      spacing: ZapSpacing.sm,
      runSpacing: ZapSpacing.sm,
      children: [
        for (final b in buttons)
          ZapButton.outlined(
            label: b.label,
            icon: b.icon,
            intent: b.intent,
            onPressed: b.onPressed,
          ),
      ],
    );
  }
}

class _TransitionButton {
  final String label;
  final IconData icon;
  final ZapButtonIntent intent;
  final VoidCallback onPressed;
  _TransitionButton(this.label, this.icon, this.intent, this.onPressed);
}

class _HistoryCard extends StatelessWidget {
  final List<AppStateTransition> history;
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSITION LOG · ${history.length} entries',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          if (history.isEmpty)
            Text(
              'No transitions yet — tap any button above.',
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

// ─── Section 3: Battery ──────────────────────────────────────────────────────

class _BatteryCard extends StatelessWidget {
  final BatteryProfile profile;
  const _BatteryCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tierColor = switch (profile.tier) {
      BatteryTier.normal        => ZapColors.safe,
      BatteryTier.powerSaver    => ZapColors.warning,
      BatteryTier.proactiveDrop => ZapColors.warning,
      BatteryTier.vadOnly       => ZapColors.danger,
    };
    final pct = profile.level < 0 ? '—' : '${profile.level}%';
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                profile.isCharging
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_5_bar_rounded,
                color: tierColor,
                size: 26,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                pct,
                style: ZapTypography.displaySmall.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  profile.tier.label,
                  style: ZapTypography.labelSmall.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(profile.tier.description,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              )),
          const SizedBox(height: ZapSpacing.md),
          _Kv(k: 'Camera enabled',
              v: profile.cameraEnabled ? 'YES' : 'NO'),
          _Kv(k: 'GPS reduced',
              v: profile.gpsReduced ? 'YES' : 'NO'),
          _Kv(k: 'Proactive drop',
              v: profile.proactiveDropActive ? 'YES' : 'NO'),
          _Kv(k: 'VAD-only mode',
              v: profile.vadOnly ? 'YES' : 'NO'),
          _Kv(k: 'Charging',
              v: profile.isCharging ? 'YES' : 'NO'),
        ],
      ),
    );
  }
}

class _BatteryTierTable extends StatelessWidget {
  final BatteryTier active;
  const _BatteryTierTable({required this.active});

  @override
  Widget build(BuildContext context) {
    final rows = const [
      ('> 20 %', BatteryTier.normal, 'no throttling'),
      ('≤ 20 %', BatteryTier.powerSaver, 'camera off · GPS reduced'),
      ('≤ 15 %', BatteryTier.proactiveDrop, 'proactive drop one level'),
      ('≤ 10 %', BatteryTier.vadOnly, 'VAD only · SOS still works'),
    ];
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      r.$1,
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  SizedBox(
                    width: 120,
                    child: Text(
                      r.$2.label,
                      style: ZapTypography.labelSmall.copyWith(
                        color: r.$2 == active
                            ? ZapColors.warning
                            : ZapColors.textSecondary,
                        fontWeight:
                            r.$2 == active ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.$3,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                  ),
                  if (r.$2 == active)
                    const Icon(Icons.arrow_back_rounded,
                        color: ZapColors.warning, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BatteryControls extends StatelessWidget {
  final void Function(int level) onLevel;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onStart;
  const _BatteryControls({
    required this.onLevel,
    required this.onRefresh,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ZapButton.elevated(
                label: 'START SERVICE',
                icon: Icons.play_arrow_rounded,
                intent: ZapButtonIntent.safe,
                onPressed: onStart,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: ZapButton.outlined(
                label: 'REFRESH',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          children: [
            for (final lvl in const [85, 18, 12, 7])
              ZapButton.outlined(
                label: 'INJECT $lvl%',
                icon: Icons.bolt_rounded,
                onPressed: () => onLevel(lvl),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

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
              width: 150,
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
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
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
