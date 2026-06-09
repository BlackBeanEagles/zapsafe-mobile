/// Day 164 — Data Safety Form & Privacy Labels
///
/// Second day of the Days 163-165 Analytics block.
/// Day 163: toggles, what-we-collect, iOS ATT.
/// Day 164: compliance documentation screens:
///
///   1. Google Play Data Safety Form — guided walkthrough of the
///      exact declarations required for the Play Store listing.
///      Must match actual data practices AND the Privacy Policy.
///
///   2. Analytics Events Reference — every event ZapSafe fires,
///      what it captures, and whether it requires consent.
///
///   3. Apple Privacy Nutrition Label — the categories ZapSafe
///      declares in App Store Connect (Data Used to Track You,
///      Data Linked to You, Data Not Linked to You).
///
/// All 🟢 FRONTEND-ONLY — documentation + form walkthrough.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _formStepProvider     = StateProvider<int>((ref) => 0);
final _formAnswersProvider  = StateProvider<Map<String, String>>((ref) => {});

// ── Data ───────────────────────────────────────────────────────────────────────
class _DataSafetyQuestion {
  final String id;
  final String question;
  final String guidance;
  final String answer;
  final Color  color;
  const _DataSafetyQuestion({
    required this.id,
    required this.question,
    required this.guidance,
    required this.answer,
    required this.color,
  });
}

const _kDataSafetyQuestions = [
  _DataSafetyQuestion(
    id: 'collect',
    question: 'Does your app collect or share any of the required user data types?',
    guidance: 'Answer "Yes" if you collect any data, even for core app functionality.',
    answer: 'YES — ZapSafe collects location, audio, contacts, and device info.',
    color: Color(0xFF10B981),
  ),
  _DataSafetyQuestion(
    id: 'share',
    question: 'Is all of the user data collected by your app encrypted in transit?',
    guidance: 'All API calls must use HTTPS TLS 1.2+.',
    answer: 'YES — all data uses TLS 1.2+ with certificate pinning.',
    color: Color(0xFF10B981),
  ),
  _DataSafetyQuestion(
    id: 'delete',
    question: 'Do you provide a way for users to request that their data is deleted?',
    guidance: 'You must link to an in-app or web form for data deletion.',
    answer: 'YES — Settings → Delete My Account (Days 169-172 screen).',
    color: Color(0xFF10B981),
  ),
  _DataSafetyQuestion(
    id: 'optional',
    question: 'Is data collection required for your app to function, or is it optional?',
    guidance: 'Mark optional data types as optional so users understand they can decline.',
    answer: 'MIXED — location required for SOS; analytics + heatmap optional.',
    color: Color(0xFFF59E0B),
  ),
];

class _DataType {
  final String type;
  final String subtype;
  final bool   collected;
  final bool   shared;
  final bool   optional;
  final bool   encrypted;
  final String purpose;
  final Color  color;
  const _DataType({
    required this.type,
    required this.subtype,
    required this.collected,
    required this.shared,
    required this.optional,
    required this.encrypted,
    required this.purpose,
    required this.color,
  });
}

const _kDataTypes = [
  _DataType(
    type: 'Location',
    subtype: 'Precise location',
    collected: true, shared: true, optional: false, encrypted: true,
    purpose: 'SOS emergency contact notification',
    color: Color(0xFFEF4444),
  ),
  _DataType(
    type: 'Audio',
    subtype: 'Voice or sound recordings',
    collected: true, shared: false, optional: true, encrypted: true,
    purpose: 'Evidence capture (on-device only unless user exports)',
    color: Color(0xFF8B5CF6),
  ),
  _DataType(
    type: 'Contacts',
    subtype: 'Contacts list',
    collected: true, shared: true, optional: false, encrypted: true,
    purpose: 'Store and notify emergency contacts during SOS',
    color: Color(0xFF10B981),
  ),
  _DataType(
    type: 'Device or other IDs',
    subtype: 'Device IDs (hashed)',
    collected: true, shared: false, optional: false, encrypted: true,
    purpose: 'Device tier detection, anonymous consent records',
    color: Color(0xFFF59E0B),
  ),
  _DataType(
    type: 'App activity',
    subtype: 'App interactions',
    collected: true, shared: false, optional: true, encrypted: true,
    purpose: 'Bug fixes and feature improvement (Sentry + analytics)',
    color: Color(0xFF3B82F6),
  ),
  _DataType(
    type: 'Crash logs',
    subtype: 'Crash logs',
    collected: true, shared: false, optional: true, encrypted: true,
    purpose: 'Crash diagnostics via Sentry (if opted in)',
    color: Color(0xFFF59E0B),
  ),
];

class _AnalyticsEvent {
  final String name;
  final String trigger;
  final String captures;
  final bool   requiresConsent;
  final Color  color;
  const _AnalyticsEvent({
    required this.name,
    required this.trigger,
    required this.captures,
    required this.requiresConsent,
    required this.color,
  });
}

const _kEvents = [
  _AnalyticsEvent(
    name: 'screen_view',
    trigger: 'Every time a screen is navigated to',
    captures: 'Screen name + timestamp (no user ID)',
    requiresConsent: true,
    color: Color(0xFF3B82F6),
  ),
  _AnalyticsEvent(
    name: 'sos_trigger',
    trigger: 'SOS is activated (manual or AI)',
    captures: 'Trigger method (volume/shake/manual) + success/fail — NO location, NO contacts',
    requiresConsent: false, // core function
    color: Color(0xFFEF4444),
  ),
  _AnalyticsEvent(
    name: 'feature_used',
    trigger: 'User opens a major feature',
    captures: 'Feature name (e.g. "journey_mode") + outcome — no personal data',
    requiresConsent: true,
    color: Color(0xFF10B981),
  ),
  _AnalyticsEvent(
    name: 'crash',
    trigger: 'Unhandled exception in app code',
    captures: 'Exception class + stack trace + device model + OS version',
    requiresConsent: true, // Sentry opt-in
    color: Color(0xFFF59E0B),
  ),
  _AnalyticsEvent(
    name: 'consent_changed',
    trigger: 'User changes an analytics consent toggle',
    captures: 'Consent type + new value + timestamp — logged locally only, not sent to any server',
    requiresConsent: false, // always local
    color: Color(0xFF8B5CF6),
  ),
  _AnalyticsEvent(
    name: 'onboarding_step',
    trigger: 'Each onboarding step is completed',
    captures: 'Step number + time taken — helps measure onboarding drop-off',
    requiresConsent: true,
    color: Color(0xFF06B6D4),
  ),
];

class _PrivacyLabel {
  final String category;   // Apple's three categories
  final String type;
  final String purpose;
  final bool   linkedToUser;
  const _PrivacyLabel({
    required this.category,
    required this.type,
    required this.purpose,
    required this.linkedToUser,
  });
}

const _kPrivacyLabels = [
  // Data linked to you
  _PrivacyLabel(category: 'Data Linked to You', type: 'Location',
      purpose: 'App Functionality', linkedToUser: true),
  _PrivacyLabel(category: 'Data Linked to You', type: 'Contacts',
      purpose: 'App Functionality', linkedToUser: true),
  // Data not linked to you
  _PrivacyLabel(category: 'Data Not Linked to You', type: 'Crash Data',
      purpose: 'App Functionality', linkedToUser: false),
  _PrivacyLabel(category: 'Data Not Linked to You', type: 'Usage Data',
      purpose: 'Analytics', linkedToUser: false),
  _PrivacyLabel(category: 'Data Not Linked to You', type: 'Device ID',
      purpose: 'App Functionality', linkedToUser: false),
  // Not collected
  _PrivacyLabel(category: 'Not Collected', type: 'Purchases',
      purpose: '—', linkedToUser: false),
  _PrivacyLabel(category: 'Not Collected', type: 'Financial Info',
      purpose: '—', linkedToUser: false),
  _PrivacyLabel(category: 'Not Collected', type: 'Health & Fitness',
      purpose: '—', linkedToUser: false),
  _PrivacyLabel(category: 'Not Collected', type: 'Browsing History',
      purpose: '—', linkedToUser: false),
  _PrivacyLabel(category: 'Not Collected', type: 'Sensitive Info',
      purpose: '—', linkedToUser: false),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day164DataSafetyScreen extends ConsumerWidget {
  const Day164DataSafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Data Safety & Privacy Labels'),
        elevation: 0,
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
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _PlayDataSafetyTab(),
            if (tab == 1) const _EventsReferenceTab(),
            if (tab == 2) const _ApplePrivacyLabelTab(),
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
          colors: [Color(0xFF0A0E14), Color(0xFF05070A), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 164', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Play + App Store', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Data Safety\n& Privacy Labels',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Google Play Data Safety form + Apple Privacy Nutrition Label. '
            'Analytics events reference. All three must match your Privacy Policy.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('Play', 'Data Safety', Color(0xFF3DDC84)),
            _HStat('Apple', 'Privacy Labels', Color(0xFF9CA3AF)),
            _HStat('6', 'Events', Color(0xFF3B82F6)),
            _HStat('Match', 'Policy required', Color(0xFFEF4444)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
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
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
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
      (Icons.android_rounded,   Color(0xFF3DDC84), 'Play Store'),
      (Icons.analytics_rounded, Color(0xFF3B82F6), 'Events'),
      (Icons.apple_rounded,     Color(0xFF9CA3AF), 'App Store'),
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
                    width: isActive ? 2 : 1),
              ),
              child: Column(children: [
                Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(
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

// ── Play Data Safety Tab ───────────────────────────────────────────────────────
class _PlayDataSafetyTab extends StatelessWidget {
  const _PlayDataSafetyTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.android_rounded, color: const Color(0xFF3DDC84),
            text: 'Google Play requires a "Data Safety" section in every app listing. '
                'The answers here MUST match your Privacy Policy. '
                'Mismatches lead to app removal.'),
        const SizedBox(height: ZapSpacing.xl),

        // Questions
        const _SectionLabel('PLAY STORE QUESTIONS  ·  OUR ANSWERS'),
        const SizedBox(height: ZapSpacing.md),
        ..._kDataSafetyQuestions.asMap().entries.map((e) {
          final i  = e.key;
          final q  = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: q.color.withOpacity(0.12), shape: BoxShape.circle),
                    child: Center(child: Text('${i + 1}',
                        style: TextStyle(color: q.color, fontSize: 11,
                            fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(child: Text(q.question,
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: ZapSpacing.sm),
                Text(q.guidance, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                const SizedBox(height: ZapSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: q.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: q.color.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_rounded, color: q.color, size: 14),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(child: Text(q.answer,
                        style: TextStyle(color: q.color, fontSize: 11,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.xl),

        // Data types table
        const _SectionLabel('DATA TYPES DECLARATION'),
        const SizedBox(height: ZapSpacing.md),
        _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
            text: 'For each data type: declare if collected, if shared, '
                'if optional, and if encrypted. These feed directly into '
                'the Play Console Data Safety form.'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: const Row(children: [
                Expanded(flex: 3, child: Text('Data Type', style: TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w700))),
                Expanded(child: Center(child: Text('Coll.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)))),
                Expanded(child: Center(child: Text('Shared', style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)))),
                Expanded(child: Center(child: Text('Opt.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)))),
                Expanded(child: Center(child: Text('Enc.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 9)))),
              ]),
            ),
            ..._kDataTypes.asMap().entries.map((e) {
              final i  = e.key;
              final dt = e.value;
              final isLast = i == _kDataTypes.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(dt.type, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        Text(dt.subtype, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 9)),
                      ]),
                    ),
                    ...[dt.collected, dt.shared, dt.optional, dt.encrypted]
                        .map((v) => Expanded(
                              child: Center(
                                child: Icon(
                                  v ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
                                  color: v ? const Color(0xFF10B981) : const Color(0xFF2A2A2A),
                                  size: 16,
                                ),
                              ),
                            )),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _codeNote('Play Console → App Content → Data Safety',
            '# Fields per data type:\n'
            '  Collected:  YES / NO\n'
            '  Shared:     YES (emergency contacts) / NO (most)\n'
            '  Optional:   YES (analytics, audio evidence)\n'
            '                 / NO (location, contacts — required)\n'
            '  Encrypted:  YES (all — TLS 1.2+ in transit, AES-256 at rest)\n'
            '  User can request deletion: YES (Settings → Delete Account)'),
      ],
    );
  }
}

// ── Events Reference Tab ───────────────────────────────────────────────────────
class _EventsReferenceTab extends StatelessWidget {
  const _EventsReferenceTab();

  @override
  Widget build(BuildContext context) {
    final consentRequired = _kEvents.where((e) => e.requiresConsent).length;
    final alwaysOn        = _kEvents.where((e) => !e.requiresConsent).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.analytics_rounded, color: const Color(0xFF3B82F6),
            text: 'Every analytics event ZapSafe fires. '
                '"Consent required" means the event is only sent '
                'if the user has enabled the relevant analytics toggle. '
                '"Always" events are local-only or core-function logs '
                'that never leave the device.'),
        const SizedBox(height: ZapSpacing.lg),

        // Summary
        Row(children: [
          _sumBox(consentRequired.toString(), 'Consent-gated', const Color(0xFF3B82F6)),
          const SizedBox(width: ZapSpacing.sm),
          _sumBox(alwaysOn.toString(), 'Always / Local', const Color(0xFF10B981)),
          const SizedBox(width: ZapSpacing.sm),
          _sumBox('0', 'PII included', const Color(0xFF4B5563)),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Event list
        const _SectionLabel('ALL ANALYTICS EVENTS'),
        const SizedBox(height: ZapSpacing.md),
        ..._kEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _EventCard(event: event),
            )),
        const SizedBox(height: ZapSpacing.lg),

        // How events are sent
        _codeNote('analytics_service.dart',
            '// Fire an event (respects consent flag):\n'
            'void trackEvent(String name, Map<String, dynamic> props) {\n'
            '  if (!ConsentService.isGranted(ConsentType.analytics)) return;\n'
            '  // Strip any PII before sending\n'
            '  final safe = _stripPii(props);\n'
            '  Sentry.addBreadcrumb(Breadcrumb(\n'
            '    message: name, data: safe,\n'
            '    timestamp: DateTime.now().toUtc(),\n'
            '  ));\n'
            '  // OR: send to your own analytics endpoint (Day 166+)\n'
            '}\n'
            '\n'
            '// Example: screen view\n'
            'trackEvent(\'screen_view\', {\'screen\': \'EvidenceVault\'});'),
      ],
    );
  }

  Widget _sumBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _EventCard extends StatefulWidget {
  final _AnalyticsEvent event;
  const _EventCard({required this.event});
  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _expanded ? e.color.withOpacity(0.06) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: _expanded ? e.color.withOpacity(0.3) : const Color(0xFF2A2A2A)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: e.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(e.name, style: TextStyle(color: e.color, fontSize: 10,
                    fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(e.trigger,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: e.requiresConsent
                      ? const Color(0xFF3B82F6).withOpacity(0.1)
                      : const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  e.requiresConsent ? 'Consent' : 'Always',
                  style: TextStyle(
                      color: e.requiresConsent ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                      fontSize: 8, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF4B5563), size: 16),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Column(children: [
                      const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                      _detailRow('Trigger', e.trigger),
                      const SizedBox(height: 4),
                      _detailRow('Captures', e.captures),
                      const SizedBox(height: 4),
                      _detailRow('Consent needed',
                          e.requiresConsent ? 'YES — only fires when analytics is ON' : 'NO — local only or core function'),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value,
              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.4))),
        ],
      );
}

// ── Apple Privacy Label Tab ────────────────────────────────────────────────────
class _ApplePrivacyLabelTab extends StatelessWidget {
  const _ApplePrivacyLabelTab();

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<_PrivacyLabel>>{};
    for (final pl in _kPrivacyLabels) {
      categories.putIfAbsent(pl.category, () => []).add(pl);
    }

    final catColors = {
      'Data Linked to You':     const Color(0xFFEF4444),
      'Data Not Linked to You': const Color(0xFFF59E0B),
      'Not Collected':          const Color(0xFF10B981),
    };
    final catIcons = {
      'Data Linked to You':     Icons.person_rounded,
      'Data Not Linked to You': Icons.person_off_rounded,
      'Not Collected':          Icons.block_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(icon: Icons.apple_rounded, color: const Color(0xFF9CA3AF),
            text: 'Apple requires a "Privacy Nutrition Label" in App Store Connect. '
                'Declare every data type under three categories. '
                'Must match your Privacy Policy and actual app behaviour.'),
        const SizedBox(height: ZapSpacing.xl),

        // Mock App Store privacy label card
        const _SectionLabel('APP STORE PRIVACY LABEL  ·  MOCK'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3A3A3C)),
          ),
          child: Column(children: [
            // App header
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE63946), Color(0xFFB01F2A)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: ZapSpacing.md),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ZapSafe', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('Personal Safety', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                  ]),
                ),
                const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Privacy', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
                  Text('Nutrition Label', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 9)),
                ]),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFF3A3A3C)),
            // Categories
            ...categories.entries.map((entry) {
              final cat   = entry.key;
              final items = entry.value;
              final color = catColors[cat] ?? const Color(0xFF9CA3AF);
              final icon  = catIcons[cat] ?? Icons.help_outline_rounded;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(cat, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: ZapSpacing.sm),
                    ...items.map((label) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Container(width: 4, height: 4,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(label.type, style: const TextStyle(color: Colors.white, fontSize: 11)),
                            if (label.purpose != '—') ...[
                              const Spacer(),
                              Text(label.purpose,
                                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
                            ],
                          ]),
                        )),
                  ]),
                ),
                if (cat != 'Not Collected') const Divider(height: 1, color: Color(0xFF3A3A3C)),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Matching note
        const _SectionLabel('IMPORTANT  ·  ALL THREE MUST MATCH'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _matchRow(Icons.description_rounded, const Color(0xFF8B5CF6),
                'Privacy Policy (Day 151)', 'Source of truth — the legal document'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _matchRow(Icons.android_rounded, const Color(0xFF3DDC84),
                'Play Data Safety Form', 'Must match Privacy Policy exactly'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _matchRow(Icons.apple_rounded, const Color(0xFF9CA3AF),
                'Apple Privacy Label', 'Must match Privacy Policy exactly'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _matchRow(Icons.tune_rounded, const Color(0xFF10B981),
                'In-App Toggles (Day 163)', 'Must reflect actual SDK behaviour'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.md),
        _infoBox(icon: Icons.warning_amber_rounded, color: const Color(0xFFEF4444),
            text: 'Mismatches between Privacy Policy, store declarations, and '
                'actual app behaviour lead to app rejection or removal. '
                'When you update data practices, update all four in the same release.'),
        const SizedBox(height: ZapSpacing.xl),

        // Completion block
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF3B82F6).withOpacity(0.12),
              const Color(0xFF3B82F6).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
          ),
          child: Column(children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
            const SizedBox(height: ZapSpacing.md),
            const Text('Day 164: Data Safety & Labels ✅',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.lg),
            _infoBox(icon: Icons.arrow_forward_rounded, color: const Color(0xFF10B981),
                text: 'Day 165 completes the Analytics block: '
                    'Analytics preferences hub + final Section A sign-off.'),
          ]),
        ),
      ],
    );
  }

  Widget _matchRow(IconData icon, Color color, String label, String desc) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(desc, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            ]),
          ),
          const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 14),
        ]),
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
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
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
          decoration: BoxDecoration(color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(4)),
          child: Text(filename, style: const TextStyle(color: Color(0xFF79C0FF), fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ]),
    );
