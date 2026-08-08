/// Day 362 — Play Store Submission Executor
///
/// Section L (Days 361-365, Public Launch Week): a step-by-step Play
/// Console submission checklist. Google Play Console has no public API that
/// lets an app submit itself for review — every step below is a REAL manual
/// action a human takes in the Play Console web UI. This screen is a
/// checklist/tracker for that manual process, not an automation of it.
///
/// **The app has not been submitted.** Every step defaults to unchecked.
/// Checking a box here does not call any Play Console API — it only tracks
/// local progress through the real manual workflow. Day 361's War Room gate
/// (5 open P0s, including debug-signed release keys and no cert pinning)
/// should block "signed AAB upload" in practice until those are fixed —
/// this screen deliberately does not hide that by pre-checking anything.
///
/// `android/app/build.gradle` sets `targetSdkVersion flutter.targetSdkVersion`
/// (Flutter's own default, not pinned by this project) — real finding,
/// verify against Play Console's current minimum target API requirement at
/// actual submission time rather than trusting a number typed here.
///
/// Country/rollout staging is Day 316's job (`day316_play_staged_rollout_screen.dart`)
/// — this screen links to it rather than re-implementing that simulation.
///
/// Tag: 🟢 FRONTEND-ONLY · real manual-step checklist · nothing submitted.
///
/// Route: [AppRoutes.playStoreSubmission] → `/day-362-play-store-submission`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF34A853);
const _kTabs = ['Steps', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _SubmissionStep {
  const _SubmissionStep({
    required this.id,
    required this.title,
    required this.detail,
    required this.manualNote,
  });

  final String id;
  final String title;
  final String detail;
  final String manualNote;
}

const _kSteps = [
  _SubmissionStep(
    id: 'content_rating',
    title: 'Content rating questionnaire (IARC)',
    detail: 'Play Console → App content → Content ratings → complete the '
        'IARC questionnaire (violence, safety-app category disclosures, '
        'location access, user-generated content).',
    manualNote: 'Manual — no Play Developer API exposes this form.',
  ),
  _SubmissionStep(
    id: 'data_safety',
    title: 'Data safety section',
    detail: 'Declare every data type collected/shared: precise location '
        '(SOS/journey), contacts, audio (evidence vault), device ID. Must '
        'match this app\'s actual permissions and Day 337\'s DPDP findings — '
        'do not under-declare.',
    manualNote: 'Manual — Play Console form, cross-check against real code.',
  ),
  _SubmissionStep(
    id: 'target_api',
    title: 'Target API level compliance',
    detail: 'android/app/build.gradle currently reads '
        '"targetSdkVersion flutter.targetSdkVersion" — inherited from the '
        'Flutter SDK\'s default, not pinned in this project. Verify it meets '
        'Play\'s current minimum target API requirement before upload.',
    manualNote: 'Real repo finding — re-check flutter --version at submission time.',
  ),
  _SubmissionStep(
    id: 'app_signing',
    title: 'Play App Signing enrollment',
    detail: 'Opt into Play App Signing so Google manages the distribution '
        'key. Day 336 found the release build currently signs with the '
        'DEBUG keystore — that must be fixed before any AAB is generated '
        'for real upload.',
    manualNote: 'Blocked by Day 336 P0 (debug-signed release) until fixed.',
  ),
  _SubmissionStep(
    id: 'signed_aab',
    title: 'Signed AAB build & upload',
    detail: 'flutter build appbundle --release with a real (non-debug) '
        'signing config, then upload via Release → Production → Create new release.',
    manualNote: 'Manual upload — cannot be triggered from inside the app.',
  ),
  _SubmissionStep(
    id: 'store_listing',
    title: 'Store listing assets',
    detail: 'Screenshots, feature graphic, short/full description. Day 349 '
        'built the multi-language mockup generator for this — no real '
        'device screenshot exists yet in this environment.',
    manualNote: 'See Day 349 mockups — not real captured screenshots.',
  ),
  _SubmissionStep(
    id: 'pricing_countries',
    title: 'Pricing & country availability',
    detail: 'Set free/paid + in-app purchase pricing per Day 318\'s regional '
        'matrix, and choose initial country rollout per Day 316\'s staged plan.',
    manualNote: 'See Day 316 for the staged rollout simulation.',
  ),
  _SubmissionStep(
    id: 'final_review',
    title: 'Final review & submit',
    detail: 'Review all sections for warnings, then "Send for review". '
        'Google review typically takes hours to a few days — do not treat '
        'submission as launch.',
    manualNote: 'Submitting starts REVIEW, not launch — Day 365 stays a preview until this is real.',
  ),
];

Map<String, dynamic> _submissionPayload(Map<String, bool> checked) => {
      'endpoint': 'NONE — Google Play Developer API does not expose store submission',
      'steps_total': _kSteps.length,
      'steps_checked': checked.values.where((v) => v).length,
      'submitted_for_real': false,
      'blocked_by_open_p0': true,
      'wire_note': 'Local checklist only · Day 361 war room gate should hold '
          'this back until debug-signing and cert-pinning P0s are fixed',
    };

String _buildExportReport(Map<String, bool> checked) {
  final buf = StringBuffer('ZapSafe Play Store Submission Checklist — Day 362\n\n');
  for (final s in _kSteps) {
    final status = checked[s.id] == true ? 'DONE' : 'PENDING';
    buf.writeln('[$status] ${s.title}');
    buf.writeln('    ${s.manualNote}');
  }
  buf.writeln();
  buf.writeln('NOTE: nothing has actually been submitted to Play Console.');
  return buf.toString();
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d362TabProvider = StateProvider<int>((ref) => 0);
final _d362CheckedProvider = StateProvider<Map<String, bool>>((ref) => {});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day362PlayStoreSubmissionScreen extends ConsumerWidget {
  const Day362PlayStoreSubmissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d362CheckedProvider);
    final done = checked.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day361_370.play_submission_title'.tr()),
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
                child: Text(
                  '$done/${_kSteps.length}',
                  style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d362TabProvider), onSelect: (i) => ref.read(_d362TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d362TabProvider)) {
              0 => const _StepsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Steps ──────────────────────────────────────────────────────────────
class _StepsTab extends ConsumerWidget {
  const _StepsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d362CheckedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'There is no Google Play Developer API for submitting an app '
                  'for review. Every step here is a real manual Play Console '
                  'action — checking a box only tracks local progress. Nothing '
                  'has been submitted. See Day 361 war room before uploading '
                  'a real AAB.',
                  style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kSteps.map((s) {
          final isChecked = checked[s.id] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (isChecked ? ZapColors.safe : ZapColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isChecked,
                  activeColor: ZapColors.safe,
                  onChanged: (v) => ref.read(_d362CheckedProvider.notifier).state = {...checked, s.id: v ?? false},
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(s.detail, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, height: 1.4)),
                      const SizedBox(height: 4),
                      Text(s.manualNote, style: const TextStyle(color: ZapColors.textMuted, fontSize: 9, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.playStagedRollout),
          icon: const Icon(Icons.trending_up_rounded, size: 18),
          label: const Text('Open Day 316 staged rollout plan'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _buildExportReport(checked)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission checklist copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy checklist'),
        ),
      ],
    );
  }
}

// ── Tab 1: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = _submissionPayload(ref.watch(_d362CheckedProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Play Store submission executor', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text('Section L Day 2/5 · real manual checklist, nothing submitted yet.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_kJsonEncoder.convert(payload), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Spec copied.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy spec JSON'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.info.withOpacity(0.3))),
          child: const Text('Next: Day 363 — App Store Submission Executor.', style: TextStyle(color: ZapColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 361 War Room'), onPressed: () => context.push(AppRoutes.finalQaWarRoom)),
            ActionChip(label: const Text('Day 316 Staged Rollout'), onPressed: () => context.push(AppRoutes.playStagedRollout)),
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
