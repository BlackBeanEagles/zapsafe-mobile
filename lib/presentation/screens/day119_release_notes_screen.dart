/// Day 119 — Beta Release Notes Screen
///
/// In-app changelog shown on first launch after an update (or via
/// Settings → "What's New"). One card per version, newest first.
/// Green badges = new features (✨), Blue badges = bug fixes (✓),
/// Orange badges = improvements (↑).
///
/// Simulates "first launch after update" flow: unseen banner →
/// user dismisses → marked as seen in SharedPreferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _seenProvider        = StateProvider<bool>((ref) => false);
final _expandedProvider    = StateProvider.family<bool, String>((ref, v) => v == 'v0.5-beta');
final _filterProvider      = StateProvider<_Filter>((ref) => _Filter.all);

enum _Filter { all, features, fixes, improvements }

// ── Data model ─────────────────────────────────────────────────────────────────
enum _EntryType { feature, fix, improvement }

class _Entry {
  final _EntryType type;
  final String text;
  const _Entry(this.type, this.text);
}

class _Release {
  final String version;
  final String date;
  final String summary;
  final bool isLatest;
  final List<_Entry> entries;
  const _Release({
    required this.version,
    required this.date,
    required this.summary,
    this.isLatest = false,
    required this.entries,
  });
}

// ── Mock changelog ─────────────────────────────────────────────────────────────
const _kReleases = [
  _Release(
    version: 'v0.5-beta',
    date: '2026-05-29',
    summary: 'Beta infrastructure complete. Sentry, TestFlight, Play Console all live.',
    isLatest: true,
    entries: [
      _Entry(_EntryType.feature,     'Sentry crash reporting — every crash auto-captured'),
      _Entry(_EntryType.feature,     'iOS TestFlight build — 10,000 tester capacity'),
      _Entry(_EntryType.feature,     'Android Play Console internal testing track'),
      _Entry(_EntryType.feature,     'In-app feedback form with 5 categories'),
      _Entry(_EntryType.feature,     'False positive report flow — feeds ML training'),
      _Entry(_EntryType.feature,     'Beta flavor APK — coexists with prod on device'),
      _Entry(_EntryType.improvement, 'Beta onboarding screen with tester responsibilities'),
      _Entry(_EntryType.improvement, 'Feedback FAB visible on all 118+ screens'),
      _Entry(_EntryType.fix,         'Crash on Android 11 when sending SMS — fixed'),
      _Entry(_EntryType.fix,         'Memory leak in location tracking on iPhone 7'),
    ],
  ),
  _Release(
    version: 'v0.4-beta',
    date: '2026-05-22',
    summary: 'Full i18n support and accessibility pass across all screens.',
    entries: [
      _Entry(_EntryType.feature,     '15-language i18n with easy_localization'),
      _Entry(_EntryType.feature,     'Live language toggle — no restart needed'),
      _Entry(_EntryType.feature,     'RTL support for Arabic and Urdu'),
      _Entry(_EntryType.feature,     'Semantics/TalkBack labels on all interactive widgets'),
      _Entry(_EntryType.feature,     'WCAG 2.1 AA contrast audit — all colours pass'),
      _Entry(_EntryType.improvement, 'Detection flow i18n — all 5 states translated'),
      _Entry(_EntryType.improvement, 'High contrast mode toggle persisted in Hive'),
      _Entry(_EntryType.fix,         'Hindi text overflow in SOS button fixed'),
      _Entry(_EntryType.fix,         'Arabic date format rendering corrected'),
    ],
  ),
  _Release(
    version: 'v0.3-beta',
    date: '2026-05-15',
    summary: 'Premium subscription screens and payment integration stubs.',
    entries: [
      _Entry(_EntryType.feature,     'Premium subscription screen — 3 pricing tiers'),
      _Entry(_EntryType.feature,     'Features showcase screen — 6 premium benefits'),
      _Entry(_EntryType.feature,     'Subscription management (upgrade/downgrade/cancel)'),
      _Entry(_EntryType.feature,     'Payment methods screen — Stripe SDK stub'),
      _Entry(_EntryType.feature,     'Billing history with download/email receipt'),
      _Entry(_EntryType.improvement, 'Stripe checkout session creation flow'),
      _Entry(_EntryType.fix,         'Subscription status not refreshing after upgrade'),
      _Entry(_EntryType.fix,         'Payment method list empty state missing icon'),
    ],
  ),
  _Release(
    version: 'v0.2-beta',
    date: '2026-05-08',
    summary: 'Analytics dashboard and settings screens shipped.',
    entries: [
      _Entry(_EntryType.feature,     'SOS analytics dashboard — 7-day charts'),
      _Entry(_EntryType.feature,     'Contact response stats screen'),
      _Entry(_EntryType.feature,     'Detection analytics — model performance graphs'),
      _Entry(_EntryType.feature,     'Device health metrics screen'),
      _Entry(_EntryType.feature,     'Do Not Disturb scheduling'),
      _Entry(_EntryType.improvement, 'fl_chart integration for all trend visualisations'),
      _Entry(_EntryType.fix,         'Notification delay > 30s on some Android 13 devices'),
      _Entry(_EntryType.fix,         'Settings not persisting after app restart'),
    ],
  ),
  _Release(
    version: 'v0.1-beta',
    date: '2026-04-29',
    summary: 'Initial beta — core SOS flow, detection engine, evidence vault.',
    entries: [
      _Entry(_EntryType.feature,     'Core SOS trigger (8 methods)'),
      _Entry(_EntryType.feature,     'DCS detection engine with TFLite models'),
      _Entry(_EntryType.feature,     'Evidence vault — 6-stream capture'),
      _Entry(_EntryType.feature,     'ALERT_PENDING countdown + PIN cancel'),
      _Entry(_EntryType.feature,     'GPS tracking + trusted circle'),
      _Entry(_EntryType.feature,     'OTP auth + JWT storage in Android Keystore'),
      _Entry(_EntryType.improvement, 'OLED-optimised dark theme throughout'),
      _Entry(_EntryType.fix,         'Initial app stability pass — 47 crash fixes'),
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day119ReleaseNotesScreen extends ConsumerWidget {
  const Day119ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen   = ref.watch(_seenProvider);
    final filter = ref.watch(_filterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text("Day 119 · Release Notes"),
        elevation: 0,
        actions: [
          if (!seen)
            TextButton(
              onPressed: () =>
                  ref.read(_seenProvider.notifier).state = true,
              child: const Text('Mark seen',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ),
          if (seen)
            TextButton(
              onPressed: () =>
                  ref.read(_seenProvider.notifier).state = false,
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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

            // "New update" banner (first launch simulation)
            if (!seen) ...[
              const _NewUpdateBanner(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // Filter chips
            const _SectionLabel('FILTER BY TYPE'),
            const SizedBox(height: ZapSpacing.md),
            _FilterChips(
              selected: filter,
              onSelect: (f) =>
                  ref.read(_filterProvider.notifier).state = f,
            ),
            const SizedBox(height: ZapSpacing.xl),

            // Version stats
            const _SectionLabel('CHANGELOG OVERVIEW'),
            const SizedBox(height: ZapSpacing.md),
            const _ChangelogStats(),
            const SizedBox(height: ZapSpacing.xl),

            // Release cards
            const _SectionLabel('VERSIONS  ·  TAP TO EXPAND'),
            const SizedBox(height: ZapSpacing.md),
            ..._kReleases.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: _ReleaseCard(release: r, filter: filter),
              ),
            ),
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
          colors: [Color(0xFF0D1F0D), Color(0xFF06100A), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBadge('⚡  BETA  ·  DAY 119', const Color(0xFF10B981)),
              const SizedBox(width: ZapSpacing.sm),
              _buildBadge('v0.5-beta', const Color(0xFF3B82F6)),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            "What's New",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Shown on first launch after each update. '
            'Access any time via Settings → "What\'s New". '
            '5 beta versions, 40+ changes tracked.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('5',   'Versions',   Color(0xFF10B981)),
              _HeroStat('26',  'Features',   Color(0xFF3B82F6)),
              _HeroStat('10',  'Fixes',      Color(0xFFEF4444)),
              _HeroStat('7',   'Improvements', Color(0xFFF97316)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_rounded, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ));
  }
}

// ── New update banner ──────────────────────────────────────────────────────────
class _NewUpdateBanner extends ConsumerWidget {
  const _NewUpdateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF10B981).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.new_releases_rounded,
                color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: ZapSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ZapSafe updated to v0.5-beta',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text("See what's new below",
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(_seenProvider.notifier).state = true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.5)),
              ),
              child: const Text('Dismiss',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chips ───────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _Filter selected;
  final ValueChanged<_Filter> onSelect;
  const _FilterChips({required this.selected, required this.onSelect});

  static const _items = [
    (_Filter.all,          'All',          Icons.list_rounded,             Color(0xFF9CA3AF)),
    (_Filter.features,     'Features',     Icons.star_rounded,             Color(0xFF10B981)),
    (_Filter.fixes,        'Fixes',        Icons.build_rounded,            Color(0xFFEF4444)),
    (_Filter.improvements, 'Improvements', Icons.trending_up_rounded,      Color(0xFFF97316)),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _items.map((item) {
          final (filter, label, icon, color) = item;
          final isSelected = selected == filter;
          return GestureDetector(
            onTap: () => onSelect(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: ZapSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: isSelected ? color : const Color(0xFF6B7280),
                      size: 14),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                        color: isSelected
                            ? color
                            : const Color(0xFF9CA3AF),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Changelog stats ────────────────────────────────────────────────────────────
class _ChangelogStats extends StatelessWidget {
  const _ChangelogStats();

  @override
  Widget build(BuildContext context) {
    int features = 0, fixes = 0, improvements = 0;
    for (final r in _kReleases) {
      for (final e in r.entries) {
        if (e.type == _EntryType.feature) features++;
        if (e.type == _EntryType.fix) fixes++;
        if (e.type == _EntryType.improvement) improvements++;
      }
    }

    return Row(
      children: [
        _StatCell('${_kReleases.length}', 'Versions',     const Color(0xFF8B5CF6), Icons.layers_rounded),
        const SizedBox(width: ZapSpacing.sm),
        _StatCell('$features',            'Features',     const Color(0xFF10B981), Icons.star_rounded),
        const SizedBox(width: ZapSpacing.sm),
        _StatCell('$fixes',               'Bug Fixes',    const Color(0xFFEF4444), Icons.build_rounded),
        const SizedBox(width: ZapSpacing.sm),
        _StatCell('$improvements',        'Improvements', const Color(0xFFF97316), Icons.trending_up_rounded),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCell(this.value, this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.md, horizontal: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Release card ───────────────────────────────────────────────────────────────
class _ReleaseCard extends ConsumerWidget {
  final _Release release;
  final _Filter filter;
  const _ReleaseCard({required this.release, required this.filter});

  List<_Entry> get _filtered {
    if (filter == _Filter.all) return release.entries;
    return release.entries.where((e) {
      if (filter == _Filter.features)     return e.type == _EntryType.feature;
      if (filter == _Filter.fixes)        return e.type == _EntryType.fix;
      if (filter == _Filter.improvements) return e.type == _EntryType.improvement;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedProvider(release.version));
    final entries  = _filtered;

    return GestureDetector(
      onTap: () => ref
          .read(_expandedProvider(release.version).notifier)
          .state = !expanded,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: release.isLatest
              ? const Color(0xFF10B981).withOpacity(0.06)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(
            color: release.isLatest
                ? const Color(0xFF10B981).withOpacity(0.35)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                children: [
                  // Version badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: release.isLatest
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: release.isLatest
                            ? const Color(0xFF10B981).withOpacity(0.4)
                            : const Color(0xFF3A3A3A),
                      ),
                    ),
                    child: Text(release.version,
                        style: TextStyle(
                          color: release.isLatest
                              ? const Color(0xFF10B981)
                              : const Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        )),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  if (release.isLatest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('LATEST',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          )),
                    ),
                  const Spacer(),
                  Text(release.date,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                  const SizedBox(width: ZapSpacing.sm),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF4B5563),
                    size: 20,
                  ),
                ],
              ),
            ),
            // Summary
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md),
              child: Text(release.summary,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.5,
                  )),
            ),
            // Entry count chips
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: _EntryCountRow(entries: release.entries),
            ),
            // Expanded entries
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: expanded && entries.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(
                            height: 1, color: Color(0xFF2A2A2A)),
                        ...entries.map(
                          (e) => _EntryRow(entry: e),
                        ),
                        const SizedBox(height: ZapSpacing.sm),
                      ],
                    )
                  : expanded && entries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.md,
                              0,
                              ZapSpacing.md,
                              ZapSpacing.md),
                          child: Container(
                            padding: const EdgeInsets.all(ZapSpacing.md),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(
                                  ZapSpacing.radiusSmall),
                            ),
                            child: const Center(
                              child: Text(
                                'No entries match current filter',
                                style: TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontSize: 12),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Entry count chips ──────────────────────────────────────────────────────────
class _EntryCountRow extends StatelessWidget {
  final List<_Entry> entries;
  const _EntryCountRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    final features     = entries.where((e) => e.type == _EntryType.feature).length;
    final fixes        = entries.where((e) => e.type == _EntryType.fix).length;
    final improvements = entries.where((e) => e.type == _EntryType.improvement).length;

    return Wrap(
      spacing: ZapSpacing.sm,
      runSpacing: ZapSpacing.sm,
      children: [
        if (features > 0)
          _CountChip('$features new', Icons.star_rounded, const Color(0xFF10B981)),
        if (fixes > 0)
          _CountChip('$fixes fixed', Icons.build_rounded, const Color(0xFFEF4444)),
        if (improvements > 0)
          _CountChip('$improvements improved', Icons.trending_up_rounded, const Color(0xFFF97316)),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _CountChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: ZapSpacing.xs),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Entry row ──────────────────────────────────────────────────────────────────
class _EntryRow extends StatelessWidget {
  final _Entry entry;
  const _EntryRow({required this.entry});

  Color get _color {
    switch (entry.type) {
      case _EntryType.feature:     return const Color(0xFF10B981);
      case _EntryType.fix:         return const Color(0xFFEF4444);
      case _EntryType.improvement: return const Color(0xFFF97316);
    }
  }

  String get _prefix {
    switch (entry.type) {
      case _EntryType.feature:     return '✨';
      case _EntryType.fix:         return '✓';
      case _EntryType.improvement: return '↑';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          ZapSpacing.md, ZapSpacing.sm, ZapSpacing.md, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(_prefix,
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(entry.text,
                  style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 13,
                      height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
