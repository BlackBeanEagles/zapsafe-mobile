/// Day 306 — Production Notification Tiers
///
/// Documents the three-tier banner system added to the production
/// dashboard (`lib/presentation/screens/placeholder/dashboard_placeholder.dart`,
/// route `AppRoutes.dashboard`, `/dashboard` — the real post-onboarding
/// home when `kProductionShell` is true, which is the default). Before
/// Day 306 that file was a static [PlaceholderScaffold] describing the
/// eventual Day 46-50 dashboard in prose; it had no real widgets. Day 306
/// is the first Section F polish day to wire an actual production widget
/// into it rather than just documenting/auditing existing wiring.
///
/// Tiers:
///   • CRITICAL (red)    — battery <10% ([batteryCriticalProvider], real
///     `battery_plus` reading via the Day 38 `BatteryService`) or evidence
///     storage full ([evidenceStorageFullProvider], real sum of
///     `EvidenceFile.sizeBytes` across the Day 82 vault's evidence list
///     against the real Free-tier 50 MB cap from
///     `zapsafe_backend/subscription/models.py`). Must acknowledge — no
///     dismiss/X. Only one shown at a time (battery takes priority over
///     storage). The acknowledgement is persisted via
///     `NotificationTierAckStorage` (SharedPreferences, not Hive — see
///     that file's header for why, following the exact Day 37
///     `GpsStorage` precedent) and is automatically cleared once the
///     underlying condition itself goes false, so a future recurrence
///     surfaces fresh instead of staying suppressed forever.
///   • IMPORTANT (orange) — an unverified Tier-2 contact
///     ([unverifiedTier2ContactProvider], real `contactsProvider` /
///     `isVerified` field). Dismissible for the current app session.
///   • SUGGESTION (blue)  — monthly drill reminder, a local-only 30-day
///     nudge (no backend concept of "reminder shown" exists — real
///     completed drills are tracked separately via
///     `/api/v1/drill/history/`, Day 60).
///
/// Tag: 🟣 POLISH
///
/// Route: AppRoutes.notificationTiersPolish
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/notification_tier_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day306NotificationTiersPolishScreen extends ConsumerWidget {
  const Day306NotificationTiersPolishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(activeNotificationBannersProvider);
    final battery = ref.watch(batteryCriticalProvider);
    final storageBytes = ref.watch(vaultStorageBytesUsedProvider);
    final storageFull = ref.watch(evidenceStorageFullProvider);
    final unverified = ref.watch(unverifiedTier2ContactProvider);

    return Scaffold(
      appBar: AppBar(title: Text('day306_310.notif_tiers_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day306_310.notif_tiers_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Live read of the real condition providers driving the dashboard '
            'banner stack — this screen shares the exact same providers as '
            'the production dashboard, it just also shows the raw numbers.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConditionRow(
                  label: 'Battery critical (<10%)',
                  value: battery,
                ),
                _ConditionRow(
                  label: 'Evidence storage',
                  value: storageFull,
                  detail:
                      '${(storageBytes / (1024 * 1024)).toStringAsFixed(1)} MB / '
                      '${kFreeTierEvidenceCapBytes ~/ (1024 * 1024)} MB (Free tier)',
                ),
                _ConditionRow(
                  label: 'Unverified Tier-2 contact',
                  value: unverified,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text('Active banners (${banners.length})',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          if (banners.isEmpty)
            ZapCard(
              child: Text('No banners active right now — every condition is clear.',
                  style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary)),
            )
          else
            for (final b in banners)
              ZapCard(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Row(
                  children: [
                    ZapBadge(
                      label: b.kind.name.toUpperCase(),
                      intent: switch (b.kind) {
                        NotificationTierKind.critical => ZapBadgeIntent.danger,
                        NotificationTierKind.important => ZapBadgeIntent.warning,
                        NotificationTierKind.suggestion => ZapBadgeIntent.info,
                      },
                      size: ZapBadgeSize.small,
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(b.title,
                          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                    ),
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
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.label, required this.value, this.detail});
  final String label;
  final bool value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Row(
        children: [
          Icon(value ? Icons.error_rounded : Icons.check_circle_outline_rounded,
              size: 16, color: value ? ZapColors.danger : ZapColors.safe),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary)),
                if (detail != null)
                  Text(detail!,
                      style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
