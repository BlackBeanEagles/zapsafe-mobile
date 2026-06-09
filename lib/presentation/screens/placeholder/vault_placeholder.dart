import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class VaultPlaceholderScreen extends StatelessWidget {
  const VaultPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Evidence Vault',
      icon: Icons.lock_rounded,
      accent: ZapColors.safe,
      dayBuilt: 'Day 81-85',
      summary:
          'Forensic chain of custody. Each SOS event has 6 forensic streams (audio, video front+rear, IMU, GPS, DCS log) with SHA-256 hashes and 72h immutability.',
      features: [
        'Per-event expansion — see all 6 stream files',
        'Each file shows size, duration, hash preview',
        'Expiry countdown — "30 days remaining, tap to extend"',
        'Vault PIN screen — separate from SOS cancel PIN (LP16)',
        'Cascade: 3 wrong PINs → key rotate, 5 wrong → wipe (LP23)',
        'Tamper flag indicator — red badge if logged',
        'Export options: encrypted ZIP for police, legal PDF',
      ],
    );
  }
}
