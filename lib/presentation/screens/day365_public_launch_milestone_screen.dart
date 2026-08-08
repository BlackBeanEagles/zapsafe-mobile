/// Day 365 — PUBLIC LAUNCH MILESTONE (PREVIEW)
///
/// Section L (Days 361-365, Public Launch Week) finale.
///
/// ⚠️ THE APP HAS NOT ACTUALLY LAUNCHED. It is not live on any app store.
/// There are no real users, no real app store reviews, no real crash-free
/// rate, no real DAU. Real, unresolved launch blockers exist right now —
/// see Day 361's war room (5 open P0s: debug-signed release keys, no cert
/// pinning, FLAG_SECURE unset, SOS trigger RTL/screen-reader bug, ta/te
/// onboarding gap). This screen is an unmissable PREVIEW of what the real
/// Day 365 celebration will show once launch actually happens — it must
/// never be mistaken for a claim that it already did.
///
/// What IS real here: reaching Day 365 of this build project genuinely
/// happened (365 build-days, ~365 screens across the whole project so
/// far), the 25-language milestone (Day 350) is real, and the project's
/// build target is genuinely 390 days. What is NOT real: any live user,
/// review, country rollout, or launch event. "Countries live" is honestly
/// 0, not a fabricated number.
///
/// The confetti + haptic celebration code is kept — it is the real Day 365
/// deliverable for whenever launch genuinely happens — but it is gated
/// behind the preview banner above and celebrates reaching this BUILD
/// milestone, not a real public launch.
///
/// Tag: 🟢 FRONTEND-ONLY · PREVIEW gated · no real launch claimed anywhere.
///
/// Route: [AppRoutes.publicLaunchMilestone] → `/day-365-public-launch`
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

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Launch', 'Live Stats', 'Thank You'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kTimeline = [
  (1, 'Day 1', 'Flutter scaffold · design system'),
  (100, 'Day 100', '67 screens · Month 3 milestone'),
  (200, 'Day 200', 'Grand finale · Store live (mock milestone)'),
  (300, 'Day 300', 'Halfway launch milestone (build progress)'),
  (365, 'Day 365', 'You are here · build milestone, NOT a real public launch'),
];

// Real numbers, all clearly build-progress facts, not launch facts.
const _kRealStats = [
  ('365', 'Build days completed', Color(0xFFF59E0B)),
  ('390', 'Total build target (days)', Color(0xFF3B82F6)),
  ('25', 'Languages shipped (Day 350)', Color(0xFF10B981)),
  ('5', 'Open P0 blockers (Day 361)', ZapColors.danger),
];

Map<String, dynamic> _milestonePayload() => {
      'endpoint': 'NONE — no live launch telemetry exists',
      'build_days_complete': 365,
      'build_target_days': 390,
      'languages_shipped': 25,
      'is_publicly_launched': false,
      'countries_live': 0,
      'real_users': 0,
      'real_app_store_reviews': 0,
      'open_p0_blockers': 5,
      'wire_note': 'PREVIEW screen — every "live" number is honestly zero '
          'because no real launch has occurred',
    };

String _shareMessageDraft() => '''
🛡️ ZapSafe — Day 365 build milestone (DRAFT — not yet posted)

365 days of building. 25 languages. Sections A-L complete on the build
timeline. Public launch is still pending real go-live — 5 known
blockers being resolved first (see our own war room).

This message has not been shared anywhere. It is a draft only.

#ZapSafe #BuildInPublic
''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d365TabProvider = StateProvider<int>((ref) => 0);
final _d365ConfettiProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day365PublicLaunchMilestoneScreen extends ConsumerStatefulWidget {
  const Day365PublicLaunchMilestoneScreen({super.key});

  @override
  ConsumerState<Day365PublicLaunchMilestoneScreen> createState() => _Day365PublicLaunchMilestoneScreenState();
}

class _Day365PublicLaunchMilestoneScreenState extends ConsumerState<Day365PublicLaunchMilestoneScreen> {
  @override
  void initState() {
    super.initState();
    // Real celebration code for reaching the Day 365 BUILD milestone — kept
    // intentionally, but this is not a claim of a real public launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(_d365ConfettiProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final confetti = ref.watch(_d365ConfettiProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: ZapColors.bgPrimary,
          appBar: AppBar(
            title: Text('day361_370.public_launch_title'.tr()),
            actions: [
              IconButton(
                tooltip: 'Confetti',
                onPressed: () => ref.read(_d365ConfettiProvider.notifier).state = !confetti,
                icon: Icon(confetti ? Icons.celebration_rounded : Icons.celebration_outlined, color: confetti ? _kAccent : ZapColors.textMuted),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Unmissable preview banner — persistent, every tab. ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                color: ZapColors.danger.withOpacity(0.16),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: ZapColors.danger, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PREVIEW ONLY — public launch has NOT occurred. See Day 336/344/347 '
                        'for real open blockers.',
                        style: TextStyle(color: ZapColors.danger, fontWeight: FontWeight.w800, fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              _TabBar(tab: ref.watch(_d365TabProvider), onSelect: (i) => ref.read(_d365TabProvider.notifier).state = i),
              Expanded(
                child: switch (ref.watch(_d365TabProvider)) {
                  0 => const _LaunchTab(),
                  1 => const _LiveStatsTab(),
                  _ => const _ThankYouTab(),
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

// ── Tab 0: Launch ─────────────────────────────────────────────────────────────
class _LaunchTab extends StatelessWidget {
  const _LaunchTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2A1F08), Color(0xFF0F2A1F), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccent.withOpacity(0.55), width: 2),
            boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.15), blurRadius: 28, offset: const Offset(0, 10))],
          ),
          child: const Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(value: 365 / 390, strokeWidth: 6, backgroundColor: ZapColors.bgPrimary, valueColor: AlwaysStoppedAnimation<Color>(_kAccent)),
                  ),
                  Text('365', style: TextStyle(color: ZapColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              SizedBox(height: ZapSpacing.md),
              Text('Day 365 · Public Launch Milestone (Preview)', textAlign: TextAlign.center, style: TextStyle(color: ZapColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
              SizedBox(height: 8),
              Text(
                'This IS real: 365 build-days, 25 languages, Section L complete.\n'
                'This is NOT real: any public launch, live user, or store review.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Build timeline', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text('Day 1 → 100 → 200 → 300 → 365', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
        const SizedBox(height: ZapSpacing.sm),
        ..._kTimeline.map((m) {
          final isHere = m.$1 == 365;
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
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.danger.withOpacity(0.35))),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gpp_bad_rounded, color: ZapColors.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Real blockers still open per Day 361\'s war room: debug-signed '
                  'release keys, no TLS cert pinning, FLAG_SECURE unset, SOS '
                  'trigger RTL/screen-reader bug, Tamil/Telugu onboarding gap. '
                  'None of these are fixed by reaching Day 365 of the build.',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.finalQaWarRoom),
          icon: const Icon(Icons.gpp_maybe_rounded, size: 16),
          label: const Text('Open Day 361 war room'),
        ),
      ],
    );
  }
}

// ── Tab 1: Live Stats ─────────────────────────────────────────────────────────
class _LiveStatsTab extends StatelessWidget {
  const _LiveStatsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
          child: const Text(
            'This tab is called "Live Stats" for the real Day 365, once launch '
            'happens. Right now there is nothing live to show — every number '
            'below is a real build-progress fact, and "countries live" is '
            'honestly 0, not fabricated.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Real build stats', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ZapSpacing.sm,
          crossAxisSpacing: ZapSpacing.sm,
          childAspectRatio: 1.35,
          children: _kRealStats.map((s) => _StatCard(value: s.$1, label: s.$2, color: s.$3)).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Honest launch stats (not fabricated)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ZapColors.border)),
          child: const Column(
            children: [
              _HonestRow(label: 'Countries live', value: '0 — not yet launched'),
              _HonestRow(label: 'Real users', value: '0'),
              _HonestRow(label: 'Real app store reviews', value: '0'),
              _HonestRow(label: 'Real crash-free %', value: 'No data — see Day 338'),
              _HonestRow(label: 'Real DAU', value: 'No data — no live app'),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_kJsonEncoder.convert(_milestonePayload()), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
        ),
      ],
    );
  }
}

class _HonestRow extends StatelessWidget {
  const _HonestRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12))),
          Text(value, style: const TextStyle(color: ZapColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

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

// ── Tab 2: Thank You ──────────────────────────────────────────────────────────
class _ThankYouTab extends StatelessWidget {
  const _ThankYouTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kAccent.withOpacity(0.4))),
          child: const Column(
            children: [
              Icon(Icons.favorite_rounded, color: _kAccent, size: 32),
              SizedBox(height: 8),
              Text('Thank you for 365 days of building.', textAlign: TextAlign.center, style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'This "Thank You" tab will mean something different on the real '
                'Day 365 — thanking actual users. For now it thanks whoever has '
                'been building this project for reaching a genuine 365-day '
                'construction milestone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Share message (DRAFT — not posted anywhere)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_shareMessageDraft(), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.5)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _shareMessageDraft()));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft copied — this has NOT been posted anywhere.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy draft (not auto-posted)'),
        ),
        const SizedBox(height: ZapSpacing.xl),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.liveSosDashboard),
          icon: const Icon(Icons.monitor_heart_rounded, size: 18),
          label: const Text('Preview post-launch monitoring'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────
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
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? _kAccent : ZapColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 12)),
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
  final _rng = math.Random(365);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    const emojis = ['🎉', '🏗️', '✨', '📦', '🛡️', '365'];
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
