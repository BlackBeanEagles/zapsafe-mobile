/// Day 133 — Simplify Onboarding (Part 1)
///
/// Beta feedback: 34% of new users abandon onboarding at step 3.
/// Current flow has 7 steps taking ~5 minutes. Problems:
///   • Step 3 "Device permissions" shows 5 permissions at once — confusing
///   • Step 4 "Emergency contacts" requires adding 2 minimum — blocker
///   • Step 5 "Medical profile" feels invasive before trust is built
///   • Step 6 "Detection calibration" is too technical for new users
///   • Step 7 "Review" is redundant if earlier steps were clear
///
/// Day 133: audit → redesign → build new 4-step skeleton.
/// Day 134: permission rationale + experienced-user skip + timing test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider      = StateProvider<int>((ref) => 0);
final _newStepProvider        = StateProvider<int>((ref) => 0);
final _auditExpandedProvider  = StateProvider<int?>((ref) => null);
final _demoStepProvider       = StateProvider<int>((ref) => 0);
final _demoStartedProvider    = StateProvider<bool>((ref) => false);

// ── Data ───────────────────────────────────────────────────────────────────────
class _OldStep {
  final int    number;
  final String title;
  final double dropOffPct;
  final Color  dropColor;
  final String problem;
  final String action; // keep / merge / cut
  final Color  actionColor;
  const _OldStep({
    required this.number,
    required this.title,
    required this.dropOffPct,
    required this.dropColor,
    required this.problem,
    required this.action,
    required this.actionColor,
  });
}

const _kOldSteps = [
  _OldStep(
    number: 1,
    title: 'Welcome & value prop',
    dropOffPct: 3,
    dropColor: Color(0xFF10B981),
    problem: 'Low drop-off — users excited to continue.',
    action: 'KEEP',
    actionColor: Color(0xFF10B981),
  ),
  _OldStep(
    number: 2,
    title: 'Phone number + OTP',
    dropOffPct: 8,
    dropColor: Color(0xFF10B981),
    problem: 'Minor friction — phone entry is expected.',
    action: 'KEEP',
    actionColor: Color(0xFF10B981),
  ),
  _OldStep(
    number: 3,
    title: 'Device permissions (5 at once)',
    dropOffPct: 34,
    dropColor: Color(0xFFEF4444),
    problem: 'Highest drop-off. Showing all 5 permissions at once with '
        'no explanation is alarming. Users deny and quit.',
    action: 'REDESIGN → inline with first use',
    actionColor: Color(0xFFF59E0B),
  ),
  _OldStep(
    number: 4,
    title: 'Emergency contacts (2 required)',
    dropOffPct: 21,
    dropColor: Color(0xFFEF4444),
    problem: 'Requiring 2 contacts before seeing the app is a hard '
        'blocker. Users haven\'t built enough trust yet.',
    action: 'MOVE → post-onboarding, 1 optional',
    actionColor: Color(0xFFF97316),
  ),
  _OldStep(
    number: 5,
    title: 'Medical profile',
    dropOffPct: 12,
    dropColor: Color(0xFFF59E0B),
    problem: 'Feels invasive on first launch. '
        'Users don\'t understand why the app needs medical info.',
    action: 'MOVE → Settings, prompted later',
    actionColor: Color(0xFFF97316),
  ),
  _OldStep(
    number: 6,
    title: 'Detection calibration',
    dropOffPct: 9,
    dropColor: Color(0xFFF59E0B),
    problem: 'Too technical. "Speak normally for 30s" is confusing '
        'for new users who just want protection.',
    action: 'CUT → run silently in background',
    actionColor: Color(0xFFEF4444),
  ),
  _OldStep(
    number: 7,
    title: 'Review & confirm',
    dropOffPct: 4,
    dropColor: Color(0xFF10B981),
    problem: 'Redundant if earlier steps are clear.',
    action: 'CUT → merge into Step 4',
    actionColor: Color(0xFFEF4444),
  ),
];

class _NewStep {
  final int    number;
  final String title;
  final String subtitle;
  final Color  color;
  final IconData icon;
  final String duration;
  final List<String> contents;
  final List<String> removed;
  const _NewStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.duration,
    required this.contents,
    required this.removed,
  });
}

const _kNewSteps = [
  _NewStep(
    number: 1,
    title: 'Welcome',
    subtitle: 'Value prop + phone number OTP',
    color: Color(0xFF10B981),
    icon: Icons.waving_hand_rounded,
    duration: '30s',
    contents: [
      'Hero: "Your safety, always on"',
      'Two-line value summary',
      'Phone entry + OTP verify (merged from old step 2)',
      '"Get started" CTA',
    ],
    removed: [
      'Separate OTP screen — now inline',
    ],
  ),
  _NewStep(
    number: 2,
    title: 'One permission',
    subtitle: 'Microphone only — explained in context',
    color: Color(0xFF3B82F6),
    icon: Icons.mic_rounded,
    duration: '20s',
    contents: [
      'Single permission: Microphone',
      'Plain-language: "ZapSafe listens for distress to protect you"',
      '"Allow" button → system dialog',
      'Other permissions deferred to first use',
    ],
    removed: [
      'Location (asked when Journey mode first used)',
      'Camera (asked when evidence capture first used)',
      'Contacts (asked when first contact added)',
      'Notifications (asked after first SOS test)',
    ],
  ),
  _NewStep(
    number: 3,
    title: 'First contact',
    subtitle: 'Optional — 1 is enough to start',
    color: Color(0xFFF59E0B),
    icon: Icons.person_add_rounded,
    duration: '40s',
    contents: [
      'Add one emergency contact (optional)',
      '"I\'ll add contacts later" skip option',
      'Contact card preview showing what they receive',
      'Clearly optional — no minimum requirement',
    ],
    removed: [
      'Minimum 2 contacts requirement',
      'Medical profile (moved to Settings)',
      'Contact verification (background, not blocking)',
    ],
  ),
  _NewStep(
    number: 4,
    title: 'You\'re protected',
    subtitle: 'Dashboard preview + quick SOS test',
    color: Color(0xFF8B5CF6),
    icon: Icons.shield_rounded,
    duration: '20s',
    contents: [
      'Protection score shown (starts at 60)',
      '"Test SOS" optional drill button',
      'Detection calibration runs silently in background',
      '"Start protecting me" → goes to Dashboard',
    ],
    removed: [
      'Detection calibration wizard (now silent)',
      'Review / confirm step (redundant)',
    ],
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day133OnboardingSimplifyScreen extends ConsumerWidget {
  const Day133OnboardingSimplifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 133 · Simplify Onboarding'),
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

            if (tab == 0) const _AuditTab(),
            if (tab == 1) const _RedesignTab(),
            if (tab == 2) const _DemoTab(),
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
          colors: [Color(0xFF0D1520), Color(0xFF070C12), Color(0xFF0A0A0A)],
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
            _badge('⚡  BETA  ·  DAY 133', const Color(0xFF3B82F6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('34% abandon at step 3', const Color(0xFFEF4444)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Simplify\nOnboarding',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '34% of users abandon at step 3 (permissions). '
            'Total time is ~5 min — too long. '
            'Redesigning 7 steps → 4, target < 2 min.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('7 → 4',  'Steps',          Color(0xFF3B82F6)),
            _HStat('5 min',  'Before',         Color(0xFFEF4444)),
            _HStat('→ 2 min','Target',         Color(0xFF10B981)),
            _HStat('34%',    'Abandon rate',   Color(0xFFF97316)),
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
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
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
      (Icons.bar_chart_rounded,   Color(0xFFEF4444), 'Audit'),
      (Icons.design_services_rounded, Color(0xFF3B82F6), 'Redesign'),
      (Icons.play_circle_rounded, Color(0xFF10B981), 'Demo'),
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
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280),
                    size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Audit Tab ──────────────────────────────────────────────────────────────────
class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_auditExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop-off funnel summary
        const _SectionLabel('DROP-OFF FUNNEL  ·  CURRENT 7 STEPS'),
        const SizedBox(height: ZapSpacing.md),
        const _DropOffFunnel(),
        const SizedBox(height: ZapSpacing.xl),

        // Step audit cards
        const _SectionLabel('STEP AUDIT  ·  TAP TO SEE VERDICT'),
        const SizedBox(height: ZapSpacing.md),
        ..._kOldSteps.map((step) {
          final isOpen = expanded == step.number;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: GestureDetector(
              onTap: () => ref
                  .read(_auditExpandedProvider.notifier)
                  .state = isOpen ? null : step.number,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isOpen
                      ? step.actionColor.withOpacity(0.07)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                    color: isOpen
                        ? step.actionColor.withOpacity(0.4)
                        : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(ZapSpacing.md),
                    child: Row(children: [
                      // Step number
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: step.dropColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${step.number}',
                              style: TextStyle(
                                  color: step.dropColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Text(step.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      // Drop-off badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: step.dropColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '−${step.dropOffPct}%',
                          style: TextStyle(
                              color: step.dropColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Icon(
                        isOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF4B5563), size: 18),
                    ]),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: isOpen
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                                ZapSpacing.md, 0,
                                ZapSpacing.md, ZapSpacing.md),
                            child: Column(children: [
                              const Divider(height: ZapSpacing.md,
                                  color: Color(0xFF2A2A2A)),
                              // Problem
                              _auditRow(Icons.warning_amber_rounded,
                                  const Color(0xFFEF4444),
                                  'Problem', step.problem),
                              const SizedBox(height: ZapSpacing.sm),
                              // Action
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(ZapSpacing.sm),
                                decoration: BoxDecoration(
                                  color:
                                      step.actionColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                      ZapSpacing.radiusSmall),
                                  border: Border.all(
                                      color: step.actionColor
                                          .withOpacity(0.35)),
                                ),
                                child: Row(children: [
                                  Icon(
                                    step.action.startsWith('KEEP')
                                        ? Icons.check_circle_rounded
                                        : step.action.startsWith('CUT')
                                            ? Icons.delete_rounded
                                            : Icons.edit_rounded,
                                    color: step.actionColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: ZapSpacing.sm),
                                  Expanded(
                                    child: Text(step.action,
                                        style: TextStyle(
                                          color: step.actionColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        )),
                                  ),
                                ]),
                              ),
                            ]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DropOffFunnel extends StatelessWidget {
  const _DropOffFunnel();

  @override
  Widget build(BuildContext context) {
    // Cumulative completion rates
    final completes = <double>[];
    double rate = 100;
    for (final step in _kOldSteps) {
      rate -= step.dropOffPct;
      completes.add(rate.clamp(0, 100));
    }

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('100% start',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
            Text('${completes.last.round()}% complete',
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 11)),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: completes.asMap().entries.map((e) {
            final i   = e.key;
            final pct = e.value;
            final h   = (pct / 100 * 80).clamp(4.0, 80.0);
            final col = pct > 80
                ? const Color(0xFF10B981)
                : pct > 60
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${pct.round()}%',
                        style: TextStyle(
                            color: col, fontSize: 8,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: col.withOpacity(0.7),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text('S${i + 1}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 8),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: const Text(
            'Only 9% of users who start onboarding complete it. '
            'S3 (permissions) is the cliff — 34% abandon here.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5),
          ),
        ),
      ]),
    );
  }
}

Widget _auditRow(IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label: ',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ),
    ]);

// ── Redesign Tab ───────────────────────────────────────────────────────────────
class _RedesignTab extends ConsumerWidget {
  const _RedesignTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStep = ref.watch(_newStepProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mapping
        const _SectionLabel('7 → 4 MAPPING'),
        const SizedBox(height: ZapSpacing.md),
        const _MappingDiagram(),
        const SizedBox(height: ZapSpacing.xl),

        // New step cards
        const _SectionLabel('NEW 4-STEP FLOW  ·  TAP TO INSPECT'),
        const SizedBox(height: ZapSpacing.md),

        // Step tabs
        Row(
          children: List.generate(4, (i) {
            final step     = _kNewSteps[i];
            final isActive = i == activeStep;
            return Expanded(
              child: GestureDetector(
                onTap: () => ref
                    .read(_newStepProvider.notifier)
                    .state = i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? step.color.withOpacity(0.12)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(
                        ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: isActive
                          ? step.color.withOpacity(0.5)
                          : const Color(0xFF2A2A2A),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Icon(step.icon,
                        color: isActive
                            ? step.color
                            : const Color(0xFF6B7280),
                        size: 18),
                    const SizedBox(height: ZapSpacing.xs),
                    Text('Step ${step.number}',
                        style: TextStyle(
                            color: isActive
                                ? step.color
                                : const Color(0xFF6B7280),
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400)),
                    Text(step.duration,
                        style: const TextStyle(
                            color: Color(0xFF4B5563), fontSize: 8)),
                  ]),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.md),

        // Active step detail
        _NewStepCard(step: _kNewSteps[activeStep]),
        const SizedBox(height: ZapSpacing.xl),

        // Time comparison
        const _SectionLabel('TIME COMPARISON'),
        const SizedBox(height: ZapSpacing.md),
        const _TimeComparison(),
      ],
    );
  }
}

class _MappingDiagram extends StatelessWidget {
  const _MappingDiagram();

  @override
  Widget build(BuildContext context) {
    const mappings = [
      // (old steps merged, new step label, new color)
      ('S1 + S2', 'Step 1 · Welcome',     Color(0xFF10B981)),
      ('S3',      'Step 2 · Permission',  Color(0xFF3B82F6)),
      ('S4 + S5', 'Step 3 · Contact',     Color(0xFFF59E0B)),
      ('S7',      'Step 4 · Protected',   Color(0xFF8B5CF6)),
      ('S6',      'CUT (silent BG)',       Color(0xFF4B5563)),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: mappings.map((m) {
          final (old, newStep, color) = m;
          final isCut = newStep.startsWith('CUT');
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(old,
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  isCut
                      ? Icons.remove_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  color: isCut
                      ? const Color(0xFF4B5563)
                      : color,
                  size: 16,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(newStep,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _NewStepCard extends StatelessWidget {
  final _NewStep step;
  const _NewStepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: step.color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: step.color.withOpacity(0.35)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(step.icon, color: step.color, size: 22),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step ${step.number} · ${step.title}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(step.subtitle,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(step.duration,
                  style: TextStyle(
                      color: step.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        // Contents
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CONTAINS',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: ZapSpacing.sm),
              ...step.contents.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded,
                            color: step.color, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c,
                              style: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 12,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  )),
              if (step.removed.isNotEmpty) ...[
                const SizedBox(height: ZapSpacing.md),
                const Text('REMOVED FROM HERE',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: ZapSpacing.sm),
                ...step.removed.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.remove_circle_outline_rounded,
                              color: Color(0xFF4B5563), size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(r,
                                style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 11,
                                    height: 1.4,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFF4B5563))),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _TimeComparison extends StatelessWidget {
  const _TimeComparison();

  @override
  Widget build(BuildContext context) {
    const steps = [
      // (label, old sec, new sec)
      ('Step 1 (Welcome + OTP)',     90, 30),
      ('Step 2 (Permissions)',       120, 20),
      ('Step 3 (Contacts + Medical)',150, 40),
      ('Step 4 (Calibration/Review)', 60, 20),
      ('Removed steps',              80,  0),
    ];
    const oldTotal = 500;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(children: [
          _timeBox('5 min 0s', 'Before', const Color(0xFFEF4444)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF4B5563), size: 20),
          ),
          _timeBox('1 min 50s', 'After', const Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        ...steps.map((s) {
          final (label, oldSec, newSec) = s;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
                const SizedBox(height: ZapSpacing.xs),
                Row(children: [
                  Expanded(
                    flex: oldSec,
                    child: Container(
                      height: 12,
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                    ),
                  ),
                  Expanded(
                    flex: oldTotal - oldSec,
                    child: const SizedBox(height: ZapSpacing.md),
                  ),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    flex: newSec,
                    child: Container(
                      height: 12,
                      color: const Color(0xFF10B981).withOpacity(0.6),
                    ),
                  ),
                  Expanded(
                    flex: oldTotal - newSec,
                    child: const SizedBox(height: ZapSpacing.md),
                  ),
                ]),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Row(children: [
          _legend(const Color(0xFFEF4444).withOpacity(0.4), 'Before'),
          const SizedBox(width: ZapSpacing.md),
          _legend(const Color(0xFF10B981).withOpacity(0.6), 'After'),
        ]),
      ]),
    );
  }

  Widget _timeBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 10)),
          ]),
        ),
      );

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: ZapSpacing.xs),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 10)),
      ]);
}

// ── Demo Tab ───────────────────────────────────────────────────────────────────
class _DemoTab extends ConsumerWidget {
  const _DemoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step    = ref.watch(_demoStepProvider);
    final started = ref.watch(_demoStartedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.play_circle_rounded,
          color: const Color(0xFF10B981),
          text: 'Walk through the new 4-step onboarding. '
              'Each step shows the actual screen layout and '
              'what the user sees.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Progress dots
        if (started)
          Row(
            children: List.generate(4, (i) {
              final isActive   = i == step;
              final isComplete = i < step;
              final stepData   = _kNewSteps[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => ref
                      .read(_demoStepProvider.notifier)
                      .state = i,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isComplete || isActive
                            ? stepData.color
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(stepData.duration,
                        style: TextStyle(
                            color: isActive
                                ? stepData.color
                                : const Color(0xFF4B5563),
                            fontSize: 8)),
                  ]),
                ),
              );
            }),
          ),
        const SizedBox(height: ZapSpacing.md),

        // Screen mockup
        if (!started)
          _actionButton(
            label: 'Start onboarding demo',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF10B981),
            onTap: () {
              ref.read(_demoStartedProvider.notifier).state = true;
              ref.read(_demoStepProvider.notifier).state    = 0;
            },
          )
        else
          _OnboardingMockup(
            step: _kNewSteps[step],
            onNext: step < 3
                ? () => ref
                    .read(_demoStepProvider.notifier)
                    .state = step + 1
                : null,
            onBack: step > 0
                ? () => ref
                    .read(_demoStepProvider.notifier)
                    .state = step - 1
                : null,
            onReset: () {
              ref.read(_demoStartedProvider.notifier).state = false;
              ref.read(_demoStepProvider.notifier).state    = 0;
            },
          ),
      ],
    );
  }
}

class _OnboardingMockup extends StatelessWidget {
  final _NewStep step;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback  onReset;
  const _OnboardingMockup({
    required this.step,
    required this.onNext,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = onNext == null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: step.color.withOpacity(0.4), width: 2),
      ),
      child: Column(children: [
        // Mock status bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: step.color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radius - 2)),
          ),
          child: Row(children: [
            Text('Step ${step.number} / 4',
                style: TextStyle(
                    color: step.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(step.duration,
                style: TextStyle(
                    color: step.color, fontSize: 10)),
          ]),
        ),

        // Screen content
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.xl),
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: step.color.withOpacity(0.4), width: 2),
              ),
              child: Icon(step.icon, color: step.color, size: 36),
            ),
            const SizedBox(height: ZapSpacing.lg),
            Text(step.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            Text(step.subtitle,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.xl),
            // Content bullets as preview chips
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center,
              children: step.contents.map((c) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: step.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: step.color.withOpacity(0.25)),
                    ),
                    child: Text(
                      c.length > 30 ? '${c.substring(0, 28)}…' : c,
                      style: TextStyle(
                          color: step.color.withOpacity(0.9),
                          fontSize: 10),
                    ),
                  )).toList(),
            ),
          ]),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.lg),
          child: Row(children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.lg, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(
                        ZapSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Text('Back',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 13)),
                ),
              )
            else
              const SizedBox.shrink(),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: GestureDetector(
                onTap: isLast ? onReset : onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [step.color, step.color.withOpacity(0.8)]),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    boxShadow: [
                      BoxShadow(
                          color: step.color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isLast ? 'Start over ↺' : 'Continue →',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _infoBox({
  required IconData icon,
  required Color color,
  required String text,
}) =>
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
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
