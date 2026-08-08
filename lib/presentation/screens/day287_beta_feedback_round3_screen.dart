/// Day 287 — Beta Feedback Round 3
///
/// Section E (Days 281-300): extends Day 136 feedback survey with post-polish
/// metrics after Sections C/D/E work — NPS, polish verification, Round 2 delta.
///
/// Tag: 🟣 POLISH · mock survey + metrics · no live analytics API.
///
/// Route: [AppRoutes.betaFeedbackRound3] → `/beta-feedback-round3`
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
const _kAccent = Color(0xFF8B5CF6);
const _kTabs = ['Survey', 'Metrics', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _SurveyAnswer { unset, yes, partial, no }

class _PolishQuestion {
  const _PolishQuestion({
    required this.id,
    required this.prompt,
    required this.dayLink,
  });

  final String id;
  final String prompt;
  final String dayLink;
}

const _kPolishQuestions = [
  _PolishQuestion(
    id: 'sos_ring',
    prompt: 'Is the SOS long-press ring clearer than beta-2?',
    dayLink: 'Day 203',
  ),
  _PolishQuestion(
    id: 'journey_v2',
    prompt: 'Does Journey mode v2 feel smoother to share?',
    dayLink: 'Day 241',
  ),
  _PolishQuestion(
    id: 'counselor_queue',
    prompt: 'Is counselor queue wait time understandable?',
    dayLink: 'Day 278',
  ),
  _PolishQuestion(
    id: 'prod_dashboard',
    prompt: 'Does the production dashboard build confidence?',
    dayLink: 'Day 279',
  ),
  _PolishQuestion(
    id: 'offline_sos',
    prompt: 'Did offline SOS UX improvements help?',
    dayLink: 'Day 245',
  ),
  _PolishQuestion(
    id: 'weekly_digest',
    prompt: 'Is Weekly Digest v2 useful without spam?',
    dayLink: 'Day 274',
  ),
  _PolishQuestion(
    id: 'landing',
    prompt: 'Does the in-app landing preview match store listing?',
    dayLink: 'Day 281',
  ),
  _PolishQuestion(
    id: 'overall_polish',
    prompt: 'Overall — ready for public launch polish?',
    dayLink: 'Section E',
  ),
];

class _PostPolishMetric {
  const _PostPolishMetric({
    required this.title,
    required this.round2,
    required this.round3,
    required this.unit,
    required this.lowerIsBetter,
    required this.icon,
  });

  final String title;
  final double round2;
  final double round3;
  final String unit;
  final bool lowerIsBetter;
  final IconData icon;

  double get deltaPct {
    if (round2 == 0) return 0;
    return lowerIsBetter
        ? ((round2 - round3) / round2) * 100
        : ((round3 - round2) / round2) * 100;
  }

  bool get improved => lowerIsBetter ? round3 < round2 : round3 > round2;
}

const _kPostPolishMetrics = [
  _PostPolishMetric(
    title: 'Crash-free sessions',
    round2: 99.1,
    round3: 99.6,
    unit: '%',
    lowerIsBetter: false,
    icon: Icons.bug_report_rounded,
  ),
  _PostPolishMetric(
    title: 'Beta NPS',
    round2: 42,
    round3: 58,
    unit: '',
    lowerIsBetter: false,
    icon: Icons.thumb_up_rounded,
  ),
  _PostPolishMetric(
    title: 'SOS false triggers / week',
    round2: 4.6,
    round3: 2.1,
    unit: '%',
    lowerIsBetter: true,
    icon: Icons.emergency_rounded,
  ),
  _PostPolishMetric(
    title: 'Counselor queue P95 wait',
    round2: 4.2,
    round3: 2.4,
    unit: ' min',
    lowerIsBetter: true,
    icon: Icons.support_agent_rounded,
  ),
  _PostPolishMetric(
    title: 'Journey share completion',
    round2: 61,
    round3: 74,
    unit: '%',
    lowerIsBetter: false,
    icon: Icons.map_rounded,
  ),
  _PostPolishMetric(
    title: 'Day-7 retention',
    round2: 43,
    round3: 51,
    unit: '%',
    lowerIsBetter: false,
    icon: Icons.trending_up_rounded,
  ),
];

String _answerLabel(_SurveyAnswer a) => switch (a) {
      _SurveyAnswer.yes => 'yes',
      _SurveyAnswer.partial => 'partial',
      _SurveyAnswer.no => 'no',
      _SurveyAnswer.unset => 'unset',
    };

_SurveyAnswer _answerFromLabel(String? s) => switch (s) {
      'yes' => _SurveyAnswer.yes,
      'partial' => _SurveyAnswer.partial,
      'no' => _SurveyAnswer.no,
      _ => _SurveyAnswer.unset,
    };

Map<String, dynamic> _feedbackPayload({
  required int nps,
  required Map<String, String> answers,
  required bool surveySent,
}) {
  final answered = answers.values.where((v) => v != 'unset').length;
  final yesCount = answers.values.where((v) => v == 'yes').length;
  return {
    'endpoint': 'POST /api/v1/beta/feedback-round3/',
    'extends': 'Day 136 Feedback Round 2',
    'survey_sent': surveySent,
    'nps_score': nps,
    'questions_answered': answered,
    'questions_total': _kPolishQuestions.length,
    'positive_rate': answered == 0 ? 0 : (yesCount / answered),
    'answers': answers,
    'metrics_vs_round2': _kPostPolishMetrics
        .map(
          (m) => {
            'title': m.title,
            'round2': m.round2,
            'round3': m.round3,
            'improved': m.improved,
          },
        )
        .toList(),
    'wire_note': 'Mock Round 3 · post-polish launch readiness signal',
  };
}

String _buildSurveyExport({
  required int nps,
  required Map<String, String> answers,
}) {
  final buf = StringBuffer('ZapSafe Beta Feedback Round 3\n\n');
  buf.writeln('NPS: $nps / 10');
  buf.writeln();
  for (final q in _kPolishQuestions) {
    final a = _answerFromLabel(answers[q.id]);
    buf.writeln(
        '[${_answerLabel(a).toUpperCase()}] ${q.prompt} (${q.dayLink})');
  }
  buf.writeln();
  buf.writeln('── vs Round 2 (Day 136) ──');
  for (final m in _kPostPolishMetrics) {
    final arrow = m.improved ? '↑' : '→';
    buf.writeln(
      '$arrow ${m.title}: ${m.round2}${m.unit} → ${m.round3}${m.unit}',
    );
  }
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d287TabProvider = StateProvider<int>((ref) => 0);
final _d287NpsProvider = StateProvider<int>((ref) => 8);
final _d287AnswersProvider = StateProvider<Map<String, String>>((ref) {
  return {for (final q in _kPolishQuestions) q.id: 'unset'};
});
final _d287SurveySentProvider = StateProvider<bool>((ref) => false);
final _d287SendingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day287BetaFeedbackRound3Screen extends ConsumerWidget {
  const Day287BetaFeedbackRound3Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(_d287AnswersProvider);
    final answered = answers.values.where((v) => v != 'unset').length;
    final nps = ref.watch(_d287NpsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 287 · Feedback Round 3'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  'NPS $nps · $answered/8',
                  style: const TextStyle(
                    color: _kAccent,
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
            tab: ref.watch(_d287TabProvider),
            onSelect: (i) => ref.read(_d287TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d287TabProvider)) {
              0 => const _SurveyTab(),
              1 => const _MetricsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Survey ─────────────────────────────────────────────────────────────
class _SurveyTab extends ConsumerWidget {
  const _SurveyTab();

  void _setAnswer(WidgetRef ref, String id, _SurveyAnswer answer) {
    ref.read(_d287AnswersProvider.notifier).state = {
      ...ref.read(_d287AnswersProvider),
      id: _answerLabel(answer),
    };
  }

  Future<void> _sendSurvey(WidgetRef ref, BuildContext context) async {
    if (ref.read(_d287SendingProvider)) return;
    ref.read(_d287SendingProvider.notifier).state = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    ref.read(_d287SurveySentProvider.notifier).state = true;
    ref.read(_d287SendingProvider.notifier).state = false;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Round 3 survey sent to beta cohort (mock).')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(_d287AnswersProvider);
    final nps = ref.watch(_d287NpsProvider);
    final sending = ref.watch(_d287SendingProvider);
    final sent = ref.watch(_d287SurveySentProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Post-polish beta survey',
          subtitle: 'Extends Day 136 Round 2 · 8 polish-focused questions',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.2),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Round 3 · post Sections C/D/E polish',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: ZapSpacing.xs),
              Text(
                'Measure whether polish work (Days 241-281) improved beta sentiment '
                'before store submission.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Net Promoter Score (0-10)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Slider(
          value: nps.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$nps',
          activeColor: _kAccent,
          onChanged: (v) =>
              ref.read(_d287NpsProvider.notifier).state = v.round(),
        ),
        Center(
          child: Text(
            nps >= 9
                ? 'Promoter'
                : nps >= 7
                    ? 'Passive'
                    : 'Detractor',
            style: TextStyle(
              color: nps >= 7 ? ZapColors.safe : ZapColors.warning,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kPolishQuestions.map((q) {
          final current = _answerFromLabel(answers[q.id]);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.dayLink,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  q.prompt,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Yes'),
                      selected: current == _SurveyAnswer.yes,
                      selectedColor: ZapColors.safe.withOpacity(0.25),
                      onSelected: (_) =>
                          _setAnswer(ref, q.id, _SurveyAnswer.yes),
                    ),
                    ChoiceChip(
                      label: const Text('Partial'),
                      selected: current == _SurveyAnswer.partial,
                      selectedColor: ZapColors.warning.withOpacity(0.25),
                      onSelected: (_) =>
                          _setAnswer(ref, q.id, _SurveyAnswer.partial),
                    ),
                    ChoiceChip(
                      label: const Text('No'),
                      selected: current == _SurveyAnswer.no,
                      selectedColor: ZapColors.danger.withOpacity(0.25),
                      onSelected: (_) =>
                          _setAnswer(ref, q.id, _SurveyAnswer.no),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        FilledButton.icon(
          onPressed: sending ? null : () => _sendSurvey(ref, context),
          icon: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(sent ? Icons.check_rounded : Icons.send_rounded, size: 18),
          label: Text(sent ? 'Survey sent' : 'Send to beta cohort'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildSurveyExport(nps: nps, answers: answers),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Survey export copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy survey export'),
        ),
      ],
    );
  }
}

// ── Tab 1: Metrics ────────────────────────────────────────────────────────────
class _MetricsTab extends ConsumerWidget {
  const _MetricsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final improved = _kPostPolishMetrics.where((m) => m.improved).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Post-polish metrics delta',
          subtitle: 'Round 3 vs Day 136 Round 2 baseline',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricStat(
                label: 'Improved',
                value: '$improved/${_kPostPolishMetrics.length}',
                color: ZapColors.safe,
              ),
              const _MetricStat(
                label: 'NPS delta',
                value: '+16',
                color: _kAccent,
              ),
              const _MetricStat(
                label: 'Crash-free',
                value: '99.6%',
                color: ZapColors.safe,
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kPostPolishMetrics.map((m) {
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (m.improved ? ZapColors.safe : ZapColors.warning)
                    .withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(m.icon, color: _kAccent, size: 22),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'R2: ${m.round2}${m.unit} → R3: ${m.round3}${m.unit}',
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      m.improved
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                      color: m.improved ? ZapColors.safe : ZapColors.warning,
                      size: 20,
                    ),
                    Text(
                      '${m.deltaPct >= 0 ? '+' : ''}${m.deltaPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: m.improved ? ZapColors.safe : ZapColors.warning,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'Polish verification highlights',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.check_circle_rounded,
          title: 'SOS ring + offline UX',
          subtitle:
              'False triggers down 54% · long-press comprehension up in survey.',
        ),
        const _PolicyRow(
          icon: Icons.check_circle_rounded,
          title: 'Counselor queue polish',
          subtitle: 'P95 wait 4.2 → 2.4 min · ETA ring rated "clear" by 81%.',
        ),
        const _PolicyRow(
          icon: Icons.schedule_rounded,
          title: 'Crash-free target',
          subtitle: '99.6% achieved · Day 288 tracker will monitor 99.5% gate.',
        ),
      ],
    );
  }
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
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
    final payload = _feedbackPayload(
      nps: ref.watch(_d287NpsProvider),
      answers: ref.watch(_d287AnswersProvider),
      surveySent: ref.watch(_d287SurveySentProvider),
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Beta Feedback Round 3',
          subtitle: 'Extends Day 136 · measures post-polish launch readiness.',
        ),
        const _PolicyRow(
          icon: Icons.poll_rounded,
          title: 'Survey extension',
          subtitle:
              '8 new questions on SOS, journey, counselor, dashboard polish.',
        ),
        const _PolicyRow(
          icon: Icons.analytics_rounded,
          title: 'Metrics comparison',
          subtitle: 'Round 2 baseline from Day 136 Sentry + retention pulls.',
        ),
        const _PolicyRow(
          icon: Icons.rocket_launch_rounded,
          title: 'Launch gate',
          subtitle: 'NPS ≥ 50 and crash-free ≥ 99.5% before public release.',
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
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
              const SnackBar(content: Text('Feedback spec copied.')),
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
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 288 — Crash-Free Session Tracker '
            '(mock Sentry dashboard · 99.5% target).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 136 Round 2'),
              onPressed: () => context.push(AppRoutes.feedbackRound2),
            ),
            ActionChip(
              label: const Text('Day 279 Dashboard'),
              onPressed: () => context.push(AppRoutes.productionDashboard),
            ),
            ActionChip(
              label: const Text('Day 278 Counselor'),
              onPressed: () => context.push(AppRoutes.counselorQueuePolish),
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
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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
