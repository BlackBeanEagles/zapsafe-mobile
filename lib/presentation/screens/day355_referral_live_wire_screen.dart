/// Day 355 — Referral Production Wire
///
/// Wires Day 224/225's mock referral screens (`day224_referral_invite_
/// screen.dart`, `day225_referral_rewards_screen.dart` — read first: mock
/// share sheet, hardcoded `ZAP-HRIDYA42` code, +10 pts per completion) to
/// the REAL backend endpoints, verified real by reading
/// `zapsafe_backend/referral/views.py` + `referral/serializers.py` +
/// `referral/models.py` directly:
///
///   GET /api/v1/referral/code/   -> {"code","link"}
///   GET /api/v1/referral/stats/  -> {"invited","completed","bonus_points"}
///
/// Both endpoints are real, working Django views backed by real
/// `ReferralCode`/`ReferralEvent` models (Days 206-207) — not stubs.
///
/// Two real details Day 224's mock got wrong, corrected here:
///   1. Bonus points per completed referral is 50
///      (`POINTS_PER_COMPLETED_REFERRAL` in `referral/models.py`), not the
///      +10 Day 224's mock UI advertised.
///   2. Both endpoints are gated behind the `referral` feature flag
///      (`is_feature_enabled("referral")`, Day 240) — when off, both
///      return `403 {"code": "FEATURE_DISABLED"}`. This screen surfaces
///      that explicitly instead of treating it as a generic error, since
///      it's an expected, documented backend state, not a bug.
///
/// Tag: 🔵 EXISTING-API — real backend, real wire.
///
/// Route: [AppRoutes.referralLiveWire] → `/day-355-referral-live-wire`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/referral_api_service.dart';
import '../../domain/providers/referral_api_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day355ReferralLiveWireScreen extends ConsumerWidget {
  const Day355ReferralLiveWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(referralCodeRawProvider);
    final stats = ref.watch(referralStatsRawProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.referral_wire_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🔵 REAL API · Section K Day 5/10 · GET /api/v1/referral/code/ '
                    'and .../stats/ both real — gated behind the `referral` feature '
                    'flag server-side. Bonus is 50 pts/completion (real), not the '
                    '+10 Day 224\'s mock UI showed.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.referral_wire_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xl),
          Text('GET /api/v1/referral/code/',
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
          const SizedBox(height: ZapSpacing.sm),
          code.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorCard(error: e, onRetry: () => ref.invalidate(referralCodeRawProvider)),
            data: (c) => ZapCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.code,
                            style: ZapTypography.headlineSmall
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w900)),
                        Text(c.link, style: ZapTypography.labelSmall.copyWith(color: ZapColors.info)),
                      ],
                    ),
                  ),
                  const ZapBadge(label: 'LIVE', intent: ZapBadgeIntent.safe, size: ZapBadgeSize.small),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('GET /api/v1/referral/stats/',
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
          const SizedBox(height: ZapSpacing.sm),
          stats.when(
            loading: () => const _Loading(),
            error: (e, _) => _ErrorCard(error: e, onRetry: () => ref.invalidate(referralStatsRawProvider)),
            data: (s) => Row(
              children: [
                Expanded(child: _StatTile(label: 'Invited', value: '${s.invited}', color: ZapColors.info)),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(child: _StatTile(label: 'Completed', value: '${s.completed}', color: ZapColors.safe)),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                    child: _StatTile(
                        label: 'Bonus pts', value: '+${s.bonusPoints}', color: ZapColors.warning)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.tonal(
            label: 'Open Day 224 invite screen',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.referralInvite),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.tonal(
            label: 'Open Day 225 rewards screen',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.referralRewards),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.3),
      child: Column(
        children: [
          Text(value, style: ZapTypography.headlineSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: ZapTypography.labelSmall.copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: ZapSpacing.md),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  String get _label {
    if (error is ReferralFeatureDisabledException) {
      return 'Referral is currently disabled server-side '
          '(FEATURE_DISABLED) — this is an expected backend state, not a '
          'wiring bug.';
    }
    final s = error.toString();
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('500')) return 'Server error — tap retry.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Request failed: $s';
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          Icon(
            error is ReferralFeatureDisabledException ? Icons.toggle_off_rounded : Icons.error_outline,
            color: error is ReferralFeatureDisabledException ? ZapColors.warning : ZapColors.danger,
            size: 18,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              _label,
              style: ZapTypography.bodySmall.copyWith(
                color: error is ReferralFeatureDisabledException ? ZapColors.warning : ZapColors.danger,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
