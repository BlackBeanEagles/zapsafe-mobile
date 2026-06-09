/// Day 106 — Detection State Flow i18n Demo
///
/// Interactive 5-state detection pipeline (Idle → Listening → Analysing →
/// Threat Detected → SOS Sent) with live locale switching and RTL support.
/// Also previews the new zones, checkin, and incidents namespaces.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

// State index provider — 0=Idle, 1=Listening, 2=Analysing, 3=Alert, 4=SOS
final _flowStateProvider = StateProvider<int>((ref) => 0);

// Per-state visual config
const _stateIcons = [
  Icons.shield_rounded,
  Icons.hearing_rounded,
  Icons.analytics_rounded,
  Icons.warning_rounded,
  Icons.check_circle_rounded,
];

const _stateColors = [
  Color(0xFF374151),  // idle — grey
  Color(0xFF06B6D4),  // listening — cyan
  Color(0xFFF59E0B),  // analysing — amber
  Color(0xFFEF4444),  // alert — red
  Color(0xFF10B981),  // sos sent — green
];

const _stateBgColors = [
  Color(0xFF111827),
  Color(0xFF061318),
  Color(0xFF1C1000),
  Color(0xFF1A0000),
  Color(0xFF022C1A),
];

class Day106DetectionFlowScreen extends ConsumerWidget {
  const Day106DetectionFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n      = ref.watch(i18nProvider);
    final stateIdx  = ref.watch(_flowStateProvider);
    final states    = kDetectionStates[i18n.selectedCode] ?? kDetectionStates['en']!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(lang: i18n.lang, stateIdx: stateIdx),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                _LocaleSelector(state: i18n, ref: ref),
                const SizedBox(height: ZapSpacing.lg),
                _FlowCard(stateIdx: stateIdx, states: states, isRtl: i18n.isRtl),
                const SizedBox(height: ZapSpacing.md),
                _StateControls(stateIdx: stateIdx, ref: ref),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('NEW NAMESPACES — DAY 106'),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('LIVE PREVIEW — ZONES · CHECK-IN · INCIDENTS'),
                const SizedBox(height: ZapSpacing.sm),
                _ZoneCheckinPreview(state: i18n),
                const SizedBox(height: ZapSpacing.lg),
                const _PipelineSummary(),
                const SizedBox(height: ZapSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.lang, required this.stateIdx});
  final LangInfo lang;
  final int stateIdx;

  @override
  Widget build(BuildContext context) {
    final color = _stateColors[stateIdx];
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.25), const Color(0xFF060606)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.6), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: const Text('DAY 106', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Text('${lang.flag} ${lang.nativeName}', style: TextStyle(color: color, fontSize: 13)),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text('Detection Flow\ni18n Applied', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'zones · checkin · incidents · 5-state detection pipeline · 15 languages',
              style: TextStyle(color: color.withOpacity(0.85), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats ────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatBox(value: '5',  label: 'States')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '3',  label: 'Namespaces')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '26', label: 'New Keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '17', label: 'Total\nNamespaces')),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Locale Selector ──────────────────────────────────────────────────────────

class _LocaleSelector extends StatelessWidget {
  const _LocaleSelector({required this.state, required this.ref});
  final I18nState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kSupportedLanguages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final lang     = kSupportedLanguages[i];
          final selected = lang.code == state.selectedCode;
          return GestureDetector(
            onTap: () {
              ref.read(i18nProvider.notifier).select(lang.code);
              ref.read(_flowStateProvider.notifier).state = 0;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEF4444) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selected ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A)),
              ),
              child: Text(
                '${lang.flag} ${lang.code.toUpperCase()}',
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Flow Card ────────────────────────────────────────────────────────────────

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.stateIdx, required this.states, required this.isRtl});
  final int stateIdx;
  final List<String> states;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final color   = _stateColors[stateIdx];
    final bgColor = _stateBgColors[stateIdx];
    final icon    = _stateIcons[stateIdx];
    final label   = states[stateIdx];

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          children: [
            if (isRtl)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('RTL ←', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            if (isRtl) const SizedBox(height: ZapSpacing.sm),

            // Pulsing state icon
            TweenAnimationBuilder<double>(
              key: ValueKey(stateIdx),
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 4)],
                ),
                child: Icon(icon, color: color, size: 40),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),

            // State index indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final active = i == stateIdx;
                final past   = i < stateIdx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: past
                        ? _stateColors[i].withOpacity(0.5)
                        : active
                            ? color
                            : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: ZapSpacing.md),

            // State label
            Text(
              label,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),

            Text(
              'State ${stateIdx + 1} of 5',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── State Controls ───────────────────────────────────────────────────────────

class _StateControls extends StatelessWidget {
  const _StateControls({required this.stateIdx, required this.ref});
  final int stateIdx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final color = _stateColors[stateIdx];

    void advance() {
      final next = (stateIdx + 1) % 5;
      ref.read(_flowStateProvider.notifier).state = next;
    }

    void retreat() {
      if (stateIdx > 0) ref.read(_flowStateProvider.notifier).state = stateIdx - 1;
    }

    void reset() => ref.read(_flowStateProvider.notifier).state = 0;

    return Row(
      children: [
        // Back
        GestureDetector(
          onTap: retreat,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),

        // Reset
        GestureDetector(
          onTap: reset,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280), size: 20),
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),

        // Advance (primary)
        Expanded(
          child: GestureDetector(
            onTap: advance,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                stateIdx == 4 ? 'Restart Flow' : 'Next State →',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Namespace Row ────────────────────────────────────────────────────────────

class _NamespaceRow extends StatelessWidget {
  const _NamespaceRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _NsChip(Icons.map_rounded, Color(0xFF10B981), 'zones', '10 keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _NsChip(Icons.check_circle_outline_rounded, Color(0xFF3B82F6), 'checkin', '7 keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _NsChip(Icons.report_rounded, Color(0xFFF97316), 'incidents', '9 keys')),
      ],
    );
  }
}

class _NsChip extends StatelessWidget {
  const _NsChip(this.icon, this.color, this.label, this.count);
  final IconData icon;
  final Color color;
  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(count, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Zone / Check-in Preview ──────────────────────────────────────────────────

class _ZoneCheckinPreview extends StatelessWidget {
  const _ZoneCheckinPreview({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final t   = kZoneCheckinTranslations[state.selectedCode] ?? kZoneCheckinTranslations['en']!;
    final dir = state.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F1F1F)),
        ),
        child: Column(
          children: [
            _previewRow(Icons.map_rounded, const Color(0xFF10B981), 'zones.title', t['zones.title'] ?? ''),
            _previewRow(Icons.home_rounded, const Color(0xFF10B981), 'zones.home', t['zones.home'] ?? ''),
            _previewRow(Icons.check_circle_outline_rounded, const Color(0xFF3B82F6), 'checkin.confirm_safe', t['checkin.confirm_safe'] ?? ''),
            _previewRow(Icons.report_rounded, const Color(0xFFF97316), 'incidents.high', t['incidents.high'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(IconData icon, Color color, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          SizedBox(width: 130, child: Text(key, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13))),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ─── Pipeline Summary ─────────────────────────────────────────────────────────

class _PipelineSummary extends StatelessWidget {
  const _PipelineSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MONTH 3 i18n COMPLETE', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: ZapSpacing.sm),
          _summaryRow('Day 105', const Color(0xFF06B6D4), 'detection · audio · drills — 29 keys'),
          _summaryRow('Day 106', const Color(0xFFEF4444), 'zones · checkin · incidents — 26 keys'),
          _summaryRow('Total', const Color(0xFF10B981), '17 namespaces · 175+ keys · 15 languages'),
          _summaryRow('en + hi', const Color(0xFF10B981), 'Full JSON coverage'),
          _summaryRow('13 others', const Color(0xFF3B82F6), 'Fallback to English for new keys'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, Color color, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(detail, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
        ],
      ),
    );
  }
}
