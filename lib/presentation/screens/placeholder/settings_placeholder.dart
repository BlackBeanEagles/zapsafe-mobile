import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Settings',
      icon: Icons.settings_rounded,
      accent: ZapColors.textSecondary,
      dayBuilt: 'Day 96-98',
      summary:
          'Power-user controls. Trigger toggles, notification preferences, DCS sensitivity, evidence retention, accessibility modes.',
      features: [
        'Profile — name, language (15 locales), UI mode',
        'Triggers — enable/disable each of 8 SOS triggers',
        'Notifications — quiet hours, per-type toggles',
        'DCS sensitivity — Low / Medium / High',
        'Evidence — retention period, S3 cloud backup opt-in',
        'Accessibility — High Contrast Mode toggle, font size, Simple Mode',
        'Privacy controls — export data (GDPR), delete account (30d grace)',
      ],
    );
  }
}
