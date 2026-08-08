/// Day 145 — Cold Start Optimisation
///
/// The final performance day (Days 141-145) before AWS migration.
/// Days 142-144 reduced the APK size. Today measures whether those
/// changes actually improved the cold-start experience:
///
///   1. Profile startup with Flutter DevTools (--profile build)
///   2. Analyse the timeline flame chart (what still blocks main?)
///   3. Apply three remaining tweaks:
///      • Skeleton loader on Dashboard (was a 400ms empty screen)
///      • defer analytics init by 3s post-launch
///      • reduce home-screen ListView initial load
///   4. Verify on 4 target devices: target < 2.0s on all
///   5. Sign off the performance phase — hand off to Days 146-150 (AWS)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider   = StateProvider<int>((ref) => 0);
final _profileStateProvider= StateProvider<_ProfileState>((ref) => _ProfileState.idle);
final _tweakAppliedProvider= StateProvider<List<bool>>(
  (ref) => List.filled(3, false),
);
final _deviceTestedProvider= StateProvider<List<bool?>>(
  (ref) => List.filled(_kDevices.length, null),
);

enum _ProfileState { idle, profiling, done }

// ── Data ───────────────────────────────────────────────────────────────────────
class _StartupPhase {
  final String  name;
  final int     durationMs;
  final bool    blocking;
  final Color   color;
  final String  status;   // 'ok' | 'warn' | 'fix'
  final String? fix;
  const _StartupPhase({
    required this.name,
    required this.durationMs,
    required this.blocking,
    required this.color,
    required this.status,
    this.fix,
  });
}

// After all D141-144 optimisations — what still shows in the profiler
const _kPhases = [
  _StartupPhase(
    name: 'Dart VM init',
    durationMs: 185,
    blocking: true,
    color: Color(0xFF9CA3AF),
    status: 'ok',
  ),
  _StartupPhase(
    name: 'Firebase.initializeApp()',
    durationMs: 310,
    blocking: true,
    color: Color(0xFFF59E0B),
    status: 'ok',
  ),
  _StartupPhase(
    name: 'Auth token hydration',
    durationMs: 95,
    blocking: true,
    color: Color(0xFF10B981),
    status: 'ok',
  ),
  _StartupPhase(
    name: 'Dashboard widget build',
    durationMs: 380,
    blocking: true,
    color: Color(0xFFEF4444),
    status: 'warn',
    fix: 'Replace with skeleton — defer real data to post-frame',
  ),
  _StartupPhase(
    name: 'Analytics.init()',
    durationMs: 280,
    blocking: true,
    color: Color(0xFFF97316),
    status: 'fix',
    fix: 'Defer 3s post-launch — not needed before first frame',
  ),
  _StartupPhase(
    name: 'First frame paint',
    durationMs: 62,
    blocking: true,
    color: Color(0xFF8B5CF6),
    status: 'ok',
  ),
];

// Total blocking time (before tweaks)
const _kTotalMs = 185 + 310 + 95 + 380 + 280 + 62;

class _Tweak {
  final String title;
  final String problem;
  final String fix;
  final int    savedMs;
  final Color  color;
  final String codeFile;
  final String codeBefore;
  final String codeAfter;
  const _Tweak({
    required this.title,
    required this.problem,
    required this.fix,
    required this.savedMs,
    required this.color,
    required this.codeFile,
    required this.codeBefore,
    required this.codeAfter,
  });
}

const _kTweaks = [
  _Tweak(
    title: 'Dashboard skeleton loader',
    problem: 'Dashboard builds a ListView with contact cards + '
        'protection score ring + DCS status — 380ms blocking on first frame.',
    fix: 'Render a lightweight skeleton on first build. '
        'Load real data in a FutureProvider after frame is painted.',
    savedMs: 320,
    color: Color(0xFFEF4444),
    codeFile: 'dashboard_screen.dart',
    codeBefore:
        '// ❌ Heavy build on first frame\n'
        'Widget build(BuildContext context) {\n'
        '  final data = ref.watch(dashboardProvider); // waits\n'
        '  return _DashboardContent(data); // 380ms\n'
        '}',
    codeAfter:
        '// ✅ Skeleton first, data after\n'
        'Widget build(BuildContext context) {\n'
        '  final data = ref.watch(dashboardProvider);\n'
        '  return data.when(\n'
        '    loading: () => const _DashboardSkeleton(), // < 5ms\n'
        '    data:    (d) => _DashboardContent(d),\n'
        '    error:   (e, _) => _DashboardError(e),\n'
        '  );\n'
        '}',
  ),
  _Tweak(
    title: 'Defer analytics init by 3 seconds',
    problem: 'Analytics.init() runs in main() blocking startup by 280ms. '
        'Analytics data is not needed until the user has been in '
        'the app for at least a few seconds.',
    fix: 'Move analytics init to a postFrame callback with a 3-second delay.',
    savedMs: 250,
    color: Color(0xFFF97316),
    codeFile: 'main.dart',
    codeBefore:
        '// ❌ Analytics blocks startup\n'
        'void main() async {\n'
        '  await Firebase.initializeApp();\n'
        '  await Analytics.init();  // 280ms\n'
        '  runApp(ProviderScope(child: App()));\n'
        '}',
    codeAfter:
        '// ✅ Analytics deferred 3s\n'
        'void main() async {\n'
        '  await Firebase.initializeApp();\n'
        '  runApp(ProviderScope(child: App()));\n'
        '  // Non-blocking: init after app is visible\n'
        '  Future.delayed(const Duration(seconds: 3),\n'
        '      Analytics.init);\n'
        '}',
  ),
  _Tweak(
    title: 'Reduce initial ListView item count',
    problem: 'Dashboard contact list renders all contacts immediately. '
        'If a user has 10 contacts, 10 card widgets are built on '
        'first frame — wasted work for below-fold items.',
    fix: 'Render only the first 3 items synchronously. '
        'Load the rest lazily with ListView.builder.',
    savedMs: 60,
    color: Color(0xFF8B5CF6),
    codeFile: 'trusted_circle_list.dart',
    codeBefore:
        '// ❌ All items built at once\n'
        'ListView(\n'
        '  children: contacts\n'
        '      .map((c) => ContactCard(c))\n'
        '      .toList(),\n'
        ')',
    codeAfter:
        '// ✅ Lazy builder — only visible items built\n'
        'ListView.builder(\n'
        '  itemCount: contacts.length,\n'
        '  itemBuilder: (_, i) => ContactCard(contacts[i]),\n'
        ')',
  ),
];

class _DeviceResult {
  final String name, os;
  final double beforeMs, afterMs;
  final Color  color;
  const _DeviceResult(this.name, this.os, this.beforeMs, this.afterMs, this.color);
  bool get passes => afterMs < 2000;
}

const _kDevices = [
  _DeviceResult('Pixel 7',       'Android 14',  1812, 1340, Color(0xFF3B82F6)),
  _DeviceResult('Samsung S23',   'Android 13',  1950, 1520, Color(0xFF3DDC84)),
  _DeviceResult('iPhone 14',     'iOS 17',       1620, 1180, Color(0xFF9CA3AF)),
  _DeviceResult('Xiaomi Redmi 9','Android 12',  2480, 1890, Color(0xFFEF4444)),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day145ColdStartScreen extends ConsumerWidget {
  const Day145ColdStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 145 · Cold Start'),
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
            if (tab == 0) const _ProfileTab(),
            if (tab == 1) const _TweaksTab(),
            if (tab == 2) const _DevicesTab(),
            if (tab == 3) const _SignOffTab(),
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
          colors: [Color(0xFF0A0A1A), Color(0xFF050510), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 145', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('Final perf day · AWS next', const Color(0xFF9CA3AF)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Cold Start\nOptimisation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Days 142-144 cut APK size. Today confirms cold start is '
            '< 2s across all target devices. Three final tweaks: '
            'skeleton loader, deferred analytics, lazy ListView.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('1,312 ms', 'Before tweaks', Color(0xFFF59E0B)),
            _HStat('682 ms',   'After tweaks',  Color(0xFF10B981)),
            _HStat('< 2s',     'All devices',   Color(0xFF10B981)),
            _HStat('Day 146',  'Next: AWS',      Color(0xFF3B82F6)),
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
                  color: color, fontSize: 12, fontWeight: FontWeight.w800),
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
      (Icons.timer_rounded,        Color(0xFF8B5CF6), 'Profile'),
      (Icons.build_rounded,        Color(0xFFEF4444), 'Tweaks'),
      (Icons.phone_android_rounded,Color(0xFF10B981), 'Devices'),
      (Icons.flag_rounded,         Color(0xFF3B82F6), 'Sign-off'),
    ];
    return Row(
      children: List.generate(4, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                    color: isActive ? color : const Color(0xFF6B7280), size: 16),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Profile Tab ────────────────────────────────────────────────────────────────
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_profileStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Commands
        _codeNote('terminal',
            '# Profile build (not debug — close to release perf)\n'
            'flutter run --profile\n'
            '\n'
            '# Open DevTools: http://127.0.0.1:9102\n'
            '# → Performance → Record → cold restart app\n'
            '# → Stop → analyse flame chart'),
        const SizedBox(height: ZapSpacing.md),

        // Profiler button
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: state == _ProfileState.done
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: state == _ProfileState.done
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            if (state == _ProfileState.idle)
              _actionButton(
                label: 'Run startup profiler simulation',
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () async {
                  ref.read(_profileStateProvider.notifier).state =
                      _ProfileState.profiling;
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (!context.mounted) return;
                  ref.read(_profileStateProvider.notifier).state =
                      _ProfileState.done;
                },
              )
            else if (state == _ProfileState.profiling)
              _statusChip(Icons.radar_rounded, const Color(0xFF8B5CF6),
                  'Collecting startup frames…', loading: true)
            else ...[
              Row(children: [
                _pBox('${_kTotalMs} ms', 'Total blocking', const Color(0xFFF97316)),
                const SizedBox(width: ZapSpacing.sm),
                _pBox('${_kPhases.where((p) => p.status == 'ok').length}/${_kPhases.length}',
                    'Phases OK', const Color(0xFF10B981)),
                const SizedBox(width: ZapSpacing.sm),
                _pBox('2', 'Fix needed', const Color(0xFFEF4444)),
              ]),
              const SizedBox(height: ZapSpacing.md),
              _statusChip(Icons.check_circle_rounded,
                  const Color(0xFF10B981), 'Profile complete — see flame chart below'),
            ],
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Flame chart
        if (state == _ProfileState.done) ...[
          const _SectionLabel('STARTUP FLAME CHART  ·  POST D141-144'),
          const SizedBox(height: ZapSpacing.md),
          const _FlameChart(phases: _kPhases, totalMs: _kTotalMs),
          const SizedBox(height: ZapSpacing.lg),
          _infoBox(
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            text: '2 phases still above threshold: '
                'Dashboard build (380ms) and Analytics init (280ms). '
                'Both can be deferred — see Tweaks tab.',
          ),
        ],
      ],
    );
  }

  Widget _pBox(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _FlameChart extends StatelessWidget {
  final List<_StartupPhase> phases;
  final int                 totalMs;
  const _FlameChart({required this.phases, required this.totalMs});

  static const _statusColors = {
    'ok':   Color(0xFF10B981),
    'warn': Color(0xFFF59E0B),
    'fix':  Color(0xFFEF4444),
  };
  static const _statusIcons = {
    'ok':   Icons.check_circle_rounded,
    'warn': Icons.warning_rounded,
    'fix':  Icons.error_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(children: [
        // Time axis
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 ms', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8, fontFamily: 'monospace')),
            Text('500 ms', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8, fontFamily: 'monospace')),
            Text('1000 ms', style: TextStyle(color: Color(0xFF4B5563), fontSize: 8, fontFamily: 'monospace')),
            Text('1312 ms', style: TextStyle(color: Color(0xFFF97316), fontSize: 8, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 6),
        // 2000ms target line
        Stack(children: [
          Container(height: 2, color: const Color(0xFF2A2A2A)),
          Positioned(
            left: MediaQuery.of(context).size.width * 0.72 * (1500 / 2000),
            child: Container(
              width: 2, height: 6,
              color: const Color(0xFF10B981).withOpacity(0.6),
            ),
          ),
        ]),
        const SizedBox(height: ZapSpacing.sm),

        // Phase bars
        ...phases.map((p) {
          final frac  = p.durationMs / 2000.0;
          final sColor= _statusColors[p.status]!;
          final sIcon = _statusIcons[p.status]!;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(sIcon, color: sColor, size: 11),
                  const SizedBox(width: ZapSpacing.xs),
                  Expanded(
                    child: Text(p.name,
                        style: TextStyle(
                            color: sColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  Text('${p.durationMs} ms',
                      style: TextStyle(
                          color: p.color,
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 3),
                Stack(children: [
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(
                            p.status == 'fix' ? 0.5 : 0.35),
                        borderRadius: BorderRadius.circular(3),
                        border: p.status != 'ok'
                            ? Border.all(
                                color: p.color.withOpacity(0.6), width: 1)
                            : null,
                      ),
                    ),
                  ),
                ]),
                if (p.fix != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('→ ${p.fix}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 9, height: 1.3)),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.xs),
        // Target line label
        Row(children: [
          Container(width: 10, height: 2, color: const Color(0xFF10B981).withOpacity(0.6)),
          const SizedBox(width: ZapSpacing.xs),
          const Text('< 2000ms target',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 8)),
        ]),
      ]),
    );
  }
}

// ── Tweaks Tab ─────────────────────────────────────────────────────────────────
class _TweaksTab extends ConsumerWidget {
  const _TweaksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied   = ref.watch(_tweakAppliedProvider);
    final doneCount = applied.where((a) => a).length;
    final totalSaved= _kTweaks.asMap().entries
        .where((e) => applied[e.key])
        .fold(0, (s, e) => s + e.value.savedMs);
    final timeAfter = _kTotalMs - totalSaved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: doneCount == 3
                ? const Color(0xFF10B981).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
              color: doneCount == 3
                  ? const Color(0xFF10B981).withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
            ),
          ),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$doneCount / 3 tweaks applied',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Row(children: [
                  Text(
                    '$timeAfter ms',
                    style: TextStyle(
                        color: timeAfter < 1000
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace'),
                  ),
                  const Text('  cold start',
                      style: TextStyle(
                          color: Color(0xFF6B7280), fontSize: 11)),
                ]),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: doneCount / 3,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation(
                  doneCount == 3 ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
                ),
                minHeight: 5,
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Tweak cards
        ..._kTweaks.asMap().entries.map((e) {
          final i    = e.key;
          final tweak= e.value;
          final done = applied[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _TweakCard(
              tweak: tweak,
              done: done,
              onApply: () async {
                await Future.delayed(const Duration(milliseconds: 600));
                if (!context.mounted) return;
                final updated = List<bool>.from(ref.read(_tweakAppliedProvider));
                updated[i] = true;
                ref.read(_tweakAppliedProvider.notifier).state = updated;
              },
            ),
          );
        }),
      ],
    );
  }
}

class _TweakCard extends StatefulWidget {
  final _Tweak       tweak;
  final bool         done;
  final VoidCallback onApply;
  const _TweakCard({required this.tweak, required this.done, required this.onApply});

  @override
  State<_TweakCard> createState() => _TweakCardState();
}

class _TweakCardState extends State<_TweakCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tweak;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.done
            ? const Color(0xFF10B981).withOpacity(0.06)
            : _expanded
                ? t.color.withOpacity(0.06)
                : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: widget.done
              ? const Color(0xFF10B981).withOpacity(0.35)
              : _expanded
                  ? t.color.withOpacity(0.35)
                  : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.done
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : t.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.done ? Icons.check_rounded : Icons.timer_rounded,
                  color: widget.done ? const Color(0xFF10B981) : t.color,
                  size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                      widget.done
                          ? '−${t.savedMs} ms saved'
                          : '−${t.savedMs} ms potential',
                      style: TextStyle(
                          color: widget.done
                              ? const Color(0xFF10B981)
                              : t.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
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
                    // Problem
                    _metaRow(Icons.warning_amber_rounded,
                        const Color(0xFFEF4444), 'Problem', t.problem),
                    const SizedBox(height: ZapSpacing.sm),
                    // Fix
                    _metaRow(Icons.build_rounded,
                        const Color(0xFF10B981), 'Fix', t.fix),
                    const SizedBox(height: ZapSpacing.md),
                    // Code diff
                    _diffBlock(t.codeFile, t.codeBefore, t.codeAfter),
                    const SizedBox(height: ZapSpacing.md),
                    widget.done
                        ? _statusChip(Icons.check_circle_rounded,
                            const Color(0xFF10B981), 'Applied ✅')
                        : _actionButton(
                            label: 'Apply tweak (−${t.savedMs} ms)',
                            icon: Icons.flash_on_rounded,
                            color: t.color,
                            onTap: widget.onApply),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// ── Devices Tab ────────────────────────────────────────────────────────────────
class _DevicesTab extends ConsumerWidget {
  const _DevicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tested = ref.watch(_deviceTestedProvider);
    final allPass = tested.every((t) => t == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.phone_android_rounded,
          color: const Color(0xFF10B981),
          text: 'Test cold start on 4 target devices. '
              'All must be < 2,000ms to pass. '
              'Tap "Run test" on each device to simulate the measurement.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        ..._kDevices.asMap().entries.map((e) {
          final i      = e.key;
          final device = e.value;
          final result = tested[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: _DeviceCard(
              device: device,
              result: result,
              onTest: () async {
                // Mark as running (null while testing)
                final updated = List<bool?>.from(ref.read(_deviceTestedProvider));
                updated[i] = null;
                ref.read(_deviceTestedProvider.notifier).state = updated;
                await Future.delayed(const Duration(milliseconds: 900));
                if (!context.mounted) return;
                final done = List<bool?>.from(ref.read(_deviceTestedProvider));
                done[i] = device.passes;
                ref.read(_deviceTestedProvider.notifier).state = done;
              },
            ),
          );
        }),

        if (allPass) ...[
          const SizedBox(height: ZapSpacing.lg),
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
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 36),
              const SizedBox(height: ZapSpacing.sm),
              const Text('All devices < 2s ✅',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                'Fastest: ${_kDevices.map((d) => d.afterMs).reduce((a, b) => a < b ? a : b).toInt()} ms  '
                '·  Slowest: ${_kDevices.map((d) => d.afterMs).reduce((a, b) => a > b ? a : b).toInt()} ms',
                style: const TextStyle(
                    color: Color(0xFF10B981), fontSize: 12),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final _DeviceResult device;
  final bool?         result;   // null = testing, true = pass, false = fail
  final VoidCallback  onTest;
  const _DeviceCard({required this.device, required this.result, required this.onTest});

  @override
  Widget build(BuildContext context) {
    final pass = device.passes;
    final improvement = ((1 - device.afterMs / device.beforeMs) * 100).round();

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: result == true
            ? const Color(0xFF10B981).withOpacity(0.06)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: result == true
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Row(children: [
        // Device icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: device.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_android_rounded,
              color: device.color, size: 20),
        ),
        const SizedBox(width: ZapSpacing.md),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(device.os,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10)),
            ],
          ),
        ),
        // Times
        if (result != null) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              Text('${device.beforeMs.toInt()} ms',
                  style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Color(0xFFEF4444))),
              const Text(' → ',
                  style: TextStyle(color: Color(0xFF4B5563), fontSize: 11)),
              Text('${device.afterMs.toInt()} ms',
                  style: TextStyle(
                      color: pass
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700)),
            ]),
            Text(
              pass
                  ? '−$improvement% · < 2s ✅'
                  : '−$improvement% · FAIL ❌',
              style: TextStyle(
                  color: pass
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  fontSize: 9),
            ),
          ]),
        ] else
          GestureDetector(
            onTap: onTest,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 8),
              decoration: BoxDecoration(
                color: device.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: device.color.withOpacity(0.35)),
              ),
              child: Text('Run test',
                  style: TextStyle(
                      color: device.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

// ── Sign-off Tab ───────────────────────────────────────────────────────────────
class _SignOffTab extends ConsumerWidget {
  const _SignOffTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Performance phase complete summary
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
          child: const Column(children: [
            Icon(Icons.emoji_events_rounded,
                color: Color(0xFF10B981), size: 44),
            SizedBox(height: ZapSpacing.md),
            Text(
              'Performance Phase Complete!\nDays 141-145 ✅',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ZapSpacing.lg),
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _Chip('APK 44.9→26 MB',       Color(0xFF10B981)),
                _Chip('Cold start < 2s ✅',    Color(0xFF10B981)),
                _Chip('ML models −59%',         Color(0xFFEF4444)),
                _Chip('141 screens lazy',       Color(0xFF3B82F6)),
                _Chip('WebP + font prune',      Color(0xFFF59E0B)),
                _Chip('i18n lazy-load',         Color(0xFF8B5CF6)),
                _Chip('All 4 devices pass',     Color(0xFF10B981)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Full performance journey
        const _SectionLabel('5-DAY PERFORMANCE JOURNEY'),
        const SizedBox(height: ZapSpacing.md),
        const _PerformanceJourney(),
        const SizedBox(height: ZapSpacing.xl),

        // What's next
        const _SectionLabel('NEXT  ·  DAYS 146-150  ·  AWS MIGRATION'),
        const SizedBox(height: ZapSpacing.md),
        _infoBox(
          icon: Icons.cloud_rounded,
          color: const Color(0xFF3B82F6),
          text: 'Performance phase done. Days 146-150: '
              'switch API base URL to AWS, test all 58 screens, '
              'fix CORS/SSL/Lambda issues, regression test, '
              'tag v0.6-aws-production.',
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _nextRow(const Color(0xFF3B82F6), 'Day 146', 'Switch API URL to AWS  ·  api-aws.zapsafe.app'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFF8B5CF6), 'Day 147', 'Test all 58 screens against AWS backend'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFFEF4444), 'Day 148', 'Fix AWS-specific issues (CORS, SSL, Lambda cold start)'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFFF59E0B), 'Day 149', 'Performance regression test (DigitalOcean vs AWS)'),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            _nextRow(const Color(0xFF10B981), 'Day 150', 'Tag v0.6-aws-production  ·  public launch ready'),
          ]),
        ),
      ],
    );
  }

  Widget _nextRow(Color color, String day, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(children: [
          Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(day,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class _PerformanceJourney extends StatelessWidget {
  const _PerformanceJourney();

  static const _steps = [
    (Color(0xFF3B82F6), 'Day 141', 'App Size Audit',
        '44.9 MB · 7 components · optimisation plan'),
    (Color(0xFFEF4444), 'Day 142', 'ML Model Compression',
        '17.4 MB → 7.2 MB · INT8 + pruning · 6 models validated'),
    (Color(0xFF8B5CF6), 'Day 143', 'Lazy Loading',
        '141 non-critical screens deferred · RAM −41%'),
    (Color(0xFFF59E0B), 'Day 144', 'Asset Optimisation',
        'WebP + font prune + i18n lazy · APK 34.7→26 MB'),
    (Color(0xFF10B981), 'Day 145', 'Cold Start Polish',
        '682 ms total · all 4 devices < 2s ✅'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _steps.asMap().entries.map((e) {
          final i = e.key;
          final (color, day, title, desc) = e.value;
          final isLast = i == _steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 30, height: 30,
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
                  Container(
                      width: 2, height: 32,
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
                        Text(day,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: ZapSpacing.sm),
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                      Text(desc,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
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
Widget _metaRow(IconData icon, Color color, String label, String text) =>
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: ZapSpacing.sm),
      Text('$label: ',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      Expanded(
        child: Text(text,
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5)),
      ),
    ]);

Widget _diffBlock(String filename, String before, String after) => Container(
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
              color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...before.split('\n').map((l) => Text('- $l',
            style: const TextStyle(
                color: Color(0xFFFF7B72), fontSize: 11,
                fontFamily: 'monospace', height: 1.5))),
        const SizedBox(height: ZapSpacing.xs),
        ...after.split('\n').map((l) => Text('+ $l',
            style: const TextStyle(
                color: Color(0xFF7EE787), fontSize: 11,
                fontFamily: 'monospace', height: 1.5))),
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
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label, {bool loading = false}) =>
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
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
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
              color: const Color(0xFF1C2128), borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(color: Color(0xFF79C0FF), fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 11, fontFamily: 'monospace', height: 1.6)),
      ]),
    );
