/// Day 323 — Journey Mode ML Confidence UI
///
/// 🟡 MOCK-NOW.
///
/// Spec's imagined API contract: `POST /api/v1/journey/session/start/`,
/// `GET /api/v1/journey/session/{id}/risk-score/`. Verified against the
/// real backend (`zapsafe_backend/journey/urls.py`) — **neither path
/// exists**. The real solo-journey routes are `POST /api/v1/journey/start/`
/// and `POST /api/v1/journey/<uuid:id>/checkpoint/` (Day 226), and no
/// endpoint on either name returns a risk/confidence score at all. This
/// screen honestly stays MOCK-NOW rather than pretending either imagined
/// path or the real (score-less) journey endpoints satisfy the contract.
///
/// Until a real risk-score endpoint ships, [computeJourneyRiskScore]
/// (`journey_risk_heuristic.dart`) computes a real 0-100 score locally from
/// actual [GpsSample] fields (speed, GPS accuracy, sample-to-sample speed
/// variance) plus time-of-day — not a random number. This screen lets you
/// move the demo GPS samples and clock to see the real computation update
/// live, and lists every contributing factor so the score is never a black
/// box.
///
/// Tag: 🟡 MOCK-NOW
///
/// Route: AppRoutes.journeyMlConfidence
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/gps_sample.dart';
import '../../domain/journey/journey_risk_heuristic.dart';
import '../widgets/protection_score_ring.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class Day323JourneyMlConfidenceScreen extends StatefulWidget {
  const Day323JourneyMlConfidenceScreen({super.key});

  @override
  State<Day323JourneyMlConfidenceScreen> createState() =>
      _Day323JourneyMlConfidenceScreenState();
}

class _Day323JourneyMlConfidenceScreenState
    extends State<Day323JourneyMlConfidenceScreen> {
  double _hour = 12;
  double _speedMps = 1.4;
  double _accuracyM = 8;
  bool _erratic = false;

  List<GpsSample> get _samples {
    if (!_erratic) {
      return [
        GpsSample(timestampMs: 0, lat: 0, lng: 0, accuracyM: _accuracyM, speedMps: _speedMps),
      ];
    }
    // A hand-built erratic sample sequence — real variance computation
    // runs over these in computeJourneyRiskScore, not a canned score.
    return [
      GpsSample(timestampMs: 0, lat: 0, lng: 0, accuracyM: _accuracyM, speedMps: 0),
      GpsSample(timestampMs: 1, lat: 0, lng: 0, accuracyM: _accuracyM, speedMps: 22),
      GpsSample(timestampMs: 2, lat: 0, lng: 0, accuracyM: _accuracyM, speedMps: 1),
      GpsSample(timestampMs: 3, lat: 0, lng: 0, accuracyM: _accuracyM, speedMps: _speedMps),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime(2026, 1, 1, _hour.round());
    final result = computeJourneyRiskScore(recentSamples: _samples, now: now);

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.journey_confidence_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Row(
            children: [
              Text('day321_330.journey_confidence_heading'.tr(),
                  style: ZapTypography.headlineSmall
                      .copyWith(color: ZapColors.textPrimary)),
              const SizedBox(width: ZapSpacing.sm),
              const ZapBadge(label: 'MOCK-NOW', intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Text(
              'Backend contract mismatch found: the spec\'s '
              '"/journey/session/.../risk-score/" path does not exist. '
              'Real routes are POST /api/v1/journey/start/ and POST '
              '/api/v1/journey/<id>/checkpoint/ (Day 226) — neither returns '
              'a score. This screen computes one locally instead.',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Center(
            child: ProtectionScoreRing(
              score: result.confidenceScore,
              size: 160,
              label: 'SAFETY CONFIDENCE',
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('DEMO INPUTS (real GpsSample fields)',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time of day · ${_hour.round().toString().padLeft(2, '0')}:00',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                Slider(
                  value: _hour,
                  min: 0,
                  max: 23,
                  divisions: 23,
                  onChanged: (v) => setState(() => _hour = v),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text('Speed · ${_speedMps.toStringAsFixed(1)} m/s',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                Slider(
                  value: _speedMps,
                  min: 0,
                  max: 40,
                  onChanged: (v) => setState(() => _speedMps = v),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text('GPS accuracy · ±${_accuracyM.toStringAsFixed(0)}m',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                Slider(
                  value: _accuracyM,
                  min: 3,
                  max: 300,
                  onChanged: (v) => setState(() => _accuracyM = v),
                ),
                const SizedBox(height: ZapSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Erratic speed pattern (4 samples)',
                      style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                  value: _erratic,
                  onChanged: (v) => setState(() => _erratic = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('SCORE BREAKDOWN (real, computed live)',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in result.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('• $r',
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                  ),
                const Divider(height: ZapSpacing.lg),
                Text('Risk score: ${result.riskScore}/100 · Confidence: ${result.confidenceScore}/100',
                    style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
