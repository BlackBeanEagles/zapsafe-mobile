/// Day 154 — Legal Documents Hub
///
/// Second half of the Days 153-154 Terms of Service block.
/// Day 153 built the full ToS screen.
/// Day 154 builds the central Legal Hub that:
///
///   1. Shows both Privacy Policy + Terms of Service in one place
///      with their version, acceptance status, and last-updated date
///
///   2. Policy Version History — a changelog showing what changed
///      between policy versions (v1.0 → v2.0) so users understand
///      WHY they are being asked to re-accept
///
///   3. Acceptance Certificate — a human-readable record of
///      exactly what the user agreed to, when, on which device,
///      and which version. Useful if they ever need to prove consent.
///
///   4. Legal Links — external URLs for support, legal notices,
///      and the GitHub Pages landing page
///
/// All 🟢 FRONTEND-ONLY — local data, zero backend.
/// This screen lives at Settings → Privacy & Legal → Legal Documents.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import 'day151_privacy_policy_screen.dart';
import 'day153_terms_of_service_screen.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const _kPrivacyVersion = '2.0';
const _kPrivacyDate    = 'June 17, 2026';
const _kTosVersion     = '1.0';
const _kTosDate        = 'June 17, 2026';

// ── Providers ──────────────────────────────────────────────────────────────────
final _hubTabProvider         = StateProvider<int>((ref) => 0);
final _certExpandedProvider   = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
class _PolicyDoc {
  final String   title;
  final String   version;
  final String   updatedDate;
  final String   acceptedVersion;
  final DateTime acceptedAt;
  final bool     isUpToDate;
  final Color    color;
  final IconData icon;
  final String   route;
  final String   summary;
  const _PolicyDoc({
    required this.title,
    required this.version,
    required this.updatedDate,
    required this.acceptedVersion,
    required this.acceptedAt,
    required this.isUpToDate,
    required this.color,
    required this.icon,
    required this.route,
    required this.summary,
  });
}

final _kDocs = [
  _PolicyDoc(
    title: 'Privacy Policy',
    version: _kPrivacyVersion,
    updatedDate: _kPrivacyDate,
    acceptedVersion: _kPrivacyVersion,
    acceptedAt: DateTime(2026, 6, 17, 14, 30),
    isUpToDate: true,
    color: const Color(0xFF3B82F6),
    icon: Icons.privacy_tip_rounded,
    route: '/privacy-policy',
    summary: 'What data we collect, why, who sees it, and your rights under DPDP + GDPR.',
  ),
  _PolicyDoc(
    title: 'Terms of Service',
    version: _kTosVersion,
    updatedDate: _kTosDate,
    acceptedVersion: _kTosVersion,
    acceptedAt: DateTime(2026, 6, 17, 14, 30),
    isUpToDate: true,
    color: const Color(0xFF8B5CF6),
    icon: Icons.gavel_rounded,
    route: '/terms-of-service',
    summary: 'How you may use ZapSafe, the emergency disclaimer, liability limits, and governing law.',
  ),
];

class _ChangeEntry {
  final String version;
  final String date;
  final String changeType; // 'new' | 'updated' | 'removed'
  final String description;
  const _ChangeEntry(this.version, this.date, this.changeType, this.description);
}

const _kPrivacyHistory = [
  _ChangeEntry('2.0', 'June 17, 2026', 'new',
      'Added AWS ap-south-1 as data hosting region (moved from DigitalOcean)'),
  _ChangeEntry('2.0', 'June 17, 2026', 'updated',
      'Updated retention periods: evidence now configurable 7/30/90 days'),
  _ChangeEntry('2.0', 'June 17, 2026', 'new',
      'Added CloudFront CDN as static asset delivery — no personal data involved'),
  _ChangeEntry('2.0', 'June 17, 2026', 'updated',
      'Clarified AI model improvement consent: anonymised features only, never raw audio'),
  _ChangeEntry('1.0', 'May 23, 2026', 'new',
      'Initial privacy policy published for beta launch'),
];

const _kTosHistory = [
  _ChangeEntry('1.0', 'June 17, 2026', 'new',
      'Initial Terms of Service published'),
  _ChangeEntry('1.0', 'June 17, 2026', 'new',
      'Emergency Services Disclaimer (Section 3) added — legally required'),
  _ChangeEntry('1.0', 'June 17, 2026', 'new',
      'User Responsibilities section: drills, contact updates, acceptable use'),
  _ChangeEntry('1.0', 'June 17, 2026', 'new',
      'Governing law: India (DPDP Act 2023), arbitration in Bengaluru'),
];

const _kLegalLinks = [
  ('Privacy Policy (Web)', 'https://zapsafe.app/privacy', Icons.link_rounded, Color(0xFF3B82F6)),
  ('Terms of Service (Web)', 'https://zapsafe.app/terms', Icons.link_rounded, Color(0xFF8B5CF6)),
  ('Support', 'support@zapsafe.app', Icons.mail_rounded, Color(0xFF10B981)),
  ('Legal enquiries', 'legal@zapsafe.app', Icons.gavel_rounded, Color(0xFFF59E0B)),
  ('Data / Privacy', 'privacy@zapsafe.app', Icons.privacy_tip_rounded, Color(0xFF3B82F6)),
  ('GitHub (open source)', 'github.com/zapsafe-app', Icons.code_rounded, Color(0xFF9CA3AF)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day154LegalHubScreen extends ConsumerWidget {
  const Day154LegalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_hubTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Legal Documents'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Document cards (always visible)
            const _SectionLabel('YOUR POLICY DOCUMENTS'),
            const SizedBox(height: ZapSpacing.md),
            ..._kDocs.map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: _DocCard(doc: doc),
                )),
            const SizedBox(height: ZapSpacing.xl),

            // Tab bar
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_hubTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _CertificateTab(),
            if (tab == 1) const _HistoryTab(),
            if (tab == 2) const _LinksTab(),
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
          colors: [Color(0xFF0A0A1A), Color(0xFF060610), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 154', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Section A Complete', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Legal\nDocuments Hub',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Central screen for Privacy Policy + Terms of Service. '
            'Shows acceptance status, version changelog, consent '
            'certificate, and legal contact links.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('2',     'Legal docs',     Color(0xFF8B5CF6)),
            _HStat('✅',    'All accepted',   Color(0xFF10B981)),
            _HStat('Hive',  'Local proof',    Color(0xFF3B82F6)),
            _HStat('DPDP',  'Compliant',      Color(0xFFF59E0B)),
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
                  color: color, fontSize: 15, fontWeight: FontWeight.w800),
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

// ── Document card ──────────────────────────────────────────────────────────────
class _DocCard extends StatelessWidget {
  final _PolicyDoc doc;
  const _DocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => doc.title.contains('Privacy')
            ? const Day151PrivacyPolicyScreen()
            : const Day153TermsOfServiceScreen(),
      )),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: doc.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: doc.isUpToDate
                ? doc.color.withOpacity(0.3)
                : const Color(0xFFEF4444).withOpacity(0.4),
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: doc.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(doc.icon, color: doc.color, size: 20),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(doc.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: ZapSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: doc.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text('v${doc.version}',
                        style: TextStyle(
                            color: doc.color, fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                  ),
                  if (doc.isUpToDate) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 14),
                  ],
                ]),
                Text(doc.summary,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  doc.isUpToDate
                      ? 'Accepted v${doc.acceptedVersion} on ${_fmt(doc.acceptedAt)}'
                      : 'Accepted v${doc.acceptedVersion} — current is v${doc.version}',
                  style: TextStyle(
                      color: doc.isUpToDate
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF4B5563), size: 20),
        ]),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.workspace_premium_rounded, Color(0xFF10B981), 'Certificate'),
      (Icons.history_rounded,           Color(0xFF3B82F6), 'History'),
      (Icons.link_rounded,              Color(0xFF8B5CF6), 'Links'),
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

// ── Certificate Tab ────────────────────────────────────────────────────────────
class _CertificateTab extends ConsumerWidget {
  const _CertificateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_certExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF10B981),
          text: 'This is your legal proof of informed consent. '
              'It records exactly which version of each policy you accepted, '
              'when, and on which device. Store it in case you ever need to '
              'demonstrate that you were properly informed.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Certificate card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF10B981).withOpacity(0.1),
              const Color(0xFF10B981).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.45), width: 2),
          ),
          child: Column(children: [
            // Certificate header
            Container(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFF10B981), size: 36),
                const SizedBox(height: ZapSpacing.sm),
                const Text('Policy Acceptance Certificate',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                const SizedBox(height: ZapSpacing.xs),
                const Text('ZapSafe Legal Compliance Record',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11),
                    textAlign: TextAlign.center),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),

            // Fields
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(children: [
                _certRow('User', 'Priya Kumar (+91 98765 XXXXX)'),
                _certRow('Privacy Policy', 'v$_kPrivacyVersion — accepted'),
                _certRow('Terms of Service', 'v$_kTosVersion — accepted'),
                _certRow('Accepted at',
                    '17 June 2026, 14:30:22 UTC'),
                _certRow('Device', 'Pixel 7 (Android 14)'),
                _certRow('App version', 'ZapSafe v0.6.0'),
                _certRow('Method',
                    'In-app checkbox + active confirmation'),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),

            // Hash / fingerprint
            GestureDetector(
              onTap: () => ref
                  .read(_certExpandedProvider.notifier)
                  .state = !expanded,
              child: Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Column(children: [
                  Row(children: [
                    const Icon(Icons.fingerprint_rounded,
                        color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: ZapSpacing.sm),
                    const Expanded(
                      child: Text('Consent fingerprint',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                  ]),
                  if (expanded) ...[
                    const SizedBox(height: ZapSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(ZapSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radiusSmall),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: const Text(
                        '# Consent Record\n'
                        'privacy_version: "2.0"\n'
                        'tos_version:     "1.0"\n'
                        'accepted_utc:    "2026-06-17T14:30:22Z"\n'
                        'device_hash:     "sha256:a3f9...c2d1"\n'
                        'app_version:     "0.6.0"\n'
                        'method:          "checkbox_active"\n'
                        'record_hash:     "sha256:7b2e...4f8a"',
                        style: TextStyle(
                            color: Color(0xFF7EE787),
                            fontSize: 10,
                            fontFamily: 'monospace',
                            height: 1.6),
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    const Text(
                      'This record is stored in Hive on your device. '
                      'A SHA-256 hash of the record ensures it cannot be '
                      'retroactively altered.',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          height: 1.4),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // How it's stored
        const _SectionLabel('HOW THE CERTIFICATE IS STORED'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('hive/policy_consent_box',
            '// On acceptance, PolicyConsentService.recordAcceptance() runs:\n'
            '{\n'
            '  "privacy_version":  "2.0",\n'
            '  "tos_version":      "1.0",\n'
            '  "accepted_utc":     "2026-06-17T14:30:22Z",\n'
            '  "device_id":        "sha256:a3f9...c2d1",\n'
            '  "app_version":      "0.6.0",\n'
            '  "method":           "checkbox_active",\n'
            '  "record_hash":      "sha256:7b2e...4f8a"\n'
            '}\n'
            '// record_hash = SHA-256 of all other fields\n'
            '// → if any field is tampered, hash mismatch is detectable'),
      ],
    );
  }

  Widget _certRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11),
                textAlign: TextAlign.end),
          ),
        ]),
      );
}

// ── History Tab ────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.history_rounded,
          color: const Color(0xFF3B82F6),
          text: 'When we update policies, users are asked to re-accept. '
              'This changelog explains WHAT changed and WHY, so you can '
              'make an informed decision rather than just clicking "Accept".',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Privacy Policy history
        const _SectionLabel('PRIVACY POLICY  ·  CHANGE LOG'),
        const SizedBox(height: ZapSpacing.md),
        _ChangeLog(
            docTitle: 'Privacy Policy',
            color: const Color(0xFF3B82F6),
            icon: Icons.privacy_tip_rounded,
            entries: _kPrivacyHistory),
        const SizedBox(height: ZapSpacing.xl),

        // Terms of Service history
        const _SectionLabel('TERMS OF SERVICE  ·  CHANGE LOG'),
        const SizedBox(height: ZapSpacing.md),
        _ChangeLog(
            docTitle: 'Terms of Service',
            color: const Color(0xFF8B5CF6),
            icon: Icons.gavel_rounded,
            entries: _kTosHistory),
      ],
    );
  }
}

class _ChangeLog extends StatelessWidget {
  final String docTitle;
  final Color  color;
  final IconData icon;
  final List<_ChangeEntry> entries;
  const _ChangeLog({
    required this.docTitle,
    required this.color,
    required this.icon,
    required this.entries,
  });

  static const _typeColors = {
    'new':     Color(0xFF10B981),
    'updated': Color(0xFF3B82F6),
    'removed': Color(0xFFEF4444),
  };
  static const _typeLabels = {
    'new': 'NEW', 'updated': 'UPDATED', 'removed': 'REMOVED',
  };

  @override
  Widget build(BuildContext context) {
    // Group by version
    final versions = <String, List<_ChangeEntry>>{};
    for (final e in entries) {
      versions.putIfAbsent(e.version, () => []).add(e);
    }

    return Column(
      children: versions.entries.toList().reversed.map((vEntry) {
        final ver     = vEntry.key;
        final changes = vEntry.value;
        final vDate   = changes.first.date;

        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            // Version header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ZapSpacing.radiusSmall - 1)),
              ),
              child: Row(children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('v$ver',
                      style: TextStyle(
                          color: color, fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace')),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Text(vDate,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 10)),
                const Spacer(),
                Text('${changes.length} change${changes.length > 1 ? 's' : ''}',
                    style: TextStyle(
                        color: color, fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            // Changes
            ...changes.asMap().entries.map((e) {
              final i      = e.key;
              final change = e.value;
              final isLast = i == changes.length - 1;
              final tColor = _typeColors[change.changeType] ??
                  const Color(0xFF9CA3AF);
              final tLabel = _typeLabels[change.changeType] ?? 'CHANGED';

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tLabel,
                            style: TextStyle(
                                color: tColor, fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(change.description,
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }),
          ]),
        );
      }).toList(),
    );
  }
}

// ── Links Tab ──────────────────────────────────────────────────────────────────
class _LinksTab extends StatelessWidget {
  const _LinksTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.link_rounded,
          color: const Color(0xFF8B5CF6),
          text: 'External links and contact addresses for legal, support, '
              'and privacy enquiries. All policies are also bundled in-app '
              'and accessible offline.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Links list
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kLegalLinks.asMap().entries.map((e) {
              final i = e.key;
              final (label, url, icon, color) = e.value;
              final isLast = i == _kLegalLinks.length - 1;
              final isEmail = url.contains('@');

              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEmail ? 'Email: $url' : 'Open: $url',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: color,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            Text(url,
                                style: TextStyle(
                                    color: color.withOpacity(0.8),
                                    fontSize: 10,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      Icon(
                        isEmail
                            ? Icons.mail_outline_rounded
                            : Icons.open_in_new_rounded,
                        color: const Color(0xFF4B5563), size: 16),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Offline note
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFF10B981), size: 16),
            SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Privacy Policy and Terms of Service are bundled inside '
                'the app and always readable offline. The web links above '
                'are for sharing externally.',
                style: TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Section A complete banner
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
            const Text('Section A Complete ✅',
                style: TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Days 151-154: Privacy & Legal screens done.\n'
              'Privacy Policy · Consent Tracking · Terms of Service · Legal Hub',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center,
              children: const [
                _Chip('Privacy Policy ✅',   Color(0xFF3B82F6)),
                _Chip('Consent Service ✅',  Color(0xFF10B981)),
                _Chip('Terms of Service ✅', Color(0xFF8B5CF6)),
                _Chip('Legal Hub ✅',        Color(0xFFF59E0B)),
                _Chip('DPDP compliant ✅',   Color(0xFF10B981)),
                _Chip('GDPR compliant ✅',   Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: ZapSpacing.lg),
            _infoBox(
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF3B82F6),
              text: 'Next: Days 155-157 — Consent Management Screen '
                  '(granular toggles for each type of data processing).',
            ),
          ]),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
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
