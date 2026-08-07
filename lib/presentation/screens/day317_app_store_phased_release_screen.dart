/// Day 317 — App Store Phased Release Controller
///
/// Apple's real phased release mechanism (App Store Connect → app version
/// → Release Notes/Phased Release section) rolls out to 100% of new
/// installs and updates over 7 real calendar days on this exact fixed
/// schedule: Day 1: 1%, Day 2: 2%, Day 3: 5%, Day 4: 10%, Day 5: 20%,
/// Day 6: 50%, Day 7: 100%. It cannot be customized — Apple does not
/// expose an arbitrary-percentage API the way this screen's Day 316
/// sibling documents Play Console's manual staged rollout. Users who
/// already have the app can always update manually regardless of phase.
///
/// This screen renders that fixed real schedule as a day-by-day table,
/// a TestFlight group mapping (internal / beta / production — the three
/// real distribution tiers App Store Connect exposes), and exports the
/// whole runbook as Markdown via the clipboard (no share_plus dependency
/// in this repo yet, so "share" here means a real clipboard export the
/// developer can paste into Notion/Slack/a PR description — consistent
/// with the Clipboard.setData pattern already used across Days 1/166/311-316).
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.appStorePhasedRelease
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class _PhaseDay {
  const _PhaseDay(this.day, this.percent);
  final int day;
  final int percent;
}

/// Apple's real, fixed 7-day phased release schedule. Cannot be edited —
/// unlike Day 316's Play Console simulation, this isn't a percentage a
/// developer chooses; it is exactly this sequence, every time.
const _kPhaseSchedule = [
  _PhaseDay(1, 1),
  _PhaseDay(2, 2),
  _PhaseDay(3, 5),
  _PhaseDay(4, 10),
  _PhaseDay(5, 20),
  _PhaseDay(6, 50),
  _PhaseDay(7, 100),
];

class _TestFlightGroup {
  const _TestFlightGroup({required this.name, required this.tier, required this.description});
  final String name;
  final String tier;
  final String description;
}

const _kTestFlightGroups = [
  _TestFlightGroup(
    name: 'Internal Testers',
    tier: 'Internal',
    description: 'Up to 100 App Store Connect users on the team. No Apple review needed — builds are '
        'available within minutes of upload. Used for smoke-testing every build before it reaches External.',
  ),
  _TestFlightGroup(
    name: 'Beta — EU Early Access',
    tier: 'External',
    description: 'Up to 10,000 external testers. Requires one Apple Beta App Review (usually <24h) per build. '
        'Used to validate the Day 314/315 EU localization pack with real EU-region devices before Production.',
  ),
  _TestFlightGroup(
    name: 'Production (App Store)',
    tier: 'Production',
    description: 'The public release, gated by the standard App Review, then released under the 7-day '
        'phased schedule above (or immediately, if phased release is turned off for that version).',
  ),
];

String _buildMarkdownRunbook() {
  final buffer = StringBuffer();
  buffer.writeln('# ZapSafe — App Store Phased Release Runbook (Day 317)');
  buffer.writeln();
  buffer.writeln('## Fixed 7-day schedule (Apple-controlled, not editable)');
  buffer.writeln();
  buffer.writeln('| Day | Rollout % |');
  buffer.writeln('|-----|-----------|');
  for (final p in _kPhaseSchedule) {
    buffer.writeln('| Day ${p.day} | ${p.percent}% |');
  }
  buffer.writeln();
  buffer.writeln('Users who already have the app installed can always update manually '
      'to the new version at any phase, regardless of the phased-release percentage.');
  buffer.writeln();
  buffer.writeln('## TestFlight group mapping');
  buffer.writeln();
  for (final g in _kTestFlightGroups) {
    buffer.writeln('### ${g.name} (${g.tier})');
    buffer.writeln(g.description);
    buffer.writeln();
  }
  buffer.writeln('## Manual steps in App Store Connect');
  buffer.writeln();
  buffer.writeln('1. App Store Connect -> App -> TestFlight -> upload build via Xcode/Transporter.');
  buffer.writeln('2. Internal Testers group gets it automatically once processing completes.');
  buffer.writeln('3. Add to the External "Beta - EU Early Access" group; submit for Beta App Review.');
  buffer.writeln('4. Once validated, App Store -> "+ Version" -> attach the same build.');
  buffer.writeln('5. In the version\'s "Phased Release for Automatic Updates" section, toggle it ON.');
  buffer.writeln('6. Submit for App Review. On approval, the 7-day schedule above starts automatically.');
  buffer.writeln('7. Pause or resume phased release anytime from the same section if a regression is found.');
  return buffer.toString();
}

class Day317AppStorePhasedReleaseScreen extends StatelessWidget {
  const Day317AppStorePhasedReleaseScreen({super.key});

  void _exportRunbook(BuildContext context) {
    final markdown = _buildMarkdownRunbook();
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Runbook copied as Markdown — paste into Notion/Slack/a PR')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.app_store_phased_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Apple\'s phased release schedule is fixed — 7 real calendar days, '
                    'not a percentage the developer chooses. Users with the app '
                    'already installed can always update manually at any phase.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day311_320.fixed_schedule'.tr(),
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.md),
          ZapCard(
            child: Column(
              children: [
                for (var i = 0; i < _kPhaseSchedule.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == _kPhaseSchedule.length - 1 ? 0 : ZapSpacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text('Day ${_kPhaseSchedule[i].day}',
                              style: ZapTypography.bodyMedium
                                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _kPhaseSchedule[i].percent / 100,
                              minHeight: 10,
                              backgroundColor: ZapColors.bgSurface,
                              valueColor: AlwaysStoppedAnimation(
                                _kPhaseSchedule[i].percent == 100 ? ZapColors.safe : ZapColors.info,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        SizedBox(
                          width: 48,
                          child: Text('${_kPhaseSchedule[i].percent}%',
                              textAlign: TextAlign.right,
                              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day311_320.testflight_groups'.tr(),
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.md),
          for (final g in _kTestFlightGroups)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(g.name,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                      ),
                      ZapBadge(
                        label: g.tier,
                        intent: g.tier == 'Production'
                            ? ZapBadgeIntent.safe
                            : g.tier == 'External'
                                ? ZapBadgeIntent.warning
                                : ZapBadgeIntent.info,
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(g.description,
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Export runbook as Markdown',
            icon: Icons.description_rounded,
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => _exportRunbook(context),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
