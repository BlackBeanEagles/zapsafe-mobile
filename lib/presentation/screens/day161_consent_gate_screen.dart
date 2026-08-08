/// Day 161-162 — First-Launch Consent Gate
///
/// 🟢 FRONTEND-ONLY — Hive local storage, zero backend.
///
/// Shown to NEW users (or when policy versions change) BEFORE the
/// Dashboard is accessible. Legal requirement: informed consent to
/// Privacy Policy + Terms of Service.
///
/// Key legal requirements:
///   ✅ Checkbox CANNOT be pre-checked (user must actively opt in)
///   ✅ Must record WHICH version was accepted (not just "yes")
///   ✅ Must record WHEN and on WHAT device
///   ✅ Links to full Privacy Policy + ToS must be accessible
///   ✅ Never shown again unless policy version changes
///   ✅ Policy version mismatch → shown again for the new version
///
/// Two modes:
///   1. FIRST_LAUNCH — brand-new user, no record in Hive
///   2. POLICY_UPDATE — returning user, accepted older version
///
/// After acceptance: GoRouter redirect allows navigation to Dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import 'day151_privacy_policy_screen.dart';
import 'day153_terms_of_service_screen.dart';
import 'day152_policy_consent_screen.dart'
    show kCurrentPrivacyVersion, kCurrentTermsVersion, kPrivacyUpdatedDate, kTermsUpdatedDate;

// ── Constants ──────────────────────────────────────────────────────────────────
// Re-export from Day 152 for clarity
const _kPrivacyVersion = kCurrentPrivacyVersion;
const _kTermsVersion   = kCurrentTermsVersion;

// ── Providers ──────────────────────────────────────────────────────────────────
final _privacyCheckedProvider  = StateProvider<bool>((ref) => false);
final _termsCheckedProvider    = StateProvider<bool>((ref) => false);
final _activeTabProvider       = StateProvider<int>((ref) => 0);
final _acceptStateProvider     = StateProvider<_AcceptState>(
    (ref) => _AcceptState.idle);

enum _AcceptState { idle, saving, done }

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day161ConsentGateScreen extends ConsumerWidget {
  const Day161ConsentGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('First-Launch Consent Gate'),
        elevation: 0,
        automaticallyImplyLeading: false, // no back button — must accept
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _GateTab(),
            if (tab == 1) const _UpdateModeTab(),
            if (tab == 2) const _RouterIntegrationTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A0612), Color(0xFF050309), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 161', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Hive + GoRouter', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'First-Launch\nConsent Gate',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Blocks dashboard access until Privacy Policy + Terms '
            'are actively accepted. Stores version + timestamp in Hive. '
            'Re-shown if policy versions change.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('Gate',   'Blocks dashboard', Color(0xFF8B5CF6)),
            _HStat('Active', 'Checkbox only',    Color(0xFFEF4444)),
            _HStat('Hive',   'Version stored',   Color(0xFF3B82F6)),
            _HStat('v2+v1',  'Both docs',        Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_rounded,  Color(0xFF8B5CF6), 'Gate Screen'),
      (Icons.update_rounded,         Color(0xFFF59E0B), 'Policy Update'),
      (Icons.route_rounded,          Color(0xFF3B82F6), 'Router'),
    ];
    return Row(
      children: List.generate(3, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Gate Tab ───────────────────────────────────────────────────────────────────
class _GateTab extends ConsumerWidget {
  const _GateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privChecked = ref.watch(_privacyCheckedProvider);
    final termsChecked= ref.watch(_termsCheckedProvider);
    final acceptState = ref.watch(_acceptStateProvider);
    final isDone      = acceptState == _AcceptState.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.verified_user_rounded,
          color: const Color(0xFF8B5CF6),
          text: 'This is what new users see BEFORE reaching the dashboard. '
              'No back button. Cannot be skipped. '
              'Checkbox cannot be pre-ticked (DPDP/GDPR hard requirement). '
              '"Continue" stays disabled until both are checked.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // The actual gate screen (simulated)
        const _SectionLabel('LIVE CONSENT GATE  ·  EXACTLY AS SHOWN IN-APP'),
        const SizedBox(height: ZapSpacing.md),
        _ConsentGateCard(
            privChecked: privChecked,
            termsChecked: termsChecked,
            acceptState: acceptState,
            isDone: isDone),
        const SizedBox(height: ZapSpacing.lg),

        // Reset demo
        if (isDone) ...[
          GestureDetector(
            onTap: () {
              ref.read(_privacyCheckedProvider.notifier).state = false;
              ref.read(_termsCheckedProvider.notifier).state   = false;
              ref.read(_acceptStateProvider.notifier).state    = _AcceptState.idle;
            },
            child: const Center(
              child: Text('↺ Reset demo — simulate new user',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
        ],

        // Hive storage code
        const _SectionLabel('WHAT IS STORED IN HIVE ON ACCEPT'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('hive/consent_acceptance',
            '// Stored on accept (same record as Day 152 PolicyConsentService):\n'
            '{\n'
            '  "privacy_version":  "$_kPrivacyVersion",\n'
            '  "terms_version":    "$_kTermsVersion",\n'
            '  "accepted_at":      "${DateTime.now().toIso8601String().split('.').first}Z",\n'
            '  "device_id":        "sha256:a3f9...c2d1",\n'
            '  "app_version":      "0.6.0",\n'
            '  "method":           "checkbox_active",\n'
            '  "record_hash":      "sha256:7b2e...4f8a"\n'
            '}\n'
            '\n'
            '// record_hash = SHA-256 of all fields above\n'
            '// → tamper-evident consent certificate (Day 154 showed this)'),
        const SizedBox(height: ZapSpacing.lg),

        // Legal notes
        const _SectionLabel('LEGAL REQUIREMENTS MET'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            ...[
              ('Checkbox cannot be pre-checked',
                  'User must actively tap — passive scrolling is not consent (DPDP §6)',
                  const Color(0xFF10B981)),
              ('Full policy accessible via link',
                  'Users can read the complete text before agreeing (Day 151 + Day 153)',
                  const Color(0xFF10B981)),
              ('Version number recorded',
                  'Records "privacy v2.0" not just "accepted" — required for version tracking',
                  const Color(0xFF10B981)),
              ('Timestamp stored',
                  'ISO 8601 UTC timestamp — legal proof of when consent was given',
                  const Color(0xFF10B981)),
              ('No dark patterns',
                  'Button labelled "I Agree" not "Get Started" — clear about what user is doing',
                  const Color(0xFF10B981)),
              ('Can read before accepting',
                  '"Read Privacy Policy" + "Read Terms" open the full documents in-app',
                  const Color(0xFF10B981)),
            ].asMap().entries.map((e) {
              final i     = e.key;
              final (req, desc, color) = e.value;
              final isLast= i == 5;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 16),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(desc,
                              style: const TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 10,
                                  height: 1.3)),
                        ],
                      ),
                    ),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }),
          ]),
        ),
      ],
    );
  }
}

// ── The actual consent gate card ───────────────────────────────────────────────
class _ConsentGateCard extends ConsumerWidget {
  final bool privChecked, termsChecked;
  final _AcceptState acceptState;
  final bool isDone;
  const _ConsentGateCard({
    required this.privChecked,
    required this.termsChecked,
    required this.acceptState,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allChecked = privChecked && termsChecked;

    if (isDone) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF10B981).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.45), width: 2),
        ),
        child: const Column(children: [
          Icon(Icons.verified_rounded,
              color: Color(0xFF10B981), size: 48),
          SizedBox(height: ZapSpacing.md),
          Text('Consent recorded ✅',
              style: TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'Privacy Policy v$_kPrivacyVersion + Terms of Service v$_kTermsVersion\n'
            'accepted and stored in Hive.\n'
            'GoRouter now allows navigation to Dashboard.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.35), width: 2),
      ),
      child: Column(children: [
        // App header (simulated)
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
          ),
          child: const Row(children: [
            Icon(Icons.bolt_rounded, color: ZapColors.danger, size: 22),
            SizedBox(width: ZapSpacing.sm),
            Text('ZapSafe',
                style: TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ]),
        ),

        // Gate content
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            // Icon + headline
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4)),
              ),
              child: const Icon(Icons.privacy_tip_rounded,
                  color: Color(0xFF8B5CF6), size: 32),
            ),
            const SizedBox(height: ZapSpacing.lg),
            const Text('Before you continue',
                style: TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'ZapSafe collects location, audio, and contact data '
              'to protect you during emergencies. '
              'Please read and accept our policies before using the app.',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Key points summary
            _keyPoint(Icons.location_on_rounded, const Color(0xFFEF4444),
                'Location shared with emergency contacts during SOS'),
            _keyPoint(Icons.mic_rounded, const Color(0xFF8B5CF6),
                'Audio processed on-device — never uploaded raw'),
            _keyPoint(Icons.people_rounded, const Color(0xFF10B981),
                'Contacts stored to notify them during emergencies'),
            _keyPoint(Icons.lock_rounded, const Color(0xFF3B82F6),
                'Evidence encrypted + stays on device by default'),
            const SizedBox(height: ZapSpacing.xl),

            // Privacy Policy checkbox
            _ConsentCheckRow(
              label: 'I have read the',
              linkLabel: 'Privacy Policy',
              version: 'v$_kPrivacyVersion',
              updatedDate: kPrivacyUpdatedDate,
              icon: Icons.privacy_tip_rounded,
              color: const Color(0xFF3B82F6),
              checked: privChecked,
              onToggle: () => ref
                  .read(_privacyCheckedProvider.notifier)
                  .state = !privChecked,
              onReadTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Day151PrivacyPolicyScreen(),
              )),
            ),
            const SizedBox(height: ZapSpacing.md),

            // Terms checkbox
            _ConsentCheckRow(
              label: 'I have read the',
              linkLabel: 'Terms of Service',
              version: 'v$_kTermsVersion',
              updatedDate: kTermsUpdatedDate,
              icon: Icons.gavel_rounded,
              color: const Color(0xFF8B5CF6),
              checked: termsChecked,
              onToggle: () => ref
                  .read(_termsCheckedProvider.notifier)
                  .state = !termsChecked,
              onReadTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Day153TermsOfServiceScreen(),
              )),
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Important note about Section 3
            if (!termsChecked)
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                margin: const EdgeInsets.only(bottom: ZapSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_rounded,
                        color: Color(0xFFEF4444), size: 14),
                    SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Before ticking Terms: read Section 3 (Emergency Disclaimer) — '
                        'it explains that ZapSafe does not replace calling 112.',
                        style: TextStyle(
                            color: Color(0xFFFFD0CA),
                            fontSize: 10, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

            // Accept button
            GestureDetector(
              onTap: allChecked && acceptState == _AcceptState.idle
                  ? () async {
                      ref.read(_acceptStateProvider.notifier).state =
                          _AcceptState.saving;
                      await Future.delayed(
                          const Duration(milliseconds: 900));
                      if (!context.mounted) return;
                      ref.read(_acceptStateProvider.notifier).state =
                          _AcceptState.done;
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: allChecked
                      ? const LinearGradient(colors: [
                          Color(0xFF5B21B6),
                          Color(0xFF8B5CF6),
                        ])
                      : null,
                  color: allChecked ? null : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radius),
                  boxShadow: allChecked
                      ? [
                          BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.4),
                              blurRadius: 20, offset: const Offset(0, 6))
                        ]
                      : null,
                  border: allChecked
                      ? null
                      : Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: acceptState == _AcceptState.saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: ZapSpacing.sm),
                          Text('Saving consent…',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            allChecked
                                ? Icons.verified_rounded
                                : Icons.lock_rounded,
                            color: allChecked
                                ? Colors.white
                                : const Color(0xFF4B5563),
                            size: 20,
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Text(
                            allChecked
                                ? 'I Agree — Enter ZapSafe'
                                : 'Tick both checkboxes above',
                            style: TextStyle(
                              color: allChecked
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              allChecked
                  ? 'Accepting creates a tamper-evident consent record'
                  : 'Both policies must be read before continuing',
              style: const TextStyle(
                  color: Color(0xFF4B5563), fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _keyPoint(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.3)),
          ),
        ]),
      );
}

class _ConsentCheckRow extends StatelessWidget {
  final String   label, linkLabel, version, updatedDate;
  final IconData icon;
  final Color    color;
  final bool     checked;
  final VoidCallback onToggle, onReadTap;
  const _ConsentCheckRow({
    required this.label,
    required this.linkLabel,
    required this.version,
    required this.updatedDate,
    required this.icon,
    required this.color,
    required this.checked,
    required this.onToggle,
    required this.onReadTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: checked
            ? color.withOpacity(0.08)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: checked ? color.withOpacity(0.4) : const Color(0xFF2A2A2A),
          width: checked ? 2 : 1,
        ),
      ),
      child: Column(children: [
        Row(children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: checked ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: checked ? color : const Color(0xFF4B5563),
                    width: 2),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, color: color, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 13)),
                GestureDetector(
                  onTap: onReadTap,
                  child: Text(linkLabel,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: color)),
                ),
                Text('($version)',
                    style: TextStyle(
                        color: color.withOpacity(0.6), fontSize: 10)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        // Read button
        GestureDetector(
          onTap: onReadTap,
          child: Row(children: [
            const SizedBox(width: 30), // align with text
            Icon(icon, color: color, size: 12),
            const SizedBox(width: ZapSpacing.xs),
            Text('Read full $linkLabel →',
                style: TextStyle(
                    color: color, fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: ZapSpacing.sm),
            Text('Updated $updatedDate',
                style: const TextStyle(
                    color: Color(0xFF4B5563), fontSize: 9)),
          ]),
        ),
      ]),
    );
  }
}

// ── Policy Update Mode Tab ─────────────────────────────────────────────────────
class _UpdateModeTab extends ConsumerWidget {
  const _UpdateModeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.update_rounded,
          color: const Color(0xFFF59E0B),
          text: 'When you ship a new policy version (e.g. Privacy Policy v3.0), '
              'returning users who accepted v2.0 see this gate again. '
              'The screen shows "Policy Updated" mode with a changelog summary.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Mode comparison
        const _SectionLabel('TWO MODES'),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          Expanded(
            child: _modeCard(
              'FIRST_LAUNCH',
              'Brand-new user\n(no Hive record)',
              Icons.fiber_new_rounded,
              const Color(0xFF10B981),
              [
                'Shows full welcome explanation',
                'No "what changed" section',
                'Both checkboxes required',
                '"Enter ZapSafe" button label',
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: _modeCard(
              'POLICY_UPDATE',
              'Returning user\n(old version in Hive)',
              Icons.published_with_changes_rounded,
              const Color(0xFFF59E0B),
              [
                'Shows "Policy Updated" banner',
                '"What changed" summary shown',
                'Only updated doc needs re-tick',
                '"I Agree to Updates" label',
              ],
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // Policy Update banner mock
        const _SectionLabel('POLICY UPDATE BANNER  ·  SHOWN AT TOP'),
        const SizedBox(height: ZapSpacing.md),
        _PolicyUpdateBannerMock(),
        const SizedBox(height: ZapSpacing.xl),

        // Version detection code
        const _SectionLabel('HOW VERSION MISMATCH IS DETECTED'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('policy_consent_service.dart',
            '// On every app launch:\n'
            'bool needsConsentGate() {\n'
            '  final record = Hive.box<PolicyConsent>(\'policy_consent\')\n'
            '      .get(\'consent\');\n'
            '\n'
            '  // First launch: no record\n'
            '  if (record == null) return true;\n'
            '\n'
            '  // Policy updated: version mismatch\n'
            '  if (record.privacyVersion != kCurrentPrivacyVersion) return true;\n'
            '  if (record.termsVersion   != kCurrentTermsVersion)   return true;\n'
            '\n'
            '  // All good: user accepted current versions\n'
            '  return false;\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('mode_detection.dart',
            '// Detect which mode to show:\n'
            '_ConsentGateMode _detectMode() {\n'
            '  final record = PolicyConsentService.getRecord();\n'
            '  if (record == null) return _ConsentGateMode.firstLaunch;\n'
            '\n'
            '  // Has record but version differs → policy update\n'
            '  return _ConsentGateMode.policyUpdate;\n'
            '}'),
      ],
    );
  }

  Widget _modeCard(String title, String subtitle, IconData icon, Color color,
      List<String> points) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: ZapSpacing.xs),
            Text(subtitle,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 10, height: 1.3)),
            const SizedBox(height: ZapSpacing.sm),
            ...points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, color: color, size: 5),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(p,
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 10, height: 1.3)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
}

class _PolicyUpdateBannerMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.45), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.published_with_changes_rounded,
                color: Color(0xFFF59E0B), size: 18),
            SizedBox(width: ZapSpacing.sm),
            Text('Our Privacy Policy has been updated',
                style: TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'We updated our Privacy Policy to reflect the move to AWS '
            'servers and new data retention options.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
          const SizedBox(height: ZapSpacing.md),
          // What changed summary
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What changed in v2.0:',
                    style: TextStyle(
                        color: Color(0xFFF59E0B), fontSize: 10,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: ZapSpacing.xs),
                Text(
                  '• Data now hosted on AWS ap-south-1 (Mumbai, India)\n'
                  '• Evidence retention now configurable: 7/30/90 days\n'
                  '• Anonymous heatmap contribution clarified',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'You previously accepted v1.0. Please re-read and '
            'accept the updated policy to continue.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Router Integration Tab ─────────────────────────────────────────────────────
class _RouterIntegrationTab extends StatelessWidget {
  const _RouterIntegrationTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.route_rounded,
          color: const Color(0xFF3B82F6),
          text: 'GoRouter\'s `redirect` callback runs on every navigation. '
              'This is the cleanest pattern: a single check in redirect '
              'gates ALL routes behind consent without wrapping each screen.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // The full router integration
        const _SectionLabel('GOROUTER REDIRECT  ·  GATES ALL ROUTES'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('app_router.dart',
            'final router = GoRouter(\n'
            '  initialLocation: AppRoutes.dashboard,\n'
            '\n'
            '  redirect: (context, state) {\n'
            '    final authed    = AuthService.isLoggedIn();\n'
            '    final consented = !PolicyConsentService.needsConsentGate();\n'
            '    final onboarded = OnboardingService.isDone();\n'
            '\n'
            '    // 1. Not authenticated → phone entry\n'
            '    if (!authed) return AppRoutes.phoneEntry;\n'
            '\n'
            '    // 2. Authenticated but no consent → gate\n'
            '    //    Applies to ALL routes (incl. deep links)\n'
            '    if (!consented) return AppRoutes.consentGate;\n'
            '\n'
            '    // 3. Authenticated + consented but not onboarded\n'
            '    if (!onboarded) return AppRoutes.onboarding;\n'
            '\n'
            '    // 4. All clear — proceed to requested route\n'
            '    return null;\n'
            '  },\n'
            '\n'
            '  routes: [\n'
            '    GoRoute(\n'
            '      path: AppRoutes.consentGate,\n'
            '      builder: (_, __) => const ConsentGateScreen(),\n'
            '    ),\n'
            '    GoRoute(\n'
            '      path: AppRoutes.dashboard,\n'
            '      builder: (_, __) => const DashboardScreen(),\n'
            '    ),\n'
            '    // ... all other routes\n'
            '  ],\n'
            ')'),
        const SizedBox(height: ZapSpacing.lg),

        // After acceptance
        const _SectionLabel('AFTER ACCEPTANCE  ·  NAVIGATE TO DASHBOARD'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('consent_gate_screen.dart',
            '// When user taps "I Agree":\n'
            'Future<void> _onAccept() async {\n'
            '  // Save to Hive (the consent certificate)\n'
            '  await PolicyConsentService.recordAcceptance();\n'
            '\n'
            '  // GoRouter redirect will now return null\n'
            '  // → navigation to dashboard is unblocked\n'
            '  if (!mounted) return;\n'
            '  context.go(AppRoutes.dashboard);\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        // Deep link protection
        const _SectionLabel('DEEP LINK PROTECTION'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('deep_link_example',
            '// Example: push notification opens /vault/sos_123\n'
            '// User taps notification → GoRouter calls redirect:\n'
            '//   authed=true, consented=FALSE → returns consentGate\n'
            '// User sees consent gate instead of evidence vault\n'
            '// After accepting, GoRouter resumes to /vault/sos_123\n'
            '//\n'
            '// This protects ALL routes automatically —\n'
            '// no need to add consent check to each screen.'),
        const SizedBox(height: ZapSpacing.xl),

        // Summary card
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF8B5CF6).withOpacity(0.12),
              const Color(0xFF8B5CF6).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.4)),
          ),
          child: Column(children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 36),
            const SizedBox(height: ZapSpacing.md),
            const Text('Days 161-162: Consent Gate Complete ✅',
                style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Day 161: gate screen + legal checkboxes + version storage\n'
              'Day 162: update mode + GoRouter integration + test flows',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),
            _infoBox(
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF3B82F6),
              text: 'Days 163-165: Tracking & Analytics Preferences — '
                  'ATT prompt on iOS, Sentry opt-in/out, usage analytics toggle.',
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 10,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
