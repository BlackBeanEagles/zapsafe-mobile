/// Day 271 — Share Safe Route Card
///
/// Section D (Days 261-280): generate a shareable route card mock with map
/// preview, safety score ring, and messaging-app export actions.
///
/// Tag: 🟢 FRONTEND-ONLY · mock PNG/share export for WhatsApp-style handoff.
///
/// Route: [AppRoutes.shareSafeRoute] → `/share-safe-route`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF10B981);
const _kTabs = ['Preview', 'Customize', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _RoutePreset {
  const _RoutePreset({
    required this.id,
    required this.origin,
    required this.destination,
    required this.distance,
    required this.duration,
    required this.baseScore,
    required this.routePoints,
  });

  final String id;
  final String origin;
  final String destination;
  final String distance;
  final String duration;
  final int baseScore;
  final List<Offset> routePoints;
}

const _kRoutePresets = [
  _RoutePreset(
    id: 'kor-whitefield',
    origin: 'Koramangala 5th Block',
    destination: 'Whitefield ITPL',
    distance: '18.4 km',
    duration: '42 min',
    baseScore: 84,
    routePoints: [
      Offset(0.12, 0.78),
      Offset(0.22, 0.62),
      Offset(0.35, 0.55),
      Offset(0.48, 0.48),
      Offset(0.62, 0.38),
      Offset(0.78, 0.28),
      Offset(0.88, 0.18),
    ],
  ),
  _RoutePreset(
    id: 'indir-mg',
    origin: 'Indiranagar 100ft Rd',
    destination: 'MG Road Metro',
    distance: '6.2 km',
    duration: '18 min',
    baseScore: 91,
    routePoints: [
      Offset(0.15, 0.72),
      Offset(0.28, 0.58),
      Offset(0.42, 0.52),
      Offset(0.58, 0.44),
      Offset(0.72, 0.32),
    ],
  ),
  _RoutePreset(
    id: 'hsr-airport',
    origin: 'HSR Layout Sector 2',
    destination: 'Kempegowda T1',
    distance: '38.1 km',
    duration: '58 min',
    baseScore: 76,
    routePoints: [
      Offset(0.1, 0.82),
      Offset(0.2, 0.7),
      Offset(0.32, 0.6),
      Offset(0.45, 0.5),
      Offset(0.58, 0.42),
      Offset(0.7, 0.32),
      Offset(0.82, 0.22),
      Offset(0.9, 0.14),
    ],
  ),
];

enum _CardTheme { light, dark }

Color _scoreColor(int score) {
  if (score >= 85) return ZapColors.safe;
  if (score >= 70) return _kAccent;
  if (score >= 50) return ZapColors.warning;
  return ZapColors.danger;
}

String _scoreLabel(int score) {
  if (score >= 85) return 'Excellent';
  if (score >= 70) return 'Good';
  if (score >= 50) return 'Fair';
  return 'Caution';
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d271TabProvider = StateProvider<int>((ref) => 0);
final _d271RouteIndexProvider = StateProvider<int>((ref) => 0);
final _d271ScoreProvider = StateProvider<int>((ref) => 84);
final _d271CaptionProvider =
    StateProvider<String>((ref) => 'Taking the safer route tonight 🛡️');
final _d271ThemeProvider = StateProvider<_CardTheme>((ref) => _CardTheme.light);
final _d271IncludeEtaProvider = StateProvider<bool>((ref) => true);
final _d271IncludeScoreProvider = StateProvider<bool>((ref) => true);
final _d271ExportedProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day271ShareSafeRouteScreen extends ConsumerWidget {
  const Day271ShareSafeRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d271TabProvider);
    final exported = ref.watch(_d271ExportedProvider);
    final route = _kRoutePresets[ref.watch(_d271RouteIndexProvider)];
    final score = ref.watch(_d271ScoreProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 271 · Share Safe Route'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (exported ? ZapColors.safe : _kAccent)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (exported ? ZapColors.safe : _kAccent)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  exported ? 'EXPORTED ✅' : 'SCORE $score',
                  style: TextStyle(
                    color: exported ? ZapColors.safe : _kAccent,
                    fontSize: 11,
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
            tab: tab,
            onSelect: (i) => ref.read(_d271TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PreviewTab(route: route, score: score),
              1 => _CustomizeTab(route: route),
              _ => _InfoTab(route: route, score: score),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Preview ────────────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab({required this.route, required this.score});

  final _RoutePreset route;
  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = ref.watch(_d271CaptionProvider);
    final theme = ref.watch(_d271ThemeProvider);
    final includeEta = ref.watch(_d271IncludeEtaProvider);
    final includeScore = ref.watch(_d271IncludeScoreProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section D Day 11/20 · shareable route card · mock export',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Center(
          child: _ShareRouteCard(
            route: route,
            score: score,
            caption: caption,
            theme: theme,
            includeEta: includeEta,
            includeScore: includeScore,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () => _mockExport(context, ref, 'WhatsApp'),
          icon: const Icon(Icons.chat_rounded),
          label: const Text('Share to WhatsApp (mock)'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _mockExport(context, ref, 'Save PNG'),
                icon: const Icon(Icons.image_rounded, size: 18),
                label: const Text('Save PNG'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text: 'https://zapsafe.app/r/safe-route/kor-whitefield',
                    ),
                  );
                  ref.read(_d271ExportedProvider.notifier).state = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deep link copied to clipboard.')),
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Copy link'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () => _mockExport(context, ref, 'Share sheet'),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Open share sheet (mock)'),
        ),
      ],
    );
  }

  void _mockExport(BuildContext context, WidgetRef ref, String target) {
    ref.read(_d271ExportedProvider.notifier).state = true;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route card exported via $target (mock).')),
    );
  }
}

class _ShareRouteCard extends StatelessWidget {
  const _ShareRouteCard({
    required this.route,
    required this.score,
    required this.caption,
    required this.theme,
    required this.includeEta,
    required this.includeScore,
  });

  final _RoutePreset route;
  final int score;
  final String caption;
  final _CardTheme theme;
  final bool includeEta;
  final bool includeScore;

  @override
  Widget build(BuildContext context) {
    final isDark = theme == _CardTheme.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : ZapColors.textPrimary;
    final textSecondary =
        isDark ? Colors.white70 : ZapColors.textSecondary;
    final scoreColor = _scoreColor(score);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : ZapColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: _kAccent, size: 16),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZapSafe · Safe Route',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Shared journey card',
                        style: TextStyle(color: textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (includeScore)
                  _ScoreBadge(score: score, color: scoreColor),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _RouteMapPainter(
                    points: route.routePoints,
                    isDark: isDark,
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white)
                          .withOpacity(0.82),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RoutePinRow(
                          icon: Icons.trip_origin_rounded,
                          label: route.origin,
                          color: ZapColors.safe,
                          textColor: textPrimary,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Container(
                            width: 2,
                            height: 12,
                            color: _kAccent.withOpacity(0.5),
                          ),
                        ),
                        _RoutePinRow(
                          icon: Icons.place_rounded,
                          label: route.destination,
                          color: _kAccent,
                          textColor: textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (includeEta)
                  Row(
                    children: [
                      _MetaChip(
                        icon: Icons.straighten_rounded,
                        label: route.distance,
                        isDark: isDark,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      _MetaChip(
                        icon: Icons.schedule_rounded,
                        label: route.duration,
                        isDark: isDark,
                      ),
                      if (includeScore) ...[
                        const SizedBox(width: ZapSpacing.sm),
                        _MetaChip(
                          icon: Icons.verified_user_rounded,
                          label: _scoreLabel(score),
                          isDark: isDark,
                          accent: scoreColor,
                        ),
                      ],
                    ],
                  ),
                if (includeEta) const SizedBox(height: 10),
                Text(
                  caption,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'zapsafe.app · Safe routes for everyone',
                  style: TextStyle(color: textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _RoutePinRow extends StatelessWidget {
  const _RoutePinRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.accent,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? _kAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: ZapSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({required this.points, required this.isDark});

  final List<Offset> points;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFE0F2FE), const Color(0xFFDCFCE7)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      final y = size.height * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) return;

    final path = Path();
    final scaled = points
        .map(
          (p) => Offset(p.dx * size.width, p.dy * size.height),
        )
        .toList();
    path.moveTo(scaled.first.dx, scaled.first.dy);
    for (var i = 1; i < scaled.length; i++) {
      final prev = scaled[i - 1];
      final cur = scaled[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(scaled.last.dx, scaled.last.dy);

    final glowPaint = Paint()
      ..color = _kAccent.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = _kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    for (final pt in [scaled.first, scaled.last]) {
      canvas.drawCircle(
        pt,
        6,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        pt,
        4,
        Paint()..color = pt == scaled.first ? ZapColors.safe : _kAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.isDark != isDark;
}

// ── Tab 1: Customize ──────────────────────────────────────────────────────────
class _CustomizeTab extends ConsumerWidget {
  const _CustomizeTab({required this.route});

  final _RoutePreset route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeIdx = ref.watch(_d271RouteIndexProvider);
    final score = ref.watch(_d271ScoreProvider);
    final caption = ref.watch(_d271CaptionProvider);
    final theme = ref.watch(_d271ThemeProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Route preset',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...List.generate(_kRoutePresets.length, (i) {
          final r = _kRoutePresets[i];
          final selected = routeIdx == i;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: selected
                  ? _kAccent.withOpacity(0.08)
                  : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? _kAccent.withOpacity(0.45)
                    : ZapColors.border,
              ),
            ),
            child: ListTile(
              title: Text(
                '${r.origin} → ${r.destination}',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                '${r.distance} · ${r.duration} · base score ${r.baseScore}',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded, color: _kAccent)
                  : null,
              onTap: () {
                ref.read(_d271RouteIndexProvider.notifier).state = i;
                ref.read(_d271ScoreProvider.notifier).state = r.baseScore;
                ref.read(_d271ExportedProvider.notifier).state = false;
              },
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Safety score · $score',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Slider(
          value: score.toDouble(),
          min: 40,
          max: 100,
          divisions: 12,
          label: '$score',
          activeColor: _scoreColor(score),
          onChanged: (v) {
            ref.read(_d271ScoreProvider.notifier).state = v.round();
            ref.read(_d271ExportedProvider.notifier).state = false;
          },
        ),
        Text(
          _scoreLabel(score),
          style: TextStyle(color: _scoreColor(score), fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        TextFormField(
          key: ValueKey('caption-$routeIdx-$caption'),
          initialValue: caption,
          decoration: const InputDecoration(
            labelText: 'Card caption',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          onChanged: (v) {
            ref.read(_d271CaptionProvider.notifier).state = v;
            ref.read(_d271ExportedProvider.notifier).state = false;
          },
        ),
        const SizedBox(height: ZapSpacing.md),
        SegmentedButton<_CardTheme>(
          segments: const [
            ButtonSegment(
              value: _CardTheme.light,
              label: Text('Light card'),
              icon: Icon(Icons.light_mode_rounded, size: 16),
            ),
            ButtonSegment(
              value: _CardTheme.dark,
              label: Text('Dark card'),
              icon: Icon(Icons.dark_mode_rounded, size: 16),
            ),
          ],
          selected: {theme},
          onSelectionChanged: (s) {
            ref.read(_d271ThemeProvider.notifier).state = s.first;
            ref.read(_d271ExportedProvider.notifier).state = false;
          },
        ),
        const SizedBox(height: ZapSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show distance & ETA'),
          value: ref.watch(_d271IncludeEtaProvider),
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d271IncludeEtaProvider.notifier).state = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show safety score badge'),
          value: ref.watch(_d271IncludeScoreProvider),
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d271IncludeScoreProvider.notifier).state = v,
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.route, required this.score});

  final _RoutePreset route;
  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exported = ref.watch(_d271ExportedProvider);
    final caption = ref.watch(_d271CaptionProvider);

    final payload = {
      'endpoint': 'POST /api/v1/journey/share-card/',
      'route_id': route.id,
      'origin': route.origin,
      'destination': route.destination,
      'distance': route.distance,
      'duration': route.duration,
      'safety_score': score,
      'caption': caption,
      'exported': exported,
      'export_targets': ['whatsapp', 'share_sheet', 'save_png', 'deep_link'],
      'deep_link': 'https://zapsafe.app/r/safe-route/${route.id}',
      'card_dimensions': '1080×1350 PNG (mock)',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.image_rounded,
          title: 'Shareable route card',
          subtitle:
              'Branded card with mock map polyline, origin/destination pins, '
              'safety score ring, and caption for messaging apps.',
        ),
        const _PolicyRow(
          icon: Icons.share_rounded,
          title: 'Mock export',
          subtitle:
              'WhatsApp, share sheet, Save PNG, and deep link copy — frontend '
              'mock only · real export uses RepaintBoundary + share_plus.',
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
              const SnackBar(content: Text('Share card spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy share card spec'),
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
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 241 Journey Mode v2'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
            ),
            ActionChip(
              label: const Text('Day 257 Widget Score'),
              onPressed: () => context.push(AppRoutes.homeWidgetScore),
            ),
            ActionChip(
              label: const Text('Day 270 Community Heatmap'),
              onPressed: () => context.push(AppRoutes.communityHeatmap),
            ),
          ],
        ),
      ],
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
