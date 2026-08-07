/// Day 370 — Week 1 Retrospective
///
/// Section M (Days 366-370, Post-Launch Week 1) close: a fillable
/// retrospective TEMPLATE — what went well, bugs found, user quotes, action
/// items.
///
/// **This is explicitly a template for a retrospective that has not
/// happened.** There was no real Week 1, because there is no real launch
/// (see Day 361's war room — 5 open P0s). Every field starts genuinely
/// empty. The example content shown alongside each section is clearly
/// marked "EXAMPLE — illustrative only, not a real finding" and is never
/// pre-filled into the actual input fields — it exists only to show what a
/// real entry might look like once a real Week 1 happens.
///
/// Tag: 🟢 FRONTEND-ONLY · real fillable template · illustrative examples
/// clearly labeled, never presented as real retrospective data.
///
/// Route: [AppRoutes.week1Retrospective] → `/day-370-week1-retrospective`
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
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kPrefsKeyWentWell = 'day370_retro_went_well_v1';
const _kPrefsKeyBugs = 'day370_retro_bugs_v1';
const _kPrefsKeyQuotes = 'day370_retro_quotes_v1';
const _kPrefsKeyActions = 'day370_retro_actions_v1';

class _RetroSection {
  const _RetroSection({required this.title, required this.prefsKey, required this.example, required this.hint});
  final String title;
  final String prefsKey;
  final String example;
  final String hint;
}

const _kSections = [
  _RetroSection(
    title: 'What went well',
    prefsKey: _kPrefsKeyWentWell,
    example: 'EXAMPLE (illustrative only, not real): "Staged rollout at 5% '
        'caught a crash on Pixel devices before it reached most users." — '
        'fill in real wins once Week 1 genuinely happens.',
    hint: 'What actually went well this week?',
  ),
  _RetroSection(
    title: 'Bugs found',
    prefsKey: _kPrefsKeyBugs,
    example: 'EXAMPLE (illustrative only, not real): "3 users reported SOS '
        'countdown got stuck on Android 12 — traced to a race condition in '
        'the cancel handler." — log real bugs found during the real week.',
    hint: 'What real bugs surfaced?',
  ),
  _RetroSection(
    title: 'User quotes',
    prefsKey: _kPrefsKeyQuotes,
    example: 'EXAMPLE (illustrative only, not real): "This app made me feel '
        'safer walking home at night." — a real support ticket or review, '
        'paste verbatim once real users exist (see Day 367).',
    hint: 'Real user quotes (from Day 367 reviews, support tickets, etc.)',
  ),
  _RetroSection(
    title: 'Action items',
    prefsKey: _kPrefsKeyActions,
    example: 'EXAMPLE (illustrative only, not real): "Fix the Android 12 '
        'cancel-handler race condition before advancing rollout past 10%." '
        '— one action item per line, owner in parentheses.',
    hint: 'What should change before Week 2?',
  ),
];

class _RetroFieldNotifier extends StateNotifier<String> {
  _RetroFieldNotifier(this.prefsKey) : super('') {
    _load();
  }
  final String prefsKey;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(prefsKey) ?? '';
    } catch (_) {}
  }

  Future<void> set(String value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, value);
    } catch (_) {}
  }
}

final _d370WentWellProvider = StateNotifierProvider<_RetroFieldNotifier, String>((ref) => _RetroFieldNotifier(_kPrefsKeyWentWell));
final _d370BugsProvider = StateNotifierProvider<_RetroFieldNotifier, String>((ref) => _RetroFieldNotifier(_kPrefsKeyBugs));
final _d370QuotesProvider = StateNotifierProvider<_RetroFieldNotifier, String>((ref) => _RetroFieldNotifier(_kPrefsKeyQuotes));
final _d370ActionsProvider = StateNotifierProvider<_RetroFieldNotifier, String>((ref) => _RetroFieldNotifier(_kPrefsKeyActions));

StateNotifierProvider<_RetroFieldNotifier, String> _providerFor(String prefsKey) => switch (prefsKey) {
      _kPrefsKeyWentWell => _d370WentWellProvider,
      _kPrefsKeyBugs => _d370BugsProvider,
      _kPrefsKeyQuotes => _d370QuotesProvider,
      _ => _d370ActionsProvider,
    };

Map<String, dynamic> _retroPayload(Map<String, String> values) => {
      'is_real_week1_data': false,
      'week1_actually_happened': false,
      'sections': {
        for (final s in _kSections) s.title: (values[s.prefsKey]?.isEmpty ?? true) ? '(not filled in yet)' : values[s.prefsKey],
      },
      'wire_note': 'Real fillable template · examples are illustrative only, '
          'never pre-filled as real data',
    };

String _buildExportReport(Map<String, String> values) {
  final buf = StringBuffer('ZapSafe Week 1 Retrospective — Day 370\n');
  buf.writeln('(TEMPLATE — fill in once a real Week 1 has genuinely happened)\n');
  for (final s in _kSections) {
    final value = values[s.prefsKey] ?? '';
    buf.writeln('── ${s.title} ──');
    buf.writeln(value.isEmpty ? '(not filled in yet)' : value);
    buf.writeln();
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day370Week1RetrospectiveScreen extends ConsumerWidget {
  const Day370Week1RetrospectiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = {for (final s in _kSections) s.prefsKey: ref.watch(_providerFor(s.prefsKey))};

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day361_370.week1_retro_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: _kAccent, size: 20),
                SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'This is a TEMPLATE for a retrospective that has not '
                    'happened — there was no real Week 1 since there is no real '
                    'launch. All fields start empty. Example text is clearly '
                    'labeled and illustrative only.',
                    style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          for (final section in _kSections) ...[
            _RetroSectionWidget(section: section),
            const SizedBox(height: ZapSpacing.lg),
          ],
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildExportReport(values)));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retrospective copied.')));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy retrospective'),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
            child: SelectableText(_kJsonEncoder.convert(_retroPayload(values)), style: const TextStyle(color: ZapColors.textSecondary, fontSize: 10, fontFamily: 'monospace', height: 1.45)),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Day 367 Reviews'), onPressed: () => context.push(AppRoutes.ratingsReviewsMonitor)),
            ActionChip(label: const Text('Day 369 Triage'), onPressed: () => context.push(AppRoutes.supportTriage)),
            ActionChip(label: const Text('Day 366 SOS Dashboard'), onPressed: () => context.push(AppRoutes.liveSosDashboard)),
            ActionChip(label: const Text('Day 361 War Room'), onPressed: () => context.push(AppRoutes.finalQaWarRoom)),
          ]),
        ],
      ),
    );
  }
}

class _RetroSectionWidget extends ConsumerStatefulWidget {
  const _RetroSectionWidget({required this.section});
  final _RetroSection section;

  @override
  ConsumerState<_RetroSectionWidget> createState() => _RetroSectionWidgetState();
}

class _RetroSectionWidgetState extends ConsumerState<_RetroSectionWidget> {
  late final TextEditingController _controller;
  bool _showExample = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(_providerFor(widget.section.prefsKey)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.section.title, style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13))),
            TextButton.icon(
              onPressed: () => setState(() => _showExample = !_showExample),
              icon: Icon(_showExample ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 14),
              label: Text(_showExample ? 'Hide example' : 'Show example', style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
        if (_showExample)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(color: ZapColors.bgSurface, borderRadius: BorderRadius.circular(6), border: Border.all(color: ZapColors.textMuted.withOpacity(0.3))),
            child: Text(widget.section.example, style: const TextStyle(color: ZapColors.textMuted, fontSize: 10, fontStyle: FontStyle.italic, height: 1.4)),
          ),
        TextField(
          controller: _controller,
          maxLines: 4,
          onChanged: (v) => ref.read(_providerFor(widget.section.prefsKey).notifier).set(v),
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: widget.section.hint,
            hintStyle: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            filled: true, fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
