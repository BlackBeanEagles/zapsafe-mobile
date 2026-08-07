/// Day 308 — Production Persistent Status Card.
///
/// A collapsible card on the production dashboard, real signals only:
///   • Collapsed: mode badge ([appStateProvider], Day 38 state machine) +
///     battery % ([batteryProfileProvider], real `battery_plus` reading)
///     + last DCS score (parsed from the real
///     `AppStateNotifier.history` transition log — the same real `cause`
///     strings `TriggerOrchestrator.dispatchDcs` writes, e.g.
///     `"DCS vote · scream=0.42"` — rather than subscribing to the live
///     `dcsStreamProvider` mic/TFLite pipeline, which would start real
///     microphone capture just by mounting the dashboard. That pipeline
///     is deliberately *not* auto-started here; this card only reads
///     history that already exists from real triggers).
///   • Expanded (tap only — no drag-to-dismiss): GPS quality (real
///     `GpsService.latest?.isHighQuality`, Day 37 — read-only, does not
///     start GPS polling), monitoring state detail (silently-escalating
///     LP3 flag), subscription tier + premium badge (real
///     `subscriptionStatusProvider`, Day 303 — only watched once the
///     card is actually expanded, so it doesn't fire a network call on
///     every dashboard mount).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/app_state.dart';
import '../../domain/providers/app_state_provider.dart';
import '../../domain/providers/battery_providers.dart';
import '../../domain/providers/gps_providers.dart';
import '../../domain/providers/premium_subscription_providers.dart';
import 'premium_tier_badge.dart';
import 'zap_badge.dart';
import 'zap_card.dart';

class PersistentStatusCard extends ConsumerStatefulWidget {
  const PersistentStatusCard({super.key});

  @override
  ConsumerState<PersistentStatusCard> createState() => _PersistentStatusCardState();
}

class _PersistentStatusCardState extends ConsumerState<PersistentStatusCard> {
  bool _expanded = false;

  String? _lastDcsLabel(List<AppStateTransition> history) {
    for (final t in history.reversed) {
      if (t.cause.startsWith('DCS')) return t.cause;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final battery = ref.watch(batteryProfileProvider);
    final history = ref.read(appStateProvider.notifier).history;
    final lastDcs = _lastDcsLabel(history);
    final silentlyEscalating = ref.read(appStateProvider.notifier).silentlyEscalating;

    return ZapCard(
      // No drag-to-dismiss — only onTap toggles expansion, per Day 308 spec.
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ZapBadge(label: appState.label, intent: _modeIntent(appState), size: ZapBadgeSize.small),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(
                      battery.isCharging ? Icons.battery_charging_full_rounded : _batteryIcon(battery.level),
                      size: 16,
                      color: battery.level >= 0 && battery.level < 20
                          ? ZapColors.warning
                          : ZapColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      battery.level < 0 ? '—' : '${battery.level}%',
                      style: ZapTypography.labelMedium.copyWith(color: ZapColors.textPrimary),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    const Icon(Icons.graphic_eq_rounded, size: 16, color: ZapColors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        lastDcs ?? 'No DCS score yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: ZapColors.textMuted,
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: ZapSpacing.xl, color: ZapColors.divider),
            _ExpandedRows(silentlyEscalating: silentlyEscalating),
          ],
        ],
      ),
    );
  }

  IconData _batteryIcon(int level) {
    if (level < 0) return Icons.battery_unknown_rounded;
    if (level < 10) return Icons.battery_alert_rounded;
    if (level < 50) return Icons.battery_3_bar_rounded;
    return Icons.battery_full_rounded;
  }

  ZapBadgeIntent _modeIntent(AppState s) => switch (s) {
        AppState.idle => ZapBadgeIntent.neutral,
        AppState.monitoring => ZapBadgeIntent.safe,
        AppState.elevated => ZapBadgeIntent.warning,
        AppState.alertPending || AppState.sosActive || AppState.escalating =>
          ZapBadgeIntent.danger,
        AppState.postIncident => ZapBadgeIntent.info,
      };
}

/// Watches [gpsServiceProvider] / [subscriptionStatusProvider] only while
/// mounted — i.e. only while the card is actually expanded — so the
/// (real, network-backed) subscription status call doesn't fire on every
/// dashboard build.
class _ExpandedRows extends ConsumerWidget {
  const _ExpandedRows({required this.silentlyEscalating});
  final bool silentlyEscalating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gpsSample = ref.watch(gpsServiceProvider).latest;
    final subStatus = ref.watch(subscriptionStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(
          label: 'GPS quality',
          value: gpsSample == null
              ? 'No fix yet'
              : gpsSample.isHighQuality
                  ? 'High (±${gpsSample.accuracyM.toStringAsFixed(0)}m)'
                  : 'Low (±${gpsSample.accuracyM.toStringAsFixed(0)}m)',
        ),
        _Row(
          label: 'Monitoring state',
          value: silentlyEscalating
              ? '${_stateLabel(ref)} (LP3 silent escalation active)'
              : _stateLabel(ref),
        ),
        subStatus.when(
          data: (s) => Row(
            children: [
              Expanded(
                child: Text('Tier',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
              ),
              PremiumTierBadge(
                planLabel: s.plan.apiValue.toUpperCase(),
                isPremium: s.hasPremiumBenefits,
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => const _Row(label: 'Tier', value: 'Unavailable offline'),
        ),
      ],
    );
  }

  String _stateLabel(WidgetRef ref) => ref.read(appStateProvider).label;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
          ),
          Text(value, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary)),
        ],
      ),
    );
  }
}
