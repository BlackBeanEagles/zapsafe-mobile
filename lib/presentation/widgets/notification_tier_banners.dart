/// Day 306 — Production Notification Tiers banner stack.
///
/// Renders [activeNotificationBannersProvider] (see
/// `notification_tier_providers.dart`) as a vertical stack of tier
/// banners on the production dashboard. Critical banners require an
/// explicit acknowledge tap (no dismiss/X); Important and Suggestion
/// banners are dismissible. All action buttons are ≥48dp tall — this
/// repo's own AAA touch-target standard ([ZapSpacing.minTouchTarget]) is
/// 75dp, well above the Day 306 48dp acceptance floor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/notification_tier_providers.dart';
import 'zap_card.dart';

class NotificationTierBannerStack extends ConsumerStatefulWidget {
  const NotificationTierBannerStack({super.key});

  @override
  ConsumerState<NotificationTierBannerStack> createState() =>
      _NotificationTierBannerStackState();
}

class _NotificationTierBannerStackState
    extends ConsumerState<NotificationTierBannerStack> {
  /// Session-only dismissals for Important banners — re-appears next app
  /// session by design (a real contact verification is the correct fix,
  /// not a longer snooze).
  final Set<String> _sessionDismissed = {};

  @override
  Widget build(BuildContext context) {
    // Keeps the ack-clearing side-effect bridge alive (see its doc comment).
    ref.watch(notificationTierAckBridgeProvider);

    final banners = ref
        .watch(activeNotificationBannersProvider)
        .where((b) => !_sessionDismissed.contains(b.id))
        .toList();

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final banner in banners)
          Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: _TierBannerCard(
              banner: banner,
              onAcknowledge: banner.kind == NotificationTierKind.critical
                  ? () => ref.read(notificationTierAckProvider.notifier).acknowledge(banner.id)
                  : null,
              onDismiss: banner.kind == NotificationTierKind.important
                  ? () => setState(() => _sessionDismissed.add(banner.id))
                  : banner.kind == NotificationTierKind.suggestion
                      ? () async {
                          await ref.read(drillReminderStorageProvider).dismiss();
                          ref.invalidate(drillReminderDueProvider);
                        }
                      : null,
            ),
          ),
      ],
    );
  }
}

class _TierBannerCard extends StatelessWidget {
  const _TierBannerCard({
    required this.banner,
    this.onAcknowledge,
    this.onDismiss,
  });

  final NotificationTierBanner banner;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDismiss;

  (Color, IconData, String) get _style => switch (banner.kind) {
        NotificationTierKind.critical =>
          (ZapColors.danger, Icons.error_rounded, 'CRITICAL'),
        NotificationTierKind.important =>
          (ZapColors.warning, Icons.warning_amber_rounded, 'IMPORTANT'),
        NotificationTierKind.suggestion =>
          (ZapColors.info, Icons.lightbulb_outline_rounded, 'SUGGESTION'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _style;
    final isCritical = banner.kind == NotificationTierKind.critical;

    return Semantics(
      liveRegion: isCritical,
      label: '$label: ${banner.title}',
      child: ZapCard(
        backgroundColor: color.withOpacity(0.08),
        borderColor: color.withOpacity(isCritical ? 0.5 : 0.3),
        borderWidth: isCritical ? 1.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: ZapTypography.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner.title,
                        style: ZapTypography.bodyMedium.copyWith(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null && !isCritical)
                  _TouchTarget(
                    tooltip: 'Dismiss',
                    icon: Icons.close_rounded,
                    onTap: onDismiss!,
                  ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              banner.message,
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (onAcknowledge != null) ...[
              const SizedBox(height: ZapSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onAcknowledge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                  ),
                  child: const Text('ACKNOWLEDGE',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A ≥48×48dp tap target wrapping a small icon — used for the Important /
/// Suggestion dismiss control, which is visually an 18dp glyph but must
/// still meet the Day 306 48dp+ acceptance criterion.
class _TouchTarget extends StatelessWidget {
  const _TouchTarget({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: 18, color: ZapColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
