/// Day 153-154 — Terms of Service Screen
///
/// 🟢 FRONTEND-ONLY — zero backend, zero conflict.
/// Content is bundled as local structured data (no server call).
///
/// This is ESPECIALLY IMPORTANT for ZapSafe because it is a
/// life-safety product. The ToS must prominently state:
///   • ZapSafe is a best-effort tool, NOT a guaranteed emergency service
///   • Users should still call 112 / 911 directly whenever possible
///   • We are not liable if SOS fails (no signal, battery, OS kill, etc.)
///
/// Required by:
///   • Apple App Store (must be accessible in-app)
///   • Google Play (same requirement)
///   • India DPDP Act 2023 (terms of use must be clearly presented)
///
/// The emergency disclaimer section uses bold/prominent red styling to
/// ensure users cannot miss it — this protects the company legally.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _tosTocExpandedProvider   = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
const _kTosVersion     = '1.0';
const _kTosLastUpdated = 'June 17, 2026';
const _kGoverningLaw   = 'India (DPDP Act 2023)';
const _kSupportEmail   = 'support@zapsafe.app';

class _TosSection {
  final String id;
  final String title;
  final IconData icon;
  final Color  color;
  final bool   isCritical; // true = emergency disclaimer — rendered prominently
  final List<_TosItem> items;
  const _TosSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.isCritical = false,
  });
}

class _TosItem {
  final String heading;
  final String body;
  final bool   isBold; // highlighted subsection
  const _TosItem(this.heading, this.body, {this.isBold = false});
}

const _kTosSections = [
  _TosSection(
    id: 'acceptance',
    title: '1. Acceptance of Terms',
    icon: Icons.handshake_rounded,
    color: Color(0xFF3B82F6),
    items: [
      _TosItem('Agreement',
          'By downloading, installing, or using ZapSafe, you agree to be bound by these '
          'Terms of Service ("Terms"). If you do not agree, do not install or use the app.'),
      _TosItem('Eligibility',
          'You must be at least 13 years of age to use ZapSafe. If you are under 18, '
          'you must have the permission of a parent or legal guardian. Using ZapSafe on behalf '
          'of a minor under 13 is not permitted.'),
      _TosItem('Updates to Terms',
          'We may update these Terms from time to time. When we do, we will notify you '
          'in-app and require you to review and accept the new version before continuing to '
          'use ZapSafe. Continued use after acceptance constitutes agreement to the updated Terms.'),
      _TosItem('Language',
          'The authoritative version of these Terms is in English. Translations into other '
          'languages are provided for convenience only. In case of conflict, the English version '
          'controls.'),
    ],
  ),
  _TosSection(
    id: 'description',
    title: '2. Description of Service',
    icon: Icons.info_outline_rounded,
    color: Color(0xFF8B5CF6),
    items: [
      _TosItem('What ZapSafe Does',
          'ZapSafe is a personal safety application that uses AI-based detection (sound, motion, '
          'scene), GPS tracking, and emergency contact notification to assist users in distress. '
          'It provides: (a) automatic SOS triggering, (b) evidence capture and preservation, '
          '(c) emergency contact notification, (d) personal safety tools (journey mode, drills, heatmap).'),
      _TosItem('What ZapSafe Does NOT Do',
          'ZapSafe is NOT: (a) an emergency call service (it does not call 112 or 911 on your behalf), '
          '(b) a law enforcement platform, (c) a medical response service, '
          '(d) a substitute for professional security services, '
          '(e) a guaranteed protection system. '
          'The app supplements but does not replace direct emergency contact.'),
      _TosItem('Availability',
          'ZapSafe requires a working internet connection to notify emergency contacts. '
          'Evidence capture and detection work offline, but notifications are NOT delivered '
          'without network connectivity. The app requires: a smartphone with GPS, microphone '
          'permission, and battery charge.'),
      _TosItem('Beta and Development Versions',
          'Features may be added, changed, or removed. During beta testing (the phase you '
          'are currently in), the service is provided on a best-effort basis without guaranteed '
          'uptime or availability.'),
    ],
  ),
  _TosSection(
    id: 'disclaimer',
    title: '3. ⚠️ Emergency Services Disclaimer',
    icon: Icons.warning_rounded,
    color: Color(0xFFEF4444),
    isCritical: true,
    items: [
      _TosItem(
          'ALWAYS CALL 112 / 911 DIRECTLY',
          'ZapSafe is a SUPPLEMENTARY tool. In any genuine emergency, '
          'your first action should always be to call emergency services directly: '
          '112 in India, 999 in UK, 911 in USA, or your local emergency number. '
          'DO NOT rely solely on ZapSafe when direct communication is possible.',
          isBold: true),
      _TosItem(
          'Technology Limitations',
          'ZapSafe may FAIL to trigger, notify, or deliver SOS in the following situations: '
          '(1) No internet connection or poor signal; '
          '(2) Battery dead or critically low; '
          '(3) Device OS has killed the app background process (especially on Samsung, Xiaomi, Huawei with aggressive battery management); '
          '(4) Emergency contacts have disabled notifications or changed their number; '
          '(5) Audio/motion detection not triggered by the specific type of threat. '
          'NONE of these failures constitute liability on our part.',
          isBold: true),
      _TosItem('No Guarantee of Response Time',
          'Even when ZapSafe successfully notifies emergency contacts, there is no guarantee '
          'that contacts will see the notification, be available, or be able to respond within '
          'any particular time. Emergency response depends on factors entirely outside our control.'),
      _TosItem('Evidence Admissibility',
          'ZapSafe evidence (audio, video, GPS) is captured with a chain-of-custody hash. '
          'However, we make NO representation that this evidence will be admissible in court '
          'in any jurisdiction. Legal admissibility depends on local law and the circumstances '
          'of capture.'),
      _TosItem('AI Detection Accuracy',
          'Our AI models (scream detection, motion anomaly, scene analysis) are not perfect. '
          'They have false positive rates (incorrectly triggering SOS) and false negative rates '
          '(failing to detect genuine emergencies). You should not rely exclusively on AI '
          'detection — learn and use the manual SOS triggers as your primary activation method.'),
    ],
  ),
  _TosSection(
    id: 'responsibilities',
    title: '4. User Responsibilities',
    icon: Icons.person_rounded,
    color: Color(0xFF10B981),
    items: [
      _TosItem('Keep Emergency Contacts Updated',
          'You are responsible for maintaining accurate emergency contacts. '
          'Contacts who have changed their phone number, disabled notifications, or are '
          'unreachable cannot receive SOS alerts. Verify your contacts regularly and run '
          'drills to confirm delivery. ZapSafe is not liable for undelivered alerts due to '
          'contact information you have not kept current.'),
      _TosItem('Run Regular Drills',
          'We strongly recommend running an SOS drill at least once per month '
          '(Settings → Drill Mode). This tests your detection settings, notification delivery, '
          'and contact availability. The [DRILL] label on drill notifications distinguishes '
          'tests from real emergencies. Failure to test regularly increases your risk.'),
      _TosItem('Keep the App Updated',
          'You are responsible for keeping ZapSafe updated to the latest version. '
          'Old versions may have security vulnerabilities or unpatched AI model issues. '
          'We strongly recommend enabling automatic app updates.'),
      _TosItem('Acceptable Use',
          'You may not use ZapSafe: '
          '(a) to file false emergency reports, '
          '(b) to harass or track another person without their consent, '
          '(c) to circumvent the app\'s safety restrictions, '
          '(d) for any illegal purpose. '
          'Misuse may result in immediate account termination and referral to law enforcement.'),
      _TosItem('Account Credentials',
          'You are responsible for the security of your account. '
          'Do not share your PIN with others (except trusted emergency contacts who need it '
          'to cancel a false alarm). If you believe your account is compromised, change your '
          'PIN immediately and review your active sessions (Settings → Security → Active Devices).'),
    ],
  ),
  _TosSection(
    id: 'liability',
    title: '5. Limitation of Liability',
    icon: Icons.balance_rounded,
    color: Color(0xFFF97316),
    items: [
      _TosItem('Maximum Liability',
          '"ZapSafe" (the operator) shall not be liable for any indirect, incidental, '
          'special, consequential, or punitive damages, including but not limited to: '
          'harm arising from failure of the SOS system, delayed or undelivered notifications, '
          'inaccurate AI detection, data loss, or device compatibility issues. '
          'Our total liability to you for any claim shall not exceed the amount you paid us '
          'in the 12 months preceding the claim (which may be zero for free users).'),
      _TosItem('Indemnification',
          'You agree to indemnify and hold harmless ZapSafe, its directors, employees, '
          'and contractors from any claims, losses, or damages (including legal fees) '
          'arising from your use of the app in violation of these Terms, including '
          'filing false SOS reports, misuse of evidence capture, or unauthorized account sharing.'),
      _TosItem('Force Majeure',
          'We are not liable for failures caused by: natural disasters, power outages, '
          'government-ordered network shutdowns, cyberattacks on third-party infrastructure '
          '(AWS, FCM/APNs), carrier-level SMS failures, or any other event beyond our '
          'reasonable control.'),
      _TosItem('Third-Party Services',
          'ZapSafe relies on third-party services (AWS for hosting, Firebase for notifications, '
          'Stripe for payments). We are not liable for failures of these third-party services, '
          'though we will make commercially reasonable efforts to restore service.'),
    ],
  ),
  _TosSection(
    id: 'termination',
    title: '6. Account Termination',
    icon: Icons.no_accounts_rounded,
    color: Color(0xFFF59E0B),
    items: [
      _TosItem('Termination by You',
          'You may delete your account at any time (Settings → Delete My Account). '
          'A 30-day grace period applies before permanent deletion. During this period you '
          'can recover your account by logging back in. After 30 days, all data is '
          'permanently and irreversibly deleted.'),
      _TosItem('Termination by Us',
          'We reserve the right to suspend or terminate your account without prior notice if: '
          '(a) you violate these Terms (especially the acceptable use provisions), '
          '(b) you engage in fraudulent activity, '
          '(c) continued service poses a legal risk to us or other users, '
          '(d) you are under 13 years of age.'),
      _TosItem('Effect of Termination',
          'On termination, your access to the app is immediately revoked. '
          'Evidence on your device is not deleted by us — that is your data and remains on '
          'your device until you clear it or it expires per your retention settings. '
          'Server-side data is deleted per the privacy policy timeline.'),
    ],
  ),
  _TosSection(
    id: 'governing',
    title: '7. Governing Law & Disputes',
    icon: Icons.gavel_rounded,
    color: Color(0xFF06B6D4),
    items: [
      _TosItem('Governing Law',
          'These Terms are governed by the laws of India, including the Information Technology '
          'Act 2000, the DPDP Act 2023, and the Consumer Protection Act 2019. '
          'For users outside India, applicable local consumer protection laws may also apply.'),
      _TosItem('Dispute Resolution',
          'We prefer to resolve disputes informally. If you have a complaint, contact '
          '$_kSupportEmail first and we will make good-faith efforts to resolve it within '
          '30 days. If we cannot resolve the dispute informally, it shall be referred to '
          'arbitration in Bengaluru, India, under the Arbitration and Conciliation Act 1996.'),
      _TosItem('Class Action Waiver',
          'To the extent permitted by applicable law, you waive the right to participate '
          'in any class-action lawsuit against ZapSafe. Disputes must be brought individually.'),
      _TosItem('Contact',
          'For legal notices or questions about these Terms:\n'
          'Email: legal@zapsafe.app\n'
          'Response time: 5 business days'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day153TermsOfServiceScreen extends ConsumerStatefulWidget {
  /// [showAcceptButton] is true only in the first-launch consent flow (Day 161-162).
  final bool showAcceptButton;
  const Day153TermsOfServiceScreen({super.key, this.showAcceptButton = false});

  @override
  ConsumerState<Day153TermsOfServiceScreen> createState() =>
      _Day153TermsOfServiceScreenState();
}

class _Day153TermsOfServiceScreenState
    extends ConsumerState<Day153TermsOfServiceScreen> {
  final _scrollController = ScrollController();
  final _sectionKeys = List.generate(_kTosSections.length, (_) => GlobalKey());

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    ref.read(_tosTocExpandedProvider.notifier).state = false;
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
    final tocExpanded = ref.watch(_tosTocExpandedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Terms of Service'),
        elevation: 0,
        actions: [
          GestureDetector(
            onTap: () => ref
                .read(_tosTocExpandedProvider.notifier)
                .state = !tocExpanded,
            child: Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Icon(
                tocExpanded ? Icons.list_alt_rounded : Icons.list_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Version header
          _TosVersionHeader(),

          // Collapsible ToC
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: tocExpanded
                ? _TosToc(onTap: _scrollToSection)
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
                  const _TosIntroBlock(),
                  const SizedBox(height: ZapSpacing.xl),

                  ..._kTosSections.asMap().entries.map((e) => Padding(
                        key: _sectionKeys[e.key],
                        padding: const EdgeInsets.only(bottom: ZapSpacing.xl),
                        child: e.value.isCritical
                            ? _CriticalSection(section: e.value)
                            : _TosSectionWidget(
                                section: e.value, sectionIndex: e.key),
                      )),

                  const _TosFooter(),
                  const SizedBox(height: ZapSpacing.huge),
                ],
              ),
            ),
          ),

          if (widget.showAcceptButton) _TosAcceptBar(),
        ],
      ),
    );
  }
}

// ── Version header ─────────────────────────────────────────────────────────────
class _TosVersionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: Row(children: [
        const Icon(Icons.gavel_rounded,
            color: Color(0xFF8B5CF6), size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(
            'Version $_kTosVersion  ·  Last updated: $_kTosLastUpdated',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.3)),
          ),
          child: const Text('Read Section 3 First',
              style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Table of contents ──────────────────────────────────────────────────────────
class _TosToc extends StatelessWidget {
  final ValueChanged<int> onTap;
  const _TosToc({required this.onTap});

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
          ..._kTosSections.asMap().entries.map((e) => GestureDetector(
                onTap: () => onTap(e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(e.value.icon,
                        color: e.value.color, size: 14),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(e.value.title,
                        style: TextStyle(
                            color: e.value.isCritical
                                ? const Color(0xFFEF4444)
                                : e.value.color,
                            fontSize: 12,
                            fontWeight: e.value.isCritical
                                ? FontWeight.w800
                                : FontWeight.w500)),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

// ── Intro block ────────────────────────────────────────────────────────────────
class _TosIntroBlock extends StatelessWidget {
  const _TosIntroBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF18080A), Color(0xFF0D0405), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: ZapSpacing.sm),
            Text('Important — Please Read',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'ZapSafe is a personal safety TOOL, not a guaranteed emergency service. '
            'ALWAYS call 112 (India), 999 (UK), 911 (US) or your local emergency '
            'number in any genuine emergency — do not rely solely on this app.',
            style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'ZapSafe Terms of Service',
            style: TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'These Terms govern your use of ZapSafe. By using the app, '
            'you agree to these terms. These Terms work together with our '
            'Privacy Policy — please read both.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            children: const [
              _TosChip('Read Section 3 First',   Color(0xFFEF4444)),
              _TosChip('Not liable for failures',Color(0xFFF97316)),
              _TosChip('Call 112 directly',      Color(0xFFEF4444)),
              _TosChip('India law governs',      Color(0xFF8B5CF6)),
              _TosChip('Arbitration in Bengaluru',Color(0xFF06B6D4)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TosChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _TosChip(this.label, this.color);

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

// ── Critical section (Section 3 — Emergency Disclaimer) ────────────────────────
class _CriticalSection extends StatefulWidget {
  final _TosSection section;
  const _CriticalSection({required this.section});

  @override
  State<_CriticalSection> createState() => _CriticalSectionState();
}

class _CriticalSectionState extends State<_CriticalSection> {
  final _expanded = <int>{0, 1}; // first two items expanded by default

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A0505),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        // Critical header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.12),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 2)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_rounded,
                color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title,
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const Text(
                    'This section is the most legally important — read it carefully.',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // Items
        ...section.items.asMap().entries.map((e) {
          final i      = e.key;
          final item   = e.value;
          final isLast = i == section.items.length - 1;
          final isExp  = _expanded.contains(i);

          return GestureDetector(
            onTap: () => setState(() {
              if (isExp) {
                _expanded.remove(i);
              } else {
                _expanded.add(i);
              }
            }),
            child: Column(children: [
              Container(
                color: item.isBold
                    ? const Color(0xFFEF4444).withOpacity(0.06)
                    : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                              color: item.isBold
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF4B5563),
                              shape: BoxShape.circle)),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.heading,
                                style: TextStyle(
                                    color: item.isBold
                                        ? const Color(0xFFFF7B72)
                                        : Colors.white,
                                    fontSize: item.isBold ? 14 : 13,
                                    fontWeight: item.isBold
                                        ? FontWeight.w800
                                        : FontWeight.w600)),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              child: isExp
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                          top: ZapSpacing.sm),
                                      child: Text(item.body,
                                          style: TextStyle(
                                              color: item.isBold
                                                  ? const Color(0xFFFFD0CA)
                                                  : const Color(0xFFD1D5DB),
                                              fontSize: 12,
                                              height: 1.65)),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xFF6B7280),
                                              fontSize: 11, height: 1.4)),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                          isExp
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF4B5563), size: 16),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Normal ToS section ─────────────────────────────────────────────────────────
class _TosSectionWidget extends StatefulWidget {
  final _TosSection section;
  final int         sectionIndex;
  const _TosSectionWidget({required this.section, required this.sectionIndex});

  @override
  State<_TosSectionWidget> createState() => _TosSectionState();
}

class _TosSectionState extends State<_TosSectionWidget> {
  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              final isExp  = _expanded.contains(i);

              return GestureDetector(
                onTap: () => setState(() {
                  if (isExp) {
                    _expanded.remove(i);
                  } else {
                    _expanded.add(i);
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
                                shape: BoxShape.circle)),
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
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(item.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11, height: 1.4)),
                                      ),
                              ),
                            ],
                          ),
                        ),
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

// ── Footer ─────────────────────────────────────────────────────────────────────
class _TosFooter extends StatelessWidget {
  const _TosFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.mail_rounded, color: Color(0xFF06B6D4), size: 14),
            SizedBox(width: ZapSpacing.sm),
            Text('Legal questions or disputes:',
                style: TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          const Text('legal@zapsafe.app',
              style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 12,
                  fontFamily: 'monospace')),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Terms of Service v$_kTosVersion · Last updated $_kTosLastUpdated\n'
            'Governing law: $_kGoverningLaw\n'
            'This document is bundled in the app and available offline.',
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 10, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Accept bar ─────────────────────────────────────────────────────────────────
class _TosAcceptBar extends StatefulWidget {
  @override
  State<_TosAcceptBar> createState() => _TosAcceptBarState();
}

class _TosAcceptBarState extends State<_TosAcceptBar> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: ZapSpacing.lg,
        right: ZapSpacing.lg,
        top: ZapSpacing.md,
        bottom: ZapSpacing.lg + MediaQuery.of(context).padding.bottom,
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
                        ? const Color(0xFF8B5CF6).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: _checked
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF4B5563),
                        width: 2),
                  ),
                  child: _checked
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF8B5CF6), size: 14)
                      : null,
                ),
                const SizedBox(width: ZapSpacing.sm),
                const Expanded(
                  child: Text(
                    'I have read and agree to the Terms of Service, '
                    'including the emergency services disclaimer in Section 3. '
                    'I understand ZapSafe does not replace calling 112 / 911.',
                    style: TextStyle(
                        color: Color(0xFFD1D5DB), fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          GestureDetector(
            onTap: _checked ? () => Navigator.of(context).pop(true) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _checked
                    ? const LinearGradient(colors: [
                        Color(0xFF5B21B6),
                        Color(0xFF8B5CF6),
                      ])
                    : null,
                color: _checked ? null : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: _checked
                    ? [
                        BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
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
                        ? 'I Agree to Terms — Continue'
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
