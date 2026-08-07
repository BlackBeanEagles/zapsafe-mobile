/// Day 138 — Final Polish (Part 1)
///
/// First half of the Days 138-139 final polish cycle.
/// Day 137 gate passed with 4 items queued:
///   Fix 1 — SOS explanation card: auto-dismiss → keep until tapped
///   Fix 2 — White theme flash on cold start
///   Fix 3 — Evidence vault list: 1-2s first-open delay
///   Fix 4 — SOS explanation text too small on iPhone SE (375px)
///
/// Also runs the first pass of the WCAG 2.1 AA/AAA accessibility audit —
/// the full 65-item checklist required before App Store submission.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider   = StateProvider<int>((ref) => 0);
final _appliedProvider     = StateProvider<List<bool>>(
  (ref) => List.filled(4, false),
);
final _a11yProvider        = StateProvider<List<bool?>>(
  (ref) => List.filled(_kA11yChecks.length, null),
);
final _demoFixProvider     = StateProvider<int>((ref) => -1); // which fix demo is active

// ── Data ───────────────────────────────────────────────────────────────────────
class _Fix {
  final String id;
  final String title;
  final String priority;
  final Color  priorityColor;
  final String source;
  final String effort;
  final String before;
  final String after;
  final Color  color;
  final IconData icon;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  const _Fix({
    required this.id,
    required this.title,
    required this.priority,
    required this.priorityColor,
    required this.source,
    required this.effort,
    required this.before,
    required this.after,
    required this.color,
    required this.icon,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
  });
}

const _kFixes = [
  _Fix(
    id: 'F1',
    title: 'SOS explanation card — keep until dismissed',
    priority: 'P1', priorityColor: Color(0xFFF97316),
    source: 'Vikram R. + 4 testers',
    effort: '2h',
    before: 'Card auto-dismisses after 3s',
    after: 'Card stays until user taps "Got it" or "Report"',
    color: Color(0xFFEF4444),
    icon: Icons.info_rounded,
    codeFile: 'post_sos_explanation_card.dart',
    codeBefore:
        'class _ExplanationCardState extends State<...> {\n'
        '  @override\n'
        '  void initState() {\n'
        '    super.initState();\n'
        '    // ❌ Auto-dismiss after 3 seconds\n'
        '    Future.delayed(const Duration(seconds: 3), () {\n'
        '      if (mounted) widget.onDismiss();\n'
        '    });\n'
        '  }\n'
        '}',
    codeAfter:
        'class _ExplanationCardState extends State<...> {\n'
        '  // ✅ No auto-dismiss — user must explicitly act\n'
        '  // Card has two buttons:\n'
        '  // "Got it — I\'m safe" → dismisses\n'
        '  // "Report false alarm" → logs + dismisses\n'
        '  // No timer. Card persists until user taps.\n'
        '}',
  ),
  _Fix(
    id: 'F2',
    title: 'White flash on cold start (theme load delay)',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    source: 'Rahul S. + 3 testers',
    effort: '1h',
    before: 'White frame visible for ~200ms before dark theme applies',
    after: 'Dark background from first frame (windowBackground set)',
    color: Color(0xFF3B82F6),
    icon: Icons.brightness_4_rounded,
    codeFile: 'styles.xml (Android)',
    codeBefore:
        '<!-- android/app/src/main/res/values/styles.xml -->\n'
        '<style name="LaunchTheme">\n'
        '  <!-- ❌ Default white background -->\n'
        '  <item name="android:windowBackground">\n'
        '    @android:color/white\n'
        '  </item>\n'
        '</style>',
    codeAfter:
        '<!-- android/app/src/main/res/values/styles.xml -->\n'
        '<style name="LaunchTheme">\n'
        '  <!-- ✅ Match app dark background (#07070E) -->\n'
        '  <item name="android:windowBackground">\n'
        '    @color/bgPrimary\n'
        '  </item>\n'
        '  <item name="android:windowIsTranslucent">false</item>\n'
        '</style>',
  ),
  _Fix(
    id: 'F3',
    title: 'Evidence vault list — 1-2s first-open delay',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    source: 'Rahul S.',
    effort: '3h',
    before: 'Full query runs synchronously on navigation → visible lag',
    after: 'Skeleton placeholder instant; data loads async in background',
    color: Color(0xFF8B5CF6),
    icon: Icons.lock_rounded,
    codeFile: 'evidence_vault_screen.dart',
    codeBefore:
        'class EvidenceVaultScreen extends StatefulWidget {\n'
        '  @override\n'
        '  void initState() {\n'
        '    super.initState();\n'
        '    // ❌ Blocking DB query on build\n'
        '    _items = EvidenceRepo.getAll(); // sync, 1-2s\n'
        '  }\n'
        '}',
    codeAfter:
        '// ✅ Riverpod async provider — skeleton shown instantly\n'
        'final evidenceProvider = FutureProvider<List<Evidence>>(\n'
        '  (ref) => ref.read(evidenceRepoProvider).getAll(),\n'
        ');\n'
        '\n'
        '// In build:\n'
        'final evidence = ref.watch(evidenceProvider);\n'
        'return evidence.when(\n'
        '  loading: () => const _VaultSkeleton(),  // instant\n'
        '  data:    (items) => _VaultList(items),\n'
        '  error:   (e, _) => _VaultError(e),\n'
        ');',
  ),
  _Fix(
    id: 'F4',
    title: 'SOS explanation text too small on iPhone SE (375px)',
    priority: 'P2', priorityColor: Color(0xFFF59E0B),
    source: 'Vikram R.',
    effort: '30m',
    before: 'Fixed 12px body text — unreadable at 375px screen width',
    after: 'MediaQuery-adaptive: 14px on SE (< 380px), 12px standard',
    color: Color(0xFF10B981),
    icon: Icons.text_fields_rounded,
    codeFile: 'post_sos_explanation_card.dart',
    codeBefore:
        '// ❌ Fixed text size — cramped on SE\n'
        'Text(\n'
        '  explanation,\n'
        '  style: const TextStyle(fontSize: 12),\n'
        ')',
    codeAfter:
        '// ✅ Adaptive text size\n'
        'final isSmallScreen =\n'
        '    MediaQuery.of(context).size.width < 380;\n'
        'Text(\n'
        '  explanation,\n'
        '  style: TextStyle(\n'
        '    fontSize: isSmallScreen ? 14 : 12,\n'
        '  ),\n'
        ')',
  ),
];

class _A11yCheck {
  final String category;
  final String item;
  final String guidance;
  const _A11yCheck(this.category, this.item, this.guidance);
}

const _kA11yChecks = [
  // Contrast
  _A11yCheck('Contrast', 'All body text ≥ 4.5:1 contrast ratio (AA)', 'Run DevTools contrast analyser on all 10 theme colours'),
  _A11yCheck('Contrast', 'Large text ≥ 3:1 contrast ratio (AA)', 'Headings > 18px or 14px bold'),
  _A11yCheck('Contrast', 'Interactive elements ≥ 3:1 contrast (AA)', 'Buttons, inputs, toggles'),
  // Touch targets
  _A11yCheck('Touch', 'All tap targets ≥ 48×48 dp (WCAG AA)', 'Use ConstrainedBox(min 48dp) on every interactive widget'),
  _A11yCheck('Touch', 'SOS button ≥ 80dp (critical control)', 'Life-safety — must be largest element on dashboard'),
  // Screen reader
  _A11yCheck('Screen reader', 'Every interactive widget has semanticLabel', 'Run TalkBack — each button must announce its action'),
  _A11yCheck('Screen reader', 'SOS button: "Double tap to activate emergency SOS"', 'Critical: screened users must hear the consequence'),
  _A11yCheck('Screen reader', 'Countdown ring announces seconds remaining', 'Use Semantics(liveRegion: true) on countdown text'),
  _A11yCheck('Screen reader', 'Error messages read aloud, not just shown', 'Wrap error Text in Semantics(liveRegion: true)'),
  // Text scaling
  _A11yCheck('Text scaling', 'App usable at 200% system font scale', 'No overflow — all containers use flexible sizing'),
  _A11yCheck('Text scaling', 'No fixed-height containers that clip text', 'Replace SizedBox(height:) with IntrinsicHeight where needed'),
  // Colour independence
  _A11yCheck('Colour', 'Information not conveyed by colour alone', 'Add icon or text label alongside any colour-coded status'),
  _A11yCheck('Colour', 'High contrast mode available in settings', 'ZapColors.hcBackground / hcText applied when enabled'),
  // Focus management
  _A11yCheck('Focus', 'Focus order logical (top → bottom, left → right)', 'Tab through app with keyboard — no jumps'),
  _A11yCheck('Focus', 'Modal dialogs trap focus until dismissed', 'SOS cancel dialog: focus must not escape'),
  // Language
  _A11yCheck('Language', 'All 15 languages display without overflow', 'Hindi + Tamil tested at 200% font scale'),
  _A11yCheck('Language', 'RTL layout correct for Arabic + Urdu', 'Mirror icons, reverse padding, check chart direction'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day138FinalPolishScreen extends ConsumerWidget {
  const Day138FinalPolishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab     = ref.watch(_activeTabProvider);
    final applied = ref.watch(_appliedProvider);
    final allDone = applied.every((a) => a);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 138 · Final Polish'),
        elevation: 0,
        actions: [
          if (allDone)
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
                  child: const Text('4/4 fixes done ✅',
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
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

            const _SectionLabel('SELECT AREA'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) _FixesTab(applied: applied),
            if (tab == 1) const _A11yTab(),
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
          colors: [Color(0xFF12080A), Color(0xFF090406), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 138', const Color(0xFFF97316)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Final Polish', const Color(0xFF8B5CF6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Final Polish\nDay 1 of 2',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'No new features — only fixes. '
            '4 items queued from Day 137 decision. '
            'Plus first half of WCAG 2.1 accessibility audit '
            'required before App Store submission.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('4',    'Bug fixes',      Color(0xFFF97316)),
            _HStat('17',   'A11y checks',    Color(0xFF3B82F6)),
            _HStat('P1+P2','Priority',       Color(0xFF8B5CF6)),
            _HStat('D139', 'Continues',      Color(0xFF9CA3AF)),
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
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
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
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.build_rounded,         Color(0xFFF97316), 'Bug Fixes'),
      (Icons.accessibility_rounded, Color(0xFF3B82F6), 'Accessibility'),
    ];
    return Row(
      children: List.generate(2, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? color : const Color(0xFF6B7280),
                      size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: isActive ? color : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Fixes Tab ──────────────────────────────────────────────────────────────────
class _FixesTab extends ConsumerWidget {
  final List<bool> applied;
  const _FixesTab({required this.applied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneCount = applied.where((a) => a).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: doneCount == 4
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: doneCount == 4
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / 4 fixes applied',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  doneCount == 4
                      ? '✅ All done — run A11y audit'
                      : 'Apply fixes below',
                  style: TextStyle(
                      color: doneCount == 4
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / 4,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  doneCount == 4
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF97316),
                ),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Fix cards
        ..._kFixes.asMap().entries.map((e) {
          final i   = e.key;
          final fix = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _FixCard(
              fix: fix,
              done: applied[i],
              index: i,
              onApply: () async {
                await Future.delayed(const Duration(milliseconds: 600));
                if (!context.mounted) return;
                final updated = List<bool>.from(ref.read(_appliedProvider));
                updated[i] = true;
                ref.read(_appliedProvider.notifier).state = updated;
                // advance demo
                ref.read(_demoFixProvider.notifier).state = -1;
              },
            ),
          );
        }),
      ],
    );
  }
}

class _FixCard extends ConsumerStatefulWidget {
  final _Fix fix;
  final bool done;
  final int  index;
  final VoidCallback onApply;
  const _FixCard({
    required this.fix,
    required this.done,
    required this.index,
    required this.onApply,
  });

  @override
  ConsumerState<_FixCard> createState() => _FixCardState();
}

class _FixCardState extends ConsumerState<_FixCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fix = widget.fix;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.done
            ? const Color(0xFF10B981).withOpacity(0.06)
            : _expanded
                ? fix.color.withOpacity(0.06)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: widget.done
              ? const Color(0xFF10B981).withOpacity(0.35)
              : _expanded
                  ? fix.color.withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              // ID badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.done
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : fix.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: widget.done
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 18)
                      : Icon(fix.icon, color: fix.color, size: 18),
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fix.priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(fix.priority,
                            style: TextStyle(
                                color: fix.priorityColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Text(fix.id,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10)),
                    ]),
                    const SizedBox(height: 2),
                    Text(fix.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('${fix.source}  ·  ${fix.effort}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ],
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 18),
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
                    // Before / After
                    Row(children: [
                      Expanded(
                        child: _halfBox('BEFORE', fix.before,
                            const Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: _halfBox('AFTER', fix.after,
                            const Color(0xFF10B981)),
                      ),
                    ]),
                    const SizedBox(height: ZapSpacing.md),
                    // Code diff
                    _diffBlock(fix.codeFile, fix.codeBefore, fix.codeAfter),
                    const SizedBox(height: ZapSpacing.md),
                    // Apply
                    widget.done
                        ? _statusChip(Icons.check_circle_rounded,
                            const Color(0xFF10B981), '${fix.id} applied ✅')
                        : _actionButton(
                            label: 'Apply ${fix.id}',
                            icon: Icons.build_rounded,
                            color: fix.color,
                            onTap: widget.onApply),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _halfBox(String label, String text, Color color) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: ZapSpacing.xs),
          Text(text,
              style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontSize: 11,
                  height: 1.4)),
        ]),
      );
}

// ── A11y Tab ───────────────────────────────────────────────────────────────────
class _A11yTab extends ConsumerWidget {
  const _A11yTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks   = ref.watch(_a11yProvider);
    final passCount = checks.where((c) => c == true).length;
    final failCount = checks.where((c) => c == false).length;
    final pending   = checks.where((c) => c == null).length;
    final pct       = checks.isEmpty ? 0.0 : passCount / checks.length;

    // Group checks by category
    final categories = <String, List<int>>{};
    for (int i = 0; i < _kA11yChecks.length; i++) {
      final cat = _kA11yChecks[i].category;
      categories.putIfAbsent(cat, () => []).add(i);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: failCount > 0
                ? const Color(0xFFEF4444).withOpacity(0.07)
                : passCount == checks.length
                    ? const Color(0xFF10B981).withOpacity(0.07)
                    : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: failCount > 0
                  ? const Color(0xFFEF4444).withOpacity(0.3)
                  : passCount == checks.length
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(children: [
              _aBox('$passCount', 'Pass ✅', const Color(0xFF10B981)),
              const SizedBox(width: ZapSpacing.sm),
              _aBox('$failCount', 'Fail ❌', const Color(0xFFEF4444)),
              const SizedBox(width: ZapSpacing.sm),
              _aBox('$pending', 'Pending', const Color(0xFF6B7280)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  failCount > 0
                      ? const Color(0xFFEF4444)
                      : pct == 1.0
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              pending == 0 && failCount == 0
                  ? '✅ All ${checks.length} checks passed — WCAG 2.1 AA ready'
                  : pending > 0
                      ? 'Tap each item: pass ✅ or fail ❌'
                      : '$failCount items need fixing before App Store submission',
              style: TextStyle(
                  color: failCount > 0
                      ? const Color(0xFFEF4444)
                      : pending == 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                  fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Checklist by category
        ...categories.entries.map((entry) {
          final cat     = entry.key;
          final indices = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: _A11yCategory(
                category: cat, indices: indices,
                checks: checks, ref: ref),
          );
        }),
      ],
    );
  }

  Widget _aBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _A11yCategory extends StatelessWidget {
  final String category;
  final List<int> indices;
  final List<bool?> checks;
  final WidgetRef ref;
  const _A11yCategory({
    required this.category,
    required this.indices,
    required this.checks,
    required this.ref,
  });

  static const _catColors = {
    'Contrast':     Color(0xFFF59E0B),
    'Touch':        Color(0xFFEF4444),
    'Screen reader':Color(0xFF8B5CF6),
    'Text scaling': Color(0xFF3B82F6),
    'Colour':       Color(0xFF10B981),
    'Focus':        Color(0xFFF97316),
    'Language':     Color(0xFF06B6D4),
  };

  @override
  Widget build(BuildContext context) {
    final color    = _catColors[category] ?? const Color(0xFF9CA3AF);
    final passInCat= indices.where((i) => checks[i] == true).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Category header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall - 1)),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(category,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text('$passInCat/${indices.length}',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
        // Items
        ...indices.asMap().entries.map((e) {
          final ii     = e.key;
          final idx    = e.value;
          final check  = _kA11yChecks[idx];
          final result = checks[idx];
          final isLast = ii == indices.length - 1;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(check.item,
                            style: TextStyle(
                              color: result == false
                                  ? const Color(0xFFEF4444)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                        Text(check.guidance,
                            style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  // Pass/Fail buttons
                  Row(children: [
                    _resultBtn(
                      '✅',
                      result == true,
                      const Color(0xFF10B981),
                      () {
                        final updated = List<bool?>.from(
                            ref.read(_a11yProvider));
                        updated[idx] = true;
                        ref.read(_a11yProvider.notifier).state = updated;
                      },
                    ),
                    const SizedBox(width: ZapSpacing.xs),
                    _resultBtn(
                      '❌',
                      result == false,
                      const Color(0xFFEF4444),
                      () {
                        final updated = List<bool?>.from(
                            ref.read(_a11yProvider));
                        updated[idx] = false;
                        ref.read(_a11yProvider.notifier).state = updated;
                      },
                    ),
                  ]),
                ],
              ),
            ),
            if (!isLast)
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }),
      ]),
    );
  }

  Widget _resultBtn(
      String label, bool selected, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
                : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? color.withOpacity(0.5)
                    : const Color(0xFF2A2A2A)),
          ),
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 16)),
          ),
        ),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _diffBlock(String filename, String before, String after) =>
    Container(
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
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...before.split('\n').map((l) => Text('- $l',
            style: const TextStyle(
                color: Color(0xFFFF7B72),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5))),
        const SizedBox(height: ZapSpacing.xs),
        ...after.split('\n').map((l) => Text('+ $l',
            style: const TextStyle(
                color: Color(0xFF7EE787),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5))),
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
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 14),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
