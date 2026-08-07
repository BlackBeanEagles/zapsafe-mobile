/// Day 323 — Journey Mode dashboard card.
///
/// 🟡 MOCK-NOW. Shows a real 0-100 safety-confidence meter computed by
/// [computeJourneyRiskScore] (`journey_risk_heuristic.dart`) from real
/// [GpsSample] fields (speed, GPS quality, time-of-day) — not a random
/// number and not (yet) a server-computed ML score, since the imagined
/// `GET /api/v1/journey/session/{id}/risk-score/` contract does not exist
/// on the real backend (verified against `zapsafe_backend/journey/urls.py`
/// — see the heuristic file's header for the full honest breakdown).
///
/// This card reuses [ProtectionScoreRing] (`protection_score_ring.dart`)
/// as the confidence gauge rather than building a second ring painter —
/// same 0-100 gauge, different label/data source.
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/gps_sample.dart';
import '../../domain/journey/journey_risk_heuristic.dart';
import 'protection_score_ring.dart';
import 'zap_badge.dart';
import 'zap_card.dart';

class JourneyModeCard extends StatelessWidget {
  const JourneyModeCard({
    super.key,
    this.recentSamples = const [],
    this.now,
    this.onTap,
  });

  final List<GpsSample> recentSamples;
  final DateTime? now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final result = computeJourneyRiskScore(
      recentSamples: recentSamples,
      now: now,
    );

    return ZapCard(
      onTap: onTap,
      child: Row(
        children: [
          ProtectionScoreRing(
            score: result.confidenceScore,
            size: 72,
            strokeWidth: 6,
            label: 'SAFE',
            duration: const Duration(milliseconds: 600),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Journey Mode',
                        style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: ZapSpacing.sm),
                    const ZapBadge(
                      label: 'MOCK-NOW',
                      intent: ZapBadgeIntent.warning,
                      size: ZapBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Safety confidence ${result.confidenceScore}/100 · '
                  'local heuristic, not yet server-scored',
                  style: ZapTypography.bodySmall
                      .copyWith(color: ZapColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: ZapColors.textMuted),
        ],
      ),
    );
  }
}
