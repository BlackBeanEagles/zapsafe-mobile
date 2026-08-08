/// Day 262 — New Language Template Workflow
///
/// Section D (Days 261-280): step-by-step guide to add a locale —
/// copy en.json, translate keys, validate parity, register in
/// EasyLocalization, and run QA smoke checks.
///
/// Tag: 🟢 FRONTEND-ONLY · mock pipeline simulation.
///
/// Route: [AppRoutes.translationWorkflow] → `/translation-workflow`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0D9488);
const _kTabs = ['Workflow', 'Validate', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kEnKeyCount = 236;

enum _StepStatus { pending, running, done, failed }

class _WorkflowStep {
  const _WorkflowStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.command,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final String command;
  final IconData icon;
}

const _kWorkflowSteps = [
  _WorkflowStep(
    id: 'copy',
    title: 'Copy template',
    subtitle: 'Duplicate assets/translations/en.json → {locale}.json',
    command: 'cp assets/translations/en.json assets/translations/fa.json',
    icon: Icons.content_copy_rounded,
  ),
  _WorkflowStep(
    id: 'translate',
    title: 'Translate keys',
    subtitle: 'AI or human translates values — keep keys + {placeholders}',
    command: 'cursor / chatgpt: translate fa.json values only · preserve keys',
    icon: Icons.translate_rounded,
  ),
  _WorkflowStep(
    id: 'validate',
    title: 'Validate pack',
    subtitle: 'JSON syntax · key parity · placeholder tokens · empty strings',
    command: 'dart run tool/i18n_validate.dart --locale fa --base en',
    icon: Icons.fact_check_rounded,
  ),
  _WorkflowStep(
    id: 'register',
    title: 'Register locale',
    subtitle: 'Add to EasyLocalization supportedLocales + pubspec assets',
    command: "Locale('fa') · assets/translations/fa.json in pubspec",
    icon: Icons.app_registration_rounded,
  ),
  _WorkflowStep(
    id: 'qa',
    title: 'QA smoke test',
    subtitle: 'Switch locale in app · SOS + settings strings · RTL if needed',
    command: 'Day 102 demo + Day 216 coverage row for new locale',
    icon: Icons.smoke_free_rounded,
  ),
];

class _TargetLocale {
  const _TargetLocale({
    required this.code,
    required this.label,
    required this.flag,
    this.rtl = false,
  });

  final String code;
  final String label;
  final String flag;
  final bool rtl;
}

const _kTargetLocales = [
  _TargetLocale(code: 'fa', label: 'Persian (fa)', flag: '🇮🇷', rtl: true),
  _TargetLocale(code: 'id', label: 'Indonesian (id)', flag: '🇮🇩'),
  _TargetLocale(code: 'vi', label: 'Vietnamese (vi)', flag: '🇻🇳'),
  _TargetLocale(code: 'ja', label: 'Japanese (ja)', flag: '🇯🇵'),
  _TargetLocale(code: 'ko', label: 'Korean (ko)', flag: '🇰🇷'),
];

_TargetLocale _localeByCode(String code) => _kTargetLocales
    .firstWhere((l) => l.code == code, orElse: () => _kTargetLocales.first);

const _kSampleEnSnippet = '''{
  "app_name": "ZapSafe",
  "tagline": "Safety in your hands",
  "sos": {
    "trigger": "TRIGGER SOS",
    "countdown": "SOS in {seconds}s",
    "sent": "Alert sent to {count} contacts"
  }
}''';

String _mockTranslatedSnippet(String code, bool rtl) {
  if (code == 'fa') {
    return '''{
  "app_name": "ZapSafe",
  "tagline": "ایمنی در دستان شما",
  "sos": {
    "trigger": "فعال‌سازی SOS",
    "countdown": "SOS در {seconds} ثانیه",
    "sent": "هشدار به {count} مخاطب ارسال شد"
  }
}''';
  }
  if (code == 'id') {
    return '''{
  "app_name": "ZapSafe",
  "tagline": "Keamanan di tangan Anda",
  "sos": {
    "trigger": "PICU SOS",
    "countdown": "SOS dalam {seconds} d",
    "sent": "Alert dikirim ke {count} kontak"
  }
}''';
  }
  return _kSampleEnSnippet.replaceAll(
    'Safety in your hands',
    rtl ? '… translated …' : 'Translated tagline ($code)',
  );
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d262TabProvider = StateProvider<int>((ref) => 0);
final _d262LocaleProvider = StateProvider<String>((ref) => 'fa');
final _d262StepStatusProvider = StateProvider<Map<String, _StepStatus>>(
  (ref) => {for (final s in _kWorkflowSteps) s.id: _StepStatus.pending},
);
final _d262RunningProvider = StateProvider<bool>((ref) => false);
final _d262RunCountProvider = StateProvider<int>((ref) => 0);
final _d262ValidationLogProvider =
    StateProvider<List<String>>((ref) => const []);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day262TranslationWorkflowScreen extends ConsumerStatefulWidget {
  const Day262TranslationWorkflowScreen({super.key});

  @override
  ConsumerState<Day262TranslationWorkflowScreen> createState() =>
      _Day262TranslationWorkflowScreenState();
}

class _Day262TranslationWorkflowScreenState
    extends ConsumerState<Day262TranslationWorkflowScreen> {
  Future<void> _runWorkflow() async {
    if (ref.read(_d262RunningProvider)) return;

    ref.read(_d262RunningProvider.notifier).state = true;
    ref.read(_d262StepStatusProvider.notifier).state = {
      for (final s in _kWorkflowSteps) s.id: _StepStatus.pending,
    };
    ref.read(_d262ValidationLogProvider.notifier).state = [];

    final locale = _localeByCode(ref.read(_d262LocaleProvider));
    final logs = <String>[];

    for (final step in _kWorkflowSteps) {
      ref.read(_d262StepStatusProvider.notifier).state = {
        ...ref.read(_d262StepStatusProvider),
        step.id: _StepStatus.running,
      };
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;

      logs.insert(0, '${step.title} · OK · ${locale.code}');
      ref.read(_d262StepStatusProvider.notifier).state = {
        ...ref.read(_d262StepStatusProvider),
        step.id: _StepStatus.done,
      };
      ref.read(_d262ValidationLogProvider.notifier).state = [...logs];
    }

    ref.read(_d262RunCountProvider.notifier).state =
        ref.read(_d262RunCountProvider) + 1;
    ref.read(_d262RunningProvider.notifier).state = false;

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Workflow complete · ${locale.label} pack ready for Day 263+ QA',
          ),
        ),
      );
    }
  }

  void _resetWorkflow() {
    ref.read(_d262StepStatusProvider.notifier).state = {
      for (final s in _kWorkflowSteps) s.id: _StepStatus.pending,
    };
    ref.read(_d262ValidationLogProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d262TabProvider);
    final runCount = ref.watch(_d262RunCountProvider);
    final locale = ref.watch(_d262LocaleProvider);
    final statuses = ref.watch(_d262StepStatusProvider);
    final doneCount =
        statuses.values.where((s) => s == _StepStatus.done).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 262 · Translation Workflow'),
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
                  '$doneCount/${_kWorkflowSteps.length}',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          if (runCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: ZapSpacing.sm),
              child: Center(
                child: Text(
                  '$runCount run${runCount == 1 ? '' : 's'}',
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
            onSelect: (i) => ref.read(_d262TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _WorkflowTab(
                  localeCode: locale,
                  statuses: statuses,
                  running: ref.watch(_d262RunningProvider),
                  onRun: _runWorkflow,
                  onReset: _resetWorkflow,
                ),
              1 => _ValidateTab(localeCode: locale),
              _ => _InfoTab(localeCode: locale),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Workflow ───────────────────────────────────────────────────────────
class _WorkflowTab extends ConsumerWidget {
  const _WorkflowTab({
    required this.localeCode,
    required this.statuses,
    required this.running,
    required this.onRun,
    required this.onReset,
  });

  final String localeCode;
  final Map<String, _StepStatus> statuses;
  final bool running;
  final VoidCallback onRun;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = _localeByCode(localeCode);
    final logs = ref.watch(_d262ValidationLogProvider);

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
            '🟢 FRONTEND-ONLY · Section D Day 2/20 · en.json → translate → validate',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        DropdownButtonFormField<String>(
          value: localeCode,
          decoration: const InputDecoration(
            labelText: 'Target locale',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final l in _kTargetLocales)
              DropdownMenuItem(
                value: l.code,
                child: Text('${l.flag} ${l.label}'),
              ),
          ],
          onChanged: running
              ? null
              : (v) {
                  if (v != null) {
                    ref.read(_d262LocaleProvider.notifier).state = v;
                    onReset();
                  }
                },
        ),
        if (locale.rtl) ...[
          const SizedBox(height: ZapSpacing.sm),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.format_textdirection_r_to_l_rounded,
                    size: 16, color: ZapColors.warning),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'RTL locale — include Directionality + Day 263 RTL preview.',
                    style:
                        TextStyle(color: ZapColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        ..._kWorkflowSteps.map(
          (step) => _StepCard(
            step: step,
            status: statuses[step.id] ?? _StepStatus.pending,
            localeCode: localeCode,
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        FilledButton.icon(
          onPressed: running ? null : onRun,
          icon: running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(running ? 'Running pipeline…' : 'Run workflow (mock)'),
          style: FilledButton.styleFrom(
            backgroundColor: _kAccent,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: running ? null : onReset,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reset steps'),
        ),
        if (logs.isNotEmpty) ...[
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'Pipeline log',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ...logs.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '✓ $line',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.status,
    required this.localeCode,
  });

  final _WorkflowStep step;
  final _StepStatus status;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _StepStatus.done => ZapColors.safe,
      _StepStatus.running => _kAccent,
      _StepStatus.failed => ZapColors.danger,
      _StepStatus.pending => ZapColors.textMuted,
    };
    final command = step.command
        .replaceAll('fa.json', '$localeCode.json')
        .replaceAll('--locale fa', '--locale $localeCode')
        .replaceAll("Locale('fa')", "Locale('$localeCode')");

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: status == _StepStatus.running
            ? _kAccent.withOpacity(0.06)
            : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: status == _StepStatus.pending
              ? ZapColors.border
              : color.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(step.icon, size: 18, color: color),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(
                switch (status) {
                  _StepStatus.done => Icons.check_circle_rounded,
                  _StepStatus.running => Icons.hourglass_top_rounded,
                  _StepStatus.failed => Icons.error_rounded,
                  _StepStatus.pending => Icons.radio_button_unchecked,
                },
                size: 16,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            step.subtitle,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgPrimary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ZapColors.border),
            ),
            child: SelectableText(
              command,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 9,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Validate ───────────────────────────────────────────────────────────
class _ValidateTab extends StatelessWidget {
  const _ValidateTab({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final locale = _localeByCode(localeCode);
    final checks = [
      _ValidationCheck(
        label: 'JSON syntax',
        detail: 'assets/translations/$localeCode.json parses without error',
        pass: true,
      ),
      const _ValidationCheck(
        label: 'Key parity',
        detail: '236 keys match en.json structure',
        pass: true,
      ),
      const _ValidationCheck(
        label: 'Placeholder tokens',
        detail: '{seconds} · {count} preserved in sos.* keys',
        pass: true,
      ),
      _ValidationCheck(
        label: 'Empty values',
        detail: '0 empty string values in translated pack',
        pass: localeCode != 'vi',
      ),
      _ValidationCheck(
        label: 'RTL metadata',
        detail: locale.rtl
            ? 'Mark locale RTL in LangInfo + test Day 263 preview'
            : 'LTR locale — standard layout',
        pass: true,
      ),
    ];
    final passCount = checks.where((c) => c.pass).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Text(
          'Validation · ${locale.flag} ${locale.label}',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '$passCount/${checks.length} checks passed (mock)',
          style: TextStyle(
            color:
                passCount == checks.length ? ZapColors.safe : ZapColors.warning,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...checks.map((c) => _CheckRow(check: c)),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Before / after snippet',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'en.json (source)',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        const _CodeBlock(text: _kSampleEnSnippet),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '$localeCode.json (translated mock)',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        _CodeBlock(text: _mockTranslatedSnippet(localeCode, locale.rtl)),
      ],
    );
  }
}

class _ValidationCheck {
  const _ValidationCheck({
    required this.label,
    required this.detail,
    required this.pass,
  });

  final String label;
  final String detail;
  final bool pass;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final _ValidationCheck check;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: check.pass
            ? ZapColors.safe.withOpacity(0.06)
            : ZapColors.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: check.pass
              ? ZapColors.safe.withOpacity(0.35)
              : ZapColors.danger.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            check.pass ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: check.pass ? ZapColors.safe : ZapColors.danger,
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  check.detail,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
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

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZapColors.border),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          color: ZapColors.textSecondary,
          fontSize: 9,
          fontFamily: 'monospace',
          height: 1.45,
        ),
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final locale = _localeByCode(localeCode);
    final payload = {
      'endpoint': 'POST /api/v1/i18n/locale-pack/',
      'workflow_version': '262-v1',
      'target_locale': localeCode,
      'rtl': locale.rtl,
      'steps': [
        for (final s in _kWorkflowSteps) s.id,
      ],
      'source_file': 'assets/translations/en.json',
      'output_file': 'assets/translations/$localeCode.json',
      'expected_key_count': _kEnKeyCount,
      'easy_localization': {
        'supported_locales_add': "Locale('$localeCode')",
        'pubspec_assets_add': 'assets/translations/$localeCode.json',
        'fallback': 'en',
      },
      'validation_rules': [
        'json_parse_ok',
        'key_parity_with_en',
        'placeholders_preserved',
        'no_empty_values',
        if (locale.rtl) 'rtl_layout_smoke_test',
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.content_copy_rounded,
          title: 'Start from en.json',
          subtitle:
              'Never invent keys — copy the English master file and translate '
              'values only. Keys are the contract across all 25 locales.',
        ),
        const _PolicyRow(
          icon: Icons.smart_toy_outlined,
          title: 'AI + human review',
          subtitle:
              'Use AI for bulk translation, then native speaker review for '
              'SOS, legal, and safety-critical strings.',
        ),
        const _PolicyRow(
          icon: Icons.integration_instructions_rounded,
          title: 'EasyLocalization registration',
          subtitle:
              'After validate: add Locale to supportedLocales, asset path in '
              'pubspec.yaml, and kSupportedLanguages in i18n_providers.dart.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Registration snippet (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        _CodeBlock(
          text: '''// main.dart · EasyLocalization
supportedLocales: const [
  Locale('en'),
  Locale('$localeCode'), // Day 262 add
],

// pubspec.yaml
assets:
  - assets/translations/en.json
  - assets/translations/$localeCode.json''',
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
              const SnackBar(content: Text('Workflow spec JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy workflow JSON'),
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
              label: const Text('Day 261 Language Hub'),
              onPressed: () => context.push(AppRoutes.languageExpansionHub),
            ),
            ActionChip(
              label: const Text('Day 101 i18n Setup'),
              onPressed: () => context.push(AppRoutes.i18nSetup),
            ),
            ActionChip(
              label: const Text('Day 216 Coverage Audit'),
              onPressed: () => context.push(AppRoutes.i18nCoverageAudit),
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
