/// Day 316 — Play Console Staged Rollout Controller
///
/// There is no Google Play Developer API endpoint that lets an app
/// control its own staged rollout percentage — release management is a
/// Play Console (or `bundletool`/Play Developer API for CI, but never
/// from inside the shipped app itself) manual action. This screen is a
/// FRONTEND-ONLY simulation + documentation/checklist tool: the stage
/// tracker below is local in-memory state for demonstrating the
/// 5% → 10% → 25% → 50% → 100% progression and does not call any real
/// Play Console API. Every "advance stage" tap is clearly local-only.
///
/// Country targeting sequence: India first (primary market, Razorpay
/// billing already live), then an EU bundle (the 27 member states from
/// Day 311's `emergency_eu.json`) once the Day 314 EU listing copy is
/// approved.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.playStagedRollout
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kStages = [5, 10, 25, 50, 100];

class _ManualStep {
  const _ManualStep(this.text);
  final String text;
}

const _kManualSteps = [
  _ManualStep('Play Console → your app → Release → Production → "Create new release".'),
  _ManualStep('Upload the signed .aab, fill release notes, save.'),
  _ManualStep('Under "Rollout percentage", set the initial stage (5% recommended for a first release).'),
  _ManualStep('Review and roll out to Production — Google reviews before the rollout actually starts serving.'),
  _ManualStep('Monitor Android Vitals (crash rate, ANR rate) for at least 24-48h before advancing.'),
  _ManualStep('To advance: Release → Production → the active release → "Update rollout" → pick next percentage.'),
  _ManualStep('Country targeting: Release → Production → "Countries / regions" tab — add/remove markets per stage.'),
  _ManualStep('Halting: "Halt rollout" pauses at the current percentage without a new release; existing installs keep their version.'),
];

class Day316PlayStagedRolloutScreen extends StatefulWidget {
  const Day316PlayStagedRolloutScreen({super.key});

  @override
  State<Day316PlayStagedRolloutScreen> createState() => _Day316PlayStagedRolloutScreenState();
}

class _Day316PlayStagedRolloutScreenState extends State<Day316PlayStagedRolloutScreen> {
  int _stageIndex = 0;
  bool _indiaLive = true;
  bool _euLive = false;

  int get _currentPercent => _kStages[_stageIndex];
  bool get _isFinalStage => _stageIndex == _kStages.length - 1;

  void _advance() {
    if (_isFinalStage) return;
    setState(() => _stageIndex++);
  }

  void _reset() {
    setState(() {
      _stageIndex = 0;
      _indiaLive = true;
      _euLive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.play_rollout_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'There is no Google Play Developer API for controlling rollout '
                    'percentage from inside the app itself. Everything below the '
                    'stage tracker is a local simulation for planning purposes — '
                    'the real action happens manually in Play Console (steps below).',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day311_320.rollout_stage_tracker'.tr(),
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.md),
          ZapCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _kStages.length; i++)
                      _StageDot(
                        percent: _kStages[i],
                        reached: i <= _stageIndex,
                        current: i == _stageIndex,
                      ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _currentPercent / 100,
                    minHeight: 10,
                    backgroundColor: ZapColors.bgSurface,
                    valueColor: AlwaysStoppedAnimation(_isFinalStage ? ZapColors.safe : ZapColors.info),
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                Text('$_currentPercent% rollout (simulated)',
                    style: ZapTypography.headlineSmall
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: _isFinalStage ? '100% — fully rolled out' : 'Simulate: advance to ${_kStages[_stageIndex + 1]}%',
                  icon: Icons.trending_up_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed: _isFinalStage ? null : _advance,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Reset simulation',
            icon: Icons.refresh_rounded,
            onPressed: _reset,
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day311_320.country_targeting'.tr(),
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.md),
          ZapCard(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('India (primary market)',
                          style: ZapTypography.bodyMedium
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                      Text('Stage 1 — Razorpay billing already live for this market.',
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _indiaLive,
                  onChanged: (v) => setState(() => _indiaLive = v),
                  activeColor: ZapColors.safe,
                ),
              ],
            ),
          ),
          ZapCard(
            child: Row(
              children: [
                const Text('🇪🇺', style: TextStyle(fontSize: 22)),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EU bundle (27 member states)',
                          style: ZapTypography.bodyMedium
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                      Text('Stage 2 — added once Day 314 EU listing copy is approved. '
                          'Country list matches Day 311\'s emergency_eu.json.',
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: _euLive,
                  onChanged: (v) => setState(() => _euLive = v),
                  activeColor: ZapColors.safe,
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day311_320.manual_steps'.tr(),
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.md),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _kManualSteps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == _kManualSteps.length - 1 ? 0 : ZapSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ZapBadge(label: '${i + 1}', intent: ZapBadgeIntent.info, size: ZapBadgeSize.small),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Text(_kManualSteps[i].text,
                              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.percent, required this.reached, required this.current});
  final int percent;
  final bool reached;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = reached ? ZapColors.safe : ZapColors.textMuted;
    return Column(
      children: [
        Container(
          width: current ? 36 : 28,
          height: current ? 36 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? color.withOpacity(0.15) : ZapColors.bgSurface,
            border: Border.all(color: color, width: current ? 2.5 : 1.5),
          ),
          child: Center(
            child: reached
                ? Icon(Icons.check_rounded, size: current ? 18 : 14, color: color)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text('$percent%',
            style: ZapTypography.labelMedium.copyWith(
              color: color,
              fontWeight: current ? FontWeight.w800 : FontWeight.w500,
            )),
      ],
    );
  }
}
