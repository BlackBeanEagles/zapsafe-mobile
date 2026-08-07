/// Day 156 — Consent Impact Map & Feature Gates
///
/// Second day of the Days 155-157 Consent Management block.
/// Day 155 built the toggle UI + Hive storage.
/// Day 156 builds the complementary infrastructure:
///
///   1. Consent Impact Map — shows which app features are
///      affected by which consent. Users can see the consequence
///      of their choices BEFORE they toggle.
///
///   2. ConsentGate widget — a reusable widget any screen
///      wraps around content that requires consent. Shows a
///      "consent required" placeholder if the flag is off,
///      with a single "Enable" button to flip it.
///
///   3. Quick Consent Sheet — a bottom sheet shown when a user
///      tries to use a feature that needs consent they haven't
///      granted. Explains why in context and offers Enable/Skip.
///
///   4. Consent Reset — resets all optional consents to defaults.
///
/// All 🟢 FRONTEND-ONLY — zero backend.
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
    explanation:
        'During an active SOS event, we share your GPS location with your emergency contacts '
        'in real-time.',
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
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _selectedConsentProvider= StateProvider<ConsentType?>(
    (ref) => null);
final _demoGateTypeProvider   = StateProvider<ConsentType>(
    (ref) => ConsentType.evidenceRecording);
final _resetConfirmedProvider = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
class _Feature {
  final String       name;
  final String       description;
  final IconData     icon;
  final Color        color;
  final ConsentType  requiredConsent;
  final String       blockedMessage; // shown in ConsentGate when off
  const _Feature({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredConsent,
    required this.blockedMessage,
  });
}

const _kFeatures = [
  _Feature(
    name: 'Evidence Vault',
    description: 'Audio & video recordings captured during SOS events',
    icon: Icons.lock_rounded,
    color: Color(0xFF8B5CF6),
    requiredConsent: ConsentType.evidenceRecording,
    blockedMessage: 'Evidence recording is disabled. '
        'No audio or video is captured during SOS events.',
  ),
  _Feature(
    name: 'Cloud Evidence Backup',
    description: 'Evidence uploaded to ZapSafe servers (encrypted)',
    icon: Icons.cloud_upload_rounded,
    color: Color(0xFF3B82F6),
    requiredConsent: ConsentType.cloudBackup,
    blockedMessage: 'Cloud backup is off. Evidence exists only on your device.',
  ),
  _Feature(
    name: 'Safety Heatmap',
    description: 'Community map showing incident-rate areas',
    icon: Icons.map_rounded,
    color: Color(0xFF10B981),
    requiredConsent: ConsentType.heatmapContribution,
    blockedMessage: 'Heatmap contribution is off. '
        'Your SOS locations do not appear on the community map.',
  ),
  _Feature(
    name: 'Crash Auto-Report',
    description: 'Automatic crash diagnostics sent to our team',
    icon: Icons.bug_report_rounded,
    color: Color(0xFFF59E0B),
    requiredConsent: ConsentType.analytics,
    blockedMessage: 'Crash reporting is off. '
        'Bugs on your device are invisible to us until you manually report them.',
  ),
  _Feature(
    name: 'AI Model Feedback',
    description: 'False-alarm reports improve scream/motion detection',
    icon: Icons.model_training_rounded,
    color: Color(0xFF06B6D4),
    requiredConsent: ConsentType.modelImprovement,
    blockedMessage: 'Model improvement is off. '
        'Your false-alarm reports are used to cancel SOS only, '
        'not to improve detection for other users.',
  ),
];

// Consent → label mapping
const _kConsentLabels = {
  ConsentType.locationSos:          'Location (SOS)',
  ConsentType.evidenceRecording:    'Evidence Recording',
  ConsentType.cloudBackup:          'Cloud Backup',
  ConsentType.heatmapContribution:  'Heatmap',
  ConsentType.analytics:            'Analytics',
  ConsentType.modelImprovement:     'Model Improvement',
};

// Default consent values
const _kDefaults = {
  ConsentType.locationSos:          true,
  ConsentType.evidenceRecording:    true,
  ConsentType.cloudBackup:          false,
  ConsentType.heatmapContribution:  true,
  ConsentType.analytics:            true,
  ConsentType.modelImprovement:     false,
};

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day156ConsentGatesScreen extends ConsumerWidget {
  const Day156ConsentGatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Consent Impact & Gates'),
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
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ImpactMapTab(),
            if (tab == 1) const _GatesDemoTab(),
            if (tab == 2) const _ResetTab(),
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
          colors: [Color(0xFF080A14), Color(0xFF04050A), Color(0xFF0A0A0A)],
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
            _badge('⚡  DAY 156', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Consent Impact\n& Feature Gates',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Shows which features each consent affects. '
            'The ConsentGate widget gates feature UI behind '
            'an "Enable" prompt when consent is off.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',    'Gated features', Color(0xFF3B82F6)),
            _HStat('Gate', 'Widget pattern', Color(0xFF8B5CF6)),
            _HStat('Sheet','Quick consent',  Color(0xFFF59E0B)),
            _HStat('Reset','Defaults',       Color(0xFFEF4444)),
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

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.grid_view_rounded,      Color(0xFF3B82F6), 'Impact Map'),
      (Icons.lock_clock_rounded,     Color(0xFF8B5CF6), 'Gate Demo'),
      (Icons.restart_alt_rounded,    Color(0xFFEF4444), 'Reset'),
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

// ── Impact Map Tab ─────────────────────────────────────────────────────────────
class _ImpactMapTab extends ConsumerWidget {
  const _ImpactMapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values   = ref.watch(_consentValuesProvider);
    final selected = ref.watch(_selectedConsentProvider);

    // Which features are currently blocked?
    final blockedFeatures = _kFeatures
        .where((f) => !(values[f.requiredConsent] ?? true))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.grid_view_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Each optional consent controls specific features. '
              'Tap a consent type to highlight which features it gates. '
              'Red items are currently blocked by your consent settings '
              '(from Day 155 toggles).',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Consent selector (filter buttons)
        const _SectionLabel('TAP CONSENT TO FILTER'),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // "All" chip
              GestureDetector(
                onTap: () => ref
                    .read(_selectedConsentProvider.notifier)
                    .state = null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: ZapSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == null
                        ? const Color(0xFF3B82F6).withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected == null
                          ? const Color(0xFF3B82F6).withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Text('All',
                      style: TextStyle(
                          color: selected == null
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: selected == null
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ),
              ),
              // Consent filter chips (only optional ones)
              ..._kConsentItems
                  .where((c) => !c.isRequired)
                  .map((c) {
                final isSelected = selected == c.type;
                final isOn       = values[c.type] ?? true;
                return GestureDetector(
                  onTap: () => ref
                      .read(_selectedConsentProvider.notifier)
                      .state = isSelected ? null : c.type,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: ZapSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? c.color.withOpacity(0.15)
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? c.color.withOpacity(0.5)
                            : const Color(0xFF2A2A2A),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.icon,
                          color: isSelected ? c.color : const Color(0xFF4B5563),
                          size: 12),
                      const SizedBox(width: 5),
                      Text(_kConsentLabels[c.type] ?? c.title,
                          style: TextStyle(
                              color: isSelected
                                  ? c.color
                                  : const Color(0xFF6B7280),
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                      const SizedBox(width: 5),
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: isOn
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Blocked features alert
        if (blockedFeatures.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.block_rounded,
                  color: Color(0xFFEF4444), size: 14),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                '${blockedFeatures.length} feature${blockedFeatures.length > 1 ? 's' : ''} '
                'currently blocked by your consent settings',
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(height: ZapSpacing.md),
        ],

        // Feature list
        const _SectionLabel('FEATURES  ·  TAP TO SEE IMPACT'),
        const SizedBox(height: ZapSpacing.md),
        ..._kFeatures
            .where((f) => selected == null || f.requiredConsent == selected)
            .map((feature) {
          final isEnabled = values[feature.requiredConsent] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _FeatureImpactCard(
                feature: feature, isEnabled: isEnabled),
          );
        }),
      ],
    );
  }
}

class _FeatureImpactCard extends StatefulWidget {
  final _Feature feature;
  final bool     isEnabled;
  const _FeatureImpactCard(
      {required this.feature, required this.isEnabled});

  @override
  State<_FeatureImpactCard> createState() => _FeatureImpactCardState();
}

class _FeatureImpactCardState extends State<_FeatureImpactCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final f      = widget.feature;
    final isOn   = widget.isEnabled;
    final consent= _kConsentItems.firstWhere(
        (c) => c.type == f.requiredConsent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isOn
            ? f.color.withOpacity(0.06)
            : const Color(0xFFEF4444).withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: isOn
              ? f.color.withOpacity(0.3)
              : const Color(0xFFEF4444).withOpacity(0.35),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isOn
                      ? f.color.withOpacity(0.12)
                      : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOn ? f.icon : Icons.block_rounded,
                  color: isOn ? f.color : const Color(0xFFEF4444),
                  size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(f.description,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ],
                ),
              ),
              // Consent dependency badge
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOn
                        ? consent.color.withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _kConsentLabels[f.requiredConsent] ?? '',
                    style: TextStyle(
                        color: isOn
                            ? consent.color
                            : const Color(0xFFEF4444),
                        fontSize: 8,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 3),
                Text(isOn ? '✅ Active' : '🚫 Blocked',
                    style: TextStyle(
                        color: isOn
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: ZapSpacing.sm),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 16),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  child: Column(children: [
                    const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                    if (!isOn) ...[
                      Container(
                        padding: const EdgeInsets.all(ZapSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                              ZapSpacing.radiusSmall),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFEF4444), size: 13),
                          const SizedBox(width: ZapSpacing.sm),
                          Expanded(
                            child: Text(f.blockedMessage,
                                style: const TextStyle(
                                    color: Color(0xFFFFD0CA),
                                    fontSize: 11, height: 1.4)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: ZapSpacing.sm),
                    ],
                    Row(children: [
                      const Icon(Icons.link_rounded,
                          color: Color(0xFF4B5563), size: 13),
                      const SizedBox(width: ZapSpacing.sm),
                      Text('Requires: ${_kConsentLabels[f.requiredConsent]}',
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10)),
                    ]),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ── Gates Demo Tab ─────────────────────────────────────────────────────────────
class _GatesDemoTab extends ConsumerWidget {
  const _GatesDemoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values       = ref.watch(_consentValuesProvider);
    final demoType     = ref.watch(_demoGateTypeProvider);
    final gatedFeature = _kFeatures.firstWhere(
        (f) => f.requiredConsent == demoType,
        orElse: () => _kFeatures.first);
    final isEnabled    = values[demoType] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.lock_clock_rounded,
          color: const Color(0xFF8B5CF6),
          text: 'The ConsentGate widget wraps any feature that needs '
              'user consent. It shows either the real content (if consent is ON) '
              'or a "consent required" placeholder with an Enable button. '
              'Select a consent type below to simulate the gate.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Feature selector
        const _SectionLabel('SELECT FEATURE TO SIMULATE'),
        const SizedBox(height: ZapSpacing.md),
        _FeatureSelector(
            current: demoType,
            values: values,
            onSelect: (t) =>
                ref.read(_demoGateTypeProvider.notifier).state = t),
        const SizedBox(height: ZapSpacing.xl),

        // Live ConsentGate demo
        const _SectionLabel('CONSENT GATE  ·  LIVE PREVIEW'),
        const SizedBox(height: ZapSpacing.md),
        ConsentGate(
          consentType: demoType,
          isGranted: isEnabled,
          feature: gatedFeature,
          onEnable: () async {
            // In production this navigates to Day155 consent screen
            // Here we just toggle the value for demo
            final updated = Map<ConsentType, bool>.from(
                ref.read(_consentValuesProvider));
            updated[demoType] = true;
            ref.read(_consentValuesProvider.notifier).state = updated;
          },
          child: _MockFeatureContent(feature: gatedFeature),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Toggle buttons for demo
        Row(children: [
          Expanded(
            child: _actionButton(
              label: 'Turn ON consent',
              icon: Icons.toggle_on_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                final updated = Map<ConsentType, bool>.from(
                    ref.read(_consentValuesProvider));
                updated[demoType] = true;
                ref.read(_consentValuesProvider.notifier).state = updated;
              },
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: _actionButton(
              label: 'Turn OFF consent',
              icon: Icons.toggle_off_rounded,
              color: const Color(0xFFEF4444),
              onTap: () {
                final updated = Map<ConsentType, bool>.from(
                    ref.read(_consentValuesProvider));
                updated[demoType] = false;
                ref.read(_consentValuesProvider.notifier).state = updated;
              },
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.xl),

        // ConsentGate code
        const _SectionLabel('CONSENTGATE WIDGET CODE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('widgets/consent_gate.dart',
            '// Wrap any feature that requires consent:\n'
            'ConsentGate(\n'
            '  consentType: ConsentType.evidenceRecording,\n'
            '  isGranted: ConsentService.isGranted(\n'
            '    ConsentType.evidenceRecording),\n'
            '  onEnable: () => context.push(AppRoutes.consentManagement),\n'
            '  child: EvidenceVaultContent(),  // shown only when on\n'
            ')'),
        const SizedBox(height: ZapSpacing.lg),

        // Quick consent sheet code
        const _SectionLabel('QUICK CONSENT SHEET  ·  FOR FIRST-USE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('widgets/quick_consent_sheet.dart',
            '// Show when user first taps a gated feature:\n'
            'void showQuickConsentSheet(\n'
            '    BuildContext context, ConsentType type) {\n'
            '  showModalBottomSheet(\n'
            '    context: context,\n'
            '    builder: (_) => QuickConsentSheet(\n'
            '      type:      type,\n'
            '      onEnable:  () {\n'
            '        ConsentService.grant(type);\n'
            '        Navigator.pop(context);\n'
            '      },\n'
            '      onSkip: () => Navigator.pop(context),\n'
            '    ),\n'
            '  );\n'
            '}'),
        const SizedBox(height: ZapSpacing.md),

        // Live quick sheet button
        _actionButton(
          label: 'Show quick consent sheet (demo)',
          icon: Icons.expand_less_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () => _showQuickSheet(context, demoType, gatedFeature, ref),
        ),
      ],
    );
  }

  void _showQuickSheet(BuildContext context, ConsentType type,
      _Feature feature, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _QuickConsentSheet(
        feature: feature,
        onEnable: () {
          final updated = Map<ConsentType, bool>.from(
              ref.read(_consentValuesProvider));
          updated[type] = true;
          ref.read(_consentValuesProvider.notifier).state = updated;
          Navigator.of(context).pop();
        },
        onSkip: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _FeatureSelector extends StatelessWidget {
  final ConsentType current;
  final Map<ConsentType, bool> values;
  final ValueChanged<ConsentType> onSelect;
  const _FeatureSelector({
    required this.current,
    required this.values,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kFeatures.map((f) {
        final isActive  = f.requiredConsent == current;
        final isEnabled = values[f.requiredConsent] ?? false;
        return GestureDetector(
          onTap: () => onSelect(f.requiredConsent),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? f.color.withOpacity(0.1)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: isActive
                    ? f.color.withOpacity(0.5)
                    : const Color(0xFF2A2A2A),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Icon(f.icon,
                  color: isActive ? f.color : const Color(0xFF4B5563),
                  size: 16),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(f.name,
                    style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
              ),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                      color: isEnabled
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ── ConsentGate widget ─────────────────────────────────────────────────────────
/// Reusable — wrap any feature content behind this.
class ConsentGate extends StatelessWidget {
  final ConsentType  consentType;
  final bool         isGranted;
  final _Feature     feature;
  final VoidCallback onEnable;
  final Widget       child;

  const ConsentGate({
    super.key,
    required this.consentType,
    required this.isGranted,
    required this.feature,
    required this.onEnable,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (isGranted) return child;

    // Consent OFF — show gate placeholder
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.35),
            width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.35)),
            ),
            child: Icon(feature.icon,
                color: const Color(0xFFEF4444), size: 26),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text('${feature.name} is disabled',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.sm),
          Text(feature.blockedMessage,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.lg),
          GestureDetector(
            onTap: onEnable,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.xl, vertical: 13),
              decoration: BoxDecoration(
                color: feature.color,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: [
                  BoxShadow(
                      color: feature.color.withOpacity(0.35),
                      blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.toggle_on_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Text('Enable ${_kConsentLabels[consentType] ?? ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text('Go to Settings → Privacy & Consent to manage',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Mock content shown when consent is granted
class _MockFeatureContent extends StatelessWidget {
  final _Feature feature;
  const _MockFeatureContent({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: feature.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: feature.color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Icon(feature.icon, color: feature.color, size: 32),
        const SizedBox(height: ZapSpacing.md),
        Text(feature.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: ZapSpacing.sm),
        Text(feature.description,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('✅ Content visible — consent is ON',
              style: TextStyle(
                  color: Color(0xFF10B981), fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Quick Consent Sheet ────────────────────────────────────────────────────────
class _QuickConsentSheet extends StatelessWidget {
  final _Feature     feature;
  final VoidCallback onEnable;
  final VoidCallback onSkip;
  const _QuickConsentSheet({
    required this.feature,
    required this.onEnable,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final consent = _kConsentItems.firstWhere(
        (c) => c.type == feature.requiredConsent);

    return Padding(
      padding: EdgeInsets.only(
        left: ZapSpacing.lg, right: ZapSpacing.lg,
        top: ZapSpacing.lg,
        bottom: ZapSpacing.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF4B5563),
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, color: feature.color, size: 26),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text('Enable ${feature.name}?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            '${feature.description}\n\n${consent.consequenceOn.isEmpty ? '' : consent.consequenceOn}',
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Enable
          GestureDetector(
            onTap: onEnable,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: feature.color,
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                boxShadow: [
                  BoxShadow(
                      color: feature.color.withOpacity(0.3),
                      blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.toggle_on_rounded, color: Colors.white, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Text('Enable ${_kConsentLabels[feature.requiredConsent] ?? ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          // Skip
          GestureDetector(
            onTap: onSkip,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Not now',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reset Tab ──────────────────────────────────────────────────────────────────
class _ResetTab extends ConsumerWidget {
  const _ResetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values      = ref.watch(_consentValuesProvider);
    final confirmed   = ref.watch(_resetConfirmedProvider);

    // Check if already at defaults
    final atDefaults = _kDefaults.entries.every(
        (e) => values[e.key] == e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.restart_alt_rounded,
          color: const Color(0xFFEF4444),
          text: 'Reset all optional consents to their factory defaults. '
              'This is useful if you want to start fresh. '
              'Your acceptance record (from Day 154 certificate) is NOT deleted — '
              'only the toggle values change.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Current vs default comparison
        const _SectionLabel('CURRENT vs DEFAULT VALUES'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kConsentItems
                .where((c) => !c.isRequired)
                .toList()
                .asMap()
                .entries
                .map((e) {
              final i       = e.key;
              final item    = e.value;
              final current = values[item.type] ?? item.defaultValue;
              final defVal  = _kDefaults[item.type] ?? false;
              final differs = current != defVal;
              final isLast  = i == _kConsentItems.where((c) => !c.isRequired).length - 1;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 12),
                  child: Row(children: [
                    Icon(item.icon, color: item.color, size: 16),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(_kConsentLabels[item.type] ?? item.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    // Current value
                    _valBadge(current ? 'ON' : 'OFF',
                        current ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    if (differs) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF4B5563), size: 12)),
                      _valBadge(defVal ? 'ON' : 'OFF',
                          defVal ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          isTarget: true),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('=default',
                            style: TextStyle(
                                color: Color(0xFF4B5563), fontSize: 9))),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (atDefaults)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 16),
              SizedBox(width: ZapSpacing.sm),
              Text('Already at default values — nothing to reset',
                  style: TextStyle(
                      color: Color(0xFF10B981), fontSize: 12)),
            ]),
          )
        else ...[
          // Confirmation checkbox
          GestureDetector(
            onTap: () => ref
                .read(_resetConfirmedProvider.notifier)
                .state = !confirmed,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: confirmed
                        ? const Color(0xFFEF4444).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: confirmed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF4B5563),
                        width: 2),
                  ),
                  child: confirmed
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFFEF4444), size: 14)
                      : null,
                ),
                const SizedBox(width: ZapSpacing.sm),
                const Expanded(
                  child: Text(
                    'I understand this will change my consent settings '
                    'to their factory defaults. My acceptance record will '
                    'not be deleted.',
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
            onTap: confirmed
                ? () {
                    final updated = Map<ConsentType, bool>.from(
                        _kDefaults);
                    ref.read(_consentValuesProvider.notifier).state =
                        updated;
                    ref.read(_resetConfirmedProvider.notifier).state =
                        false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Consent settings reset to defaults'),
                        backgroundColor: Color(0xFF10B981),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: confirmed
                    ? const LinearGradient(colors: [
                        Color(0xFFDC2626),
                        Color(0xFFEF4444),
                      ])
                    : null,
                color: confirmed ? null : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: confirmed
                    ? null
                    : Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restart_alt_rounded,
                      color: confirmed
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      size: 18),
                  const SizedBox(width: ZapSpacing.sm),
                  Text(
                    confirmed
                        ? 'Reset to Defaults'
                        : 'Check the box above first',
                    style: TextStyle(
                      color: confirmed
                          ? Colors.white
                          : const Color(0xFF4B5563),
                      fontSize: 14, fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _valBadge(String label, Color color, {bool isTarget = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(isTarget ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: isTarget
              ? Border.all(color: color.withOpacity(0.5))
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9,
                fontWeight: FontWeight.w800)),
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
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13,
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
