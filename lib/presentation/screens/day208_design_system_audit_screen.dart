/// Day 208 — Design System Compliance Audit
///
/// Section A (Days 201-220): manual QA tool for design-system drift —
/// hardcoded colors, inline TextStyles, touch targets <75dp, missing Semantics.
///
/// Tag: 🟢 FRONTEND-ONLY — meta audit screen for QA before release.
///
/// Route: [AppRoutes.designSystemAudit] → `/design-system-audit`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Audit rules ─────────────────────────────────────────────────────────────────
enum AuditVerdict { unchecked, pass, fail }

class DesignAuditRule {
  final String id;
  final String title;
  final String description;
  final String wrongExample;
  final String rightExample;
  final String themeFile;
  final IconData icon;
  final Color accent;
  final bool critical;

  const DesignAuditRule({
    required this.id,
    required this.title,
    required this.description,
    required this.wrongExample,
    required this.rightExample,
    required this.themeFile,
    required this.icon,
    required this.accent,
    this.critical = false,
  });
}

const _kRules = [
  DesignAuditRule(
    id: 'colors',
    title: 'No hardcoded colors',
    description:
        'Use ZapColors.* tokens — never Color(0xFF…) or Colors.red in screens.',
    wrongExample: "color: Color(0xFFE63946)",
    rightExample: 'color: ZapColors.danger',
    themeFile: 'lib/core/theme/colors.dart',
    icon: Icons.palette_rounded,
    accent: ZapColors.danger,
    critical: true,
  ),
  DesignAuditRule(
    id: 'typography',
    title: 'No inline TextStyles',
    description:
        'Use ZapTypography.* with .copyWith(color:) — not raw fontSize in widgets.',
    wrongExample: "TextStyle(fontSize: 14, fontWeight: FontWeight.w600)",
    rightExample: 'ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)',
    themeFile: 'lib/core/theme/typography.dart',
    icon: Icons.text_fields_rounded,
    accent: ZapColors.info,
    critical: true,
  ),
  DesignAuditRule(
    id: 'spacing',
    title: '4px spacing grid',
    description:
        'Padding and gaps use ZapSpacing.* — multiples of 4px only.',
    wrongExample: 'padding: EdgeInsets.all(13)',
    rightExample: 'padding: EdgeInsets.all(ZapSpacing.md)',
    themeFile: 'lib/core/theme/spacing.dart',
    icon: Icons.grid_4x4_rounded,
    accent: ZapColors.safe,
  ),
  DesignAuditRule(
    id: 'touch',
    title: 'Touch targets ≥ 75dp',
    description:
        'Every tappable control meets WCAG AAA 75×75dp minimum (safety app).',
    wrongExample: 'SizedBox(width: 48, height: 48)',
    rightExample: 'minimumSize: Size(double.infinity, ZapSpacing.minTouchTarget)',
    themeFile: 'lib/core/theme/spacing.dart',
    icon: Icons.touch_app_rounded,
    accent: ZapColors.warning,
    critical: true,
  ),
  DesignAuditRule(
    id: 'semantics',
    title: 'Semantics on interactives',
    description:
        'Buttons, chips, and custom taps need Semantics label + button: true.',
    wrongExample: 'GestureDetector(onTap: …) // no Semantics',
    rightExample: "Semantics(label: 'Save', button: true, child: …)",
    themeFile: 'lib/core/theme/spacing.dart',
    icon: Icons.record_voice_over_rounded,
    accent: Color(0xFF8B5CF6),
    critical: true,
  ),
  DesignAuditRule(
    id: 'radius',
    title: 'Standard border radius',
    description:
        'Use ZapSpacing.radius / radiusSmall / radiusLarge — not magic numbers.',
    wrongExample: 'BorderRadius.circular(13)',
    rightExample: 'BorderRadius.circular(ZapSpacing.radius)',
    themeFile: 'lib/core/theme/spacing.dart',
    icon: Icons.rounded_corner_rounded,
    accent: ZapColors.neutral,
  ),
  DesignAuditRule(
    id: 'background',
    title: 'OLED background tokens',
    description:
        'Scaffold and cards use ZapColors.bg* — not Colors.black or white.',
    wrongExample: 'backgroundColor: Color(0xFF000000)',
    rightExample: 'backgroundColor: ZapColors.bgPrimary',
    themeFile: 'lib/core/theme/colors.dart',
    icon: Icons.dark_mode_rounded,
    accent: ZapColors.textMuted,
  ),
  DesignAuditRule(
    id: 'buttons',
    title: 'Button height 75dp',
    description:
        'FilledButton / OutlinedButton use ZapSpacing.buttonHeight minimum.',
    wrongExample: 'style: FilledButton.styleFrom(minimumSize: Size(0, 48))',
    rightExample: 'minimumSize: Size(double.infinity, ZapSpacing.buttonHeight)',
    themeFile: 'lib/core/theme/spacing.dart',
    icon: Icons.smart_button_rounded,
    accent: ZapColors.safe,
  ),
];

const _kThemeFiles = [
  (
    'colors.dart',
    'lib/core/theme/colors.dart',
    'Brand + semantic colors · danger/safe/warning/bg/text',
    ZapColors.danger,
  ),
  (
    'typography.dart',
    'lib/core/theme/typography.dart',
    'ClashDisplay headings · Syne body · label scales',
    ZapColors.info,
  ),
  (
    'spacing.dart',
    'lib/core/theme/spacing.dart',
    '4px grid · 75dp touch targets · component sizes',
    ZapColors.safe,
  ),
  (
    'app_theme.dart',
    'lib/core/theme/app_theme.dart',
    'MaterialApp ThemeData · component themes',
    ZapColors.warning,
  ),
  (
    'high_contrast_theme.dart',
    'lib/core/theme/high_contrast_theme.dart',
    'Accessibility high-contrast variant',
    ZapColors.neutral,
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d208TabProvider = StateProvider<int>((ref) => 0);
final _d208VerdictsProvider = StateProvider<Map<String, AuditVerdict>>(
  (ref) => {for (final r in _kRules) r.id: AuditVerdict.unchecked},
);
final _d208ExpandedRuleProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Checklist', 'Code Examples', 'Theme Files'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day208DesignSystemAuditScreen extends ConsumerWidget {
  const Day208DesignSystemAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d208TabProvider);
    final verdicts = ref.watch(_d208VerdictsProvider);
    final passed =
        verdicts.values.where((v) => v == AuditVerdict.pass).length;
    final failed =
        verdicts.values.where((v) => v == AuditVerdict.fail).length;
    final unchecked =
        verdicts.values.where((v) => v == AuditVerdict.unchecked).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 208 · Design Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$passed/${_kRules.length}',
                style: TextStyle(
                  color: passed == _kRules.length
                      ? ZapColors.safe
                      : ZapColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
            onSelect: (i) => ref.read(_d208TabProvider.notifier).state = i,
          ),
          if (tab == 0)
            _ProgressStrip(
              passed: passed,
              failed: failed,
              unchecked: unchecked,
            ),
          Expanded(
            child: switch (tab) {
              0 => _ChecklistTab(),
              1 => const _CodeExamplesTab(),
              _ => const _ThemeFilesTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final int passed;
  final int failed;
  final int unchecked;

  const _ProgressStrip({
    required this.passed,
    required this.failed,
    required this.unchecked,
  });

  @override
  Widget build(BuildContext context) {
    final total = _kRules.length;
    final progress = passed / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.sm,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      color: ZapColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Audit progress',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (failed > 0)
                Text(
                  '$failed fail',
                  style: const TextStyle(color: ZapColors.danger, fontSize: 11),
                ),
              if (unchecked > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$unchecked left',
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: ZapColors.bgElevated,
              color: progress >= 1 ? ZapColors.safe : ZapColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verdicts = ref.watch(_d208VerdictsProvider);
    final expanded = ref.watch(_d208ExpandedRuleProvider);
    final allPass = verdicts.values.every((v) => v == AuditVerdict.pass);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section A Day 8/20 · Manual QA drift scanner',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Review each screen file against 8 design-system rules. '
          'Tap Pass or Fail after inspecting code.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kRules.map((rule) {
          final verdict = verdicts[rule.id] ?? AuditVerdict.unchecked;
          final isExpanded = expanded == rule.id;
          return _RuleCard(
            rule: rule,
            verdict: verdict,
            expanded: isExpanded,
            onToggleExpand: () {
              ref.read(_d208ExpandedRuleProvider.notifier).state =
                  isExpanded ? null : rule.id;
            },
            onPass: () {
              ref.read(_d208VerdictsProvider.notifier).update(
                    (m) => {...m, rule.id: AuditVerdict.pass},
                  );
            },
            onFail: () {
              ref.read(_d208VerdictsProvider.notifier).update(
                    (m) => {...m, rule.id: AuditVerdict.fail},
                  );
            },
            onReset: () {
              ref.read(_d208VerdictsProvider.notifier).update(
                    (m) => {...m, rule.id: AuditVerdict.unchecked},
                  );
            },
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Mark all rules pass',
                button: true,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(_d208VerdictsProvider.notifier).state = {
                      for (final r in _kRules) r.id: AuditVerdict.pass,
                    };
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 75),
                  ),
                  child: const Text('Mark all pass'),
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Semantics(
                label: 'Clear all verdicts',
                button: true,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(_d208VerdictsProvider.notifier).state = {
                      for (final r in _kRules) r.id: AuditVerdict.unchecked,
                    };
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 75),
                  ),
                  child: const Text('Clear all'),
                ),
              ),
            ),
          ],
        ),
        if (allPass) ...[
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.verified_rounded, color: ZapColors.safe, size: 40),
                SizedBox(height: ZapSpacing.sm),
                Text(
                  'All 8 rules passed',
                  style: TextStyle(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Screen is design-system compliant for this audit pass.',
                  style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 210 — Error states sweep (ZapErrorState).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final DesignAuditRule rule;
  final AuditVerdict verdict;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onPass;
  final VoidCallback onFail;
  final VoidCallback onReset;

  const _RuleCard({
    required this.rule,
    required this.verdict,
    required this.expanded,
    required this.onToggleExpand,
    required this.onPass,
    required this.onFail,
    required this.onReset,
  });

  Color get _verdictColor => switch (verdict) {
        AuditVerdict.pass => ZapColors.safe,
        AuditVerdict.fail => ZapColors.danger,
        AuditVerdict.unchecked => ZapColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: verdict == AuditVerdict.fail
              ? ZapColors.danger.withOpacity(0.5)
              : verdict == AuditVerdict.pass
                  ? ZapColors.safe.withOpacity(0.4)
                  : ZapColors.border,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            label: '${rule.title}. ${verdict.name}. Tap to expand.',
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              child: Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rule.accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(rule.icon, color: rule.accent, size: 20),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rule.title,
                                  style: const TextStyle(
                                    color: ZapColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (rule.critical)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ZapColors.danger.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    '!',
                                    style: TextStyle(
                                      color: ZapColors.danger,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            rule.description,
                            style: const TextStyle(
                              color: ZapColors.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                            maxLines: expanded ? null : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _verdictIcon(verdict),
                      color: _verdictColor,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(color: ZapColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CodeSnippet(label: 'Wrong', code: rule.wrongExample, bad: true),
                  const SizedBox(height: ZapSpacing.sm),
                  _CodeSnippet(label: 'Right', code: rule.rightExample, bad: false),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    'Theme: ${rule.themeFile}',
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _VerdictButton(
                          label: 'Pass',
                          color: ZapColors.safe,
                          selected: verdict == AuditVerdict.pass,
                          onTap: onPass,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: _VerdictButton(
                          label: 'Fail',
                          color: ZapColors.danger,
                          selected: verdict == AuditVerdict.fail,
                          onTap: onFail,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Semantics(
                        label: 'Reset rule verdict',
                        button: true,
                        child: IconButton(
                          onPressed: onReset,
                          icon: const Icon(Icons.restart_alt_rounded,
                              color: ZapColors.textMuted),
                          tooltip: 'Reset',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _verdictIcon(AuditVerdict v) => switch (v) {
        AuditVerdict.pass => Icons.check_circle_rounded,
        AuditVerdict.fail => Icons.cancel_rounded,
        AuditVerdict.unchecked => Icons.radio_button_unchecked_rounded,
      };
}

class _VerdictButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _VerdictButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label rule',
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withOpacity(0.2) : ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: ZapSpacing.minTouchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? color : ZapColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : ZapColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Code Examples ──────────────────────────────────────────────────────
class _CodeExamplesTab extends ConsumerWidget {
  const _CodeExamplesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_d208ExpandedRuleProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Wrong vs right patterns',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Long-press any snippet to copy. Use during code review of new screens.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kRules.map((rule) {
          final isOpen = expanded == rule.id;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: [
                Semantics(
                  label: '${rule.title} code example',
                  button: true,
                  expanded: isOpen,
                  child: ListTile(
                    leading: Icon(rule.icon, color: rule.accent, size: 22),
                    title: Text(
                      rule.title,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ZapColors.textSecondary,
                    ),
                    onTap: () {
                      ref.read(_d208ExpandedRuleProvider.notifier).state =
                          isOpen ? null : rule.id;
                    },
                  ),
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.md,
                      0,
                      ZapSpacing.md,
                      ZapSpacing.md,
                    ),
                    child: Column(
                      children: [
                        _CodeSnippet(
                          label: 'Wrong',
                          code: rule.wrongExample,
                          bad: true,
                          copyable: true,
                        ),
                        const SizedBox(height: ZapSpacing.sm),
                        _CodeSnippet(
                          label: 'Right',
                          code: rule.rightExample,
                          bad: false,
                          copyable: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CodeSnippet extends StatelessWidget {
  final String label;
  final String code;
  final bool bad;
  final bool copyable;

  const _CodeSnippet({
    required this.label,
    required this.code,
    required this.bad,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = bad ? ZapColors.danger : ZapColors.safe;

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    if (!copyable) return child;

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label snippet copied')),
        );
      },
      child: child,
    );
  }
}

// ── Tab 2: Theme Files ────────────────────────────────────────────────────────
class _ThemeFilesTab extends StatelessWidget {
  const _ThemeFilesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'lib/core/theme/',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Single source of truth for ZapSafe visual design. '
          'Import these — never duplicate tokens in screens.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kThemeFiles.map((f) {
          final (name, path, desc, accent) = f;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.insert_drive_file_rounded,
                        color: accent, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Text(
                      name,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  path,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  desc,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Semantics(
                  label: 'Copy import path for $name',
                  button: true,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: path));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied $path')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy path'),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Text(
            'Import pattern:\n'
            "import '../../core/theme/colors.dart';\n"
            "import '../../core/theme/spacing.dart';\n"
            "import '../../core/theme/typography.dart';",
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy standard theme imports',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text:
                      "import '../../core/theme/colors.dart';\n"
                      "import '../../core/theme/spacing.dart';\n"
                      "import '../../core/theme/typography.dart';",
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Imports copied')),
              );
            },
            icon: const Icon(Icons.copy_all_rounded, size: 18),
            label: const Text('Copy standard imports'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected
                            ? ZapColors.info
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
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
