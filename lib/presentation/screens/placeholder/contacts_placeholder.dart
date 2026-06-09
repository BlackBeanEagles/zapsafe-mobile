import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '_placeholder_scaffold.dart';

class ContactsPlaceholderScreen extends StatelessWidget {
  const ContactsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScaffold(
      title: 'Contacts',
      icon: Icons.people_alt_rounded,
      accent: ZapColors.info,
      dayBuilt: 'Day 51-55',
      summary:
          'Manage emergency contacts across Tier 1 (1 max) / Tier 2 (5 max) / Tier 3 (broader notify ring). Every change biometric-gated (LP18).',
      features: [
        'Contact list sorted by tier then notify_order',
        'Row shows: name, masked phone, tier badge, verification status',
        'Add via phone contacts (fast_contacts) or manual entry',
        'Verification: SMS OTP sent to the new contact phone',
        'Long-press to edit / delete / change tier',
        'Biometric-gated changes (LP18 — prevents attacker tampering)',
        'Emergency profile preview — see what contacts get during SOS',
      ],
    );
  }
}
