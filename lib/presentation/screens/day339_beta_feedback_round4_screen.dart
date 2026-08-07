/// Day 339 — Beta Feedback Round 4
///
/// Section I (Days 331-340): extends
/// `day287_beta_feedback_round3_screen.dart` (Round 3 — 8 post-polish
/// questions + NPS + metric deltas vs Round 2). Round 4 adds the three
/// fields this spec actually asks for — NPS, an SOS-confidence rating, and
/// a self-reported false-positive rate "since RC" — and swaps Round 3's
/// eight Section-C/D/E polish questions for eight new ones covering
/// Section I hardening (Days 331-338: gate, regression, parity, soak,
/// accessibility, security, legal, Sentry).
///
/// **"Since RC" honesty note.** Round 3's `dayLink` pointers (and the spec
/// text itself) assume a `Day 330` "v9.2 RC Ready" milestone exists as the
/// release-candidate anchor. That milestone was built on `main` (commit
/// `563f5f9`) but Days 311-330 were never merged into this branch's
/// history — `git merge-base --is-ancestor 563f5f9 HEAD` returns false.
/// The closest real RC-adjacent checkpoint actually present in *this*
/// worktree is Day 331's Go/No-Go Gate v2, so "since RC" below is anchored
/// there instead of inventing a Day 330 screen that doesn't exist here.
///
/// **Submission target — checked, not assumed.** The spec says "submit to
/// a real analytics custom-event POST if `analytics_api_service.dart`
/// supports custom events". It was read directly this session
/// (`lib/data/services/analytics_api_service.dart`): it exposes exactly
/// four endpoints — `sos-summary/`, `detections/`,
/// `contacts/response-rate/`, `device-health/` (GET, plus one POST for
/// device-health only) — and the backend
/// (`zapsafe_backend/analytics/urls.py`) confirms the same four routes
/// plus a staff-only `trigger-aggregate/`. No custom-event endpoint exists
/// on either side. Per the spec's own fallback instruction, this screen
/// does NOT claim a live POST — it uses a real local log via
/// `SharedPreferences`, this project's established non-Hive precedent
/// (Day 306 `NotificationTierAckStorage`, Day 334's soak log). The log
/// starts empty and stays empty until a real beta tester actually submits.
///
/// Tag: 🟣 POLISH · real local log (no live analytics endpoint exists to
/// call) · no fabricated survey responses.
///
/// Route: [AppRoutes.betaFeedbackRound4] → `/day-339-beta-feedback-round4`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF8B5CF6);
const _kTabs = ['Survey', 'Submissions', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKey = 'day339_beta_feedback_round4_v1';

// Round 3 baseline, read directly from day287_beta_feedback_round3_screen.dart
// _kPostPolishMetrics this session — shown for context only, not recomputed.
const _kRound3Nps = 58;
const _kRound3FalseTriggerPct = 2.1;

enum _SurveyAnswer { unset, yes, partial, no }

class _HardeningQuestion {
  const _HardeningQuestion({required this.id, required this.prompt, required this.dayLink});
  final String id;
  final String prompt;
  final String dayLink;
}

const _kHardeningQuestions = [
  _HardeningQuestion(id: 'gonogo', prompt: 'Does the Go/No-Go gate (Day 331) make you trust the release process?', dayLink: 'Day 331'),
  _HardeningQuestion(id: 'regression', prompt: 'Did you notice fewer broken screens than earlier betas?', dayLink: 'Day 332'),
  _HardeningQuestion(id: 'parity', prompt: 'Does the app feel consistent across your Android/iOS devices?', dayLink: 'Day 333'),
  _HardeningQuestion(id: 'battery', prompt: 'Has battery drain during monitoring improved?', dayLink: 'Day 334'),
  _HardeningQuestion(id: 'a11y', prompt: 'Is the app easier to use with accessibility tools (TalkBack/VoiceOver, larger text)?', dayLink: 'Day 335'),
  _HardeningQuestion(id: 'security', prompt: 'Do you feel your data is handled securely?', dayLink: 'Day 336'),
  _HardeningQuestion(id: 'legal', prompt: 'Is it clear how to export or delete your data?', dayLink: 'Day 337'),
  _HardeningQuestion(id: 'crashfree', prompt: 'Has app stability (crashes/freezes) improved recently?', dayLink: 'Day 338'),
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

class _FeedbackEntry {
  const _FeedbackEntry({
    required this.id,
    required this.submittedAt,
    required this.nps,
    required this.sosConfidence,
    required this.falsePositiveRatePct,
    required this.answers,
  });

  final String id;
  final DateTime submittedAt;
  final int nps;
  final int sosConfidence;
  final double falsePositiveRatePct;
  final Map<String, String> answers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'submitted_at': submittedAt.toIso8601String(),
        'nps': nps,
        'sos_confidence': sosConfidence,
        'false_positive_rate_pct_since_rc': falsePositiveRatePct,
        'answers': answers,
      };

  factory _FeedbackEntry.fromJson(Map<String, dynamic> j) => _FeedbackEntry(
        id: j['id'] as String,
        submittedAt: DateTime.parse(j['submitted_at'] as String),
        nps: (j['nps'] as num?)?.toInt() ?? 0,
        sosConfidence: (j['sos_confidence'] as num?)?.toInt() ?? 0,
        falsePositiveRatePct: (j['false_positive_rate_pct_since_rc'] as num?)?.toDouble() ?? 0,
        answers: (j['answers'] as Map?)?.cast<String, String>() ?? const {},
      );
}

class _FeedbackLogNotifier extends StateNotifier<List<_FeedbackEntry>> {
  _FeedbackLogNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kPrefsKey);
      if (raw != null) {
        state = raw
            .map((s) => _FeedbackEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      }
    } catch (_) {
      // Best-effort load — an empty log is a safe fallback.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefsKey, state.map((e) => jsonEncode(e.toJson())).toList());
    } catch (_) {
      // Non-fatal — in-memory state is still correct for this session.
    }
  }

  void add(_FeedbackEntry entry) {
    state = [entry, ...state];
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final _d339LogProvider = StateNotifierProvider<_FeedbackLogNotifier, List<_FeedbackEntry>>(
  (ref) => _FeedbackLogNotifier(),
);
final _d339TabProvider = StateProvider<int>((ref) => 0);
final _d339NpsProvider = StateProvider<int>((ref) => 8);
final _d339SosConfidenceProvider = StateProvider<int>((ref) => 8);
final _d339AnswersProvider = StateProvider<Map<String, String>>((ref) {
  return {for (final q in _kHardeningQuestions) q.id: 'unset'};
});

({double avgNps, double avgSos, double avgFpr}) _aggregate(List<_FeedbackEntry> entries) {
  if (entries.isEmpty) return (avgNps: 0, avgSos: 0, avgFpr: 0);
  final n = entries.length;
  return (
    avgNps: entries.map((e) => e.nps).reduce((a, b) => a + b) / n,
    avgSos: entries.map((e) => e.sosConfidence).reduce((a, b) => a + b) / n,
    avgFpr: entries.map((e) => e.falsePositiveRatePct).reduce((a, b) => a + b) / n,
  );
}

Map<String, dynamic> _feedbackPayload(List<_FeedbackEntry> entries) {
  final agg = _aggregate(entries);
  return {
    'submission_target': 'LOCAL LOG (SharedPreferences) — '
        'analytics_api_service.dart has no custom-event POST endpoint; '
        'confirmed by reading the file + zapsafe_backend/analytics/urls.py '
        'this session. Only sos-summary/, detections/, '
        'contacts/response-rate/, device-health/ exist.',
    'extends': 'Day 287 Beta Feedback Round 3',
    'rc_anchor': 'Day 331 Go/No-Go Gate v2 (Day 330 v9.2 RC milestone is on '
        'main but not merged into this worktree branch)',
    'submissions_logged': entries.length,
    'avg_nps': double.parse(agg.avgNps.toStringAsFixed(1)),
    'avg_sos_confidence': double.parse(agg.avgSos.toStringAsFixed(1)),
    'avg_false_positive_rate_pct_since_rc': double.parse(agg.avgFpr.toStringAsFixed(2)),
    'round3_baseline_nps': _kRound3Nps,
    'round3_baseline_false_trigger_pct': _kRound3FalseTriggerPct,
  };
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day339BetaFeedbackRound4Screen extends ConsumerWidget {
  const Day339BetaFeedbackRound4Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d339LogProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day331_340.beta_feedback_r4_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text('${entries.length} submissions', style: const TextStyle(
                  color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900,
                )),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d339TabProvider), onSelect: (i) => ref.read(_d339TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d339TabProvider)) {
              0 => const _SurveyTab(),
              1 => const _SubmissionsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Survey ─────────────────────────────────────────────────────────────
class _SurveyTab extends ConsumerStatefulWidget {
  const _SurveyTab();

  @override
  ConsumerState<_SurveyTab> createState() => _SurveyTabState();
}

class _SurveyTabState extends ConsumerState<_SurveyTab> {
  final _fprController = TextEditingController();

  @override
  void dispose() {
    _fprController.dispose();
    super.dispose();
  }

  void _setAnswer(String id, _SurveyAnswer answer) {
    ref.read(_d339AnswersProvider.notifier).state = {
      ...ref.read(_d339AnswersProvider),
      id: _answerLabel(answer),
    };
  }

  void _submit() {
    final fpr = double.tryParse(_fprController.text);
    if (fpr == null || fpr < 0 || fpr > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a false-positive rate % between 0 and 100.')),
      );
      return;
    }
    ref.read(_d339LogProvider.notifier).add(_FeedbackEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          submittedAt: DateTime.now(),
          nps: ref.read(_d339NpsProvider),
          sosConfidence: ref.read(_d339SosConfidenceProvider),
          falsePositiveRatePct: fpr,
          answers: ref.read(_d339AnswersProvider),
        ));
    _fprController.clear();
    ref.read(_d339AnswersProvider.notifier).state = {for (final q in _kHardeningQuestions) q.id: 'unset'};
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Round 4 feedback logged locally (no live analytics endpoint exists to POST to).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(_d339AnswersProvider);
    final nps = ref.watch(_d339NpsProvider);
    final sos = ref.watch(_d339SosConfidenceProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_kAccent.withOpacity(0.2), ZapColors.bgCard],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Round 4 · post Section I hardening', style: TextStyle(
                color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900,
              )),
              SizedBox(height: 4),
              Text(
                'Extends Day 287 Round 3 with NPS, SOS confidence, and a '
                'self-reported false-positive rate since the RC checkpoint '
                '(Day 331 gate — Day 330\'s RC milestone isn\'t in this '
                'worktree). No live analytics endpoint exists for this — '
                'answers are saved to a real local log, not simulated.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Net Promoter Score (0-10)', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        Slider(
          value: nps.toDouble(), min: 0, max: 10, divisions: 10, label: '$nps',
          activeColor: _kAccent,
          onChanged: (v) => ref.read(_d339NpsProvider.notifier).state = v.round(),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text('SOS confidence — "I trust ZapSafe will detect a real emergency" (0-10)', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        Slider(
          value: sos.toDouble(), min: 0, max: 10, divisions: 10, label: '$sos',
          activeColor: ZapColors.safe,
          onChanged: (v) => ref.read(_d339SosConfidenceProvider.notifier).state = v.round(),
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          controller: _fprController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'False-positive rate since RC (%, self-reported)',
            helperText: 'Round 3 baseline (Day 287): $_kRound3FalseTriggerPct% · this is per-tester, not aggregate',
            helperMaxLines: 2,
            filled: true, fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Section I hardening — did you notice?', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12,
        )),
        const SizedBox(height: ZapSpacing.sm),
        ..._kHardeningQuestions.map((q) {
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
                Text(q.dayLink, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(q.prompt, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Yes'), selected: current == _SurveyAnswer.yes,
                      selectedColor: ZapColors.safe.withOpacity(0.25),
                      onSelected: (_) => _setAnswer(q.id, _SurveyAnswer.yes),
                    ),
                    ChoiceChip(
                      label: const Text('Partial'), selected: current == _SurveyAnswer.partial,
                      selectedColor: ZapColors.warning.withOpacity(0.25),
                      onSelected: (_) => _setAnswer(q.id, _SurveyAnswer.partial),
                    ),
                    ChoiceChip(
                      label: const Text('No'), selected: current == _SurveyAnswer.no,
                      selectedColor: ZapColors.danger.withOpacity(0.25),
                      onSelected: (_) => _setAnswer(q.id, _SurveyAnswer.no),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit Round 4 feedback'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
      ],
    );
  }
}

// ── Tab 1: Submissions ─────────────────────────────────────────────────────────
class _SubmissionsTab extends ConsumerWidget {
  const _SubmissionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d339LogProvider);
    final agg = _aggregate(entries);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Text(
              'No Round 4 submissions yet — this beta cohort hasn\'t '
              'responded in this environment. Averages below appear once '
              'real submissions exist.',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          )
        else ...[
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
                _MetricStat(label: 'Avg NPS', value: agg.avgNps.toStringAsFixed(1), color: _kAccent),
                _MetricStat(label: 'Avg SOS confidence', value: agg.avgSos.toStringAsFixed(1), color: ZapColors.safe),
                _MetricStat(label: 'Avg FPR since RC', value: '${agg.avgFpr.toStringAsFixed(1)}%', color: ZapColors.warning),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.info.withOpacity(0.3)),
            ),
            child: Text(
              'vs Round 3 baseline (Day 287, context only): NPS $_kRound3Nps, '
              'false triggers/week $_kRound3FalseTriggerPct%.',
              style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          ...entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZapColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NPS ${e.nps} · SOS confidence ${e.sosConfidence} · FPR ${e.falsePositiveRatePct}%',
                        style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                    Text(e.submittedAt.toIso8601String(), style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
                    const SizedBox(height: 4),
                    Text(
                      '${e.answers.values.where((v) => v == 'yes').length}/${_kHardeningQuestions.length} yes',
                      style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => ref.read(_d339LogProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_rounded, size: 16),
            label: const Text('Clear all submissions'),
          ),
        ],
      ],
    );
  }
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9)),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_d339LogProvider);
    final payload = _feedbackPayload(entries);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Beta Feedback Round 4', style: TextStyle(
          color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13,
        )),
        const Text(
          'Section I Day 9/10 · extends Day 287 Round 3 · no live '
          'custom-event analytics endpoint exists, so this is a real '
          'local log, not a live POST.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
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
            _kJsonEncoder.convert(payload),
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 287 Round 3'), onPressed: () => context.push(AppRoutes.betaFeedbackRound3)),
            ActionChip(label: const Text('Day 331 Go/No-Go Gate v2'), onPressed: () => context.push(AppRoutes.gonogoGateV2)),
          ],
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
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2)),
                ),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(
                  color: selected ? _kAccent : ZapColors.textMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                )),
              ),
            ),
          );
        }),
      ),
    );
  }
}
