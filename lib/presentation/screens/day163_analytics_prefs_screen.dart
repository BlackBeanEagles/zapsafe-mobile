/// Day 163-165 — Tracking & Analytics Preferences
///
/// 🟢 FRONTEND-ONLY — client-side only, zero backend.
/// Controls whether the Sentry SDK and usage analytics collect data.
///
/// Required by:
///   • Apple ATT (App Tracking Transparency) — iOS 14.5+
///     Must show OS prompt before any analytics/tracking
///   • Google Play Data Safety — must match declared data practices
///   • DPDP Act — analytics opt-in must be explicit and withdrawable
///
/// What this screen does:
///   1. Crash Reporting (Sentry) — anonymous crash stacks + device info
///   2. Usage Analytics — aggregate screen-view counts + feature usage
///   3. iOS ATT prompt — trigger at the right moment (post-onboarding)
///   4. Show exactly what is and is NOT collected
///
/// When toggled OFF:
///   • Sentry is not initialised (no data sent)
///   • Analytics events are dropped silently
///   • App works exactly the same — just quieter
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _crashReportingProvider = StateProvider<bool>((ref) => true);
final _usageAnalyticsProvider = StateProvider<bool>((ref) => false);
final _attStatusProvider      = StateProvider<_AttStatus>((ref) => _AttStatus.notDetermined);
final _attPromptProvider      = StateProvider<_PromptState>((ref) => _PromptState.idle);
final _changeLogProvider      = StateProvider<List<_ChangeEntry>>((ref) => []);

enum _AttStatus   { notDetermined, authorized, denied, restricted }
enum _PromptState { idle, showing, done }

class _ChangeEntry {
  final String setting;
  final bool   newValue;
  final DateTime at;
  const _ChangeEntry(this.setting, this.newValue, this.at);
}

// ── Data ───────────────────────────────────────────────────────────────────────
class _DataPoint {
  final String category;
  final String item;
  final bool   collected; // true = we DO collect this
  final Color  color;
  const _DataPoint(this.category, this.item, this.collected, this.color);
}

const _kWhatWeCollect = [
  // Crash data
  _DataPoint('Crash Reports', 'Exception type + stack trace', true,  Color(0xFF10B981)),
  _DataPoint('Crash Reports', 'Device model + OS version',    true,  Color(0xFF10B981)),
  _DataPoint('Crash Reports', 'App version',                  true,  Color(0xFF10B981)),
  _DataPoint('Crash Reports', 'Anonymous session ID',         true,  Color(0xFF10B981)),
  _DataPoint('Crash Reports', 'Your name or phone number',    false, Color(0xFFEF4444)),
  _DataPoint('Crash Reports', 'GPS location data',            false, Color(0xFFEF4444)),
  _DataPoint('Crash Reports', 'SOS event data',               false, Color(0xFFEF4444)),
  _DataPoint('Crash Reports', 'Contact names or numbers',     false, Color(0xFFEF4444)),
  // Analytics
  _DataPoint('Usage Analytics', 'Screen view counts (aggregate)', true,  Color(0xFF10B981)),
  _DataPoint('Usage Analytics', 'Feature usage frequency',        true,  Color(0xFF10B981)),
  _DataPoint('Usage Analytics', 'Session count + duration',       true,  Color(0xFF10B981)),
  _DataPoint('Usage Analytics', 'Individual user behaviour',      false, Color(0xFFEF4444)),
  _DataPoint('Usage Analytics', 'Advertising identifiers',        false, Color(0xFFEF4444)),
  _DataPoint('Usage Analytics', 'Cross-app tracking',             false, Color(0xFFEF4444)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day163AnalyticsPrefsScreen extends ConsumerWidget {
  const Day163AnalyticsPrefsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Analytics & Tracking'),
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
                child: const Text('Anonymous only',
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
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _SettingsTab(),
            if (tab == 1) const _WhatWeCollectTab(),
            if (tab == 2) const _AttIosTab(),
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
          colors: [Color(0xFF0A0E06), Color(0xFF050804), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 163', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 CLIENT-SIDE', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('ATT + Sentry', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Analytics &\nTracking Prefs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Control crash reporting (Sentry) and usage analytics. '
            'iOS ATT prompt. Exactly what is — and is NOT — collected. '
            'All processing is client-side.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('2',      'Toggles',       Color(0xFF10B981)),
            _HStat('Anon',   'Data only',     Color(0xFF3B82F6)),
            _HStat('ATT',    'iOS prompt',    Color(0xFF9CA3AF)),
            _HStat('Sentry', 'Crash SDK',     Color(0xFFF59E0B)),
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
      (Icons.tune_rounded,         Color(0xFF10B981), 'Settings'),
      (Icons.visibility_rounded,   Color(0xFF3B82F6), 'What We Collect'),
      (Icons.apple_rounded,        Color(0xFF9CA3AF), 'iOS ATT'),
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
                Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
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

// ── Settings Tab ───────────────────────────────────────────────────────────────
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crashOn   = ref.watch(_crashReportingProvider);
    final analyticsOn = ref.watch(_usageAnalyticsProvider);
    final log       = ref.watch(_changeLogProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.privacy_tip_rounded,
          color: const Color(0xFF10B981),
          text: 'Both types of analytics are 100% anonymous. '
              'No personal data is ever sent. Crash reports help us '
              'fix bugs faster. Usage counts help us improve features. '
              'Turn either off at any time — the app works exactly the same.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Crash reporting toggle
        const _SectionLabel('CRASH REPORTING'),
        const SizedBox(height: ZapSpacing.md),
        _AnalyticsToggleCard(
          title: 'Crash Reporting (Sentry)',
          subtitle: 'Anonymous crash stacks + device model + OS version',
          icon: Icons.bug_report_rounded,
          color: const Color(0xFFF59E0B),
          isOn: crashOn,
          onToggle: () async {
            final newVal = !crashOn;
            final confirmed = await _showConfirmDialog(
              context,
              newVal,
              'Crash Reporting',
              newVal
                  ? 'Anonymous crash reports will be sent to Sentry '
                    'to help us fix bugs. No personal data included.'
                  : 'Crash reports will not be sent. Bugs you encounter '
                    'may take longer for us to detect and fix.',
            );
            if (confirmed != true) return;
            ref.read(_crashReportingProvider.notifier).state = newVal;
            final updated = List<_ChangeEntry>.from(ref.read(_changeLogProvider));
            updated.insert(0, _ChangeEntry('Crash Reporting', newVal, DateTime.now()));
            ref.read(_changeLogProvider.notifier).state = updated;
          },
          bullets: const [
            'Exception type and stack trace',
            'Device model (e.g. "Pixel 7")',
            'Android/iOS version',
            'App version + build number',
            'Anonymous session ID (not tied to your account)',
          ],
          nots: const [
            'Your name, phone number, or any account info',
            'Your GPS location or SOS history',
            'Your emergency contacts',
            'Evidence files or audio/video data',
          ],
        ),
        const SizedBox(height: ZapSpacing.md),

        // Usage analytics toggle
        const _SectionLabel('USAGE ANALYTICS'),
        const SizedBox(height: ZapSpacing.md),
        _AnalyticsToggleCard(
          title: 'Usage Analytics',
          subtitle: 'Aggregate screen-view counts + feature frequency',
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF3B82F6),
          isOn: analyticsOn,
          onToggle: () async {
            final newVal = !analyticsOn;
            final confirmed = await _showConfirmDialog(
              context,
              newVal,
              'Usage Analytics',
              newVal
                  ? 'Aggregate usage counts (e.g. "Dashboard viewed 1,200 times") '
                    'will be collected. Completely anonymous.'
                  : 'Usage analytics will stop. We won\'t know which features '
                    'are used or ignored — harder to prioritise improvements.',
            );
            if (confirmed != true) return;
            ref.read(_usageAnalyticsProvider.notifier).state = newVal;
            final updated = List<_ChangeEntry>.from(ref.read(_changeLogProvider));
            updated.insert(0, _ChangeEntry('Usage Analytics', newVal, DateTime.now()));
            ref.read(_changeLogProvider.notifier).state = updated;
          },
          bullets: const [
            'Screen view counts (e.g. "Evidence Vault: 187 views")',
            'Feature usage frequency (e.g. "Journey Mode: 67 sessions")',
            'Session count + average duration',
            'Country-level region (not precise location)',
          ],
          nots: const [
            'Individual user behaviour or session replays',
            'Advertising identifiers (IDFA / GAID)',
            'Cross-app or cross-site tracking',
            'Any data sold to third parties',
          ],
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Implementation code
        const _SectionLabel('HOW TOGGLES AFFECT SENTRY'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('main.dart',
            '// On app launch, check Hive consent flag:\n'
            'final prefs = await ConsentService.getAnalyticsFlags();\n'
            '\n'
            'if (prefs.crashReporting) {\n'
            '  await SentryFlutter.init((options) {\n'
            '    options.dsn         = _kSentryDsn;\n'
            '    options.environment = \'production\';\n'
            '    options.release     = packageInfo.version;\n'
            '    // tracesSampleRate = 0 → no performance tracing\n'
            '    options.tracesSampleRate = 0.0;\n'
            '  }, appRunner: () => runApp(ZapSafeApp()));\n'
            '} else {\n'
            '  // Skip Sentry init entirely\n'
            '  runApp(ZapSafeApp());\n'
            '}\n'
            '\n'
            '// When toggled OFF at runtime:\n'
            'Sentry.close(); // stops all data collection immediately'),
        const SizedBox(height: ZapSpacing.lg),

        // Change log
        if (log.isNotEmpty) ...[
          const _SectionLabel('RECENT CHANGES'),
          const SizedBox(height: ZapSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: log.take(5).toList().asMap().entries.map((e) {
                final i     = e.key;
                final entry = e.value;
                final isLast= i == (log.length > 5 ? 4 : log.length - 1);
                final color = entry.newValue
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444);
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 10),
                    child: Row(children: [
                      Icon(
                        entry.newValue
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        color: color, size: 16),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(entry.setting,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                      Text(
                        entry.newValue ? 'Enabled' : 'Disabled',
                        style: TextStyle(
                            color: color, fontSize: 10,
                            fontWeight: FontWeight.w700)),
                      const SizedBox(width: ZapSpacing.sm),
                      Text(
                        '${entry.at.hour.toString().padLeft(2, '0')}:'
                        '${entry.at.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: Color(0xFF4B5563), fontSize: 9,
                            fontFamily: 'monospace')),
                    ]),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, bool newValue,
      String setting, String consequence) {
    final color =
        newValue ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(newValue ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                color: color, size: 32),
            const SizedBox(height: ZapSpacing.md),
            Text(
              newValue ? 'Enable $setting?' : 'Disable $setting?',
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Text(consequence,
                  style: const TextStyle(color: Color(0xFFD1D5DB),
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
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                    child: const Center(child: Text('Cancel',
                        style: TextStyle(color: Color(0xFF9CA3AF)))),
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
                      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    ),
                    child: Center(
                      child: Text(newValue ? 'Enable' : 'Disable',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _AnalyticsToggleCard extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final bool isOn;
  final VoidCallback onToggle;
  final List<String> bullets, nots;
  const _AnalyticsToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isOn,
    required this.onToggle,
    required this.bullets,
    required this.nots,
  });

  @override
  State<_AnalyticsToggleCard> createState() => _AnalyticsToggleCardState();
}

class _AnalyticsToggleCardState extends State<_AnalyticsToggleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isOn
            ? widget.color.withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: widget.isOn
              ? widget.color.withOpacity(0.3)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(widget.subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10)),
                ],
              ),
            ),
            // Toggle
            GestureDetector(
              onTap: widget.onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50, height: 28,
                decoration: BoxDecoration(
                  color: widget.isOn
                      ? widget.color
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: widget.isOn
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ]),
        ),
        // Expand
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(
                left: ZapSpacing.md, right: ZapSpacing.md,
                bottom: ZapSpacing.sm),
            child: Row(children: [
              const SizedBox(width: 52),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 14),
              const SizedBox(width: ZapSpacing.xs),
              Text(
                _expanded ? 'Hide details' : 'What is collected?',
                style: TextStyle(
                    color: widget.color.withOpacity(0.7),
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
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
                    const Divider(height: ZapSpacing.md,
                        color: Color(0xFF2A2A2A)),
                    _listSection('✅ WE DO COLLECT',
                        widget.bullets, const Color(0xFF10B981)),
                    const SizedBox(height: ZapSpacing.sm),
                    _listSection('❌ WE DO NOT COLLECT',
                        widget.nots, const Color(0xFFEF4444)),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _listSection(String label, List<String> items, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 11, height: 1.3)),
                  ),
                ],
              ),
            )),
      ]);
}

// ── What We Collect Tab ────────────────────────────────────────────────────────
class _WhatWeCollectTab extends StatelessWidget {
  const _WhatWeCollectTab();

  @override
  Widget build(BuildContext context) {
    // Group by category
    final categories = <String, List<_DataPoint>>{};
    for (final dp in _kWhatWeCollect) {
      categories.putIfAbsent(dp.category, () => []).add(dp);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.visibility_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Full transparency about exactly what each analytics type '
              'collects and — just as importantly — what it does NOT collect. '
              'Green = collected. Red = never collected.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        ...categories.entries.map((entry) {
          final cat   = entry.key;
          final items = entry.value;
          final collected = items.where((i) => i.collected).length;
          final notCollected = items.where((i) => !i.collected).length;

          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(cat.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$collected collected',
                        style: const TextStyle(
                            color: Color(0xFF10B981), fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$notCollected NOT collected',
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: ZapSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(ZapSpacing.radius),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    children: items.asMap().entries.map((e) {
                      final i    = e.key;
                      final dp   = e.value;
                      final isLast = i == items.length - 1;
                      return Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: ZapSpacing.md, vertical: 11),
                          child: Row(children: [
                            Icon(
                              dp.collected
                                  ? Icons.check_circle_rounded
                                  : Icons.remove_circle_rounded,
                              color: dp.color, size: 16),
                            const SizedBox(width: ZapSpacing.sm),
                            Expanded(
                              child: Text(dp.item,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: dp.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dp.collected ? 'Yes' : 'Never',
                                style: TextStyle(
                                    color: dp.color, fontSize: 9,
                                    fontWeight: FontWeight.w800),
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
              ],
            ),
          );
        }),

        // Third parties
        const _SectionLabel('THIRD-PARTY SERVICES'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _thirdPartyRow('Sentry', 'sentry.io',
                'Crash reporting — GDPR-compliant DPA signed',
                const Color(0xFFF59E0B)),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _thirdPartyRow('None', '—',
                'No advertising SDKs, no marketing trackers, no analytics resale',
                const Color(0xFF10B981)),
          ]),
        ),
      ],
    );
  }

  Widget _thirdPartyRow(
      String name, String domain, String desc, Color color) =>
      Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(name,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(domain,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10,
                      fontFamily: 'monospace')),
              Text(desc,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB), fontSize: 11)),
            ]),
          ),
        ]),
      );
}

// ── iOS ATT Tab ────────────────────────────────────────────────────────────────
class _AttIosTab extends ConsumerWidget {
  const _AttIosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attStatus = ref.watch(_attStatusProvider);
    final promptState = ref.watch(_attPromptProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.apple_rounded,
          color: const Color(0xFF9CA3AF),
          text: 'iOS 14.5+ requires ATT (App Tracking Transparency) '
              'before any analytics. The OS shows a system prompt. '
              'ZapSafe triggers it AFTER onboarding (not on first launch). '
              'Android does not have ATT — Sentry toggle is sufficient.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ATT status
        const _SectionLabel('ATT STATUS  ·  iOS ONLY'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            // Status row
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _attColor(attStatus).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_attIcon(attStatus),
                    color: _attColor(attStatus), size: 20),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ATT Status: ${_attLabel(attStatus)}',
                        style: TextStyle(
                            color: _attColor(attStatus),
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(_attDesc(attStatus),
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: ZapSpacing.lg),
            // Simulate buttons
            const Text('Simulate ATT outcome:',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
            const SizedBox(height: ZapSpacing.sm),
            Row(children: [
              Expanded(child: _attBtn('Authorized', const Color(0xFF10B981),
                  () => ref.read(_attStatusProvider.notifier).state =
                      _AttStatus.authorized)),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: _attBtn('Denied', const Color(0xFFEF4444),
                  () => ref.read(_attStatusProvider.notifier).state =
                      _AttStatus.denied)),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: _attBtn('Not asked', const Color(0xFF4B5563),
                  () => ref.read(_attStatusProvider.notifier).state =
                      _AttStatus.notDetermined)),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // ATT prompt mock
        const _SectionLabel('ATT PROMPT  ·  WHAT THE OS SHOWS'),
        const SizedBox(height: ZapSpacing.md),
        _AttPromptMock(status: attStatus, promptState: promptState,
            onShow: () async {
              ref.read(_attPromptProvider.notifier).state = _PromptState.showing;
              await Future.delayed(const Duration(milliseconds: 500));
              if (!context.mounted) return;
              ref.read(_attPromptProvider.notifier).state = _PromptState.done;
              ref.read(_attStatusProvider.notifier).state = _AttStatus.authorized;
            },
            onReset: () {
              ref.read(_attPromptProvider.notifier).state = _PromptState.idle;
              ref.read(_attStatusProvider.notifier).state = _AttStatus.notDetermined;
            }),
        const SizedBox(height: ZapSpacing.xl),

        // When to show
        const _SectionLabel('WHEN TO TRIGGER ATT'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('analytics_service.dart',
            '// ✅ DO: Show ATT AFTER onboarding Step 4 (drills)\n'
            '// By then users understand the app and trust it more.\n'
            '// Timing is key — too early = 40% denial rate\n'
            '//\n'
            'Future<void> requestAttIfNeeded() async {\n'
            '  // iOS only — check if not yet determined\n'
            '  if (!Platform.isIOS) return;\n'
            '  final status = await AppTrackingTransparency\n'
            '      .requestTrackingAuthorization();\n'
            '\n'
            '  // Store result in Hive\n'
            '  await ConsentService.setAttStatus(status.name);\n'
            '\n'
            '  // If authorized → init Sentry (if crash reporting ON)\n'
            '  if (status == TrackingStatus.authorized) {\n'
            '    await _initSentryIfEnabled();\n'
            '  }\n'
            '}\n'
            '\n'
            '// ❌ DON\'T: Show on first app launch\n'
            '// Apple rejects apps with ATT on first frame\n'
            '// Guideline: show in context, after value is demonstrated'),
        const SizedBox(height: ZapSpacing.lg),

        _codeNote('Info.plist',
            '<!-- Required string explaining why you need ATT -->\n'
            '<key>NSUserTrackingUsageDescription</key>\n'
            '<string>ZapSafe uses anonymous crash reports to detect\n'
            'and fix bugs faster. No personal data is ever collected.\n'
            'This helps keep the safety app stable and reliable.</string>'),
      ],
    );
  }

  Color _attColor(_AttStatus s) {
    switch (s) {
      case _AttStatus.authorized:    return const Color(0xFF10B981);
      case _AttStatus.denied:        return const Color(0xFFEF4444);
      case _AttStatus.restricted:    return const Color(0xFFF97316);
      case _AttStatus.notDetermined: return const Color(0xFF4B5563);
    }
  }

  IconData _attIcon(_AttStatus s) {
    switch (s) {
      case _AttStatus.authorized:    return Icons.check_circle_rounded;
      case _AttStatus.denied:        return Icons.cancel_rounded;
      case _AttStatus.restricted:    return Icons.block_rounded;
      case _AttStatus.notDetermined: return Icons.help_outline_rounded;
    }
  }

  String _attLabel(_AttStatus s) {
    switch (s) {
      case _AttStatus.authorized:    return 'Authorized';
      case _AttStatus.denied:        return 'Denied';
      case _AttStatus.restricted:    return 'Restricted';
      case _AttStatus.notDetermined: return 'Not determined';
    }
  }

  String _attDesc(_AttStatus s) {
    switch (s) {
      case _AttStatus.authorized:    return 'Analytics can run — user allowed tracking';
      case _AttStatus.denied:        return 'Skip analytics — respect user choice';
      case _AttStatus.restricted:    return 'Device-level restriction (parental control)';
      case _AttStatus.notDetermined: return 'Prompt not yet shown';
    }
  }

  Widget _attBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _AttPromptMock extends StatelessWidget {
  final _AttStatus  status;
  final _PromptState promptState;
  final VoidCallback onShow, onReset;
  const _AttPromptMock({
    required this.status,
    required this.promptState,
    required this.onShow,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (promptState == _PromptState.done) {
      return Column(children: [
        _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
            'ATT prompt shown → Authorized. Sentry initialised.'),
        const SizedBox(height: ZapSpacing.sm),
        GestureDetector(
          onTap: onReset,
          child: const Center(
            child: Text('Reset demo',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
          ),
        ),
      ]);
    }

    if (promptState == _PromptState.showing) {
      return _statusChip(Icons.apple_rounded, const Color(0xFF9CA3AF),
          'System ATT dialog appearing…', loading: true);
    }

    return Column(children: [
      // Mock iOS dialog
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A3A3C)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [ZapColors.danger, Color(0xFFB01F2A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text(
              '"ZapSafe" would like\npermission to track you\nacross apps and websites',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'ZapSafe uses anonymous crash reports to detect and fix '
              'bugs faster. No personal data is ever collected.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),
            GestureDetector(
              onTap: onShow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: const Center(
                  child: Text('Allow Tracking',
                      style: TextStyle(color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            GestureDetector(
              onTap: () {
                // Denied
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                ),
                child: const Center(
                  child: Text('Ask App Not to Track',
                      style: TextStyle(color: Color(0xFF0A84FF), fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: ZapSpacing.md),
      _actionButton(
        label: 'Simulate showing ATT prompt',
        icon: Icons.apple_rounded,
        color: const Color(0xFF9CA3AF),
        onTap: onShow,
      ),
    ]);
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
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
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12,
                offset: const Offset(0, 3)),
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

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(color: color, fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );

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
