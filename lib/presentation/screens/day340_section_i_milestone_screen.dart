/// Day 340 — Section I Milestone: Hardening Complete
///
/// Celebration + checklist screen for Section I (Days 331-339, "Launch
/// Hardening"). Mirrors `day310_section_f_milestone_screen.dart`'s shape —
/// same stat-grid + per-day checklist pattern. Also read
/// `day320_section_g_milestone_screen.dart` and
/// `day330_section_h_rc_milestone_screen.dart` for pattern consistency, as
/// instructed, before writing this file.
///
/// **A discrepancy found and corrected rather than silently inherited:**
/// the instruction that produced this file assumed Day 320 and Day 330
/// "now exist on this branch". They do not. Both were built on `main`
/// (`2652ffc` Day 320, `563f5f9` Day 330) but Days 311-330 were never
/// merged into `day331-340-launch-hardening`'s history — verified with
/// `git merge-base --is-ancestor <sha> HEAD`, which returns false for
/// both. Their content was read directly via `git show <sha>:<path>` for
/// pattern reference only; this branch's own file tree still jumps
/// straight from Day 310 to Day 331. That gap is a pre-existing fact
/// about this worktree, not something this session introduced or should
/// paper over.
///
/// Checklist rows below are this session's own real verification record
/// for Days 331-339 — each marked ✅ Verified or ⚠ Documented exception
/// with the real caveat inline, matching Day 310/320/330's own honesty
/// bar:
///   • Day 331 — Go/No-Go Gate v2; Section I execution items (333-339)
///     were still placeholders at the time that gate was written, and its
///     RC-manifest row is a placeholder since Day 324 isn't in this
///     worktree. Needs a pass reconciling it against Days 332-339's real
///     results, not done as part of this milestone.
///   • Day 332 — Full Regression Runner v2; the one genuinely clean
///     verify in this section — real automatic route-table matching via
///     the live GoRouter's `findMatch()`, no mock, also covered by
///     `test/widget/day332_route_resolution_test.dart`.
///   • Day 333 — Platform Parity Execution; real form + SharedPreferences
///     persistence, but every row stays PENDING by default — no physical
///     device in this environment to actually mark PASS/FAIL.
///   • Day 334 — Battery Soak Production Log; real form, real
///     persistence, but the log is and stays empty — no device has
///     actually run the 8-hour soak.
///   • Day 335 — Accessibility Full-App Pass; static checks are real and
///     found one genuine 44dp touch-target FAIL (Day 9) — but live
///     TalkBack/VoiceOver verification stays PENDING, no device.
///   • Day 336 — Security Pre-Launch Execution; real static findings, and
///     they are not good news: no cert pinning, `FLAG_SECURE` not set,
///     root detection is UI-only, and the release build is signed with
///     DEBUG keys. Runtime-pentest-only items (MITM, Frida, MobSF) stay
///     PENDING — no device/CI here either.
///   • Day 337 — Legal Blockers Live Tracker; the two most legally
///     load-bearing DPDP rights (export, deletion) are genuinely LIVE
///     end-to-end. Four categories (consent, sessions, audit-log,
///     retention) are real backend with zero frontend caller. One
///     category (third-party sharing disclosure) is genuinely
///     unimplemented on both sides.
///   • Day 338 — Sentry Crash-Free Live Wire; the Sentry init/config
///     itself is real and read live from `CrashReporting`. There is no
///     live Sentry account with real data in this environment — the
///     manual-paste log (the spec's own allowed fallback) starts empty.
///   • Day 339 — Beta Feedback Round 4; confirmed
///     `analytics_api_service.dart` + `zapsafe_backend/analytics/urls.py`
///     have no custom-event endpoint, so this is a real local
///     SharedPreferences log, not a live POST. The log starts empty —
///     no beta tester has submitted in this environment.
///
/// **Section I complete → Section J begins.** Days 341+ start
/// "Section J: 25-Language Completion", matching how Day 310 noted
/// Section G beginning and Day 320/330 each noted the next section.
///
/// Tag: 🟢 (milestone, not a POLISH edit)
///
/// Route: [AppRoutes.sectionIMilestone] → `/day-340-section-i-milestone`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _ChecklistRow {
  const _ChecklistRow({
    required this.day,
    required this.title,
    required this.verified,
    required this.note,
    required this.noDeviceBlocked,
  });
  final String day;
  final String title;
  final bool verified; // true = clean verify, false = documented exception
  final String note;
  final bool noDeviceBlocked; // true if the real blocker is "no device / no live account here"
}

const _kSectionIChecklist = [
  _ChecklistRow(
    day: 'Day 331',
    title: 'Go/No-Go Gate v2',
    verified: false,
    note: '40-item checklist extends Day 298\'s 22 items. Section I '
        'execution items (333-339) were still placeholders when this gate '
        'was written, and its RC-manifest row is a placeholder since '
        'Day 324 isn\'t in this worktree — needs reconciliation against '
        'the real 332-339 results below, not done as part of this '
        'milestone.',
    noDeviceBlocked: false,
  ),
  _ChecklistRow(
    day: 'Day 332',
    title: 'Full Regression Runner v2',
    verified: true,
    note: 'Real automatic route-table matching via the live GoRouter\'s '
        'findMatch() — genuinely clean, no mock. Also covered by '
        'test/widget/day332_route_resolution_test.dart.',
    noDeviceBlocked: false,
  ),
  _ChecklistRow(
    day: 'Day 333',
    title: 'Platform Parity — Execution',
    verified: false,
    note: 'Real form + SharedPreferences persistence, but every row stays '
        'PENDING by default — no physical device in this environment to '
        'mark PASS/FAIL.',
    noDeviceBlocked: true,
  ),
  _ChecklistRow(
    day: 'Day 334',
    title: 'Battery Soak — Production Log',
    verified: false,
    note: 'Real form + real persistence, but the log is and stays empty — '
        'no device has actually run the 8-hour MONITORING soak.',
    noDeviceBlocked: true,
  ),
  _ChecklistRow(
    day: 'Day 335',
    title: 'Accessibility Full-App Pass',
    verified: false,
    note: 'Static checks are real and found one genuine 44dp touch-target '
        'FAIL (Day 9). Live TalkBack/VoiceOver verification across 44 '
        'flows stays PENDING — no device.',
    noDeviceBlocked: true,
  ),
  _ChecklistRow(
    day: 'Day 336',
    title: 'Security Pre-Launch — Execution',
    verified: false,
    note: 'Real static findings, and they are not all good news: no cert '
        'pinning, FLAG_SECURE not set, root detection is UI-only, release '
        'build signed with DEBUG keys. Runtime-pentest-only items (MITM, '
        'Frida, MobSF) stay PENDING — no device/CI.',
    noDeviceBlocked: true,
  ),
  _ChecklistRow(
    day: 'Day 337',
    title: 'Legal Blockers — Live Tracker',
    verified: false,
    note: 'Export + deletion (the two most legally load-bearing DPDP '
        'rights) are genuinely LIVE end-to-end. 4 categories are real '
        'backend with zero frontend caller. Third-party sharing '
        'disclosure is genuinely unimplemented on both sides.',
    noDeviceBlocked: false,
  ),
  _ChecklistRow(
    day: 'Day 338',
    title: 'Sentry Crash-Free — Live Wire',
    verified: false,
    note: 'Sentry init/config is real and read live from CrashReporting. '
        'No live Sentry account with real data exists in this '
        'environment — the manual-paste log (the spec\'s own allowed '
        'fallback) starts empty.',
    noDeviceBlocked: true,
  ),
  _ChecklistRow(
    day: 'Day 339',
    title: 'Beta Feedback Round 4',
    verified: false,
    note: 'Confirmed analytics_api_service.dart + zapsafe_backend has no '
        'custom-event endpoint — real local SharedPreferences log, not a '
        'live POST. Log starts empty — no beta tester has submitted in '
        'this environment.',
    noDeviceBlocked: true,
  ),
];

class Day340SectionIMilestoneScreen extends StatelessWidget {
  const Day340SectionIMilestoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final verified = _kSectionIChecklist.where((e) => e.verified).length;
    final exceptions = _kSectionIChecklist.where((e) => !e.verified).length;
    final noDeviceBlocked = _kSectionIChecklist.where((e) => e.noDeviceBlocked).length;
    const daysCovered = 9; // Days 331-339 (340 is this milestone itself)

    return Scaffold(
      appBar: AppBar(title: Text('day331_340.section_i_milestone_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.xxl),
              decoration: BoxDecoration(
                color: ZapColors.safe.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: ZapColors.safe.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.shield_moon_rounded, color: ZapColors.safe, size: 56),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Center(
            child: Text('day331_340.section_i_milestone_title'.tr(),
                style: ZapTypography.displaySmall
                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Center(
            child: Text(
              'Section I · Launch Hardening · Days 331-339',
              style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Stat grid ────────────────────────────────────────────────
          Row(
            children: [
              const _StatTile(label: 'Days covered', value: '$daysCovered', color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'Clean automated verify', value: '$verified', color: ZapColors.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              _StatTile(label: 'Documented exceptions', value: '$exceptions', color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              _StatTile(label: 'No-device / no-account blocked', value: '$noDeviceBlocked', color: ZapColors.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),

          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
            ),
            child: const Text(
              'Day 320 (Section G) and Day 330 (Section H) exist on main but '
              'were never merged into this branch\'s history — this '
              'worktree\'s file tree jumps from Day 310 straight to Day '
              '331. Verified with git merge-base --is-ancestor; not papered '
              'over here.',
              style: TextStyle(color: ZapColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          // ─── Checklist ───────────────────────────────────────────────
          Text('SECTION I CHECKLIST',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final row in _kSectionIChecklist)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        row.verified ? Icons.check_circle_rounded : Icons.info_rounded,
                        color: row.verified ? ZapColors.safe : ZapColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text('${row.day} · ${row.title}',
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                      ),
                      ZapBadge(
                        label: row.verified ? 'VERIFIED' : 'EXCEPTION',
                        intent: row.verified ? ZapBadgeIntent.safe : ZapBadgeIntent.warning,
                        size: ZapBadgeSize.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(row.note,
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                  ),
                  if (row.noDeviceBlocked) ...[
                    const SizedBox(height: ZapSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Row(
                        children: [
                          const Icon(Icons.phonelink_off_rounded, size: 12, color: ZapColors.danger),
                          const SizedBox(width: 4),
                          Text('No device / live account in this environment',
                              style: ZapTypography.labelSmall.copyWith(color: ZapColors.danger)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              children: [
                const Icon(Icons.timeline_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Section I complete → Section J begins (Day 341+ · '
                    '25-Language Completion).',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open Day 331 gate ($verified verified / $exceptions documented exceptions here)',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.gonogoGateV2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              final payload = {
                'section': 'I',
                'days': '331-339',
                'clean_verified': verified,
                'documented_exceptions': exceptions,
                'no_device_or_account_blocked': noDeviceBlocked,
                'rows': _kSectionIChecklist
                    .map((r) => {'day': r.day, 'title': r.title, 'verified': r.verified, 'note': r.note})
                    .toList(),
              };
              Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(payload)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Section I checklist JSON copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy checklist JSON'),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Open production dashboard',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ZapCard(
        backgroundColor: color.withOpacity(0.08),
        borderColor: color.withOpacity(0.3),
        child: Column(
          children: [
            Text(value,
                style: ZapTypography.displaySmall.copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.xs),
            Text(label,
                textAlign: TextAlign.center,
                style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
