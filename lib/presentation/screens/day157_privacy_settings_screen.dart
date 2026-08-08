/// Day 157 — Privacy Settings Hub (Section A complete)
///
/// Third and final day of the Days 155-157 Consent Management block.
/// Day 155: consent toggles + Hive storage.
/// Day 156: impact map + ConsentGate widget + reset.
/// Day 157: the unified Settings → Privacy section that links
///           everything from Days 151-157 into one cohesive hub.
///
/// This screen IS the "Settings → Privacy" entry point users see.
/// It shows:
///   1. Privacy Health Score — a visual summary of how many optional
///      consents are active + which legal docs are accepted
///   2. Quick links to every Privacy/Legal screen
///   3. Consent review reminder — shows "Last reviewed: X days ago"
///      and nudges the user to re-check every 90 days
///   4. Data portability quick actions (stubs for Days 166-180)
///
/// All 🟢 FRONTEND-ONLY — zero backend, local Hive state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import 'day155_consent_management_screen.dart'
    show ConsentType, ConsentItem;

// ── Shared symbols copied from day155 (private symbols can't cross library boundaries) ──
const _kConsentItems = [
  ConsentItem(
    type: ConsentType.locationSos,
    title: 'Location during SOS',
    subtitle: 'Required — cannot disable',
    explanation: 'During an active SOS event, we share your GPS location with your emergency contacts in real-time.',
    consequenceOff: 'Location during SOS is required for the app to work.',
    consequenceOn: '',
    isRequired: true,
    icon: Icons.location_on_rounded,
    color: Color(0xFFEF4444),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.evidenceRecording,
    title: 'Evidence Recording',
    subtitle: 'Audio & video during SOS — stored on device',
    explanation: 'During an SOS, ZapSafe silently records audio and video.',
    consequenceOff: 'No audio or video will be recorded during SOS events.',
    consequenceOn: 'Audio and video will be silently recorded during SOS events.',
    isRequired: false,
    icon: Icons.videocam_rounded,
    color: Color(0xFF8B5CF6),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.cloudBackup,
    title: 'Cloud Evidence Backup',
    subtitle: 'Upload evidence to ZapSafe servers (encrypted)',
    explanation: 'If enabled, evidence recorded during SOS events is uploaded to our AWS servers.',
    consequenceOff: 'Evidence will only be on your device.',
    consequenceOn: 'Evidence will be uploaded to ZapSafe servers (encrypted).',
    isRequired: false,
    icon: Icons.cloud_upload_rounded,
    color: Color(0xFF3B82F6),
    defaultValue: false,
  ),
  ConsentItem(
    type: ConsentType.heatmapContribution,
    title: 'Anonymous Heatmap Contribution',
    subtitle: 'Help warn others about unsafe areas',
    explanation: 'After an SOS event, we may ask if you\'d like to anonymously contribute.',
    consequenceOff: 'Your SOS locations will not contribute to the heatmap.',
    consequenceOn: 'After each SOS, you\'ll be asked if you want to contribute anonymously.',
    isRequired: false,
    icon: Icons.map_rounded,
    color: Color(0xFF10B981),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.analytics,
    title: 'Crash & Usage Analytics',
    subtitle: 'Anonymous crash reports + screen-view counts',
    explanation: 'We use Sentry to collect anonymous crash reports.',
    consequenceOff: 'We will not receive crash reports from your device.',
    consequenceOn: 'Anonymous crash reports and aggregate usage counts will be sent to Sentry.',
    isRequired: false,
    icon: Icons.bug_report_rounded,
    color: Color(0xFFF59E0B),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.modelImprovement,
    title: 'Detection Model Improvement',
    subtitle: 'Help reduce false alarms for everyone',
    explanation: 'When you report a false alarm, you can optionally contribute anonymised features.',
    consequenceOff: 'Your false alarm reports will not contribute to improving detection accuracy.',
    consequenceOn: 'Anonymised statistical audio/motion features may be used to improve the model.',
    isRequired: false,
    icon: Icons.model_training_rounded,
    color: Color(0xFF06B6D4),
    defaultValue: false,
  ),
];

final _consentValuesProvider = StateProvider<Map<ConsentType, bool>>(
  (ref) => {
    for (final item in _kConsentItems)
      item.type: item.defaultValue,
  },
);

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _reminderDaysProvider = StateProvider<int>((ref) => 12); // days since last review
final _lastReviewedProvider = StateProvider<DateTime>(
    (ref) => DateTime(2026, 6, 5, 14, 30)); // mock date

// ── Data ───────────────────────────────────────────────────────────────────────
class _PrivacyLink {
  final String   title;
  final String   subtitle;
  final IconData icon;
  final Color    color;
  final String   route;
  final String   badge; // 'Done' | 'Review' | 'Coming soon'
  final Color    badgeColor;
  const _PrivacyLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    required this.badge,
    required this.badgeColor,
  });
}

const _kPrivacyLinks = [
  _PrivacyLink(
    title: 'Privacy Policy',
    subtitle: 'v2.0 · Accepted June 17, 2026',
    icon: Icons.privacy_tip_rounded,
    color: Color(0xFF3B82F6),
    route: '/privacy-policy',
    badge: 'Accepted ✅',
    badgeColor: Color(0xFF10B981),
  ),
  _PrivacyLink(
    title: 'Terms of Service',
    subtitle: 'v1.0 · Accepted June 17, 2026',
    icon: Icons.gavel_rounded,
    color: Color(0xFF8B5CF6),
    route: '/terms-of-service',
    badge: 'Accepted ✅',
    badgeColor: Color(0xFF10B981),
  ),
  _PrivacyLink(
    title: 'Legal Documents Hub',
    subtitle: 'Certificate · History · Links',
    icon: Icons.folder_special_rounded,
    color: Color(0xFF06B6D4),
    route: '/legal-hub',
    badge: 'Up to date',
    badgeColor: Color(0xFF10B981),
  ),
  _PrivacyLink(
    title: 'Privacy & Consent',
    subtitle: 'Manage what ZapSafe processes',
    icon: Icons.tune_rounded,
    color: Color(0xFF8B5CF6),
    route: '/consent-management',
    badge: 'Review →',
    badgeColor: Color(0xFF8B5CF6),
  ),
  _PrivacyLink(
    title: 'Consent Impact & Gates',
    subtitle: 'Which features each consent enables',
    icon: Icons.lock_clock_rounded,
    color: Color(0xFF3B82F6),
    route: '/consent-gates',
    badge: 'Interactive',
    badgeColor: Color(0xFF3B82F6),
  ),
  _PrivacyLink(
    title: 'Download My Data',
    subtitle: 'Request a copy of all your data',
    icon: Icons.download_rounded,
    color: Color(0xFF10B981),
    route: '/data-export',
    badge: 'Coming Day 166',
    badgeColor: Color(0xFF4B5563),
  ),
  _PrivacyLink(
    title: 'Delete Account',
    subtitle: '30-day grace period · irreversible',
    icon: Icons.delete_forever_rounded,
    color: Color(0xFFEF4444),
    route: '/account-deletion',
    badge: 'Coming Day 169',
    badgeColor: Color(0xFF4B5563),
  ),
];

// Privacy score dimensions
class _ScoreDimension {
  final String  label;
  final int     score; // 0-100
  final Color   color;
  final IconData icon;
  const _ScoreDimension(this.label, this.score, this.color, this.icon);
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day157PrivacySettingsScreen extends ConsumerWidget {
  const Day157PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Privacy Settings'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: const Text('DPDP + GDPR',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Privacy Health Score (always visible at top)
            const _SectionLabel('YOUR PRIVACY HEALTH'),
            const SizedBox(height: ZapSpacing.md),
            const _HealthScoreCard(),
            const SizedBox(height: ZapSpacing.xl),

            // Consent review reminder
            const _ReviewReminderBanner(),
            const SizedBox(height: ZapSpacing.xl),

            // Tab
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _LinksTab(),
            if (tab == 1) const _ConsentSummaryTab(),
            if (tab == 2) const _ReminderSettingsTab(),
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
          colors: [Color(0xFF080A18), Color(0xFF04050D), Color(0xFF0A0A0A)],
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
            _badge('⚡  DAY 157', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Section A Final', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Privacy\nSettings Hub',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'The unified Settings → Privacy entry point. '
            'Privacy health score, all legal docs, consent toggles, '
            'and review reminders — all in one place.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('7',    'Privacy links',  Color(0xFF8B5CF6)),
            _HStat('Score','Health check',   Color(0xFF10B981)),
            _HStat('90d',  'Review cadence', Color(0xFFF59E0B)),
            _HStat('A✅',  'Section done',   Color(0xFF10B981)),
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
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
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

// ── Health Score Card ──────────────────────────────────────────────────────────
class _HealthScoreCard extends ConsumerWidget {
  const _HealthScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values  = ref.watch(_consentValuesProvider);

    // Calculate score
    const legalDone = 2; // both docs accepted (mock)
    final optionalEnabled = _kConsentItems
        .where((c) => !c.isRequired && (values[c.type] ?? false))
        .length;
    final optionalTotal = _kConsentItems.where((c) => !c.isRequired).length;

    // Score breakdown
    final legalScore   = (legalDone / 2 * 100).round();
    const safetyScore  = 100; // location SOS always on
    final privacyScore = (optionalEnabled / optionalTotal * 100).round();
    final overallScore = ((legalScore + safetyScore + privacyScore) / 3).round();

    final dimensions = [
      _ScoreDimension('Legal docs accepted', legalScore, const Color(0xFF3B82F6), Icons.gavel_rounded),
      const _ScoreDimension('Safety consent', safetyScore, Color(0xFFEF4444), Icons.emergency_rounded),
      _ScoreDimension('Optional consents', privacyScore, const Color(0xFF8B5CF6), Icons.tune_rounded),
    ];

    final scoreColor = overallScore >= 80
        ? const Color(0xFF10B981)
        : overallScore >= 50
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: scoreColor.withOpacity(0.4)),
      ),
      child: Column(children: [
        Row(children: [
          // Big score circle
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withOpacity(0.12),
              border: Border.all(color: scoreColor.withOpacity(0.5), width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$overallScore',
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  Text('/100',
                      style: TextStyle(
                          color: scoreColor.withOpacity(0.6),
                          fontSize: 9)),
                ],
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overallScore >= 80
                      ? 'Privacy health: Excellent'
                      : overallScore >= 50
                          ? 'Privacy health: Good'
                          : 'Privacy health: Needs attention',
                  style: TextStyle(
                      color: scoreColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  overallScore >= 80
                      ? 'All legal docs accepted and consent configured.'
                      : 'Review your consent settings to improve your score.',
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        // Dimension bars
        ...dimensions.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _DimensionBar(dim: d),
            )),
      ]),
    );
  }
}

class _DimensionBar extends StatelessWidget {
  final _ScoreDimension dim;
  const _DimensionBar({required this.dim});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(dim.icon, color: dim.color, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(dim.label,
                style: const TextStyle(
                    color: Color(0xFFD1D5DB), fontSize: 11)),
          ),
          Text('${dim.score}%',
              style: TextStyle(
                  color: dim.color, fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: dim.score / 100,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(dim.color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── Review Reminder Banner ─────────────────────────────────────────────────────
class _ReviewReminderBanner extends ConsumerWidget {
  const _ReviewReminderBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_reminderDaysProvider);
    final needsReview = days >= 90;

    if (days < 75) return const SizedBox.shrink();

    final color = needsReview
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        Icon(
          needsReview ? Icons.schedule_rounded : Icons.notifications_rounded,
          color: color, size: 18),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                needsReview
                    ? 'Consent review overdue ($days days)'
                    : 'Consent review due soon ($days days)',
                style: TextStyle(
                    color: color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              const Text(
                'We recommend reviewing your privacy settings every 90 days.',
                style: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 10)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            // Reset reminder counter
            ref.read(_reminderDaysProvider.notifier).state = 0;
            ref.read(_lastReviewedProvider.notifier).state = DateTime.now();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Review reminder reset — see you in 90 days!'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Review',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.menu_rounded,          Color(0xFF8B5CF6), 'All Links'),
      (Icons.checklist_rounded,     Color(0xFF10B981), 'Consent Summary'),
      (Icons.alarm_rounded,         Color(0xFFF59E0B), 'Reminders'),
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

// ── Links Tab ──────────────────────────────────────────────────────────────────
class _LinksTab extends StatelessWidget {
  const _LinksTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Legal group
        _GroupHeader('Legal Documents', Icons.gavel_rounded, const Color(0xFF8B5CF6)),
        const SizedBox(height: ZapSpacing.sm),
        ..._kPrivacyLinks.take(3).map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PrivacyLinkCard(link: l),
            )),
        const SizedBox(height: ZapSpacing.lg),

        // Consent group
        _GroupHeader('Consent & Privacy', Icons.tune_rounded, const Color(0xFF10B981)),
        const SizedBox(height: ZapSpacing.sm),
        ..._kPrivacyLinks.skip(3).take(2).map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PrivacyLinkCard(link: l),
            )),
        const SizedBox(height: ZapSpacing.lg),

        // Data rights group (coming soon)
        _GroupHeader('Data Rights (Coming Days 166-180)', Icons.admin_panel_settings_rounded,
            const Color(0xFF4B5563)),
        const SizedBox(height: ZapSpacing.sm),
        ..._kPrivacyLinks.skip(5).map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PrivacyLinkCard(link: l, dimmed: true),
            )),
        const SizedBox(height: ZapSpacing.lg),

        // Section A complete card
        _SectionACompleteCard(),
      ],
    );
  }

  Widget _GroupHeader(String title, IconData icon, Color color) => Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Text(title,
            style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ]);
}

class _PrivacyLinkCard extends StatelessWidget {
  final _PrivacyLink link;
  final bool         dimmed;
  const _PrivacyLinkCard({required this.link, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: dimmed
          ? () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${link.title} — ${link.badge}'),
                  backgroundColor: link.color,
                  duration: const Duration(seconds: 2),
                ),
              )
          : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigate to: ${link.route}'),
                  backgroundColor: link.color,
                  duration: const Duration(seconds: 1),
                ),
              ),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: dimmed
              ? const Color(0xFF111111)
              : link.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: dimmed
                ? const Color(0xFF1A1A1A)
                : link.color.withOpacity(0.25),
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: link.color.withOpacity(dimmed ? 0.05 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(link.icon,
                color: dimmed
                    ? link.color.withOpacity(0.3)
                    : link.color,
                size: 18),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.title,
                    style: TextStyle(
                        color: dimmed
                            ? const Color(0xFF4B5563)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(link.subtitle,
                    style: const TextStyle(
                        color: Color(0xFF4B5563), fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: link.badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(link.badge,
                style: TextStyle(
                    color: link.badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Icon(Icons.chevron_right_rounded,
              color: dimmed
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFF4B5563),
              size: 16),
        ]),
      ),
    );
  }
}

class _SectionACompleteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
      ),
      child: Column(children: [
        const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 40),
        const SizedBox(height: ZapSpacing.md),
        const Text('Section A: Privacy & Legal — Complete! ✅',
            style: TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Days 151-157 — 7 screens built.\n'
          'DPDP Act 2023 + GDPR compliant.\n'
          'Zero backend. Zero conflict.',
          style: TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Wrap(
          spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            _Chip('Privacy Policy ✅',     Color(0xFF3B82F6)),
            _Chip('Consent Tracking ✅',   Color(0xFF10B981)),
            _Chip('Terms of Service ✅',   Color(0xFF8B5CF6)),
            _Chip('Legal Hub ✅',          Color(0xFFF59E0B)),
            _Chip('Consent Toggles ✅',    Color(0xFF8B5CF6)),
            _Chip('Consent Gates ✅',      Color(0xFF3B82F6)),
            _Chip('Privacy Hub ✅',        Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(
          icon: Icons.arrow_forward_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Next: Days 158-160 — Permissions Management Screen. '
              'Show all OS permissions ZapSafe uses with their current '
              'status and a direct "Manage" button to system settings.',
        ),
      ]),
    );
  }
}

// ── Consent Summary Tab ────────────────────────────────────────────────────────
class _ConsentSummaryTab extends ConsumerWidget {
  const _ConsentSummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(_consentValuesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.checklist_rounded,
          color: const Color(0xFF10B981),
          text: 'A compact read-only summary of all consent states — '
              'suitable for embedding in the main Settings screen '
              'without opening the full Consent Management screen.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Compact consent list
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kConsentItems.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              final isOn = values[item.type] ?? item.defaultValue;
              final isLast = i == _kConsentItems.length - 1;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 12),
                  child: Row(children: [
                    Icon(item.icon, color: item.color, size: 16),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isRequired
                            ? const Color(0xFFEF4444).withOpacity(0.1)
                            : isOn
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.isRequired
                            ? 'Required'
                            : isOn ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: item.isRequired
                              ? const Color(0xFFEF4444)
                              : isOn
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF6B7280),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Widget code
        _codeNote('widgets/consent_summary_chip.dart',
            '// Embed in main Settings screen:\n'
            'ConsentSummaryRow(\n'
            '  values: ConsentService.currentValues(),\n'
            '  onTap:  () => context.push(AppRoutes.consentManagement),\n'
            ')'),
      ],
    );
  }
}

// ── Reminder Settings Tab ──────────────────────────────────────────────────────
class _ReminderSettingsTab extends ConsumerWidget {
  const _ReminderSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days        = ref.watch(_reminderDaysProvider);
    final lastReviewed= ref.watch(_lastReviewedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.alarm_rounded,
          color: const Color(0xFFF59E0B),
          text: 'ZapSafe reminds you to review your privacy settings '
              'every 90 days. DPDP best practice: consent should be '
              'an ongoing relationship, not a one-time checkbox.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Last reviewed card
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _reviewRow(Icons.calendar_today_rounded, const Color(0xFF3B82F6),
                'Last reviewed',
                '${lastReviewed.day}/${lastReviewed.month}/${lastReviewed.year}'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _reviewRow(Icons.access_time_rounded, const Color(0xFFF59E0B),
                'Days since review', '$days days'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _reviewRow(Icons.event_repeat_rounded, const Color(0xFF10B981),
                'Review frequency', 'Every 90 days'),
            const Divider(height: ZapSpacing.lg, color: Color(0xFF2A2A2A)),
            _reviewRow(Icons.notifications_rounded, const Color(0xFF8B5CF6),
                'Next reminder',
                '${(90 - days).clamp(0, 90)} days from now'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Simulate slider
        const _SectionLabel('SIMULATE  ·  DAYS SINCE LAST REVIEW'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('0 days', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                Text('$days days',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const Text('120 days', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: days >= 90
                    ? const Color(0xFFEF4444)
                    : days >= 75
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                inactiveTrackColor: const Color(0xFF2A2A2A),
                thumbColor: days >= 90
                    ? const Color(0xFFEF4444)
                    : days >= 75
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                overlayColor: const Color(0xFF8B5CF6).withOpacity(0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: days.toDouble(),
                min: 0, max: 120, divisions: 120,
                onChanged: (v) => ref
                    .read(_reminderDaysProvider.notifier)
                    .state = v.round(),
              ),
            ),
            // Threshold markers
            Row(children: [
              const Spacer(flex: 75),
              Container(width: 2, height: 8, color: const Color(0xFFF59E0B).withOpacity(0.5)),
              const Text('  75', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8)),
              const Spacer(flex: 15),
              Container(width: 2, height: 8, color: const Color(0xFFEF4444).withOpacity(0.5)),
              const Text('  90', style: TextStyle(color: Color(0xFFEF4444), fontSize: 8)),
              const Spacer(flex: 30),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Reset button
        _actionButton(
          label: 'Mark as reviewed now',
          icon: Icons.check_rounded,
          color: const Color(0xFF10B981),
          onTap: () {
            ref.read(_reminderDaysProvider.notifier).state = 0;
            ref.read(_lastReviewedProvider.notifier).state = DateTime.now();
          },
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Reminder implementation code
        _codeNote('services/consent_reminder_service.dart',
            '// Check on every app launch:\n'
            'void checkConsentReviewReminder() {\n'
            '  final lastReview = ConsentService.lastReviewDate();\n'
            '  final daysSince  = DateTime.now()\n'
            '      .difference(lastReview).inDays;\n'
            '\n'
            '  if (daysSince >= 90) {\n'
            '    // Show banner on Dashboard (Day 156 PolicyUpdateBanner pattern)\n'
            '    showConsentReviewBanner();\n'
            '  } else if (daysSince >= 75) {\n'
            '    // Show subtle notification\n'
            '    scheduleLocalNotification(\n'
            '      title: "Privacy review due soon",\n'
            '      body: "Review your ZapSafe privacy settings",\n'
            '      when: DateTime.now().add(\n'
            '          Duration(days: 90 - daysSince)),\n'
            '    );\n'
            '  }\n'
            '}'),
      ],
    );
  }

  Widget _reviewRow(IconData icon, Color color, String label, String value) =>
      Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Text('$label:',
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 11,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]);
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

Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
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
