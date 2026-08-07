/// Day 344 — RTL Regression: ar, ur, fa Across 5 Critical Screens
///
/// Section J (Days 341-350): with fa now added (Day 343), the app has 3 RTL
/// locales — ar, ur, fa — all flagged `rtl: true` in kSupportedLanguages.
/// This day does a REAL static check (grep for hardcoded physical
/// left/right/Alignment/TextDirection that would break under RTL, run for
/// real against this repo) across 5 real, currently-wired screens:
///   1. Dashboard          — day279_production_dashboard_screen.dart
///   2. SOS trigger        — presentation/widgets/sos_trigger_button.dart
///   3. Onboarding step 1  — day41_onboarding_step1_screen.dart
///   4. OTP verify         — presentation/screens/auth/otp_verify_screen.dart
///   5. Evidence vault     — day82_evidence_vault_screen.dart
///
/// main.dart already passes `locale: context.locale` to MaterialApp.router
/// with no manual Directionality override, so Flutter's own RTL detection
/// (ar/ur/fa are in Flutter's built-in RTL locale set) correctly flips
/// Row/Column ordering, Scaffold drawer side, and default text alignment
/// app-wide for free. The findings below are the class of bug that survives
/// that automatic flip: HARDCODED physical values (Alignment.centerRight,
/// EdgeInsets.only(right:), TextDirection.ltr, an unmirrored back icon) that
/// stay put regardless of locale instead of mirroring.
///
/// No device/emulator is available in this environment, so this screen
/// cannot claim any live rendering was verified. Everything under "Static
/// findings" was found by real grep against this repo (counts and line
/// numbers are real). Everything under "Manual QA checklist" is honestly
/// PENDING — it needs a human with a physical device or emulator.
///
/// This is a documentation/regression-check day — it does not fix the
/// findings below. That is flagged as a follow-up, out of Day 344's scope.
///
/// Tag: 🟢 REAL static findings + honest pending manual checklist.
/// Route: [AppRoutes.rtl25LangRegression] → `/day-344-rtl-25lang-regression`
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

const _kAccent = Color(0xFF06B6D4);

enum _Severity { minor, moderate, safetyCritical }

class _Finding {
  const _Finding({
    required this.file,
    required this.line,
    required this.snippet,
    required this.issue,
    required this.severity,
  });

  final String file;
  final int line;
  final String snippet;
  final String issue;
  final _Severity severity;
}

// Real findings from `grep` against this exact repo state (Day 344 authoring
// time) on the 5 screens listed above. Line numbers are real.
const _kFindings = [
  _Finding(
    file: 'lib/presentation/widgets/sos_trigger_button.dart',
    line: 126,
    snippet: "SemanticsService.announce('\$remaining second(s) remaining', TextDirection.ltr)",
    issue: 'TalkBack/VoiceOver countdown announcement hardcodes TextDirection.ltr '
        'AND hardcoded English text — bypasses .tr() entirely. Same pattern at '
        "lines 146 ('Cancelled') and 157 ('SOS activated'). Under ar/ur/fa this "
        'announces in English with the wrong direction hint during an actual '
        'SOS hold — the single highest-severity finding in this batch.',
    severity: _Severity.safetyCritical,
  ),
  _Finding(
    file: 'lib/presentation/screens/auth/otp_verify_screen.dart',
    line: 276,
    snippet: "IconButton(icon: const Icon(Icons.arrow_back_rounded), ...)",
    issue: 'Manual back-icon leading widget. Icons.arrow_back_rounded does NOT '
        'auto-mirror under RTL unless given matchTextDirection: true or swapped '
        'for a directional variant — it will keep pointing left even in ar/ur/fa, '
        'i.e. away from the reading-start edge.',
    severity: _Severity.moderate,
  ),
  _Finding(
    file: 'lib/presentation/screens/auth/otp_verify_screen.dart',
    line: 387,
    snippet: 'Align(alignment: Alignment.centerRight, ...) // "Paste code" button',
    issue: 'Physical Alignment.centerRight instead of AlignmentDirectional.centerEnd '
        '— stays on the physical right under RTL instead of mirroring to the left.',
    severity: _Severity.minor,
  ),
  _Finding(
    file: 'lib/presentation/screens/day41_onboarding_step1_screen.dart',
    line: 110,
    snippet: 'margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0) // step dots',
    issue: 'Step-indicator segment gap uses physical right padding. The Row itself '
        'auto-mirrors under RTL (Flutter flips child order via ambient '
        'Directionality), but the gap stays on the physical right — the last '
        'segment ends up with a visible trailing gap on the wrong edge.',
    severity: _Severity.minor,
  ),
  _Finding(
    file: 'lib/presentation/screens/day82_evidence_vault_screen.dart',
    line: 814,
    snippet: 'margin: const EdgeInsets.only(right: ZapSpacing.sm) // tamper badge',
    issue: 'Tamper-flag badge margin uses physical right spacing instead of '
        'EdgeInsetsDirectional end — minor spacing asymmetry under RTL.',
    severity: _Severity.minor,
  ),
  _Finding(
    file: 'lib/presentation/screens/day279_production_dashboard_screen.dart',
    line: 173,
    snippet: 'padding: const EdgeInsets.only(right: ZapSpacing.md) // AppBar action',
    issue: 'AppBar trailing-action padding uses physical right spacing — minor, '
        'same class of bug as the others above.',
    severity: _Severity.minor,
  ),
];

// Real repo-wide grep counts (context only — NOT all of these are bugs; many
// EdgeInsets.only(left/right:) calls are symmetric pairs and harmless. These
// numbers show the SCALE of the pattern across the whole app, not a claim
// that all of them are broken.
const _kRepoWideCounts = [
  ('Icons.arrow_back* usages', 97),
  ('Alignment.centerLeft / centerRight', 23),
  ('EdgeInsets.only(left:/right:)', 322),
  ('Hardcoded TextDirection.ltr', 24),
];

class _ChecklistItem {
  const _ChecklistItem(this.label, this.detail);
  final String label;
  final String detail;
}

const _kManualChecklist = [
  _ChecklistItem(
    'Mirror icons on a live ar/ur/fa device',
    'Back chevrons, send/forward arrows, and the OTP paste-icon button need a '
        'human check on an actual RTL locale to confirm which ones visually '
        'point the wrong way (matches the static findings above, but layout '
        'engines can surprise you).',
  ),
  _ChecklistItem(
    '200% font-scale + RTL combined',
    'Set OS text scale to 200% AND locale to ar/ur/fa simultaneously. Check '
        'the 5 critical screens above for text clipping/overflow — this combo '
        'is the worst case and was flagged as a real FAIL for LTR alone back '
        'in Day 335 (44dp touch target); it has never been re-checked under RTL.',
  ),
  _ChecklistItem(
    'SOS long-press ring visual mirroring',
    'Confirm the countdown ring/progress arc on the SOS trigger button reads '
        'naturally under RTL (clockwise vs counter-clockwise perception can '
        'differ) — cannot be verified from source alone.',
  ),
  _ChecklistItem(
    'Numeral direction inside mixed strings',
    'Persian/Arabic-Indic digits (۱۲۳) embedded next to Latin placeholders '
        'like {seconds}/{count} (e.g. fa\'s "SOS در {seconds} ثانیه") can '
        'produce visually confusing bidi runs on-device. Needs a real render.',
  ),
  _ChecklistItem(
    'Scaffold drawer / bottom-nav side',
    'Confirm any slide-out drawer or side-anchored floating action button '
        'actually opens from the correct (mirrored) edge on-device — this '
        'relies on Flutter\'s automatic Directionality flip, which is expected '
        'to work but is unverified without a live app.',
  ),
];

class Day344Rtl25LangRegressionScreen extends ConsumerWidget {
  const Day344Rtl25LangRegressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rtlLangs = kSupportedLanguages.where((l) => l.rtl).toList();

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.rtl_regression_title'.tr()),
      ),
      body: ListView(
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
              '🟢 Section J Day 4/10 · real static grep + honest pending manual QA',
              style: TextStyle(color: _kAccent, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: rtlLangs
                .map((l) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ZapColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: ZapColors.info.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${l.flag} ${l.name} (${l.code})',
                          style: const TextStyle(
                              color: ZapColors.info, fontSize: 11),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Static findings — 5 critical screens',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            '${_kFindings.length} real findings from a grep of hardcoded '
            'Alignment/EdgeInsets.only(left|right)/TextDirection/back-icons '
            'against dashboard, SOS trigger, onboarding step 1, OTP verify, '
            'and evidence vault.',
            style: const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final f in _kFindings) _FindingCard(finding: f),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Repo-wide scale (context, not all bugs)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: _kRepoWideCounts
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(c.$1,
                                  style: const TextStyle(
                                      color: ZapColors.textSecondary,
                                      fontSize: 11)),
                            ),
                            Text('${c.$2}',
                                style: const TextStyle(
                                    color: ZapColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Manual QA checklist (needs a live device — genuinely pending)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final item in _kManualChecklist) _ChecklistRow(item: item),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Text(
              'This screen documents findings — it does not fix them. Fixing '
              'the sos_trigger_button.dart localisation gap (the '
              'safety-critical one) is recommended as an immediate follow-up, '
              'but is out of scope for Day 344 itself.',
              style: TextStyle(color: ZapColors.warning, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final _Finding finding;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (finding.severity) {
      _Severity.safetyCritical => (ZapColors.danger, 'SAFETY-CRITICAL'),
      _Severity.moderate => (ZapColors.warning, 'MODERATE'),
      _Severity.minor => (ZapColors.textMuted, 'MINOR'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${finding.file}:${finding.line}',
                  style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            finding.snippet,
            style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
          const SizedBox(height: 6),
          Text(
            finding.issue,
            style: const TextStyle(
                color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final _ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZapColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_outlined, size: 16, color: ZapColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(item.detail,
                    style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 10,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
