import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Dashboard',
      icon: Icons.shield_rounded,
      accent: ZapColors.danger,
      dayBuilt: 'Day 46-50',
      summary:
          'The home screen — shows the user their current safety mode, Protection Score, and a giant SOS button. Adapts to all 7 app states.',
      features: [
        'Mode status card — expandable header with battery + DCS (Day 204 ModeStatusCard)',
        'Center SOS button — 80dp, 2s long-press ring (Day 203 SosLongPressRingButton)',
        'Protection Score ring (uses the Day 4 widget!)',
        'Quick "Start Journey" shortcut',
        'Inline action banners — low battery, missing Tier 2, drill due '
        '(see Day 202 DashboardNotificationBanner widget)',
        'Adapts to Simple Mode — only SOS button + mode label visible',
      ],
    );
  }
}
