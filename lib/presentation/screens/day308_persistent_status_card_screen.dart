/// Day 308 — Production Persistent Status Card
///
/// Meta/QA screen for [PersistentStatusCard]
/// (`lib/presentation/widgets/persistent_status_card.dart`) — the real
/// widget now wired into the production dashboard (`AppRoutes.dashboard`,
/// `/dashboard`), directly above the Day 307 SOS button with an explicit
/// >=16dp gap so the two never overlap (Day 308 acceptance criterion).
///
/// Collapsed row (always real, no fabricated numbers):
///   • Mode badge — `appStateProvider` (Day 38 seven-state machine).
///   • Battery % — `batteryProfileProvider` (Day 38 `BatteryService`,
///     real `battery_plus` reading).
///   • Last DCS score — parsed from `AppStateNotifier.history`'s real
///     `cause` strings written by `TriggerOrchestrator.dispatchDcs`
///     (Day 39), e.g. `"DCS vote · scream=0.42"`. Deliberately does
///     *not* subscribe to the live `dcsStreamProvider` mic/TFLite
///     pipeline — doing so would start real microphone capture just by
///     mounting the dashboard, which is out of scope for a status-card
///     polish task and would be a surprising side effect to ship
///     silently.
///
/// Expanded (tap only — no drag-to-dismiss, per spec):
///   • GPS quality — reads `GpsService.latest` (Day 37), a passive getter
///     that does **not** start GPS polling on its own.
///   • Monitoring state detail, including the real LP3
///     `silentlyEscalating` flag.
///   • Subscription tier + premium badge — real `subscriptionStatusProvider`
///     (Day 303, live `GET /api/v1/subscription/status/`). Only watched
///     while the card is actually expanded (see the widget's own
///     `_ExpandedRows` sub-widget), so it doesn't fire a network call on
///     every dashboard build — shows "Unavailable offline" gracefully if
///     the backend can't be reached rather than crashing or hanging.
///
/// Tag: 🟣 POLISH
///
/// Route: AppRoutes.statusCardPolish
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/persistent_status_card.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day308PersistentStatusCardScreen extends StatelessWidget {
  const Day308PersistentStatusCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day306_310.status_card_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day306_310.status_card_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Tap the card below to expand it — same real PersistentStatusCard '
            'widget live on the dashboard, reading the same real providers.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const PersistentStatusCard(),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Design notes',
                    style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary)),
                const SizedBox(height: ZapSpacing.sm),
                _bullet('No drag-to-dismiss — tap toggles expand/collapse only'),
                _bullet('Placed in normal document flow, not a floating Stack overlay, so a >=16dp gap from the SOS button is guaranteed by layout, not by manual coordinate math'),
                _bullet('Rebuilds automatically on every AppStateNotifier transition (widget watches appStateProvider)'),
                _bullet('Subscription tier network call only fires once expanded'),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open production dashboard',
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Back to integration audit',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: ZapColors.textMuted, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(text,
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4)),
            ),
          ],
        ),
      );
}
