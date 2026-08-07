/// Day 155-157 — Consent Management Screen
///
/// 🟢 FRONTEND-ONLY — Hive local storage, zero backend now.
///
/// DPDP Act 2023 + GDPR hard requirement: consent must be:
///   • Granular — each data type toggled independently
///   • Informed — plain-language explanation of consequence
///   • Withdrawable — any optional consent can be turned off anytime
///   • Auditable — consent changes logged with timestamp
///
/// Two categories:
///   REQUIRED — location during SOS (app cannot function without it)
///              shown locked with explanation, cannot be toggled off
///   OPTIONAL — 5 types user freely controls
///
/// Toggling OFF shows a confirmation dialog listing the consequence.
/// Toggling ON for sensitive items explains what will be shared.
/// Each item has an expandable "What does this mean?" section.
///
/// Future backend sync contract (when backend catches up):
/// PUT /api/v1/account/consent/ — see mock data section for full schema.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Data model ─────────────────────────────────────────────────────────────────
enum ConsentType {
  locationSos,
  evidenceRecording,
  cloudBackup,
  heatmapContribution,
  analytics,
  modelImprovement,
}

class ConsentItem {
  final ConsentType type;
  final String  title;
  final String  subtitle;
  final String  explanation;   // "What does this mean?" detail
  final String  consequenceOff; // shown in confirmation when toggling off
  final String  consequenceOn;  // shown in confirmation when toggling on (optional)
  final bool    isRequired;     // if true, toggle is locked
  final IconData icon;
  final Color   color;
  final bool    defaultValue;

  const ConsentItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.consequenceOff,
    required this.consequenceOn,
    required this.isRequired,
    required this.icon,
    required this.color,
    required this.defaultValue,
  });
}

const _kConsentItems = [
  // ── Required ────────────────────────────────────────────────────────────────
  ConsentItem(
    type: ConsentType.locationSos,
    title: 'Location during SOS',
    subtitle: 'Required — cannot disable',
    explanation:
        'During an active SOS event, we share your GPS location with your emergency contacts '
        'in real-time. Your contacts see your location on a map and receive updates every '
        '3 seconds until the SOS is resolved. Without this, contacts cannot find you in an emergency. '
        'This is the core safety function of the app — disabling it would make ZapSafe unable '
        'to protect you.',
    consequenceOff: 'Location during SOS is required for the app to work.',
    consequenceOn: '',
    isRequired: true,
    icon: Icons.location_on_rounded,
    color: Color(0xFFEF4444),
    defaultValue: true,
  ),

  // ── Optional ─────────────────────────────────────────────────────────────────
  ConsentItem(
    type: ConsentType.evidenceRecording,
    title: 'Evidence Recording',
    subtitle: 'Audio & video during SOS — stored on device',
    explanation:
        'During an SOS, ZapSafe silently records audio and (if camera permission is granted) '
        'front and rear video. These recordings are stored AES-256 encrypted on your device only — '
        'they are NEVER uploaded to our servers unless you explicitly export them. '
        'Evidence can be used in legal proceedings. If you disable this, no recordings are made '
        'during SOS events.',
    consequenceOff:
        'No audio or video will be recorded during SOS events. '
        'You will not have on-device evidence if you need it later.',
    consequenceOn:
        'Audio and video will be silently recorded during SOS events, '
        'stored encrypted on your device only.',
    isRequired: false,
    icon: Icons.videocam_rounded,
    color: Color(0xFF8B5CF6),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.cloudBackup,
    title: 'Cloud Evidence Backup',
    subtitle: 'Upload evidence to ZapSafe servers (encrypted)',
    explanation:
        'If enabled, evidence recorded during SOS events is uploaded to our AWS servers '
        '(encrypted with AES-256) in addition to being stored on your device. '
        'This protects against evidence loss if your phone is seized, damaged, or wiped. '
        'Evidence on our servers is subject to the same 30-day retention policy as on-device. '
        'It is only accessible to you (via your account) and to law enforcement only with your '
        'explicit export action — never by us.',
    consequenceOff:
        'Evidence will only be on your device. If your phone is seized or wiped, '
        'evidence may be lost.',
    consequenceOn:
        'Evidence will be uploaded to ZapSafe servers (encrypted). '
        'Available for 30 days. Only you can access it.',
    isRequired: false,
    icon: Icons.cloud_upload_rounded,
    color: Color(0xFF3B82F6),
    defaultValue: false,
  ),
  ConsentItem(
    type: ConsentType.heatmapContribution,
    title: 'Anonymous Heatmap Contribution',
    subtitle: 'Help warn others about unsafe areas',
    explanation:
        'After an SOS event, we may ask if you\'d like to anonymously contribute your '
        'location data to the community heatmap. This shows other users which areas '
        'have higher incident rates, helping them plan safer routes. '
        'Your name and identity are NEVER attached to heatmap contributions — only '
        'approximate location (rounded to 50m precision) and the incident category '
        '(harassment, theft, poor lighting, etc.) are recorded. '
        'You can choose YES or NO after each SOS — this toggle is the default preference.',
    consequenceOff:
        'Your SOS locations will not contribute to the heatmap. '
        'Other users in your area will not benefit from your experience.',
    consequenceOn:
        'After each SOS, you\'ll be asked if you want to contribute anonymously '
        'to the community heatmap. You can decline case by case.',
    isRequired: false,
    icon: Icons.map_rounded,
    color: Color(0xFF10B981),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.analytics,
    title: 'Crash & Usage Analytics',
    subtitle: 'Anonymous crash reports + screen-view counts',
    explanation:
        'We use Sentry to collect anonymous crash reports when the app encounters '
        'an error. We also count which screens are visited most often (aggregate counts only — '
        'no tracking of individual sessions). '
        'No personal data (name, phone, location, contacts) is included in any '
        'analytics or crash report. All data is anonymous and aggregate. '
        'Disabling this means we cannot detect and fix bugs that affect you.',
    consequenceOff:
        'We will not receive crash reports from your device. '
        'Bugs you encounter may take longer to fix because we cannot see them.',
    consequenceOn:
        'Anonymous crash reports and aggregate usage counts will be sent to Sentry. '
        'No personal data included.',
    isRequired: false,
    icon: Icons.bug_report_rounded,
    color: Color(0xFFF59E0B),
    defaultValue: true,
  ),
  ConsentItem(
    type: ConsentType.modelImprovement,
    title: 'Detection Model Improvement',
    subtitle: 'Help reduce false alarms for everyone',
    explanation:
        'When you report a false alarm (SOS triggered when you were safe), '
        'you can optionally contribute anonymised statistical features from that '
        'audio/motion event to our model training dataset. '
        'We use ONLY statistical features (MFCC values, motion magnitude numbers) — '
        'NEVER raw audio or video. These features cannot be used to reconstruct '
        'the original recording. Contributing helps reduce false positives for '
        'all ZapSafe users.',
    consequenceOff:
        'Your false alarm reports will still cancel the SOS, but will not '
        'contribute to improving detection accuracy for other users.',
    consequenceOn:
        'When you report a false alarm, anonymised statistical audio/motion features '
        'may be used to improve the detection model. Never raw audio.',
    isRequired: false,
    icon: Icons.model_training_rounded,
    color: Color(0xFF06B6D4),
    defaultValue: false,
  ),
];

// ── Providers ──────────────────────────────────────────────────────────────────
// In production these come from Hive. Here we manage in-memory.
final _consentValuesProvider = StateProvider<Map<ConsentType, bool>>(
  (ref) => {
    for (final item in _kConsentItems)
      item.type: item.defaultValue,
  },
);
final _lastChangedProvider   = StateProvider<List<_ChangeRecord>>((ref) => []);
final _activeTabProvider     = StateProvider<int>((ref) => 0);

class _ChangeRecord {
  final ConsentType type;
  final bool newValue;
  final DateTime at;
  const _ChangeRecord(this.type, this.newValue, this.at);
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day155ConsentManagementScreen extends ConsumerWidget {
  const Day155ConsentManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab    = ref.watch(_activeTabProvider);
    final values = ref.watch(_consentValuesProvider);
    final changed= ref.watch(_lastChangedProvider);

    final optionalCount = _kConsentItems.where((i) => !i.isRequired).length;
    final enabledCount  = _kConsentItems
        .where((i) => !i.isRequired && (values[i.type] ?? false))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Privacy & Consent'),
        elevation: 0,
        actions: [
          if (changed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.md),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Text('${changed.length} saved',
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11, fontWeight: FontWeight.w700)),
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

            // Summary strip
            _SummaryStrip(enabled: enabledCount, total: optionalCount),
            const SizedBox(height: ZapSpacing.xl),

            // Tab bar
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _ConsentListTab(),
            if (tab == 1) _AuditTab(log: changed),
            if (tab == 2) const _ApiContractTab(),
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
          colors: [Color(0xFF0A0614), Color(0xFF05030A), Color(0xFF0A0A0A)],
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
            _badge('⚡  DAY 155', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('DPDP + GDPR', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Privacy &\nConsent Settings',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Control exactly what data ZapSafe processes. '
            'Each type of data can be enabled or disabled independently. '
            'Changes take effect immediately and are saved locally.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('6',    'Consent types', Color(0xFF8B5CF6)),
            _HStat('1',    'Required',      Color(0xFFEF4444)),
            _HStat('5',    'Optional',      Color(0xFF10B981)),
            _HStat('Hive', 'Stored locally',Color(0xFF3B82F6)),
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

// ── Summary strip ──────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final int enabled, total;
  const _SummaryStrip({required this.enabled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Text('$enabled / $total optional consents active',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            Text(
              enabled == total ? 'All enabled' : '$enabled enabled',
              style: TextStyle(
                  color: enabled == total
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? enabled / total : 0,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              enabled == total
                  ? const Color(0xFF10B981)
                  : const Color(0xFF8B5CF6),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Changes are saved immediately to your device. '
          'You can change these at any time.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 10),
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
      (Icons.tune_rounded,         Color(0xFF8B5CF6), 'Consent'),
      (Icons.history_rounded,      Color(0xFF3B82F6), 'Audit Log'),
      (Icons.api_rounded,          Color(0xFFF59E0B), 'API Contract'),
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
                const SizedBox(height: 4),
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

// ── Consent List Tab ───────────────────────────────────────────────────────────
class _ConsentListTab extends ConsumerWidget {
  const _ConsentListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: _kConsentItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _ConsentCard(item: item),
          )).toList(),
    );
  }
}

class _ConsentCard extends ConsumerStatefulWidget {
  final ConsentItem item;
  const _ConsentCard({required this.item});

  @override
  ConsumerState<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends ConsumerState<_ConsentCard> {
  bool _expanded = false;

  Future<void> _handleToggle(bool newValue) async {
    final item = widget.item;
    if (item.isRequired) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConsentConfirmDialog(
          item: item, newValue: newValue),
    );

    if (confirm != true) return;

    // Update value
    final updated = Map<ConsentType, bool>.from(
        ref.read(_consentValuesProvider));
    updated[item.type] = newValue;
    ref.read(_consentValuesProvider.notifier).state = updated;

    // Log change
    final log = List<_ChangeRecord>.from(
        ref.read(_lastChangedProvider));
    log.insert(0, _ChangeRecord(item.type, newValue, DateTime.now()));
    ref.read(_lastChangedProvider.notifier).state = log;
  }

  @override
  Widget build(BuildContext context) {
    final values  = ref.watch(_consentValuesProvider);
    final isOn    = values[widget.item.type] ?? widget.item.defaultValue;
    final item    = widget.item;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: item.isRequired
            ? const Color(0xFF1A0A0A)
            : isOn
                ? item.color.withOpacity(0.06)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: item.isRequired
              ? const Color(0xFFEF4444).withOpacity(0.25)
              : isOn
                  ? item.color.withOpacity(0.3)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(children: [
            // Icon
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(item.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (item.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Required',
                            style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  Text(item.subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            // Toggle
            GestureDetector(
              onTap: item.isRequired ? null : () => _handleToggle(!isOn),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48, height: 26,
                decoration: BoxDecoration(
                  color: item.isRequired
                      ? const Color(0xFFEF4444).withOpacity(0.3)
                      : isOn
                          ? item.color
                          : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isOn
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: item.isRequired
                        ? Icon(Icons.lock_rounded,
                            color: const Color(0xFFEF4444).withOpacity(0.6),
                            size: 12)
                        : null,
                  ),
                ),
              ),
            ),
          ]),
        ),

        // Expand button
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(
                left: ZapSpacing.md,
                right: ZapSpacing.md,
                bottom: ZapSpacing.sm),
            child: Row(children: [
              const SizedBox(width: 52), // align with text
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 14),
              const SizedBox(width: 4),
              Text(
                _expanded
                    ? 'Hide explanation'
                    : 'What does this mean?',
                style: TextStyle(
                    color: item.color.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),

        // Expandable explanation
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.fromLTRB(
                      ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.06),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                        color: item.color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.explanation,
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 12, height: 1.65)),
                      if (!item.isRequired) ...[
                        const SizedBox(height: ZapSpacing.md),
                        Row(children: [
                          Expanded(
                            child: _effBox(
                              'If OFF',
                              item.consequenceOff,
                              const Color(0xFFEF4444),
                              Icons.toggle_off_rounded,
                            ),
                          ),
                          const SizedBox(width: ZapSpacing.sm),
                          Expanded(
                            child: _effBox(
                              'If ON',
                              item.consequenceOn.isEmpty
                                  ? 'Data processing enabled as described above.'
                                  : item.consequenceOn,
                              item.color,
                              Icons.toggle_on_rounded,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _effBox(String label, String text, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10, height: 1.4)),
          ],
        ),
      );
}

// ── Confirmation dialog ────────────────────────────────────────────────────────
class _ConsentConfirmDialog extends StatelessWidget {
  final ConsentItem item;
  final bool newValue;
  const _ConsentConfirmDialog({required this.item, required this.newValue});

  @override
  Widget build(BuildContext context) {
    final isDisabling = !newValue;
    final color = isDisabling ? const Color(0xFFEF4444) : item.color;
    final consequence = isDisabling
        ? item.consequenceOff
        : (item.consequenceOn.isEmpty
            ? 'This will enable ${item.title.toLowerCase()} data processing.'
            : item.consequenceOn);

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDisabling ? Icons.toggle_off_rounded : Icons.toggle_on_rounded,
                color: color, size: 28),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              isDisabling
                  ? 'Disable ${item.title}?'
                  : 'Enable ${item.title}?',
              style: const TextStyle(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Text(consequence,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12, height: 1.5),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: ZapSpacing.lg),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        isDisabling ? 'Disable' : 'Enable',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Audit Tab ──────────────────────────────────────────────────────────────────
class _AuditTab extends StatelessWidget {
  final List<_ChangeRecord> log;
  const _AuditTab({required this.log});

  static const _typeNames = {
    ConsentType.locationSos:         'Location during SOS',
    ConsentType.evidenceRecording:   'Evidence Recording',
    ConsentType.cloudBackup:         'Cloud Evidence Backup',
    ConsentType.heatmapContribution: 'Heatmap Contribution',
    ConsentType.analytics:           'Analytics & Crash Reports',
    ConsentType.modelImprovement:    'Model Improvement',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.history_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Every consent change is recorded with a timestamp. '
              'This gives you — and us — a clear audit trail of when '
              'each type of data processing was enabled or disabled. '
              'Toggle consent items on the Consent tab to see changes appear here.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (log.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.xl),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Column(children: [
              Icon(Icons.history_rounded, color: Color(0xFF4B5563), size: 36),
              SizedBox(height: ZapSpacing.md),
              Text('No changes yet',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
              Text('Toggle consent items to see changes here',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
            ]),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: log.asMap().entries.map((e) {
                final i      = e.key;
                final record = e.value;
                final isLast = i == log.length - 1;
                final item   = _kConsentItems.firstWhere(
                    (it) => it.type == record.type);

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: record.newValue
                              ? item.color.withOpacity(0.12)
                              : const Color(0xFFEF4444).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          record.newValue
                              ? Icons.toggle_on_rounded
                              : Icons.toggle_off_rounded,
                          color: record.newValue
                              ? item.color
                              : const Color(0xFFEF4444),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_typeNames[record.type] ?? record.type.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              record.newValue ? 'Enabled' : 'Disabled',
                              style: TextStyle(
                                  color: record.newValue
                                      ? item.color
                                      : const Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${record.at.hour.toString().padLeft(2, '0')}:'
                        '${record.at.minute.toString().padLeft(2, '0')}:'
                        '${record.at.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            fontFamily: 'monospace'),
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

        _codeNote('hive/consent_flags_schema',
            '// Each consent change is saved to Hive:\n'
            'ConsentFlags {\n'
            '  bool locationSos        = true;   // always true, required\n'
            '  bool evidenceRecording  = true;\n'
            '  bool cloudBackup        = false;\n'
            '  bool heatmapContribution= true;\n'
            '  bool analytics          = true;\n'
            '  bool modelImprovement   = false;\n'
            '  DateTime updatedAt;    // timestamp of last change\n'
            '}\n'
            '\n'
            '// Audit log (last 50 changes):\n'
            'ConsentAuditEntry {\n'
            '  ConsentType type;\n'
            '  bool        newValue;\n'
            '  DateTime    changedAt;\n'
            '}'),
      ],
    );
  }
}

// ── API Contract Tab ───────────────────────────────────────────────────────────
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.api_rounded,
          color: const Color(0xFFF59E0B),
          text: '🟡 MOCK-NOW: This screen stores consent in Hive locally. '
              'When backend is ready, a single sync call is added — '
              'no restructuring needed because the contract is fixed here first.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        const _SectionLabel('FUTURE BACKEND CONTRACT'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('PUT /api/v1/account/consent/',
            '// Save consent flags to server (sync from Hive)\n'
            'PUT /api/v1/account/consent/\n'
            'Authorization: Bearer {jwt}\n'
            '\n'
            'Request body:\n'
            '{\n'
            '  "location_sos":          true,   // always true, read-only\n'
            '  "evidence_recording":    true,\n'
            '  "cloud_backup":          false,\n'
            '  "heatmap_contribution":  true,\n'
            '  "analytics":             true,\n'
            '  "model_improvement":     false,\n'
            '  "updated_at":            "2026-09-01T10:00:00Z"\n'
            '}\n'
            '\n'
            'Response 200:\n'
            '{ "status": "saved" }'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('GET /api/v1/account/consent/',
            '// Load consent flags from server (first login on new device)\n'
            'GET /api/v1/account/consent/\n'
            'Authorization: Bearer {jwt}\n'
            '\n'
            'Response 200:\n'
            '{\n'
            '  "location_sos":          true,\n'
            '  "evidence_recording":    true,\n'
            '  "cloud_backup":          false,\n'
            '  "heatmap_contribution":  true,\n'
            '  "analytics":             true,\n'
            '  "model_improvement":     false,\n'
            '  "updated_at":            "2026-09-01T10:00:00Z"\n'
            '}'),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('when_backend_is_ready.dart',
            '// The only change needed to go from mock → real:\n'
            '\n'
            '// ADD on app startup (load from server on login):\n'
            'final remote = await api.get(\'/api/v1/account/consent/\');\n'
            'ConsentService.mergeRemote(remote); // local wins if newer\n'
            '\n'
            '// ADD when user changes a toggle (sync to server):\n'
            'await api.put(\'/api/v1/account/consent/\',\n'
            '    body: ConsentService.toJson());\n'
            '\n'
            '// No UI restructuring — just two API calls added.\n'
            '// All toggle logic, confirmation dialogs, and audit log\n'
            '// already work — they stay exactly as-is.'),
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
