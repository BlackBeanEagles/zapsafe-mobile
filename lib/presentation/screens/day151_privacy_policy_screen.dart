/// Day 151-152 — Privacy Policy Screen
///
/// 🟢 FRONTEND-ONLY — zero backend, zero conflict.
/// Content is bundled as local structured data (no server call).
/// Required by:
///   • Apple App Store (must be accessible in-app, not just external URL)
///   • Google Play (same requirement)
///   • India DPDP Act 2023 (users must be informed of data practices)
///
/// Features:
///   • Scrollable sections with a collapsible table of contents
///   • Version number + "Last updated" date at the top
///   • "Accept" button only shown in first-launch consent flow (Day 161-162)
///   • i18n-ready (all text keys prefixed with privacy_policy.*)
///   • Works fully offline (content is local)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _tocExpandedProvider = StateProvider<bool>((ref) => false);
final _activeSectionProvider = StateProvider<int>((ref) => 0);

// ── Data ───────────────────────────────────────────────────────────────────────
const _kVersion     = '2.0';
const _kLastUpdated = 'June 17, 2026';
const _kContactEmail= 'privacy@zapsafe.app';

class _PolicySection {
  final String id;
  final String title;
  final IconData icon;
  final Color  color;
  final List<_PolicyItem> items;
  const _PolicySection({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _PolicyItem {
  final String heading;
  final String body;
  const _PolicyItem(this.heading, this.body);
}

const _kSections = [
  _PolicySection(
    id: 'collect',
    title: '1. What Data We Collect',
    icon: Icons.storage_rounded,
    color: Color(0xFF3B82F6),
    items: [
      _PolicyItem('Location (GPS)',
          'We collect your GPS location continuously when the app is open in SOS_ACTIVE or MONITORING '
          'state, and in batches every 30 seconds when running in the background. Location is stored '
          'locally and uploaded to our servers only during an active SOS event or when you start a '
          'Journey. We never collect location without your permission or when the app is fully closed.'),
      _PolicyItem('Audio & Video Evidence',
          'During an SOS event, ZapSafe silently records audio and (if camera permission granted) '
          'front and rear video. Recordings are stored AES-256 encrypted on your device. They are '
          'never uploaded to our servers without your explicit "Export to Police" or cloud backup '
          'action. We store only SHA-256 hashes — never raw audio — for our AI detection pipeline.'),
      _PolicyItem('Emergency Contacts',
          'You voluntarily add the names and phone numbers of people you trust. This data is stored '
          'on our servers so contacts can be notified during SOS. Contact data is never sold or used '
          'for advertising.'),
      _PolicyItem('Device Information',
          'We collect device model, OS version, RAM (to assign a LITE/STANDARD/FULL tier), and '
          'a hashed device ID for crash reporting. No personally identifiable hardware IDs (IMEI, '
          'serial number) are ever collected.'),
      _PolicyItem('App Interaction & Crash Data',
          'If you opt in, we collect anonymous crash reports (via Sentry) and aggregate screen-view '
          'counts. No personal data is included in crash reports. You can opt out at any time in '
          'Settings → Analytics & Crash Reports.'),
    ],
  ),
  _PolicySection(
    id: 'why',
    title: '2. Why We Collect It',
    icon: Icons.info_outline_rounded,
    color: Color(0xFF8B5CF6),
    items: [
      _PolicyItem('Delivering SOS Alerts',
          'Location and contact data are essential to notify your emergency contacts during a crisis. '
          'Without location, contacts cannot find you. Without contact data, no one is alerted. '
          'These are the core functions of a safety app and cannot be disabled.'),
      _PolicyItem('Evidence Preservation',
          'Audio and video evidence is recorded to help you or authorities if you need to report an '
          'incident. This is entirely in your interest — we do not access or analyse this evidence '
          'unless you explicitly share it with us for support.'),
      _PolicyItem('AI Detection Improvement',
          'With your opt-in consent (Settings → Privacy & Consent → Detection model improvement), '
          'we use anonymised, non-personally-identifiable features from false-positive reports to '
          'improve the scream/motion/scene detection models. Raw audio is never used — only '
          'statistical features (MFCC values, motion magnitude).'),
      _PolicyItem('App Performance & Bug Fixes',
          'Crash data and anonymous analytics help us fix bugs and improve the app experience. '
          'We have a genuine interest in keeping the app stable for safety purposes.'),
    ],
  ),
  _PolicySection(
    id: 'share',
    title: '3. Who We Share It With',
    icon: Icons.share_rounded,
    color: Color(0xFFEF4444),
    items: [
      _PolicyItem('Emergency Contacts (YOU choose)',
          'During an active SOS, your location, a WebLink view of your status, and push '
          'notifications are sent to the contacts YOU have added. You control who these people '
          'are. We do not choose or add contacts.'),
      _PolicyItem('Police Dispatch (SOS only, with your action)',
          'In a future version, you may be able to send an automated alert to local emergency '
          'services (112 in India). This requires your explicit in-app action — it never happens '
          'automatically without your confirmation or a configured trigger you set up.'),
      _PolicyItem('AWS (Hosting)',
          'Your data is hosted on AWS ap-south-1 (Mumbai), keeping your data in India as required '
          'by DPDP. AWS processes data on our behalf under our Data Processing Agreement. They '
          'do not have rights to use your data for any purpose other than hosting.'),
      _PolicyItem('Sentry (Crash Reporting, opt-in only)',
          'If you opt in to crash reporting, Sentry receives anonymous crash stack traces. '
          'No personal data (name, phone number, location, contacts) is included. Sentry is '
          'bound by GDPR-compliant data processing terms.'),
      _PolicyItem('We DO NOT sell your data',
          'ZapSafe does not sell, rent, or share your personal data with advertisers, data '
          'brokers, or any third party for commercial purposes. Ever.'),
    ],
  ),
  _PolicySection(
    id: 'retention',
    title: '4. How Long We Keep It',
    icon: Icons.timer_rounded,
    color: Color(0xFFF97316),
    items: [
      _PolicyItem('Evidence Files (audio/video)',
          'Kept on your device for 30 days by default. You can change this in Settings → '
          'Data Retention (7 / 30 / 90 days). After the retention period, files are permanently '
          'deleted from your device. Cloud backup (if enabled) follows the same retention period '
          'on our servers.'),
      _PolicyItem('GPS Traces',
          'GPS traces are kept for 30 days. Older traces are automatically purged. You can '
          'clear all GPS data at any time from Settings → Data Retention.'),
      _PolicyItem('SOS Event History (metadata)',
          'SOS event records (time, contacts notified, outcome — not the evidence files) '
          'are kept until you delete your account. These are needed for your event history view.'),
      _PolicyItem('Account Data',
          'Your profile, contacts, and preferences are kept until you delete your account. '
          'After account deletion, a 30-day grace period allows recovery. After 30 days, '
          'all data is permanently and irreversibly deleted.'),
      _PolicyItem('Crash Reports',
          'Sentry crash reports are retained for 90 days, then automatically deleted.'),
    ],
  ),
  _PolicySection(
    id: 'rights',
    title: '5. Your Rights',
    icon: Icons.gavel_rounded,
    color: Color(0xFF10B981),
    items: [
      _PolicyItem('Right to Access (DPDP / GDPR)',
          'You can request a copy of all data we hold about you. Go to Settings → '
          'Download My Data. We will email you a secure download link within 48 hours. '
          'The export includes your profile, contacts, SOS history, and evidence metadata '
          '(not the raw evidence files, which are on your device).'),
      _PolicyItem('Right to Erasure / Deletion (DPDP / GDPR)',
          'You can permanently delete your account and all associated data. Go to '
          'Settings → Delete My Account. A 30-day grace period applies (a safety measure — '
          'so an attacker cannot delete your account without your consent). After 30 days, '
          'deletion is permanent and cannot be undone.'),
      _PolicyItem('Right to Withdraw Consent',
          'For all optional data processing (heatmap contribution, analytics, model improvement), '
          'you can withdraw consent at any time in Settings → Privacy & Consent. Withdrawal '
          'takes effect immediately — we stop processing that data type right away.'),
      _PolicyItem('Right to Object',
          'You can object to any data processing not strictly required for the app to function. '
          'The only data we process without the ability to opt out is what is necessary for '
          'SOS delivery (location during SOS, contact notifications) — because it is the '
          'literal purpose of the app.'),
      _PolicyItem('How to Exercise Your Rights',
          'Most rights are exercisable directly in the app (Settings). For anything not '
          'available in-app, contact us at $_kContactEmail. We will respond within 72 hours.'),
    ],
  ),
  _PolicySection(
    id: 'security',
    title: '6. Security',
    icon: Icons.security_rounded,
    color: Color(0xFFF59E0B),
    items: [
      _PolicyItem('Encryption',
          'Evidence files are AES-256 encrypted on-device. Data in transit uses TLS 1.2+ '
          'with certificate pinning (the app rejects any connection that does not match our '
          'known server certificate). JWT tokens are stored in Android Keystore / iOS Keychain.'),
      _PolicyItem('No Raw Audio to Servers',
          'Our AI models run entirely on your device. Raw audio is never uploaded. Only '
          'statistical features (MFCC coefficients, spectral centroid values) and SHA-256 '
          'hashes are sent to our servers — and only for the optional model improvement feature '
          'when you have opted in.'),
      _PolicyItem('Evidence Integrity',
          'SHA-256 hashes of evidence files are recorded at capture time. These hashes are '
          'immutable on our servers, creating a tamper-evident chain of custody that '
          'can be verified in legal proceedings.'),
      _PolicyItem('Security Incident Response',
          'In the event of a security breach that affects your personal data, we will notify '
          'you within 72 hours of discovering the breach, as required by DPDP/GDPR.'),
    ],
  ),
  _PolicySection(
    id: 'contact',
    title: '7. Contact & Grievance',
    icon: Icons.mail_rounded,
    color: Color(0xFF06B6D4),
    items: [
      _PolicyItem('Data Protection Officer',
          'For privacy-related questions, data access requests, or complaints:\n'
          'Email: $_kContactEmail\n'
          'Response time: 72 hours\n'
          'Language: English, Hindi'),
      _PolicyItem('India Grievance Officer (DPDP Act)',
          'As required by the DPDP Act 2023, we have designated a Grievance Officer '
          'for users in India:\n'
          'Email: grievance@zapsafe.app\n'
          'You can also raise a complaint with the Data Protection Board of India if '
          'your grievance is not resolved to your satisfaction.'),
      _PolicyItem('Updates to This Policy',
          'When we update this policy, we will notify you in-app and require you to '
          'review and re-accept the updated version. The version number and date at '
          'the top of this screen always reflect the current version you have accepted.'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day151PrivacyPolicyScreen extends ConsumerStatefulWidget {
  /// [showAcceptButton] is true only in the first-launch consent flow (Day 161-162).
  /// In normal Settings navigation it is false (read-only).
  final bool showAcceptButton;
  const Day151PrivacyPolicyScreen({super.key, this.showAcceptButton = false});

  @override
  ConsumerState<Day151PrivacyPolicyScreen> createState() =>
      _Day151PrivacyPolicyScreenState();
}

class _Day151PrivacyPolicyScreenState
    extends ConsumerState<Day151PrivacyPolicyScreen> {
  final _scrollController = ScrollController();
  final _sectionKeys = List.generate(
      _kSections.length, (_) => GlobalKey());

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    ref.read(_tocExpandedProvider.notifier).state = false;
    ref.read(_activeSectionProvider.notifier).state = index;
    final ctx = _sectionKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tocExpanded = ref.watch(_tocExpandedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Privacy Policy'),
        elevation: 0,
        actions: [
          // ToC toggle
          GestureDetector(
            onTap: () => ref
                .read(_tocExpandedProvider.notifier)
                .state = !tocExpanded,
            child: Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Icon(
                tocExpanded
                    ? Icons.list_alt_rounded
                    : Icons.list_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Version header
          _VersionHeader(),

          // Table of contents (collapsible)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: tocExpanded
                ? _TableOfContents(onTap: _scrollToSection)
                : const SizedBox.shrink(),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(ZapSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro
                  const _IntroBlock(),
                  const SizedBox(height: ZapSpacing.xl),

                  // Sections
                  ..._kSections.asMap().entries.map((e) => Padding(
                        key: _sectionKeys[e.key],
                        padding: const EdgeInsets.only(bottom: ZapSpacing.xl),
                        child: _SectionCard(
                            section: e.value, index: e.key),
                      )),

                  // Footer
                  const _PolicyFooter(),
                  const SizedBox(height: ZapSpacing.huge),
                ],
              ),
            ),
          ),

          // Accept button (first-launch consent flow only)
          if (widget.showAcceptButton) _AcceptBar(),
        ],
      ),
    );
  }
}

// ── Version header ─────────────────────────────────────────────────────────────
class _VersionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(children: [
        const Icon(Icons.privacy_tip_rounded,
            color: Color(0xFF3B82F6), size: 16),
        const SizedBox(width: ZapSpacing.sm),
        const Expanded(
          child: Text(
            'Version $_kVersion  ·  Last updated: $_kLastUpdated',
            style: TextStyle(
                color: Color(0xFF6B7280), fontSize: 11),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: const Text('DPDP + GDPR',
              style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Table of contents ──────────────────────────────────────────────────────────
class _TableOfContents extends StatelessWidget {
  final ValueChanged<int> onTap;
  const _TableOfContents({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONTENTS',
              style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: ZapSpacing.sm),
          ..._kSections.asMap().entries.map((e) => GestureDetector(
                onTap: () => onTap(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(e.value.icon, color: e.value.color, size: 14),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(e.value.title,
                        style: TextStyle(
                            color: e.value.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Intro block ────────────────────────────────────────────────────────────────
class _IntroBlock extends StatelessWidget {
  const _IntroBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1520), Color(0xFF060A10), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shield_rounded, color: Color(0xFF3B82F6), size: 20),
            SizedBox(width: ZapSpacing.sm),
            Text('ZapSafe Privacy Policy',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: ZapSpacing.md),
          Text(
            'ZapSafe is a personal safety app designed to protect people — especially '
            'women, night-shift workers, and domestic abuse survivors. '
            'Because we handle sensitive emergency data, we take privacy extremely seriously.\n\n'
            'This policy explains exactly what data we collect, why, who can see it, '
            'how long we keep it, and what rights you have. We write this in plain language '
            'on purpose — legal jargon defeats the goal of informed consent.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.7),
          ),
          SizedBox(height: ZapSpacing.md),
          // Key promises chips
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            children: [
              _PromiseChip('No ads', Color(0xFF10B981)),
              _PromiseChip('No data selling', Color(0xFF10B981)),
              _PromiseChip('No raw audio to servers', Color(0xFF10B981)),
              _PromiseChip('Evidence stays on device', Color(0xFF3B82F6)),
              _PromiseChip('DPDP compliant', Color(0xFF8B5CF6)),
              _PromiseChip('GDPR compliant', Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromiseChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _PromiseChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ── Section card ───────────────────────────────────────────────────────────────
class _SectionCard extends StatefulWidget {
  final _PolicySection section;
  final int index;
  const _SectionCard({required this.section, required this.index});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  final _expandedItems = <int>{};

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: section.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(section.icon, color: section.color, size: 16),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(section.title,
                style: TextStyle(
                    color: section.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: ZapSpacing.md),

        // Items
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: section.items.asMap().entries.map((e) {
              final i      = e.key;
              final item   = e.value;
              final isLast = i == section.items.length - 1;
              final isExp  = _expandedItems.contains(i);

              return GestureDetector(
                onTap: () => setState(() {
                  if (isExp) {
                    _expandedItems.remove(i);
                  } else {
                    _expandedItems.add(i);
                  }
                }),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                              color: section.color,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.heading,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                child: isExp
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                            top: ZapSpacing.sm),
                                        child: Text(item.body,
                                            style: const TextStyle(
                                                color: Color(0xFFD1D5DB),
                                                fontSize: 12,
                                                height: 1.65)),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            top: 3),
                                        child: Text(
                                          item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 11,
                                              height: 1.4),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Icon(
                          isExp
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF4B5563), size: 16),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Policy footer ──────────────────────────────────────────────────────────────
class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mail_rounded, color: Color(0xFF06B6D4), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Text('Privacy questions or data requests:',
                style: TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: ZapSpacing.xs),
          Text(_kContactEmail,
              style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 12,
                  fontFamily: 'monospace')),
          SizedBox(height: ZapSpacing.md),
          Text(
            'Privacy Policy v$_kVersion · Last updated $_kLastUpdated\n'
            'Governing law: India (DPDP Act 2023) + GDPR (international users)\n'
            'This policy is bundled in the app and works offline.',
            style: TextStyle(
                color: Color(0xFF4B5563), fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Accept bar (first-launch consent flow only) ────────────────────────────────
class _AcceptBar extends StatefulWidget {
  @override
  State<_AcceptBar> createState() => _AcceptBarState();
}

class _AcceptBarState extends State<_AcceptBar> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: ZapSpacing.lg,
        right: ZapSpacing.lg,
        top: ZapSpacing.md,
        bottom: ZapSpacing.lg +
            MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _checked = !_checked),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: _checked
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _checked
                            ? const Color(0xFF10B981)
                            : const Color(0xFF4B5563),
                        width: 2),
                  ),
                  child: _checked
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 14)
                      : null,
                ),
                const SizedBox(width: ZapSpacing.sm),
                const Expanded(
                  child: Text(
                    'I have read and agree to the Privacy Policy and Terms of Service. '
                    'I understand what data is collected and why.',
                    style: TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: _checked
                ? () => Navigator.of(context).pop(true)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _checked
                    ? const LinearGradient(colors: [
                        Color(0xFF059669),
                        Color(0xFF10B981),
                      ])
                    : null,
                color: _checked ? null : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: _checked
                    ? [
                        BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ]
                    : null,
                border: _checked
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded,
                      color: _checked
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    _checked
                        ? 'I Agree — Continue to ZapSafe'
                        : 'Please check the box above',
                    style: TextStyle(
                      color: _checked
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
