/// Day 109 — Accessibility: Semantics / Screen Reader Labels
///
/// Demonstrates every Semantics pattern needed by ZapSafe:
///   • Semantics(label, hint, button) for custom buttons
///   • Semantics(header: true)        for section headings
///   • Semantics(liveRegion: true)     for SOS countdown / dynamic text
///   • MergeSemantics                  for grouped contact rows
///   • ExcludeSemantics                for decorative icons
///   • Semantics(onTapHint)            for custom action descriptions
///
/// Each pattern card has a toggle so you can compare
/// "With Semantics" vs "Without Semantics" behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// Per-card toggle state — true = semantics ON
final _toggleProvider =
    StateProvider.family<bool, int>((ref, index) => true);

// SOS countdown for liveRegion demo
final _countdownProvider = StateProvider<int>((ref) => 5);

class Day109SemanticsScreen extends ConsumerStatefulWidget {
  const Day109SemanticsScreen({super.key});

  @override
  ConsumerState<Day109SemanticsScreen> createState() =>
      _Day109SemanticsScreenState();
}

class _Day109SemanticsScreenState
    extends ConsumerState<Day109SemanticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          const _HeroBanner(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                const _StatsRow(),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('SEMANTICS PATTERNS'),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 0,
                  patternName: 'Button',
                  wcag: '4.1.2 Name, Role, Value',
                  color: Color(0xFFEF4444),
                  icon: Icons.emergency_rounded,
                  description: 'Custom gesture containers need an explicit semantic label and role so TalkBack announces them as buttons.',
                  codeSnippet:
                      'Semantics(\n'
                      '  label: "Trigger SOS emergency alert",\n'
                      '  hint: "Double-tap to activate",\n'
                      '  button: true,\n'
                      '  child: _SosCircle(),\n'
                      ')',
                  talkbackSays: '"Trigger SOS emergency alert. Button. Double-tap to activate."',
                  withWidget: _SosButtonDemo(semanticsOn: true),
                  withoutWidget: _SosButtonDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 1,
                  patternName: 'Header',
                  wcag: '1.3.1 Info & Relationships',
                  color: Color(0xFF3B82F6),
                  icon: Icons.title_rounded,
                  description: 'Section headings marked with header:true let users jump between sections with the TalkBack heading navigation gesture.',
                  codeSnippet:
                      'Semantics(\n'
                      '  header: true,\n'
                      '  child: Text("Emergency Contacts"),\n'
                      ')',
                  talkbackSays: '"Emergency Contacts. Heading."',
                  withWidget: _HeadingDemo(semanticsOn: true),
                  withoutWidget: _HeadingDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 2,
                  patternName: 'Live Region',
                  wcag: '4.1.3 Status Messages',
                  color: Color(0xFFF59E0B),
                  icon: Icons.campaign_rounded,
                  description: 'Dynamic text (SOS countdown, detection status) must be a liveRegion so changes are announced without focus.',
                  codeSnippet:
                      'Semantics(\n'
                      '  liveRegion: true,\n'
                      '  label: "SOS in \$seconds seconds",\n'
                      '  child: Text("SOS in \$seconds s"),\n'
                      ')',
                  talkbackSays: '"SOS in 3 seconds." (auto-announced on change)',
                  withWidget: _LiveRegionDemo(semanticsOn: true),
                  withoutWidget: _LiveRegionDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 3,
                  patternName: 'Merge Semantics',
                  wcag: '1.3.1 Info & Relationships',
                  color: Color(0xFF8B5CF6),
                  icon: Icons.merge_rounded,
                  description: 'Contact rows (avatar + name + tier badge) should read as one item, not three separate focusable elements.',
                  codeSnippet:
                      'MergeSemantics(\n'
                      '  child: Row(children: [\n'
                      '    _Avatar(),\n'
                      '    _Name("Priya"),\n'
                      '    _TierBadge("Tier 1"),\n'
                      '  ]),\n'
                      ')',
                  talkbackSays: '"Priya. Tier 1 contact."',
                  withWidget: _MergeDemo(semanticsOn: true),
                  withoutWidget: _MergeDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 4,
                  patternName: 'Exclude Semantics',
                  wcag: '1.1.1 Non-text Content',
                  color: Color(0xFF10B981),
                  icon: Icons.hide_source_rounded,
                  description: 'Decorative icons and dividers should be hidden from the accessibility tree to avoid clutter.',
                  codeSnippet:
                      'ExcludeSemantics(\n'
                      '  child: Icon(\n'
                      '    Icons.chevron_right_rounded,\n'
                      '  ),\n'
                      ')',
                  talkbackSays: '(decorative — not announced)',
                  withWidget: _ExcludeDemo(semanticsOn: true),
                  withoutWidget: _ExcludeDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _PatternCard(
                  index: 5,
                  patternName: 'onTap Hint',
                  wcag: '2.5.3 Label in Name',
                  color: Color(0xFF06B6D4),
                  icon: Icons.touch_app_rounded,
                  description: 'onTapHint replaces the generic "double-tap to activate" with an action-specific description.',
                  codeSnippet:
                      'Semantics(\n'
                      '  onTapHint: "view contact on map",\n'
                      '  child: _LocationButton(),\n'
                      ')',
                  talkbackSays: '"View location. Button. Double-tap to view contact on map."',
                  withWidget: _TapHintDemo(semanticsOn: true),
                  withoutWidget: _TapHintDemo(semanticsOn: false),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('SCREEN COVERAGE'),
                const SizedBox(height: ZapSpacing.sm),
                const _CoverageChecklist(),
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
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Semantics(
        header: true,
        child: Container(
          margin: const EdgeInsets.all(ZapSpacing.md),
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF0A1628)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2563EB), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(20)),
                    child: const Text('DAY 109', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ),
                  const Spacer(),
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
                      ),
                      child: const Text('WCAG 2.1 AA', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              const Text('Accessibility\nScreen Reader Labels', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                'Semantics · MergeSemantics · ExcludeSemantics · liveRegion · TalkBack · VoiceOver',
                style: TextStyle(color: Color(0xFF93C5FD), fontSize: 13, height: 1.5),
              ),
            ],
          ),
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
        Expanded(child: _StatBox(value: '6',    label: 'Patterns')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '20+',  label: 'Widgets')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: 'AA',   label: 'WCAG 2.1')),
        SizedBox(width: ZapSpacing.sm),
        Expanded(child: _StatBox(value: '2',    label: 'Platforms')),
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
    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
          ],
        ),
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
    return Semantics(
      header: true,
      child: Text(text, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }
}

// ─── Pattern Card ─────────────────────────────────────────────────────────────

class _PatternCard extends ConsumerWidget {
  const _PatternCard({
    required this.index,
    required this.patternName,
    required this.wcag,
    required this.color,
    required this.icon,
    required this.description,
    required this.codeSnippet,
    required this.talkbackSays,
    required this.withWidget,
    required this.withoutWidget,
  });

  final int index;
  final String patternName;
  final String wcag;
  final Color color;
  final IconData icon;
  final String description;
  final String codeSnippet;
  final String talkbackSays;
  final Widget withWidget;
  final Widget withoutWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(_toggleProvider(index));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patternName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(wcag, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
                    ],
                  ),
                ),
                // Toggle
                Semantics(
                  label: 'Toggle semantics ${on ? "off" : "on"} for $patternName demo',
                  button: true,
                  child: GestureDetector(
                    onTap: () => ref.read(_toggleProvider(index).notifier).state = !on,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: on ? color.withOpacity(0.15) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on ? color : const Color(0xFF2A2A2A)),
                      ),
                      child: Text(
                        on ? 'ON ✓' : 'OFF',
                        style: TextStyle(color: on ? color : const Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: Text(description, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: ZapSpacing.md),

          // Live demo widget
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(on),
                width: double.infinity,
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? color.withOpacity(0.3) : const Color(0xFF1A1A1A)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (on ? color : const Color(0xFF374151)).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              on ? 'Semantics ON' : 'Semantics OFF',
                              style: TextStyle(color: on ? color : const Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    on ? withWidget : withoutWidget,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // Code snippet
          Container(
            margin: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1A1A1A)),
            ),
            child: Text(codeSnippet, style: TextStyle(color: color.withOpacity(0.85), fontSize: 11, fontFamily: 'monospace', height: 1.55)),
          ),
          const SizedBox(height: ZapSpacing.sm),

          // TalkBack says
          Container(
            margin: const EdgeInsets.fromLTRB(ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B0D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF166534).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔊', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(child: Text(talkbackSays, style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontStyle: FontStyle.italic))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Demo Widgets — each has a semanticsOn switch ─────────────────────────────

// 1. SOS Button
class _SosButtonDemo extends StatelessWidget {
  const _SosButtonDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.4), blurRadius: 16, spreadRadius: 2)],
      ),
      child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 32),
    );

    if (!semanticsOn) return btn;
    return Semantics(
      label: 'Trigger SOS emergency alert',
      hint: 'Double-tap to activate',
      button: true,
      child: btn,
    );
  }
}

// 2. Heading
class _HeadingDemo extends StatelessWidget {
  const _HeadingDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context) {
    const txt = Text('Emergency Contacts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700));
    if (!semanticsOn) return txt;
    return Semantics(header: true, child: const Text('Emergency Contacts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)));
  }
}

// 3. Live Region
class _LiveRegionDemo extends ConsumerWidget {
  const _LiveRegionDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_countdownProvider);
    final label = 'SOS in $count seconds';
    final txt = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_rounded, color: Color(0xFFF59E0B), size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: ZapSpacing.md),
        GestureDetector(
          onTap: () {
            final c = ref.read(_countdownProvider);
            ref.read(_countdownProvider.notifier).state = c > 1 ? c - 1 : 5;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Text('−1s', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
          ),
        ),
      ],
    );

    if (!semanticsOn) return txt;
    return Semantics(liveRegion: true, label: label, child: txt);
  }
}

// 4. Merge Semantics
class _MergeDemo extends StatelessWidget {
  const _MergeDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(width: 36, height: 36, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18)),
        const SizedBox(width: 10),
        const Expanded(child: Text('Priya Sharma', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
          child: const Text('Tier 1', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
    if (!semanticsOn) return row;
    return MergeSemantics(child: row);
  }
}

// 5. Exclude Semantics
class _ExcludeDemo extends StatelessWidget {
  const _ExcludeDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context) {
    final decorative = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chevron_right_rounded, color: const Color(0xFF374151).withOpacity(0.5), size: 24),
        const SizedBox(width: ZapSpacing.xs),
        const Text('Decorative icon (not readable to TalkBack when excluded)', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ],
    );
    if (!semanticsOn) return decorative;
    return ExcludeSemantics(child: decorative);
  }
}

// 6. onTap Hint
class _TapHintDemo extends StatelessWidget {
  const _TapHintDemo({required this.semanticsOn});
  final bool semanticsOn;

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_rounded, color: Color(0xFF67E8F9), size: 16),
          SizedBox(width: 6),
          Text('View Location', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
    if (!semanticsOn) return btn;
    return Semantics(onTapHint: 'view contact on map', child: btn);
  }
}

// ─── Coverage Checklist ───────────────────────────────────────────────────────

class _CoverageChecklist extends StatelessWidget {
  const _CoverageChecklist();

  static const _screens = [
    ['SOS Active screen', 'button · liveRegion'],
    ['Onboarding Steps 1-5', 'header · button · image'],
    ['Phone Entry / OTP', 'textField · button'],
    ['App Permissions', 'button · header · image'],
    ['Emergency Contacts', 'header · mergeSemantics · button'],
    ['Home / Dashboard', 'header · liveRegion · button'],
    ['Settings', 'header · button'],
    ['Evidence Vault', 'button · image · header'],
    ['Alert Dashboard', 'liveRegion · button · header'],
    ['Language Toggle', 'button · header · onTapHint'],
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
          return MergeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 11),
              decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
              child: Row(
                children: [
                  const Icon(Icons.accessibility_new_rounded, color: Color(0xFF2563EB), size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_screens[i][0], style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_screens[i][1], style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
