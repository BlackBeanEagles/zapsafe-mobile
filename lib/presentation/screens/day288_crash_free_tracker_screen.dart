/// Day 288 — Crash-Free Session Tracker
///
/// Section E (Days 281-300): mock Sentry dashboard tracking crash-free session
/// rate with a 99.5% launch gate, daily trend bars, and issue feed.
///
/// Tag: 🟢 FRONTEND-ONLY · mock metrics · no live Sentry API.
///
/// Route: [AppRoutes.crashFreeTracker] → `/crash-free-tracker`
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF6C5CE7);
const _kTabs = ['Dashboard', 'Trends', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kTargetPct = 99.5;
const _kCurrentPct = 99.62;

class _CrashIssue {
  const _CrashIssue({
    required this.id,
    required this.title,
    required this.platform,
    required this.events,
    required this.users,
    required this.status,
    required this.lastSeen,
  });

  final String id;
  final String title;
  final String platform;
  final int events;
  final int users;
  final String status;
  final String lastSeen;
}

const _kCrashIssues = [
  _CrashIssue(
    id: 'ios_bg_location',
    title: 'EXC_BAD_ACCESS in location stream',
    platform: 'iOS 17',
    events: 3,
    users: 2,
    status: 'resolved',
    lastSeen: '2d ago',
  ),
  _CrashIssue(
    id: 'android_sms',
    title: 'NullPointer in SMS fallback',
    platform: 'Android 12',
    events: 1,
    users: 1,
    status: 'resolved',
    lastSeen: '5d ago',
  ),
  _CrashIssue(
    id: 'flutter_render',
    title: 'RenderFlex overflow on tablet',
    platform: 'Android 14',
    events: 0,
    users: 0,
    status: 'monitoring',
    lastSeen: '—',
  ),
];

// Daily crash-free % for last 14 days (mock)
const _kDailyCrashFree14d = [
  99.41, 99.48, 99.52, 99.55, 99.50, 99.58, 99.61,
  99.59, 99.63, 99.60, 99.64, 99.62, 99.65, 99.62,
];

const _kDailyCrashFree30d = [
  99.12, 99.18, 99.22, 99.25, 99.28, 99.30, 99.32,
  99.35, 99.38, 99.40, 99.42, 99.44, 99.45, 99.47,
  99.48, 99.50, 99.52, 99.51, 99.53, 99.54, 99.55,
  99.56, 99.57, 99.58, 99.59, 99.60, 99.61, 99.62,
  99.63, 99.62,
];

enum _Window { d7, d14, d30 }

double _avgForWindow(_Window w) {
  final data = switch (w) {
    _Window.d7 => _kDailyCrashFree14d.sublist(7),
    _Window.d14 => _kDailyCrashFree14d,
    _Window.d30 => _kDailyCrashFree30d,
  };
  return data.reduce((a, b) => a + b) / data.length;
}

List<double> _seriesForWindow(_Window w) => switch (w) {
      _Window.d7 => _kDailyCrashFree14d.sublist(7),
      _Window.d14 => _kDailyCrashFree14d,
      _Window.d30 => _kDailyCrashFree30d,
    };

Map<String, dynamic> _trackerPayload({
  required _Window window,
  required bool refreshed,
}) {
  final avg = _avgForWindow(window);
  return {
    'endpoint': 'GET /api/v1/observability/crash-free/',
    'provider': 'Sentry (mock)',
    'window': window.name,
    'crash_free_sessions_pct': _kCurrentPct,
    'window_avg_pct': double.parse(avg.toStringAsFixed(2)),
    'target_pct': _kTargetPct,
    'gate_passing': _kCurrentPct >= _kTargetPct,
    'sessions_24h': 18420,
    'crashes_24h': 7,
    'last_refresh': refreshed ? 'just now' : '14 min ago',
    'open_issues': _kCrashIssues.where((i) => i.status != 'resolved').length,
    'wire_note': 'Mock Sentry dashboard · launch gate 99.5%',
  };
}

String _buildCrashReport({required _Window window}) {
  final avg = _avgForWindow(window);
  final buf = StringBuffer('ZapSafe Crash-Free Session Report\n\n');
  buf.writeln('Current: $_kCurrentPct%');
  buf.writeln('${window.name} avg: ${avg.toStringAsFixed(2)}%');
  buf.writeln('Target gate: $_kTargetPct%');
  buf.writeln('Status: ${_kCurrentPct >= _kTargetPct ? 'PASSING' : 'BELOW TARGET'}');
  buf.writeln();
  buf.writeln('── Recent issues ──');
  for (final i in _kCrashIssues) {
    buf.writeln('[${i.status}] ${i.title} · ${i.platform} · ${i.events} events');
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d288TabProvider = StateProvider<int>((ref) => 0);
final _d288WindowProvider = StateProvider<_Window>((ref) => _Window.d14);
final _d288RefreshingProvider = StateProvider<bool>((ref) => false);
final _d288RefreshedProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day288CrashFreeTrackerScreen extends ConsumerWidget {
  const Day288CrashFreeTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const passing = _kCurrentPct >= _kTargetPct;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 288 · Crash-Free Tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (passing ? ZapColors.safe : ZapColors.danger)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (passing ? ZapColors.safe : ZapColors.danger)
                        .withOpacity(0.45),
                  ),
                ),
                child: const Text(
                  'GATE OK',
                  style: TextStyle(
                    color: ZapColors.safe,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d288TabProvider),
            onSelect: (i) => ref.read(_d288TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d288TabProvider)) {
              0 => const _DashboardTab(),
              1 => const _TrendsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Dashboard ──────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  Future<void> _refresh(WidgetRef ref) async {
    if (ref.read(_d288RefreshingProvider)) return;
    ref.read(_d288RefreshingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    ref.read(_d288RefreshedProvider.notifier).state = true;
    ref.read(_d288RefreshingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshing = ref.watch(_d288RefreshingProvider);
    final openIssues =
        _kCrashIssues.where((i) => i.status != 'resolved').length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Sentry crash-free sessions',
          subtitle: 'Launch gate: ≥ $_kTargetPct% · mock production dashboard',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Column(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _kCurrentPct / 100,
                      strokeWidth: 12,
                      backgroundColor: ZapColors.border,
                      color: ZapColors.safe,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_kCurrentPct%',
                          style: TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        Text(
                          'crash-free',
                          style: TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ZapSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MiniStat(label: '24h sessions', value: '18.4k'),
                  _MiniStat(label: '24h crashes', value: '7'),
                  _MiniStat(
                    label: 'Target',
                    value: '$_kTargetPct%',
                    highlight: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: ZapColors.safe,
              ),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Launch gate passing — $_kCurrentPct% exceeds $_kTargetPct% target.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent issues',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            Text(
              '$openIssues open',
              style: TextStyle(
                color: openIssues == 0 ? ZapColors.safe : ZapColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kCrashIssues.map((issue) {
          final resolved = issue.status == 'resolved';
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  resolved ? Icons.check_circle_rounded : Icons.bug_report_rounded,
                  color: resolved ? ZapColors.safe : ZapColors.warning,
                  size: 20,
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${issue.platform} · ${issue.events} events · ${issue.users} users · '
                        '${issue.lastSeen}',
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (resolved ? ZapColors.safe : ZapColors.warning)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    issue.status.toUpperCase(),
                    style: TextStyle(
                      color: resolved ? ZapColors.safe : ZapColors.warning,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        FilledButton.icon(
          onPressed: refreshing ? null : () => _refresh(ref),
          icon: refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Pull Sentry metrics'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: highlight ? ZapColors.safe : ZapColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 9),
        ),
      ],
    );
  }
}

// ── Tab 1: Trends ─────────────────────────────────────────────────────────────
class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(_d288WindowProvider);
    final series = _seriesForWindow(window);
    final avg = _avgForWindow(window);
    final minVal = series.reduce(math.min);
    final maxVal = series.reduce(math.max);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Crash-free trend',
          subtitle: 'Daily session crash-free rate · dashed line = 99.5% gate',
        ),
        SegmentedButton<_Window>(
          segments: const [
            ButtonSegment(value: _Window.d7, label: Text('7d')),
            ButtonSegment(value: _Window.d14, label: Text('14d')),
            ButtonSegment(value: _Window.d30, label: Text('30d')),
          ],
          selected: {window},
          onSelectionChanged: (s) =>
              ref.read(_d288WindowProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${avg.toStringAsFixed(2)}% avg',
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'min $minVal · max $maxVal',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              SizedBox(
                height: 120,
                child: CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: _TrendPainter(
                    values: series,
                    target: _kTargetPct,
                    accent: _kAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...series.reversed.take(7).map((v) {
          final passing = v >= _kTargetPct;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${v.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: passing ? ZapColors.safe : ZapColors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (v - 98.5) / 1.5,
                      minHeight: 8,
                      backgroundColor: ZapColors.border,
                      color: passing ? ZapColors.safe : ZapColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _buildCrashReport(window: window)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Crash-free report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy trend report'),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.target,
    required this.accent,
  });

  final List<double> values;
  final double target;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const minY = 98.8;
    const maxY = 99.8;
    final w = size.width;
    final h = size.height;
    final dx = values.length <= 1 ? w : w / (values.length - 1);

    double yFor(double v) => h - ((v - minY) / (maxY - minY)) * h;

    final gateY = yFor(target);
    final gatePaint = Paint()
      ..color = ZapColors.warning.withOpacity(0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, gateY), Offset(w, gateY), gatePaint);

    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = yFor(values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = accent;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(i * dx, yFor(values[i])), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.target != target;
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _trackerPayload(
      window: ref.watch(_d288WindowProvider),
      refreshed: ref.watch(_d288RefreshedProvider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Crash-free session tracker',
          subtitle: 'Mock Sentry dashboard · ties to Day 287 launch gate.',
        ),
        const _PolicyRow(
          icon: Icons.speed_rounded,
          title: '99.5% launch gate',
          subtitle: 'Store release blocked if crash-free sessions drop below target.',
        ),
        const _PolicyRow(
          icon: Icons.timeline_rounded,
          title: '7d / 14d / 30d windows',
          subtitle: 'Trend chart with gate line · daily bar breakdown.',
        ),
        const _PolicyRow(
          icon: Icons.bug_report_rounded,
          title: 'Issue feed',
          subtitle: 'Resolved beta crashes · monitoring tablet layout edge case.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tracker spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 289 — Full App Regression '
            '(200+ screens · pass/fail · CSV export).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 287 Feedback R3'),
              onPressed: () => context.push(AppRoutes.betaFeedbackRound3),
            ),
            ActionChip(
              label: const Text('Day 136 Feedback R2'),
              onPressed: () => context.push(AppRoutes.feedbackRound2),
            ),
            ActionChip(
              label: const Text('Day 229 Regression'),
              onPressed: () => context.push(AppRoutes.featureRegressionRunner),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
