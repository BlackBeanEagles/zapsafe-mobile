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
        'Mode badge — MINIMAL / MONITORING / ELEVATED / HIGH / CRITICAL',
        'Center SOS button — 80dp, pulsates red in CRITICAL mode',
        'Protection Score ring (uses the Day 4 widget!)',
        'Quick "Start Journey" shortcut',
        'Inline action banners (low battery, missing Tier 2, drill due)',
        'Adapts to Simple Mode — only SOS button + mode label visible',
      ],
    );
  }
}
