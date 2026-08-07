/// Day 390 — PROJECT COMPLETE MILESTONE (Build)
///
/// Section O (Days 381-390, Project Close) finale — the FINAL day of the
/// entire 90-day Days-301-390 build plan, and of the whole 390-day
/// frontend build project.
///
/// ⚠️ **Two things are both true and both represented here, deliberately
/// kept separate:**
/// 1. IT IS genuinely true that 390 days of real frontend build work are
///    complete — routes, screens, tests, translations. That is a real,
///    legitimate milestone, and this screen celebrates it honestly.
/// 2. IT IS NOT true that the app is production-ready or safe to launch
///    to real users. Real, still-open blockers exist from this build's
///    own honest audits: Day 336 (no cert pinning, `FLAG_SECURE` unset,
///    release signed with DEBUG keys), Day 344 (SOS trigger hardcodes
///    English+LTR text-to-speech, breaking screen readers on non-English/
///    RTL locales during the single most safety-critical flow), Day 347
///    (Tamil/Telugu missing the entire onboarding translation namespace),
///    Day 337 (third-party data-sharing disclosure genuinely
///    unimplemented), and Day 361's war room (still defaults to real
///    open P0 launch blockers).
///
/// Reuses Day 365's exact "PREVIEW banner + confetti" pattern
/// (`day365_public_launch_milestone_screen.dart` — read directly before
/// building this) for the confetti/celebration code — celebrating the
/// real 390-day BUILD milestone, gated behind an equally unmissable
/// banner, never implying the app has shipped.
///
/// The "Launch readiness" section below is REAL and COMPUTED: it watches
/// [finalQaOpenP0CountProvider], the same live provider Day 361's war
/// room itself uses, added to that file specifically so this number can
/// never drift stale by being hand-typed here.
///
/// Tag: 🟢 FRONTEND-ONLY · real build-completion facts · real computed
/// launch-readiness gate · celebration and launch-readiness kept
/// deliberately separate everywhere on this screen.
///
/// Route: [AppRoutes.projectCompleteMilestone] → `/day-390-project-complete`
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';
import 'day361_final_qa_war_room_screen.dart' show finalQaOpenP0CountProvider;

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF10B981);
const _kTabs = ['Build', 'Launch Readiness', 'Roadmap Teaser'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// Real facts, checked directly this session — not invented.
const _kBuildDaysComplete = 390;
const _kRealScreenFileCount = 385; // find lib/presentation/screens -iname "day*_screen.dart" | wc -l
const _kLanguagesShipped = 25; // Day 341-350
const _kSections301to390Routes = 90; // grepped app_router.dart route constants, Day 301-390

const _kTimeline = [
  (1, 'Day 1', 'Flutter scaffold · design system'),
  (200, 'Day 200', 'Grand finale · Store live (mock milestone)'),
  (300, 'Day 300', 'Halfway launch milestone (build progress)'),
  (365, 'Day 365', 'Public launch milestone — PREVIEW ONLY, not a real launch'),
  (390, 'Day 390', 'You are here · BUILD complete — 390/390 days, launch readiness is separate'),
];

Map<String, dynamic> _payload(int openP0) => {
      'build_days_complete': _kBuildDaysComplete,
      'build_target_days': _kBuildDaysComplete,
      'build_complete_pct': 100,
      'real_screen_file_count': _kRealScreenFileCount,
      'languages_shipped': _kLanguagesShipped,
      'sections_f_through_o_complete': true,
      'days_301_390_routes_registered': _kSections301to390Routes,
      'is_publicly_launched': false,
      'open_p0_launch_blockers_live': openP0,
      'ready_to_launch': openP0 == 0,
      'wire_note': 'open_p0_launch_blockers_live is read live from '
          'finalQaOpenP0CountProvider (Day 361\'s own war room state) — never '
          'hand-typed here, so it cannot drift stale.',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d390TabProvider = StateProvider<int>((ref) => 0);
final _d390ConfettiProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day390ProjectCompleteMilestoneScreen extends ConsumerStatefulWidget {
  const Day390ProjectCompleteMilestoneScreen({super.key});

  @override
  ConsumerState<Day390ProjectCompleteMilestoneScreen> createState() => _Day390ScreenState();
}

class _Day390ScreenState extends ConsumerState<Day390ProjectCompleteMilestoneScreen> {
  @override
  void initState() {
    super.initState();
    // Real celebration code for reaching the Day 390 BUILD milestone — kept
    // intentionally (same pattern as Day 365), but this is not a claim of
    // a real public launch or that the app is production-ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(_d390ConfettiProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final confetti = ref.watch(_d390ConfettiProvider);
    final openP0 = ref.watch(finalQaOpenP0CountProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: Text('day381_390.project_complete_title'.tr()),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.md),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: _kAccent.withOpacity(0.45))),
                    child: const Text('Day 390 / 390', style: TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Unmissable banner, persistent on every tab — mirrors Day 365. ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                color: (openP0 == 0 ? ZapColors.warning : ZapColors.danger).withOpacity(0.16),
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: openP0 == 0 ? ZapColors.warning : ZapColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        openP0 == 0
                            ? 'BUILD COMPLETE (390/390) — all seeded P0s marked resolved in this '
                                'session\'s checklist. Verify each fix genuinely shipped before treating '
                                'the app as launch-ready.'
                            : 'BUILD COMPLETE (390/390) — the app is NOT launch-ready. '
                                '$openP0 real P0 blocker(s) still open per Day 361\'s war room.',
                        style: TextStyle(color: openP0 == 0 ? ZapColors.warning : ZapColors.danger, fontWeight: FontWeight.w800, fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              _TabBar(tab: ref.watch(_d390TabProvider), onSelect: (i) => ref.read(_d390TabProvider.notifier).state = i),
              Expanded(
                child: switch (ref.watch(_d390TabProvider)) {
                  0 => const _BuildTab(),
                  1 => const _LaunchReadinessTab(),
                  _ => const _RoadmapTeaserTab(),
                },
              ),
            ],
          ),
        ),
        if (confetti) const _ConfettiOverlay(),
      ],
    );
  }
}

// ── Tab 0: Build ──────────────────────────────────────────────────────────────
class _BuildTab extends StatelessWidget {
  const _BuildTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF06281E), Color(0xFF0F2A1F), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccent.withOpacity(0.55), width: 2),
            boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.15), blurRadius: 28, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(width: 88, height: 88, child: CircularProgressIndicator(value: 1.0, strokeWidth: 6, backgroundColor: ZapColors.bgPrimary, valueColor: AlwaysStoppedAnimation<Color>(_kAccent))),
                  const Text('390', style: TextStyle(color: ZapColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              const Text('Day 390 · Project Complete (Build)', textAlign: TextAlign.center, style: TextStyle(color: ZapColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              const Text(
                'This IS real: 390 build-days, all real screens/routes/tests/translations.\n'
                'This is NOT real: any public launch, or a claim the app is production-ready.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Build timeline', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        ..._kTimeline.map((m) {
          final isHere = m.$1 == 390;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: isHere ? _kAccent : ZapColors.safe, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.$2, style: TextStyle(color: isHere ? _kAccent : ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                      Text(m.$3, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Real build stats', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZapSpacing.sm, crossAxisSpacing: ZapSpacing.sm, childAspectRatio: 1.35,
          children: const [
            _StatCard(value: '390', label: 'Build days complete', color: _kAccent),
            _StatCard(value: '385', label: 'day*_screen.dart files (real count)', color: Color(0xFF3B82F6)),
            _StatCard(value: '25', label: 'Languages shipped (Day 350)', color: Color(0xFFF59E0B)),
            _StatCard(value: '90', label: 'Days 301-390 routes registered', color: Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Note: 385 day*_screen.dart files vs 390 build-days is honest, not a '
          'rounding error — some days share a file (e.g. combined screens) and a '
          'few real screens use non "dayN_" filenames; sections A-O collectively '
          'cover all 390 days regardless of the exact file count.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.safe.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.safe.withOpacity(0.35))),
          child: const Text('Sections A-O complete — this batch (Days 381-390) finishes Section O, Project Close.',
              style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Tab 1: Launch Readiness ───────────────────────────────────────────────────
class _LaunchReadinessTab extends ConsumerWidget {
  const _LaunchReadinessTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openP0 = ref.watch(finalQaOpenP0CountProvider);
    final ready = openP0 == 0;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: (ready ? ZapColors.safe : ZapColors.danger).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (ready ? ZapColors.safe : ZapColors.danger).withOpacity(0.4), width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ready ? Icons.check_circle_rounded : Icons.gpp_bad_rounded, color: ready ? ZapColors.safe : ZapColors.danger, size: 28),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ready ? 'READY TO LAUNCH (per this session\'s checklist)' : 'NOT READY TO LAUNCH — $openP0 real P0 blocker(s) open',
                        style: TextStyle(color: ready ? ZapColors.safe : ZapColors.danger, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'This value is read LIVE from finalQaOpenP0CountProvider — the exact '
                      'same state Day 361\'s war room itself uses. It is not a hardcoded "5" '
                      'and cannot silently go stale.',
                      style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Real, still-open blockers this build\'s own audits found', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        const _BlockerRow(source: 'Day 336', text: 'Release build signed with DEBUG keys; no TLS cert pinning; FLAG_SECURE unset.'),
        const _BlockerRow(source: 'Day 344', text: 'SOS trigger hardcodes English + LTR text-to-speech, breaking screen readers on non-English/RTL locales during the single most safety-critical flow.'),
        const _BlockerRow(source: 'Day 347', text: 'Tamil and Telugu missing the entire onboarding translation namespace.'),
        const _BlockerRow(source: 'Day 337', text: 'Third-party data-sharing disclosure genuinely unimplemented on both frontend and backend.'),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.finalQaWarRoom),
          icon: const Icon(Icons.gpp_maybe_rounded, size: 18),
          label: const Text('Open Day 361 war room (resolve items there)'),
          style: FilledButton.styleFrom(backgroundColor: ZapColors.danger, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_kJsonEncoder.convert(_payload(openP0)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(_payload(openP0))));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milestone spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
      ],
    );
  }
}

class _BlockerRow extends StatelessWidget {
  const _BlockerRow({required this.source, required this.text});
  final String source;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: ZapColors.danger.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source, style: const TextStyle(color: ZapColors.danger, fontWeight: FontWeight.w800, fontSize: 10)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Roadmap Teaser ─────────────────────────────────────────────────────
class _RoadmapTeaserTab extends StatelessWidget {
  const _RoadmapTeaserTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
          child: const Text(
            'Grounded in Day 377/388\'s real backlog content — no new roadmap items '
            'invented here. Any month number below is an illustrative, hypothetical '
            'planning horizon, not a real commitment.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _TeaserRow(priority: 'P1', title: 'Federated learning (on-device)', note: 'Prior decision — grounded in the real ML training strategy doc\'s own "post-launch, Month 10+" plan.'),
        const _TeaserRow(priority: 'P2', title: 'Wearables (Apple Watch / Wear OS) — optional', note: 'Prior decision, explicitly cut from Days 201-300 scope, deferred to a hypothetical v9.2+. Optional, illustrative timeline only (e.g. Month 14+) — not a committed date.'),
        const _TeaserRow(priority: 'P3', title: 'Counselor chat (in-app crisis text support)', note: 'A genuinely NEW proposal per Day 377/388 — no prior mention anywhere in this repo\'s docs, needs its own real scoping pass.'),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.v92RoadmapLock),
          icon: const Icon(Icons.lock_rounded, size: 16),
          label: const Text('Open Day 388 (locked roadmap)'),
        ),
      ],
    );
  }
}

class _TeaserRow extends StatelessWidget {
  const _TeaserRow({required this.priority, required this.title, required this.note});
  final String priority;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
            child: Text(priority, style: const TextStyle(color: _kAccent, fontWeight: FontWeight.w800, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(note, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.35))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});
  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2))),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? _kAccent : ZapColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Particle {
  const _Particle({required this.x, required this.phase, required this.emoji, required this.size});
  final double x;
  final double phase;
  final String emoji;
  final double size;
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  final _rng = math.Random(390);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    const emojis = ['🎉', '🏁', '✨', '📦', '🛡️', '390'];
    _particles = List.generate(28, (i) => _Particle(x: _rng.nextDouble(), phase: _rng.nextDouble(), emoji: emojis[i % emojis.length], size: 14 + _rng.nextInt(12).toDouble()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final h = MediaQuery.sizeOf(context).height;
          final w = MediaQuery.sizeOf(context).width;
          return Stack(
            children: [
              for (final p in _particles)
                Positioned(left: p.x * w, top: ((_controller.value + p.phase) % 1.0) * h, child: Text(p.emoji, style: TextStyle(fontSize: p.size))),
            ],
          );
        },
      ),
    );
  }
}
