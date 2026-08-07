/// Day 358 — shared premium tier badge.
///
/// Before this day, "what tier am I on" rendered with 3+ different visual
/// treatments across the app (see `day358_premium_polish_screen.dart` for
/// the full audit): a plain `Text('Premium', ...)` on Day 91, a custom
/// filled pill on Day 92, and a real `ZapBadge` with a conditional icon on
/// Day 308's persistent status card (the one screen actually wired to the
/// real Day 303 `subscriptionStatusProvider`). This widget standardizes on
/// Day 308's real-data pattern — uppercase plan label, `safe` intent +
/// `workspace_premium` icon only when the plan actually has premium
/// benefits, `neutral` intent otherwise — so every call site renders the
/// same way regardless of which provider system feeds it.
library;

import 'package:flutter/material.dart';

import 'zap_badge.dart';

class PremiumTierBadge extends StatelessWidget {
  const PremiumTierBadge({
    super.key,
    required this.planLabel,
    required this.isPremium,
    this.size = ZapBadgeSize.small,
  });

  /// e.g. "FREE", "PREMIUM", "PREMIUM_PLUS" — caller decides casing source
  /// (this widget does not re-case it, so callers stay in control of
  /// exactly what a plan is called).
  final String planLabel;
  final bool isPremium;
  final ZapBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return ZapBadge(
      label: planLabel,
      intent: isPremium ? ZapBadgeIntent.safe : ZapBadgeIntent.neutral,
      icon: isPremium ? Icons.workspace_premium_rounded : null,
      size: size,
    );
  }
}
