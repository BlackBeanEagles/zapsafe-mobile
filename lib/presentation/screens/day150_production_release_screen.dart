/// Day 150 — Tag v0.6-aws-production 🚀
///
/// THE FINAL DAY. 150 days of building ZapSafe from scratch.
///
/// All systems are green:
///   ✅ 58 screens tested on AWS       ✅ WCAG 2.1 AA accessibility
///   ✅ Performance regression passed   ✅ 15 languages working
///   ✅ Security review clean           ✅ APK < 28 MB
///   ✅ Beta: 847 testers, 4.4★         ✅ No open P0/P1 bugs
///
/// Today:
///   1. Final pre-launch checklist (Testing/Quality/Docs/Marketing)
///   2. Build production APK + IPA
///   3. Tag v0.6-aws-production in Git
///   4. Create GitHub release with artifacts
///   5. Draft launch announcement for testers
///   6. 150-day journey retrospective
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider   = StateProvider<int>((ref) => 0);
final _checklistProvider   = StateProvider<Map<String, bool>>((ref) => {});
final _buildStateProvider  = StateProvider<_BuildState>((ref) => _BuildState.idle);
final _tagStateProvider    = StateProvider<_TagState>((ref) => _TagState.idle);
final _releaseStateProvider= StateProvider<_ReleaseState>((ref) => _ReleaseState.idle);
final _notifyStateProvider = StateProvider<_NotifyState>((ref) => _NotifyState.idle);

enum _BuildState   { idle, building, done }
enum _TagState     { idle, tagging, pushing, done }
enum _ReleaseState { idle, creating, done }
enum _NotifyState  { idle, sending, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _CheckSection {
  final String   title;
  final Color    color;
  final IconData icon;
  final List<String> items;
  const _CheckSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });
}

const _kSections = [
  _CheckSection(
    title: 'TESTING',
    color: Color(0xFF10B981),
    icon: Icons.science_rounded,
    items: [
      'All 58 screens tested on AWS (Day 147)',
      'Performance regression passed — AWS ≤ 10% slower (Day 149)',
      'No new P0 crashes in last 24 hours (Sentry)',
      'Battery drain < 7%/hr confirmed (Day 145)',
      'Offline mode: cached data shown, no crash',
      'Network timeout: error snackbar + retry, no hang',
    ],
  ),
  _CheckSection(
    title: 'QUALITY',
    color: Color(0xFF3B82F6),
    icon: Icons.verified_rounded,
    items: [
      'Code review: no dead code, no debug flags in release',
      'Security: 0 critical findings, 1 warning (debug log — resolved)',
      'Accessibility: WCAG 2.1 AA audit passed (Day 138)',
      'All 15 languages display correctly (no overflow)',
      'RTL: Arabic and Urdu layout verified',
      'APK: 26.0 MB (target < 30 MB ✅)',
    ],
  ),
  _CheckSection(
    title: 'DOCUMENTATION',
    color: Color(0xFF8B5CF6),
    icon: Icons.description_rounded,
    items: [
      'Release notes: v0.1 → v0.6 changelog written (Day 135)',
      'Known issues: widget locking screen (planned v0.7)',
      'API documentation: all 75+ endpoints current',
      'Deployment guide: AWS EKS + CDK IaC documented',
    ],
  ),
  _CheckSection(
    title: 'MARKETING',
    color: Color(0xFFF59E0B),
    icon: Icons.campaign_rounded,
    items: [
      'App Store screenshots: 5 per device size (iPhone 15, SE, iPad)',
      'App description: English (30-char short + 4000-char long)',
      'Keywords: safety, SOS, emergency, women, personal safety',
      'Privacy policy: updated, GDPR + DPDP compliant',
      'Support email: support@zapsafe.app active',
      'Social media announcement: drafted and scheduled',
    ],
  ),
];

const _kJourneyPhases = [
  (Color(0xFF3B82F6),  'Days 1-20',   'Month 1: Foundation',
      'Django backend, auth, OTP, contacts, SOS trigger, push notifications'),
  (Color(0xFF8B5CF6),  'Days 21-40',  'Month 2: Core Safety Engine',
      'GPS tracking, audio pipeline, TFLite skeleton, loophole defenses'),
  (Color(0xFFEF4444),  'Days 41-60',  'Month 3: AI Integration',
      'DCS detection engine, model bundles, IMU, background service'),
  (Color(0xFFF97316),  'Days 61-80',  'Month 4: SOS Flows',
      'Alert pending, SOS active, evidence vault, post-incident, WebLink'),
  (Color(0xFFF59E0B),  'Days 81-100', 'Month 5: Analytics & Premium',
      'Analytics dashboard, subscription screens, payment methods'),
  (Color(0xFF10B981),  'Days 101-120','Months 6-7: i18n & Beta Launch',
      '15 languages, accessibility, 1,000 beta testers recruited'),
  (Color(0xFFEF4444),  'Days 121-140','Beta Iteration',
      '5 crash fixes, FP reduction, notifications, performance, leaks, onboarding'),
  (Color(0xFF3B82F6),  'Days 141-150','AWS Migration & Production',
      'APK 44→26 MB, cold start < 2s, AWS migration, regression pass'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day150ProductionReleaseScreen extends ConsumerWidget {
  const Day150ProductionReleaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 150 · Production Release 🚀'),
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
            if (tab == 0) const _ChecklistTab(),
            if (tab == 1) const _ReleaseTab(),
            if (tab == 2) const _RetroTab(),
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
          colors: [Color(0xFF0D1F10), Color(0xFF060F08), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 150', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🎉  THE FINAL DAY', const Color(0xFFF59E0B)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.6-aws-production', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            '150 Days.\nShip it. 🚀',
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.1),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Production-ready app on AWS. 847 beta testers, 4.4★. '
            'APK 26 MB, cold start < 2s, crash rate 0.09%. '
            'Run the final checklist, tag the release, announce to the world.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('150',    'Days built',    Color(0xFF10B981)),
            _HStat('847',    'Beta testers',  Color(0xFF3B82F6)),
            _HStat('4.4★',   'Satisfaction',  Color(0xFFF59E0B)),
            _HStat('v0.6',   'Tag today',     Color(0xFF8B5CF6)),
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
                  color: color, fontSize: 16, fontWeight: FontWeight.w800),
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
      (Icons.checklist_rounded,    Color(0xFF10B981), 'Checklist'),
      (Icons.rocket_launch_rounded,Color(0xFF3B82F6), 'Release'),
      (Icons.history_edu_rounded,  Color(0xFF8B5CF6), 'Journey'),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon,
                    color: isActive ? color : const Color(0xFF6B7280), size: 18),
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

// ── Checklist Tab ──────────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_checklistProvider);
    final totalItems= _kSections.fold(0, (s, sec) => s + sec.items.length);
    final doneCount = checks.values.where((v) => v).length;
    final allDone   = doneCount == totalItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master progress
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: allDone
                ? const Color(0xFF10B981).withOpacity(0.08)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: allDone
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / $totalItems confirmed',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    allDone
                        ? '🚀 Launch checklist complete!'
                        : 'Tap each item to confirm',
                    key: ValueKey(allDone),
                    style: TextStyle(
                        color: allDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: allDone ? FontWeight.w700 : FontWeight.w400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalItems > 0 ? doneCount / totalItems : 0,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  allDone ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                ),
                minHeight: 8,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Section checklists
        ..._kSections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.md),
              child: _CheckSectionWidget(
                  section: section, checks: checks, ref: ref),
            )),

        if (allDone) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.35)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 16),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'All ${ 22} items confirmed. '
                  'Proceed to the Release tab to tag v0.6-aws-production.',
                  style: TextStyle(
                      color: Color(0xFFD1D5DB), fontSize: 12),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _CheckSectionWidget extends StatelessWidget {
  final _CheckSection section;
  final Map<String, bool> checks;
  final WidgetRef ref;

  // ignore: no-logic-in-create
  const _CheckSectionWidget({required this.section, required this.checks, required this.ref});

  @override
  Widget build(BuildContext context) {
    final passInSection = section.items
        .where((item) => checks['${section.title}:$item'] == true)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: section.color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ZapSpacing.radiusSmall - 1)),
          ),
          child: Row(children: [
            Icon(section.icon, color: section.color, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Text(section.title,
                style: TextStyle(
                    color: section.color, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const Spacer(),
            Text('$passInSection/${section.items.length}',
                style: TextStyle(
                    color: passInSection == section.items.length
                        ? const Color(0xFF10B981)
                        : section.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        // Items
        ...section.items.asMap().entries.map((e) {
          final i      = e.key;
          final item   = e.value;
          final key    = '${section.title}:$item';
          final done   = checks[key] == true;
          final isLast = i == section.items.length - 1;

          return GestureDetector(
            onTap: () {
              final updated = Map<String, bool>.from(
                  ref.read(_checklistProvider));
              updated[key] = !done;
              ref.read(_checklistProvider.notifier).state = updated;
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 11),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: done
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4B5563)),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF10B981), size: 14)
                        : null,
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(item,
                        style: TextStyle(
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          fontSize: 12,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF6B7280),
                        )),
                  ),
                ]),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Release Tab ────────────────────────────────────────────────────────────────
class _ReleaseTab extends ConsumerWidget {
  const _ReleaseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildState   = ref.watch(_buildStateProvider);
    final tagState     = ref.watch(_tagStateProvider);
    final releaseState = ref.watch(_releaseStateProvider);
    final notifyState  = ref.watch(_notifyStateProvider);
    final allComplete  = notifyState == _NotifyState.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 1 — Build
        const _SectionLabel('STEP 1  ·  BUILD RELEASE ARTIFACTS'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('terminal',
            '# Production builds\n'
            'flutter build appbundle --flavor prod --release \\\n'
            '  --dart-define=API_BASE_URL=https://api-aws.zapsafe.app\n'
            '\n'
            'flutter build ios --flavor prod --release \\\n'
            '  --dart-define=API_BASE_URL=https://api-aws.zapsafe.app'),
        const SizedBox(height: ZapSpacing.md),
        if (buildState == _BuildState.idle)
          _actionButton(
            label: 'Build APK + IPA',
            icon: Icons.build_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_buildStateProvider.notifier).state = _BuildState.building;
              await Future.delayed(const Duration(milliseconds: 1000));
              if (!context.mounted) return;
              ref.read(_buildStateProvider.notifier).state = _BuildState.done;
            },
          )
        else if (buildState == _BuildState.building)
          _statusChip(Icons.build_rounded, const Color(0xFF3B82F6),
              'Building…', loading: true)
        else
          _artifactRow(),
        const SizedBox(height: ZapSpacing.xl),

        // Step 2 — Tag
        const _SectionLabel('STEP 2  ·  TAG v0.6-aws-production'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('git',
            'git add -A && git commit -m \\\n'
            '  "Day 150: AWS migration complete, production ready"\n'
            'git tag v0.6-aws-production \\\n'
            '  -m "Production release on AWS ap-south-1"\n'
            'git push origin v0.6-aws-production'),
        const SizedBox(height: ZapSpacing.md),
        _TagPanel(state: tagState,
            enabled: buildState == _BuildState.done,
            ref: ref),
        const SizedBox(height: ZapSpacing.xl),

        // Step 3 — GitHub Release
        const _SectionLabel('STEP 3  ·  CREATE GITHUB RELEASE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('gh',
            'gh release create v0.6-aws-production \\\n'
            '  --title "ZapSafe v0.6-aws-production" \\\n'
            '  --notes-file RELEASE_NOTES.md \\\n'
            '  build/app/outputs/bundle/prodRelease/app-prod-release.aab \\\n'
            '  build/ios/archive/ZapSafe.ipa'),
        const SizedBox(height: ZapSpacing.md),
        _GithubReleasePanel(state: releaseState,
            enabled: tagState == _TagState.done,
            ref: ref),
        const SizedBox(height: ZapSpacing.xl),

        // Step 4 — Notify
        const _SectionLabel('STEP 4  ·  NOTIFY TESTERS'),
        const SizedBox(height: ZapSpacing.md),
        _NotifyPanel(state: notifyState,
            enabled: releaseState == _ReleaseState.done,
            ref: ref),

        if (allComplete) ...[
          const SizedBox(height: ZapSpacing.xl),
          _FinalCard(),
        ],
      ],
    );
  }

  Widget _artifactRow() => Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
        ),
        child: Column(children: [
          _artRow(Icons.android_rounded, const Color(0xFF3DDC84),
              'zapsafe-v0.6-aws-production.aab', '26.1 MB'),
          const Divider(height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
          _artRow(Icons.apple_rounded, Colors.white,
              'ZapSafe-v0.6-aws-production.ipa', '24.8 MB'),
        ]),
      );

  Widget _artRow(IconData icon, Color color, String name, String size) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11,
                  fontFamily: 'monospace')),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(size,
              style: const TextStyle(
                  color: Color(0xFF10B981), fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _TagPanel extends StatelessWidget {
  final _TagState    state;
  final bool         enabled;
  final WidgetRef    ref;
  const _TagPanel({required this.state, required this.enabled, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (state == _TagState.done) {
      return _statusChip(Icons.local_offer_rounded, const Color(0xFF10B981),
          'v0.6-aws-production tagged & pushed to GitHub ✅');
    }
    if (state == _TagState.tagging || state == _TagState.pushing) {
      return _statusChip(
          state == _TagState.tagging
              ? Icons.local_offer_rounded
              : Icons.upload_rounded,
          const Color(0xFF3B82F6),
          state == _TagState.tagging
              ? 'Creating annotated tag…'
              : 'Pushing tag to origin…',
          loading: true);
    }
    return _actionButton(
      label: enabled ? 'Tag v0.6-aws-production' : 'Build artifacts first',
      icon: Icons.local_offer_rounded,
      color: enabled ? const Color(0xFF10B981) : const Color(0xFF4B5563),
      onTap: enabled
          ? () async {
              ref.read(_tagStateProvider.notifier).state = _TagState.tagging;
              await Future.delayed(const Duration(milliseconds: 700));
              if (!context.mounted) return;
              ref.read(_tagStateProvider.notifier).state = _TagState.pushing;
              await Future.delayed(const Duration(milliseconds: 700));
              if (!context.mounted) return;
              ref.read(_tagStateProvider.notifier).state = _TagState.done;
            }
          : () {},
    );
  }
}

class _GithubReleasePanel extends StatelessWidget {
  final _ReleaseState state;
  final bool          enabled;
  final WidgetRef     ref;
  const _GithubReleasePanel(
      {required this.state, required this.enabled, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (state == _ReleaseState.done) {
      return Column(children: [
        _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
            'GitHub release created ✅'),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: const Text(
            'github.com/zapsafe-app/zapsafe-mobile/releases/tag/v0.6-aws-production',
            style: TextStyle(
                color: Color(0xFF79C0FF), fontSize: 10,
                fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
        ),
      ]);
    }
    if (state == _ReleaseState.creating) {
      return _statusChip(Icons.upload_rounded, const Color(0xFF8B5CF6),
          'Creating GitHub release…', loading: true);
    }
    return _actionButton(
      label: enabled ? 'Create GitHub release' : 'Tag first',
      icon: Icons.cloud_upload_rounded,
      color: enabled ? const Color(0xFF8B5CF6) : const Color(0xFF4B5563),
      onTap: enabled
          ? () async {
              ref.read(_releaseStateProvider.notifier).state =
                  _ReleaseState.creating;
              await Future.delayed(const Duration(milliseconds: 900));
              if (!context.mounted) return;
              ref.read(_releaseStateProvider.notifier).state =
                  _ReleaseState.done;
            }
          : () {},
    );
  }
}

class _NotifyPanel extends StatelessWidget {
  final _NotifyState state;
  final bool         enabled;
  final WidgetRef    ref;
  const _NotifyPanel(
      {required this.state, required this.enabled, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (state == _NotifyState.done) {
      return _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
          '847 testers notified: "v1.0 launching to App Store next week!" ✅');
    }
    if (state == _NotifyState.sending) {
      return _statusChip(Icons.send_rounded, const Color(0xFFF59E0B),
          'Sending launch announcement…', loading: true);
    }

    return Column(children: [
      // Email preview
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Subject: ZapSafe v1.0 is coming to the App Store! 🚀',
              style: TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Hi beta testers,\n\n'
            'Because of your feedback, ZapSafe is now production-ready.\n'
            'We\'re submitting to the App Store & Google Play this week.\n\n'
            'Your feedback changed everything:\n'
            '• Crash rate: 0.31% → 0.09%\n'
            '• Battery: 20%/hr → 6%/hr\n'
            '• Onboarding: 5 min → < 2 min\n\n'
            'Thank you. Seriously. 💙\n\n'
            '— The ZapSafe Team',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11, height: 1.6),
          ),
        ]),
      ),
      const SizedBox(height: ZapSpacing.md),
      _actionButton(
        label: enabled ? 'Send to 847 testers' : 'Create GitHub release first',
        icon: Icons.send_rounded,
        color: enabled ? const Color(0xFFF59E0B) : const Color(0xFF4B5563),
        onTap: enabled
            ? () async {
                ref.read(_notifyStateProvider.notifier).state =
                    _NotifyState.sending;
                await Future.delayed(const Duration(milliseconds: 1000));
                if (!context.mounted) return;
                ref.read(_notifyStateProvider.notifier).state =
                    _NotifyState.done;
              }
            : () {},
      ),
    ]);
  }
}

class _FinalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.15),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.5), width: 2),
      ),
      child: Column(children: [
        const Text('🎉', style: TextStyle(fontSize: 52)),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'v0.6-aws-production\nSHIPPED!',
          style: TextStyle(
              color: Colors.white, fontSize: 24,
              fontWeight: FontWeight.w900, height: 1.2),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '150 days. 1 developer. 1 safety app.\n'
          'Ready for App Store & Google Play submission.',
          style: TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
          alignment: WrapAlignment.center,
          children: const [
            _Chip('API: AWS ap-south-1',   Color(0xFF3B82F6)),
            _Chip('APK: 26 MB',            Color(0xFF10B981)),
            _Chip('Cold start: 1.8s',      Color(0xFF10B981)),
            _Chip('Crash: 0.09%',          Color(0xFF10B981)),
            _Chip('4.4★ · 847 testers',    Color(0xFFF59E0B)),
            _Chip('WCAG 2.1 AA',           Color(0xFF8B5CF6)),
            _Chip('15 languages',           Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        _infoBox(
          icon: Icons.store_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Days 151-160: Security audit + GDPR compliance.\n'
              'Days 161-170: App Store submission + marketing.\n'
              'Day 171+: 🚀 PUBLIC LAUNCH!',
        ),
      ]),
    );
  }
}

// ── Retro Tab ──────────────────────────────────────────────────────────────────
class _RetroTab extends StatelessWidget {
  const _RetroTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF10B981).withOpacity(0.12),
              const Color(0xFF10B981).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
          ),
          child: Column(children: [
            const Text('150-Day Build Summary',
                style: TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.lg),
            Row(children: const [
              _StatPair('150', 'Days built',    Color(0xFF10B981)),
              _StatPair('140+', 'Screens built', Color(0xFF3B82F6)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            Row(children: const [
              _StatPair('75+', 'API endpoints', Color(0xFF8B5CF6)),
              _StatPair('9',   'ML models',     Color(0xFFEF4444)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            Row(children: const [
              _StatPair('847', 'Beta testers',  Color(0xFFF59E0B)),
              _StatPair('15',  'Languages',     Color(0xFF3B82F6)),
            ]),
            const SizedBox(height: ZapSpacing.sm),
            Row(children: const [
              _StatPair('44',  'Safety features', Color(0xFFEF4444)),
              _StatPair('27',  'LP defenses',     Color(0xFF8B5CF6)),
            ]),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Phase timeline
        const _SectionLabel('8-PHASE BUILD TIMELINE'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kJourneyPhases.asMap().entries.map((e) {
              final i = e.key;
              final (color, days, title, desc) = e.value;
              final isLast = i == _kJourneyPhases.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: color, fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (!isLast)
                      Container(width: 2, height: 32,
                          color: const Color(0xFF2A2A2A)),
                  ]),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          bottom: ZapSpacing.sm, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(days,
                                style: TextStyle(
                                    color: color, fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: ZapSpacing.sm),
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          Text(desc,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 10, height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // What's next
        const _SectionLabel('WHAT\'S NEXT  ·  DAYS 151+'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _nextRow(const Color(0xFFEF4444), 'Days 151-160',
                'Security audit + GDPR compliance review'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFF8B5CF6), 'Days 161-170',
                'App Store submission + marketing assets + launch prep'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFF10B981), 'Day 171+',
                '🚀 PUBLIC LAUNCH — India first, then global'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFF3B82F6), 'Month 13',
                '1,000,000+ downloads · 4.7+ rating · Play Store top safety app'),
          ]),
        ),
      ],
    );
  }

  Widget _nextRow(Color color, String days, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(days,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, height: 1.4)),
            ]),
          ),
        ]),
      );
}

class _StatPair extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _StatPair(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
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
          gradient: color != const Color(0xFF4B5563)
              ? LinearGradient(colors: [color, color.withOpacity(0.8)])
              : null,
          color: color == const Color(0xFF4B5563)
              ? const Color(0xFF1A1A1A)
              : null,
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: color != const Color(0xFF4B5563)
              ? [BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 14, offset: const Offset(0, 4))]
              : null,
          border: color == const Color(0xFF4B5563)
              ? Border.all(color: const Color(0xFF2A2A2A))
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: color == const Color(0xFF4B5563)
                  ? const Color(0xFF4B5563)
                  : Colors.white,
              size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: TextStyle(
                  color: color == const Color(0xFF4B5563)
                      ? const Color(0xFF4B5563)
                      : Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w700)),
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
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ),
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
                color: Color(0xFFE6EDF3), fontSize: 11,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
