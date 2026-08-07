/// Day 257 — Home Screen Widget — Protection Score
///
/// Section C (Days 241-260): mock preview + setup guide for Android/iOS home
/// screen protection score ring widget — at-a-glance safety score with tap
/// to open full score breakdown (Day 59).
///
/// Tag: 🟢 FRONTEND-ONLY · score ring widget mock · configuration checklist.
///
/// Route: [AppRoutes.homeWidgetScore] → `/home-widget-score`
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
const _kAccent = Color(0xFF059669);
const _kTabs = ['Preview', 'Setup', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kScoreFactors = [
  _ScoreFactor(label: 'Tier 1 contacts', points: 25, max: 25),
  _ScoreFactor(label: 'Location enabled', points: 20, max: 25),
  _ScoreFactor(label: 'Recent drills', points: 15, max: 20),
  _ScoreFactor(label: 'Journey usage', points: 10, max: 15),
  _ScoreFactor(label: 'Permissions', points: 8, max: 15),
];

const _kAndroidSteps = [
  _SetupStep(
    title: 'Long-press home screen',
    detail: 'Open Widgets · search ZapSafe.',
  ),
  _SetupStep(
    title: 'Add Protection Score widget',
    detail: 'Choose Score Ring (2×2) or Score + Tips (4×2).',
  ),
  _SetupStep(
    title: 'Allow background refresh',
    detail: 'Widget updates every 30 min (WorkManager / BGTask).',
  ),
  _SetupStep(
    title: 'Sign in required',
    detail: 'Widget shows — until account linked on device.',
  ),
  _SetupStep(
    title: 'Tap to open app',
    detail: 'Deep link zapsafe://protection-score → Day 59 screen.',
  ),
];

const _kIosSteps = [
  _SetupStep(
    title: 'Edit Home Screen',
    detail: 'Add Widget → ZapSafe Protection Score.',
  ),
  _SetupStep(
    title: 'Choose size',
    detail: 'Small ring or Medium ring + improvement tips.',
  ),
  _SetupStep(
    title: 'Enable refresh',
    detail: 'WidgetKit timeline · updates on app foreground.',
  ),
  _SetupStep(
    title: 'Sign in on device',
    detail: 'Score syncs from GET /api/v1/protection-score/.',
  ),
  _SetupStep(
    title: 'Tap widget',
    detail: 'Opens protection score breakdown in app.',
  ),
];

enum _WidgetPlatform { android, ios }

enum _WidgetSize { small, medium }

// ── Models ────────────────────────────────────────────────────────────────────
class _SetupStep {
  const _SetupStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

class _ScoreFactor {
  const _ScoreFactor({
    required this.label,
    required this.points,
    required this.max,
  });

  final String label;
  final int points;
  final int max;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d257TabProvider = StateProvider<int>((ref) => 0);
final _d257PlatformProvider =
    StateProvider<_WidgetPlatform>((ref) => _WidgetPlatform.android);
final _d257SizeProvider =
    StateProvider<_WidgetSize>((ref) => _WidgetSize.small);
final _d257ScoreProvider = StateProvider<int>((ref) => 78);
final _d257AndroidStepsDoneProvider =
    StateProvider<Set<int>>((ref) => {0});
final _d257IosStepsDoneProvider = StateProvider<Set<int>>((ref) => {});
final _d257TapCountProvider = StateProvider<int>((ref) => 0);

List<_SetupStep> _stepsForPlatform(_WidgetPlatform platform) {
  return platform == _WidgetPlatform.android ? _kAndroidSteps : _kIosSteps;
}

Color _scoreColor(int score) {
  if (score >= 80) return ZapColors.safe;
  if (score >= 60) return ZapColors.warning;
  return ZapColors.danger;
}

String _scoreLabel(int score) {
  if (score >= 80) return 'Strong';
  if (score >= 60) return 'Fair';
  return 'Needs work';
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day257HomeWidgetScoreScreen extends ConsumerWidget {
  const Day257HomeWidgetScoreScreen({super.key});

  void _openScoreFromWidget(BuildContext context, WidgetRef ref) {
    ref.read(_d257TapCountProvider.notifier).state =
        ref.read(_d257TapCountProvider) + 1;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Widget tapped · opening Protection Score (mock).',
        ),
        action: SnackBarAction(
          label: 'Day 59',
          onPressed: () => context.push(AppRoutes.protectionScore),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d257TabProvider);
    final score = ref.watch(_d257ScoreProvider);
    final tapCount = ref.watch(_d257TapCountProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 257 · Score Widget'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _scoreColor(score).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: _scoreColor(score),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (tapCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.sm),
              child: Center(
                child: Text(
                  '$tapCount tap${tapCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
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
            onSelect: (i) => ref.read(_d257TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PreviewTab(
                  onWidgetTap: () => _openScoreFromWidget(context, ref),
                ),
              1 => const _SetupTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Preview ────────────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab({required this.onWidgetTap});

  final VoidCallback onWidgetTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d257PlatformProvider);
    final size = ref.watch(_d257SizeProvider);
    final score = ref.watch(_d257ScoreProvider);
    final isAndroid = platform == _WidgetPlatform.android;

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
            '🟢 FRONTEND-ONLY · Section C Day 17/20 · score ring widget mock',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SegmentedButton<_WidgetPlatform>(
          segments: const [
            ButtonSegment(
              value: _WidgetPlatform.android,
              label: Text('Android'),
              icon: Icon(Icons.android_rounded, size: 16),
            ),
            ButtonSegment(
              value: _WidgetPlatform.ios,
              label: Text('iOS'),
              icon: Icon(Icons.phone_iphone_rounded, size: 16),
            ),
          ],
          selected: {platform},
          onSelectionChanged: (s) =>
              ref.read(_d257PlatformProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Small 2×2'),
              selected: size == _WidgetSize.small,
              onSelected: (_) =>
                  ref.read(_d257SizeProvider.notifier).state = _WidgetSize.small,
            ),
            ChoiceChip(
              label: const Text('Medium 4×2'),
              selected: size == _WidgetSize.medium,
              onSelected: (_) => ref.read(_d257SizeProvider.notifier).state =
                  _WidgetSize.medium,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Mock score: $score · ${_scoreLabel(score)}',
          style: TextStyle(
            color: _scoreColor(score),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Slider(
          value: score.toDouble(),
          min: 35,
          max: 100,
          divisions: 13,
          label: '$score',
          activeColor: _scoreColor(score),
          onChanged: (v) =>
              ref.read(_d257ScoreProvider.notifier).state = v.round(),
        ),
        Center(
          child: _PhoneMockFrame(
            isAndroid: isAndroid,
            child: _ScoreWidgetPreview(
              score: score,
              size: size,
              isAndroid: isAndroid,
              onTap: onWidgetTap,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Tap the widget to simulate opening the full Protection Score screen. '
          'Use the slider to preview ring colors at different scores.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Tab 1: Setup ──────────────────────────────────────────────────────────────
class _SetupTab extends ConsumerWidget {
  const _SetupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d257PlatformProvider);
    final steps = _stepsForPlatform(platform);
    final done = platform == _WidgetPlatform.android
        ? ref.watch(_d257AndroidStepsDoneProvider)
        : ref.watch(_d257IosStepsDoneProvider);
    final progress = done.length / steps.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SegmentedButton<_WidgetPlatform>(
          segments: const [
            ButtonSegment(
              value: _WidgetPlatform.android,
              label: Text('Android'),
              icon: Icon(Icons.android_rounded, size: 16),
            ),
            ButtonSegment(
              value: _WidgetPlatform.ios,
              label: Text('iOS'),
              icon: Icon(Icons.phone_iphone_rounded, size: 16),
            ),
          ],
          selected: {platform},
          onSelectionChanged: (s) =>
              ref.read(_d257PlatformProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: ZapColors.bgCard,
                  color: _kAccent,
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            Text(
              '${done.length}/${steps.length}',
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final checked = done.contains(i);
          return _SetupStepTile(
            index: i + 1,
            step: step,
            checked: checked,
            onChanged: (v) {
              if (platform == _WidgetPlatform.android) {
                final set =
                    Set<int>.from(ref.read(_d257AndroidStepsDoneProvider));
                if (v) {
                  set.add(i);
                } else {
                  set.remove(i);
                }
                ref.read(_d257AndroidStepsDoneProvider.notifier).state = set;
              } else {
                final set = Set<int>.from(ref.read(_d257IosStepsDoneProvider));
                if (v) {
                  set.add(i);
                } else {
                  set.remove(i);
                }
                ref.read(_d257IosStepsDoneProvider.notifier).state = set;
              }
            },
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.protectionScore),
          icon: const Icon(Icons.shield_rounded),
          label: const Text('Day 59 · Full Protection Score'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(_d257ScoreProvider);
    final tapCount = ref.watch(_d257TapCountProvider);

    final spec = {
      'widget_id': 'zapsafe_score_ring_v1',
      'platforms': ['android', 'ios'],
      'sizes': ['2x2', '4x2'],
      'action': 'zapsafe://protection-score',
      'data_source': 'GET /api/v1/protection-score/',
      'refresh_interval_minutes': 30,
      'mock_score': score,
      'preview_taps': tapCount,
      'factors': _kScoreFactors
          .map((f) => {'label': f.label, 'points': f.points, 'max': f.max})
          .toList(),
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Home Screen Widget — Protection Score',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Glanceable safety score on the home screen — ring color reflects '
          'score band (green ≥80, amber ≥60, red below). Medium size shows '
          'top improvement tip. Pairs with Day 59 full breakdown.',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(spec),
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
              ClipboardData(text: _kJsonEncoder.convert(spec)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Score widget spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy widget spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.sync_rounded,
          title: 'Background refresh',
          subtitle:
              'Android WorkManager + iOS WidgetKit timeline reload score '
              'without opening app · stale badge if >24h.',
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
              label: const Text('Day 256 SOS Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetSos),
            ),
            ActionChip(
              label: const Text('Day 59 Protection Score'),
              onPressed: () => context.push(AppRoutes.protectionScore),
            ),
            ActionChip(
              label: const Text('Day 253 Family Dashboard'),
              onPressed: () => context.push(AppRoutes.familyAlertsDashboard),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Preview widgets ───────────────────────────────────────────────────────────
class _PhoneMockFrame extends StatelessWidget {
  const _PhoneMockFrame({
    required this.isAndroid,
    required this.child,
  });

  final bool isAndroid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ZapColors.border, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ZapColors.textMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: double.infinity,
            height: 360,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: isAndroid
                    ? [const Color(0xFF134E4A), const Color(0xFF042F2E)]
                    : [const Color(0xFF0F172A), const Color(0xFF1E3A5F)],
              ),
            ),
            child: Align(alignment: Alignment.center, child: child),
          ),
        ],
      ),
    );
  }
}

class _ScoreWidgetPreview extends StatelessWidget {
  const _ScoreWidgetPreview({
    required this.score,
    required this.size,
    required this.isAndroid,
    required this.onTap,
  });

  final int score;
  final _WidgetSize size;
  final bool isAndroid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score);
    final radius = isAndroid ? 16.0 : 20.0;
    final isSmall = size == _WidgetSize.small;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: isSmall ? 120 : 220,
          height: isSmall ? 120 : 100,
          padding: EdgeInsets.all(isSmall ? 10 : 12),
          decoration: BoxDecoration(
            color: ZapColors.bgCard.withOpacity(0.95),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: isSmall
              ? _SmallScoreBody(score: score, color: color)
              : _MediumScoreBody(score: score, color: color),
        ),
      ),
    );
  }
}

class _SmallScoreBody extends StatelessWidget {
  const _SmallScoreBody({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 7,
                color: color,
                backgroundColor: color.withOpacity(0.15),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _scoreLabel(score),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _MediumScoreBody extends StatelessWidget {
  const _MediumScoreBody({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tip = score >= 80
        ? 'Great job — run a drill this week'
        : score >= 60
            ? 'Add Tier 2 contact (+10 pts)'
            : 'Enable location (+20 pts)';

    return Row(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 6,
                color: color,
                backgroundColor: color.withOpacity(0.15),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Protection Score',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                _scoreLabel(score),
                style: TextStyle(color: color, fontSize: 10),
              ),
              const SizedBox(height: ZapSpacing.xs),
              Text(
                tip,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 9,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupStepTile extends StatelessWidget {
  const _SetupStepTile({
    required this.index,
    required this.step,
    required this.checked,
    required this.onChanged,
  });

  final int index;
  final _SetupStep step;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked ? _kAccent.withOpacity(0.06) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? _kAccent.withOpacity(0.35) : ZapColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: _kAccent,
        title: Text(
          '$index. ${step.title}',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          step.detail,
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 11,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ZapColors.info, size: 20),
        const SizedBox(width: 10),
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
