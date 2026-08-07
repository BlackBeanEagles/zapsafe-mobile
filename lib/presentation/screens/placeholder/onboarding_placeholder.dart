import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class OnboardingPlaceholderScreen extends StatelessWidget {
  const OnboardingPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Onboarding',
      icon: Icons.rocket_launch_rounded,
      accent: ZapColors.info,
      dayBuilt: 'Day 41-45',
      summary:
          'A 60-second guided setup that turns a new install into a fully-configured safety app. Layer 1 of the privacy-by-default architecture.',
      features: [
        'Step 1 — Choose UI mode (Standard / Simple / High Contrast)',
        'Step 2 — Drop home location pin (geohash-reduced before send)',
        'Step 3 — Add Tier 1 contact (required)',
        'Step 4 — Medical card (skippable — Day 205, +15 score)',
        'Step 5 — Tier 2 contact (skippable — Day 205, +10 score)',
        'Done — Protection Score 40 minimum, 65 if nothing skipped',
        'Phone OTP verification before any data leaves the device',
      ],
    );
  }
}
