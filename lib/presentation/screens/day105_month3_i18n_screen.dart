/// Day 105 — Month 3 Translation Coverage
///
/// Adds detection, audio, and drills namespaces for the ML/AI detection
/// screens built in Month 3. Live locale switcher with key preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

class Day105Month3I18nScreen extends ConsumerWidget {
  const Day105Month3I18nScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(i18nProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(state: state),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('NEW NAMESPACES — DAY 105'),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.radar_rounded,
                  color: Color(0xFF06B6D4),
                  namespace: 'detection',
                  keyCount: 12,
                  keys: [
                    'title', 'active', 'inactive', 'sensitivity',
                    'sensitivity_low', 'sensitivity_medium', 'sensitivity_high',
                    'glass_break', 'distress_sound', 'loud_impact',
                    'confidence', 'false_positive',
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.mic_rounded,
                  color: Color(0xFF10B981),
                  namespace: 'audio',
                  keyCount: 8,
                  keys: [
                    'title', 'listening', 'paused', 'noise_floor',
                    'peak_level', 'features', 'sample_rate', 'buffer_size',
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceCard(
                  icon: Icons.crisis_alert_rounded,
                  color: Color(0xFFF97316),
                  namespace: 'drills',
                  keyCount: 9,
                  keys: [
                    'title', 'schedule', 'run_now', 'complete',
                    'duration', 'passed', 'failed', 'next_drill', 'last_drill',
                  ],
                ),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('MONTH 3 SCREEN CHECKLIST'),
                const SizedBox(height: ZapSpacing.sm),
                const _ScreenChecklist(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('LIVE PREVIEW'),
                const SizedBox(height: ZapSpacing.sm),
                _LocaleSelector(state: state, ref: ref),
                const SizedBox(height: ZapSpacing.sm),
                _LivePreview(state: state),
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
  const _HeroBanner({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E4D5C), Color(0xFF061018)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF06B6D4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('DAY 105', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                  ),
                  child: Text(
                    '${state.lang.flag} ${state.lang.nativeName}',
                    style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text(
              'Month 3\nTranslation Coverage',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              '3 new namespaces · 29 new keys · 18 Month 3 screens · 15 languages',
              style: TextStyle(color: Color(0xFF67E8F9), fontSize: 13, height: 1.5),
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
        Expanded(child: _StatBox(value: '18', label: 'Screens')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '3', label: 'Namespaces')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '29', label: 'New Keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '14', label: 'Namespaces\nTotal')),
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
        color: const Color(0xFF061318),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
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

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}

// ─── Namespace Card ───────────────────────────────────────────────────────────

class _NamespaceCard extends StatelessWidget {
  const _NamespaceCard({
    required this.icon,
    required this.color,
    required this.namespace,
    required this.keyCount,
    required this.keys,
  });

  final IconData icon;
  final Color color;
  final String namespace;
  final int keyCount;
  final List<String> keys;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(namespace, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('$keyCount keys', style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text('15 langs', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys.map((k) => _KeyChip(k, color)).toList(),
          ),
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontFamily: 'monospace')),
    );
  }
}

// ─── Screen Checklist ─────────────────────────────────────────────────────────

class _ScreenChecklist extends StatelessWidget {
  const _ScreenChecklist();

  static const _screens = [
    ['Audio Capture', 'audio.*'],
    ['Audio Features', 'audio.*'],
    ['iOS Audio', 'audio.*'],
    ['Inference Engine', 'detection.*'],
    ['TFLite Models', 'detection.*'],
    ['DCS Engine', 'detection.*'],
    ['DCS Stream', 'detection.*'],
    ['Isolate Latency', 'detection.*'],
    ['IMU Service', 'detection.*'],
    ['GPS Service', 'detection.*'],
    ['Fallback & State', 'detection.*'],
    ['State Wiring', 'detection.*'],
    ['Heuristic Engine', 'detection.*'],
    ['Model Bundle', 'detection.*'],
    ['Detection Settings', 'detection.*'],
    ['Drill Mode', 'drills.*'],
    ['Drills & Schedule', 'drills.*'],
    ['Safety Drills V2', 'drills.*'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        children: List.generate(_screens.length, (i) {
          final isLast = i == _screens.length - 1;
          final screen = _screens[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 11),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF06B6D4), size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(screen[0], style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(screen[1], style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10, fontFamily: 'monospace')),
                ),
              ],
            ),
          );
        }),
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
          final lang = kSupportedLanguages[i];
          final selected = lang.code == state.selectedCode;
          return GestureDetector(
            onTap: () => ref.read(i18nProvider.notifier).select(lang.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF06B6D4) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? const Color(0xFF06B6D4) : const Color(0xFF2A2A2A),
                ),
              ),
              child: Text(
                '${lang.flag} ${lang.code.toUpperCase()}',
                style: TextStyle(
                  color: selected ? Colors.black : const Color(0xFF9CA3AF),
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

// ─── Live Preview ─────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final t   = kMonth3Translations[state.selectedCode] ?? kMonth3Translations['en']!;
    final dir = state.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(state.lang.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(state.lang.nativeName,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                if (state.isRtl) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('RTL', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            const Divider(color: Color(0xFF1F1F1F), height: 20),
            _PreviewGroup(
              label: 'detection.*',
              color: const Color(0xFF06B6D4),
              rows: [
                _Row('detection.title',  t['detection.title']  ?? ''),
                _Row('detection.active', t['detection.active'] ?? ''),
                _Row('detection.glass',  t['detection.glass']  ?? ''),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            _PreviewGroup(
              label: 'audio.*',
              color: const Color(0xFF10B981),
              rows: [
                _Row('audio.title',     t['audio.title']     ?? ''),
                _Row('audio.listening', t['audio.listening'] ?? ''),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            _PreviewGroup(
              label: 'drills.*',
              color: const Color(0xFFF97316),
              rows: [
                _Row('drills.title',    t['drills.title']    ?? ''),
                _Row('drills.run_now',  t['drills.run_now']  ?? ''),
                _Row('drills.complete', t['drills.complete'] ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.key, this.value);
  final String key;
  final String value;
}

class _PreviewGroup extends StatelessWidget {
  const _PreviewGroup({required this.label, required this.color, required this.rows});
  final String label;
  final Color color;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 0.5)),
        const SizedBox(height: 4),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(r.key, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontFamily: 'monospace')),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(r.value, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13))),
            ],
          ),
        )),
      ],
    );
  }
}
