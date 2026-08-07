/// Dashboard inline notification banners — Day 202
///
/// Three-tier hierarchy for the home dashboard:
/// - Critical (red): must acknowledge — cannot dismiss with X
/// - Important (orange): dismissible
/// - Suggestion (blue): low-priority, dismissible
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// Priority tier for dashboard inline banners.
enum DashboardNotificationTier {
  critical,
  important,
  suggestion,
}

/// Model for one dashboard notification.
class DashboardNotificationData {
  final String id;
  final DashboardNotificationTier tier;
  final String title;
  final String message;
  final String? actionLabel;

  const DashboardNotificationData({
    required this.id,
    required this.tier,
    required this.title,
    required this.message,
    this.actionLabel,
  });
}

/// Single inline notification banner for the ZapSafe dashboard.
class DashboardNotificationBanner extends StatelessWidget {
  final DashboardNotificationData data;
  final VoidCallback? onDismiss;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onAction;

  const DashboardNotificationBanner({
    super.key,
    required this.data,
    this.onDismiss,
    this.onAcknowledge,
    this.onAction,
  });

  Color get _accent {
    switch (data.tier) {
      case DashboardNotificationTier.critical:
        return ZapColors.danger;
      case DashboardNotificationTier.important:
        return ZapColors.warning;
      case DashboardNotificationTier.suggestion:
        return ZapColors.info;
    }
  }

  String get _tierLabel {
    switch (data.tier) {
      case DashboardNotificationTier.critical:
        return 'CRITICAL';
      case DashboardNotificationTier.important:
        return 'IMPORTANT';
      case DashboardNotificationTier.suggestion:
        return 'TIP';
    }
  }

  bool get _isCritical =>
      data.tier == DashboardNotificationTier.critical;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$_tierLabel: ${data.title}. ${data.message}',
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
            color: _accent.withOpacity(_isCritical ? 0.7 : 0.45),
            width: _isCritical ? 2 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(ZapSpacing.radius),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ZapSpacing.md,
                    ZapSpacing.md,
                    _isCritical ? ZapSpacing.md : ZapSpacing.xs,
                    ZapSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tierLabel,
                              style: TextStyle(
                                color: _accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Expanded(
                            child: Text(
                              data.title,
                              style: const TextStyle(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!_isCritical && onDismiss != null)
                            Semantics(
                              label: 'Dismiss ${data.title}',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20),
                                color: ZapColors.textSecondary,
                                onPressed: onDismiss,
                                constraints: const BoxConstraints(
                                  minWidth: 75,
                                  minHeight: 75,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(
                        data.message,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if (_isCritical && onAcknowledge != null) ...[
                        const SizedBox(height: ZapSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            label: 'Acknowledge ${data.title}',
                            button: true,
                            child: FilledButton(
                              onPressed: onAcknowledge,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(120, 75),
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Got it'),
                            ),
                          ),
                        ),
                      ] else if (data.actionLabel != null &&
                          onAction != null) ...[
                        const SizedBox(height: ZapSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            label: data.actionLabel,
                            button: true,
                            child: TextButton(
                              onPressed: onAction,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(75, 75),
                                foregroundColor: _accent,
                              ),
                              child: Text(data.actionLabel!),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders active notifications sorted critical → important → suggestion.
class DashboardNotificationStack extends StatelessWidget {
  final List<DashboardNotificationData> notifications;
  final void Function(String id)? onDismiss;
  final void Function(String id)? onAcknowledge;
  final void Function(String id)? onAction;

  const DashboardNotificationStack({
    super.key,
    required this.notifications,
    this.onDismiss,
    this.onAcknowledge,
    this.onAction,
  });

  static int _sortKey(DashboardNotificationTier t) {
    switch (t) {
      case DashboardNotificationTier.critical:
        return 0;
      case DashboardNotificationTier.important:
        return 1;
      case DashboardNotificationTier.suggestion:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...notifications]
      ..sort((a, b) => _sortKey(a.tier).compareTo(_sortKey(b.tier)));

    if (sorted.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sorted.map((n) {
        return DashboardNotificationBanner(
          key: ValueKey(n.id),
          data: n,
          onDismiss: onDismiss == null ? null : () => onDismiss!(n.id),
          onAcknowledge:
              onAcknowledge == null ? null : () => onAcknowledge!(n.id),
          onAction: onAction == null ? null : () => onAction!(n.id),
        );
      }).toList(),
    );
  }
}
