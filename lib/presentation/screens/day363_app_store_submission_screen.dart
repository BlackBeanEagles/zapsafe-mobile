/// Day 363 — App Store Submission Executor
///
/// Section L (Days 361-365, Public Launch Week): a step-by-step App Store
/// Connect submission checklist — archive, upload, review information, demo
/// account. Like Day 362's Play Console counterpart, there is no public
/// Apple API for submitting an app for review; every step is a real manual
/// action in Xcode / App Store Connect. This screen tracks that manual
/// workflow — it does not automate it.
///
/// The "Review info" paste fields are sourced directly from Day 284's
/// `day284_store_review_notes_screen.dart` — the SAME test account
/// constants (`reviewer@zapsafe.app` / `ZapSafe2026!` / cancel PIN `123456`
/// / duress PIN `999999`), not new ones invented here, so the two screens
/// never drift out of sync.
///
/// **Nothing has been submitted.** Every step defaults unchecked.
///
/// Tag: 🟢 FRONTEND-ONLY · real manual-step checklist · nothing submitted.
///
/// Route: [AppRoutes.appStoreSubmission] → `/day-363-app-store-submission`
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
const _kAccent = Color(0xFF0A84FF);
const _kTabs = ['Steps', 'Review Info', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// Sourced directly from day284_store_review_notes_screen.dart — same
// constants, not re-invented, so both screens stay in sync.
const _kTestEmail = 'reviewer@zapsafe.app';
const _kTestPassword = 'ZapSafe2026!';
const _kTestPin = '123456';
const _kDuressPin = '999999';

class _SubmissionStep {
  const _SubmissionStep({required this.id, required this.title, required this.detail, required this.manualNote});
  final String id;
  final String title;
  final String detail;
  final String manualNote;
}

const _kSteps = [
  _SubmissionStep(
    id: 'archive',
    title: 'Archive the build in Xcode',
    detail: 'Product → Archive on a Release configuration. Requires a real '
        'signing certificate and provisioning profile — neither exists yet '
        'in this environment.',
    manualNote: 'Manual — Xcode Organizer, no CLI-only shortcut for App Store distribution certs.',
  ),
  _SubmissionStep(
    id: 'upload',
    title: 'Upload to App Store Connect',
    detail: 'Xcode Organizer → Distribute App → App Store Connect, or '
        'altool/notarytool via CI once a real release lane exists (Day 336 '
        'found no .github/workflows directory in this repo at all).',
    manualNote: 'Manual — real Apple Developer Program membership required.',
  ),
  _SubmissionStep(
    id: 'review_info',
    title: 'Review information',
    detail: 'App Review contact info + notes. See the Review Info tab — '
        'fields are pre-filled from Day 284\'s real test account, not '
        'newly invented here.',
    manualNote: 'Paste into App Store Connect → App Review Information.',
  ),
  _SubmissionStep(
    id: 'demo_account',
    title: 'Demo account for reviewers',
    detail: 'Sign-in required toggle + demo credentials. LP27 blank-screen '
        'SOS mode needs the explanation from Day 284 attached here or '
        'reviewers may flag it as broken.',
    manualNote: 'Same reviewer@zapsafe.app account as Day 284 — do not create a second one.',
  ),
  _SubmissionStep(
    id: 'export_compliance',
    title: 'Export compliance (encryption)',
    detail: 'Declare use of encryption (AES-256 local storage, HTTPS/TLS). '
        'Standard exemption usually applies but must be answered honestly '
        'per this app\'s real crypto usage, not assumed.',
    manualNote: 'Manual — App Store Connect submission question, per build.',
  ),
  _SubmissionStep(
    id: 'submit_review',
    title: 'Submit for review',
    detail: 'Apple review typically 24-48h, can be longer for safety-app '
        'category apps with background location/audio. Submission starts '
        'REVIEW, not launch.',
    manualNote: 'Submitting is not launching — Day 365 stays a preview until this is real and approved.',
  ),
];

Map<String, dynamic> _submissionPayload(Map<String, bool> checked) => {
      'endpoint': 'NONE — Apple exposes no public submit-for-review API',
      'steps_total': _kSteps.length,
      'steps_checked': checked.values.where((v) => v).length,
      'submitted_for_real': false,
      'review_info_source': 'day284_store_review_notes_screen.dart (same constants)',
      'wire_note': 'Local checklist only',
    };

String _buildExportReport(Map<String, bool> checked) {
  final buf = StringBuffer('ZapSafe App Store Submission Checklist — Day 363\n\n');
  for (final s in _kSteps) {
    final status = checked[s.id] == true ? 'DONE' : 'PENDING';
    buf.writeln('[$status] ${s.title}');
    buf.writeln('    ${s.manualNote}');
  }
  buf.writeln();
  buf.writeln('NOTE: nothing has actually been submitted to App Store Connect.');
  return buf.toString();
}

String _reviewInfoText() => '''
App Review Information — ZapSafe

Test account:
Email: $_kTestEmail
Password: $_kTestPassword
Cancel PIN: $_kTestPin
Duress PIN (silent alert): $_kDuressPin

Notes for reviewer:
During an active SOS, the screen intentionally shows no "SOS", "Emergency",
or ZapSafe branding (LP27 blank-screen panic mode) — this is a safety
feature protecting users from coerced unlock, not a bug. See Day 284 for
the full SOS demo walkthrough.

Contact: support@zapsafe.app
''';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d363TabProvider = StateProvider<int>((ref) => 0);
final _d363CheckedProvider = StateProvider<Map<String, bool>>((ref) => {});

// ── Screen ────────────────────────────────────────────────────────────────────
class Day363AppStoreSubmissionScreen extends ConsumerWidget {
  const Day363AppStoreSubmissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checked = ref.watch(_d363CheckedProvider);
    final done = checked.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day361_370.appstore_submission_title'.tr()),
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
                child: Text('$done/${_kSteps.length}', style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d363TabProvider), onSelect: (i) => ref.read(_d363TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d363TabProvider)) {
              0 => const _StepsTab(),
              1 => const _ReviewInfoTab(),
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
    final checked = ref.watch(_d363CheckedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.warning.withOpacity(0.3))),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: ZapColors.warning, size: 20),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Apple exposes no public API for submitting an app to review. '
                  'Every step is a real manual App Store Connect / Xcode action. '
                  'Nothing has been submitted.',
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
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: isChecked ? ZapColors.safe : ZapColors.border)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: isChecked, activeColor: ZapColors.safe, onChanged: (v) => ref.read(_d363CheckedProvider.notifier).state = {...checked, s.id: v ?? false}),
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

// ── Tab 1: Review Info ────────────────────────────────────────────────────────
class _ReviewInfoTab extends StatelessWidget {
  const _ReviewInfoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
          child: const Text(
            'Sourced directly from Day 284\'s review notes generator — same '
            'test account constants, not re-invented here.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
          child: SelectableText(_reviewInfoText(), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11, fontFamily: 'monospace', height: 1.5)),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _reviewInfoText()));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review info copied — paste into App Store Connect.')));
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy review info'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.storeReviewNotes),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open Day 284 full review notes generator'),
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
    final payload = _submissionPayload(ref.watch(_d363CheckedProvider));

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('App Store submission executor', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text('Section L Day 3/5 · real manual checklist, nothing submitted yet.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
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
          child: const Text('Next: Day 364 — Launch Day Runbook.', style: TextStyle(color: ZapColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(label: const Text('Day 284 Review Notes'), onPressed: () => context.push(AppRoutes.storeReviewNotes)),
            ActionChip(label: const Text('Day 362 Play Submission'), onPressed: () => context.push(AppRoutes.playStoreSubmission)),
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
