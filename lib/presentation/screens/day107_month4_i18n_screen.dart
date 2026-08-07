/// Day 107 — Month 4 Translation Coverage
///
/// Adds alerts, vault, and profile namespaces for the SOS alert management
/// and account screens built in Month 4 (Days 71-90). Features an interactive
/// 4-stage SOS alert lifecycle demo with live locale switching.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

// 0=Triggered, 1=Sending, 2=Escalating, 3=Resolved
final _alertStageProvider = StateProvider<int>((ref) => 0);

const _stageColors = [
  Color(0xFFEF4444), // triggered — red
  Color(0xFFF59E0B), // sending — amber
  Color(0xFF8B5CF6), // escalating — purple
  Color(0xFF10B981), // resolved — green
];

const _stageIcons = [
  Icons.emergency_rounded,
  Icons.send_rounded,
  Icons.arrow_upward_rounded,
  Icons.check_circle_rounded,
];

class Day107Month4I18nScreen extends ConsumerWidget {
  const Day107Month4I18nScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n  = ref.watch(i18nProvider);
    final stage = ref.watch(_alertStageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(lang: i18n.lang, stage: stage),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('NEW NAMESPACES — DAY 107'),
                const SizedBox(height: ZapSpacing.sm),
                const _NamespaceRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('SOS ALERT LIFECYCLE DEMO'),
                const SizedBox(height: ZapSpacing.sm),
                _LocaleSelector(state: i18n, ref: ref),
                const SizedBox(height: ZapSpacing.sm),
                _AlertTimelineCard(i18n: i18n, stage: stage),
                const SizedBox(height: ZapSpacing.md),
                _StageControls(stage: stage, ref: ref),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('MONTH 4 SCREEN CHECKLIST'),
                const SizedBox(height: ZapSpacing.sm),
                const _ScreenChecklist(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('KEY PREVIEW'),
                const SizedBox(height: ZapSpacing.sm),
                _KeyPreview(state: i18n),
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
  const _HeroBanner({required this.lang, required this.stage});
  final LangInfo lang;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final color = _stageColors[stage];
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D1B69), Color(0xFF0A0614)],
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
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(20)),
                  child: const Text('DAY 107', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Text('${lang.flag} ${lang.nativeName}', style: TextStyle(color: color, fontSize: 13)),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text('Month 4\nTranslation Coverage', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'alerts · vault · profile · SOS lifecycle · 15 languages',
              style: TextStyle(color: Color(0xFFA78BFA), fontSize: 13, height: 1.5),
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
        Expanded(child: _StatBox(value: '20', label: 'Screens')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '3',  label: 'Namespaces')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '28', label: 'New Keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '20', label: 'Total\nNamespaces')),
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
        color: const Color(0xFF0D0A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
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
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ─── Namespace Row ────────────────────────────────────────────────────────────

class _NamespaceRow extends StatelessWidget {
  const _NamespaceRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _NsCard(Icons.notifications_rounded, Color(0xFFEF4444), 'alerts', '10 keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _NsCard(Icons.lock_rounded, Color(0xFF10B981), 'vault', '9 keys')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _NsCard(Icons.person_rounded, Color(0xFF3B82F6), 'profile', '9 keys')),
      ],
    );
  }
}

class _NsCard extends StatelessWidget {
  const _NsCard(this.icon, this.color, this.label, this.count);
  final IconData icon;
  final Color color;
  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
        separatorBuilder: (_, __) => const SizedBox(width: ZapSpacing.sm),
        itemBuilder: (_, i) {
          final lang     = kSupportedLanguages[i];
          final selected = lang.code == state.selectedCode;
          return GestureDetector(
            onTap: () {
              ref.read(i18nProvider.notifier).select(lang.code);
              ref.read(_alertStageProvider.notifier).state = 0;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF7C3AED) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selected ? const Color(0xFF7C3AED) : const Color(0xFF2A2A2A)),
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

// ─── Alert Timeline Card ──────────────────────────────────────────────────────

class _AlertTimelineCard extends StatelessWidget {
  const _AlertTimelineCard({required this.i18n, required this.stage});
  final I18nState i18n;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final lifecycle = kAlertLifecycle[i18n.selectedCode] ?? kAlertLifecycle['en']!;
    final color     = _stageColors[stage];
    final icon      = _stageIcons[stage];
    final dir       = i18n.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          children: [
            if (i18n.isRtl) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Text('RTL ←', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
            ],

            // Stage icon with animation
            TweenAnimationBuilder<double>(
              key: ValueKey(stage),
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 24, spreadRadius: 4)],
                ),
                child: Icon(icon, color: color, size: 38),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),

            // Stage dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final active = i == stage;
                final past   = i < stage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 32 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: past ? _stageColors[i].withOpacity(0.4) : active ? color : const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
            const SizedBox(height: ZapSpacing.md),

            // Current stage text
            Text(
              lifecycle[stage],
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.sm),

            // All 4 stages as a mini timeline
            const SizedBox(height: ZapSpacing.sm),
            Column(
              children: List.generate(4, (i) {
                final past    = i < stage;
                final current = i == stage;
                final c       = _stageColors[i];
                final lifecycle2 = kAlertLifecycle[i18n.selectedCode] ?? kAlertLifecycle['en']!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        past ? Icons.check_circle_rounded : current ? _stageIcons[i] : Icons.radio_button_unchecked_rounded,
                        color: past ? c.withOpacity(0.5) : current ? c : const Color(0xFF2A2A2A),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lifecycle2[i],
                          style: TextStyle(
                            color: current ? Colors.white : past ? const Color(0xFF6B7280) : const Color(0xFF374151),
                            fontSize: 13,
                            fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stage Controls ───────────────────────────────────────────────────────────

class _StageControls extends StatelessWidget {
  const _StageControls({required this.stage, required this.ref});
  final int stage;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final color = _stageColors[stage];
    void advance() => ref.read(_alertStageProvider.notifier).state = (stage + 1) % 4;
    void retreat() { if (stage > 0) ref.read(_alertStageProvider.notifier).state = stage - 1; }
    void reset()   => ref.read(_alertStageProvider.notifier).state = 0;

    return Row(
      children: [
        GestureDetector(
          onTap: retreat,
          child: Container(width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6B7280))),
        ),
        const SizedBox(width: ZapSpacing.sm),
        GestureDetector(
          onTap: reset,
          child: Container(width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF6B7280), size: 20)),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: GestureDetector(
            onTap: advance,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 52,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text(
                stage == 3 ? 'Restart' : 'Next Stage →',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Screen Checklist ─────────────────────────────────────────────────────────

class _ScreenChecklist extends StatelessWidget {
  const _ScreenChecklist();

  static const _items = [
    ['Alert Pending', 'alerts.*'],
    ['Do Not Disturb', 'alerts.*'],
    ['Delivery Confirmation', 'alerts.*'],
    ['SOS Active', 'sos.* · alerts.*'],
    ['Notification History', 'alerts.*'],
    ['Alert Dashboard', 'alerts.*'],
    ['Alert Dashboard V2', 'alerts.*'],
    ['Settings V2', 'settings.*'],
    ['Evidence Vault', 'vault.*'],
    ['Contact Management', 'contacts.*'],
    ['Emergency Drills', 'drills.*'],
    ['Alert Thresholds', 'detection.*'],
    ['Escalation Policy', 'alerts.*'],
    ['SOS Templates', 'sos.*'],
    ['Notification History V2', 'alerts.*'],
    ['Activity Audit Log', 'privacy.*'],
    ['Data Privacy', 'privacy.*'],
    ['Profile & Account', 'profile.*'],
    ['Help & Support', 'help.*'],
    ['Day 100 Milestone', 'common.*'],
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
        children: List.generate(_items.length, (i) {
          final isLast = i == _items.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(_items[i][0], style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
                  child: Text(_items[i][1], style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 10, fontFamily: 'monospace')),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Key Preview ──────────────────────────────────────────────────────────────

class _KeyPreview extends StatelessWidget {
  const _KeyPreview({required this.state});
  final I18nState state;

  @override
  Widget build(BuildContext context) {
    final t   = kMonth4Translations[state.selectedCode] ?? kMonth4Translations['en']!;
    final dir = state.isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: dir,
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.35)),
        ),
        child: Column(
          children: [
            _row(Icons.notifications_rounded, const Color(0xFFEF4444), 'alerts.pending',      t['alerts.pending'] ?? ''),
            _row(Icons.place_rounded,          const Color(0xFFEF4444), 'alerts.view_location', t['alerts.view_location'] ?? ''),
            _row(Icons.lock_rounded,            const Color(0xFF10B981), 'vault.title',          t['vault.title'] ?? ''),
            _row(Icons.verified_rounded,        const Color(0xFF3B82F6), 'profile.verified',     t['profile.verified'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, Color color, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          SizedBox(width: 140, child: Text(key, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13))),
        ],
      ),
    );
  }
}
