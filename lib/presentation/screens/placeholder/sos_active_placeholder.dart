import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class SOSActivePlaceholderScreen extends StatelessWidget {
  const SOSActivePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'SOS Active',
      icon: Icons.warning_amber_rounded,
      accent: ZapColors.danger,
      dayBuilt: 'Day 71-80',
      summary:
          'The critical SOS UI. Intentionally minimal — cannot show the word "SOS" to an attacker (LP27). Pure recording + cancel-PIN field.',
      features: [
        'Near-blank UI — only countdown + PIN entry visible',
        'No sound, no visible camera LED, no audio indicator',
        'Battery level shown (LP15 — battery critical path)',
        'Fake call feature — answer to talk while SOS continues silently',
        'Evidence buffer locking — 6 streams begin uploading hashes',
        'GPS streams every 10 seconds during SOS_ACTIVE state',
        'Duress PIN (LP3) — fake-cancels UI, SOS keeps going on backend',
      ],
    );
  }
}
