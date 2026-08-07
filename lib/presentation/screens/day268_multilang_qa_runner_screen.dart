/// Day 268 — Multi-Language QA Runner
///
/// Section D (Days 261-280): auto-cycle locales on mock sample screens,
/// per-locale screenshot checklist for translators, and exportable QA report.
///
/// Tag: 🟢 FRONTEND-ONLY · loads pack JSON from assets for fa/id/vi/ja/ko.
///
/// Route: [AppRoutes.multilangQaRunner] → `/multilang-qa-runner`
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
const _kAccent = Color(0xFF0891B2);
const _kTabs = ['Runner', 'Checklist', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _QaLocale {
  const _QaLocale({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.rtl = false,
    this.assetPath,
  });

  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool rtl;
  final String? assetPath;
}

const _kQaLocales = [
  _QaLocale(code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧'),
  _QaLocale(
    code: 'fa',
    name: 'Persian',
    nativeName: 'فارسی',
    flag: '🇮🇷',
    rtl: true,
    assetPath: 'assets/translations/fa.json',
  ),
  _QaLocale(
    code: 'id',
    name: 'Indonesian',
    nativeName: 'Bahasa Indonesia',
    flag: '🇮🇩',
    assetPath: 'assets/translations/id.json',
  ),
  _QaLocale(
    code: 'vi',
    name: 'Vietnamese',
    nativeName: 'Tiếng Việt',
    flag: '🇻🇳',
    assetPath: 'assets/translations/vi.json',
  ),
  _QaLocale(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
    assetPath: 'assets/translations/ja.json',
  ),
  _QaLocale(
    code: 'ko',
    name: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
    assetPath: 'assets/translations/ko.json',
  ),
];

class _SampleScreen {
  const _SampleScreen({
    required this.id,
    required this.label,
    required this.icon,
    required this.keys,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> keys;
}

const _kSampleScreens = [
  _SampleScreen(
    id: 'home',
    label: 'Home',
    icon: Icons.home_rounded,
    keys: ['tagline', 'home.status_safe', 'home.hold_for_sos', 'sos.trigger'],
  ),
  _SampleScreen(
    id: 'sos',
    label: 'SOS Active',
    icon: Icons.emergency_rounded,
    keys: ['sos.active', 'sos.countdown', 'sos.cancel', 'sos.sent'],
  ),
  _SampleScreen(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_rounded,
    keys: ['settings.title', 'settings.language', 'language.select'],
  ),
  _SampleScreen(
    id: 'onboarding',
    label: 'Onboarding',
    icon: Icons.login_rounded,
    keys: ['app_name', 'auth.verify', 'premium.title', 'common.done'],
  ),
];

const _kCheckItems = [
  ('layout_ok', 'Layout OK'),
  ('no_truncation', 'No text truncation'),
  ('screenshot_saved', 'Screenshot saved'),
  ('rtl_mirror', 'RTL mirrored correctly'),
];

Map<String, String> _flattenJson(Map<String, dynamic> json, [String prefix = '']) {
  final out = <String, String>{};
  json.forEach((key, value) {
    final path = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      out.addAll(_flattenJson(value, path));
    } else {
      out[path] = value.toString();
    }
  });
  return out;
}

String? _lookupFlat(Map<String, String> flat, String path) => flat[path];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d268TabProvider = StateProvider<int>((ref) => 0);
final _d268LocaleIndexProvider = StateProvider<int>((ref) => 0);
final _d268ScreenIndexProvider = StateProvider<int>((ref) => 0);
final _d268CyclingProvider = StateProvider<bool>((ref) => false);
final _d268CycleSecondsProvider = StateProvider<int>((ref) => 4);
final _d268CycleScreensProvider = StateProvider<bool>((ref) => true);
final _d268ChecklistProvider = StateProvider<Map<String, bool>>((ref) => {});

final _d268StringsProvider =
    FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final result = <String, Map<String, String>>{};
  for (final locale in _kQaLocales) {
    if (locale.assetPath != null) {
      final raw = await rootBundle.loadString(locale.assetPath!);
      result[locale.code] =
          _flattenJson(jsonDecode(raw) as Map<String, dynamic>);
    } else {
      final raw = await rootBundle.loadString('assets/translations/en.json');
      result[locale.code] =
          _flattenJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }
  return result;
});

String _checklistKey(String locale, String screen, String check) =>
    '$locale|$screen|$check';

// ── Screen ────────────────────────────────────────────────────────────────────
class Day268MultilangQaRunnerScreen extends ConsumerStatefulWidget {
  const Day268MultilangQaRunnerScreen({super.key});

  @override
  ConsumerState<Day268MultilangQaRunnerScreen> createState() =>
      _Day268MultilangQaRunnerScreenState();
}

class _Day268MultilangQaRunnerScreenState
    extends ConsumerState<Day268MultilangQaRunnerScreen> {
  Timer? _cycleTimer;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    final cycling = ref.read(_d268CyclingProvider);
    if (!cycling) return;

    final seconds = ref.read(_d268CycleSecondsProvider);
    _cycleTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!mounted) return;
      _advanceLocale();
    });
  }

  void _advanceLocale() {
    final localeIdx = ref.read(_d268LocaleIndexProvider);
    final cycleScreens = ref.read(_d268CycleScreensProvider);
    final nextLocale = (localeIdx + 1) % _kQaLocales.length;

    if (nextLocale == 0 && cycleScreens) {
      final screenIdx = ref.read(_d268ScreenIndexProvider);
      ref.read(_d268ScreenIndexProvider.notifier).state =
          (screenIdx + 1) % _kSampleScreens.length;
    }

    ref.read(_d268LocaleIndexProvider.notifier).state = nextLocale;
    HapticFeedback.selectionClick();
  }

  void _setCycling(bool value) {
    ref.read(_d268CyclingProvider.notifier).state = value;
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_d268CycleSecondsProvider, (_, __) => _syncTimer());
    ref.listen(_d268CyclingProvider, (_, __) => _syncTimer());

    final tab = ref.watch(_d268TabProvider);
    final cycling = ref.watch(_d268CyclingProvider);
    final checklist = ref.watch(_d268ChecklistProvider);
    final stringsAsync = ref.watch(_d268StringsProvider);

    final totalChecks = _kQaLocales.length *
        _kSampleScreens.length *
        _kCheckItems.length;
    final doneChecks = checklist.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 268 · Multi-Lang QA Runner'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (cycling ? _kAccent : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (cycling ? _kAccent : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  cycling ? 'CYCLING ▶' : '$doneChecks/$totalChecks QA',
                  style: TextStyle(
                    color: cycling ? _kAccent : ZapColors.textSecondary,
                    fontSize: 11,
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
            tab: tab,
            onSelect: (i) => ref.read(_d268TabProvider.notifier).state = i,
          ),
          Expanded(
            child: stringsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load locale strings · $e',
                  style: const TextStyle(color: ZapColors.danger),
                ),
              ),
              data: (strings) => switch (tab) {
                0 => _RunnerTab(
                    strings: strings,
                    onToggleCycle: _setCycling,
                    onAdvance: _advanceLocale,
                  ),
                1 => _ChecklistTab(strings: strings),
                _ => _InfoTab(
                    strings: strings,
                    doneChecks: doneChecks,
                    totalChecks: totalChecks,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Runner ─────────────────────────────────────────────────────────────
class _RunnerTab extends ConsumerWidget {
  const _RunnerTab({
    required this.strings,
    required this.onToggleCycle,
    required this.onAdvance,
  });

  final Map<String, Map<String, String>> strings;
  final ValueChanged<bool> onToggleCycle;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeIdx = ref.watch(_d268LocaleIndexProvider);
    final screenIdx = ref.watch(_d268ScreenIndexProvider);
    final cycling = ref.watch(_d268CyclingProvider);
    final cycleSeconds = ref.watch(_d268CycleSecondsProvider);
    final cycleScreens = ref.watch(_d268CycleScreensProvider);

    final locale = _kQaLocales[localeIdx];
    final screen = _kSampleScreens[screenIdx];
    final flat = strings[locale.code] ?? {};

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
            '🟢 FRONTEND-ONLY · Section D Day 8/20 · auto-cycle locales · mock sample screens',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => onToggleCycle(!cycling),
              icon: Icon(cycling ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(cycling ? 'Pause cycle' : 'Start cycle'),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
            ),
            const SizedBox(width: ZapSpacing.sm),
            OutlinedButton.icon(
              onPressed: onAdvance,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('Next locale'),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Text(
          'Interval · ${cycleSeconds}s',
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Slider(
          value: cycleSeconds.toDouble(),
          min: 2,
          max: 10,
          divisions: 8,
          label: '${cycleSeconds}s',
          activeColor: _kAccent,
          onChanged: cycling
              ? null
              : (v) =>
                  ref.read(_d268CycleSecondsProvider.notifier).state = v.round(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Advance sample screen each locale lap',
            style: TextStyle(color: ZapColors.textPrimary, fontSize: 13),
          ),
          value: cycleScreens,
          activeColor: _kAccent,
          onChanged: cycling
              ? null
              : (v) => ref.read(_d268CycleScreensProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_kSampleScreens.length, (i) {
            final s = _kSampleScreens[i];
            final selected = screenIdx == i;
            return ChoiceChip(
              label: Text(s.label),
              selected: selected,
              selectedColor: _kAccent.withOpacity(0.2),
              onSelected: cycling
                  ? null
                  : (_) => ref.read(_d268ScreenIndexProvider.notifier).state = i,
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Text(locale.flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${locale.name} (${locale.code})',
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    locale.nativeName,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (locale.rtl)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
                ),
                child: const Text(
                  'RTL',
                  style: TextStyle(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Sample · ${screen.label} · locale ${localeIdx + 1}/${_kQaLocales.length}',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.md),
        _SamplePreview(
          screen: screen,
          flat: flat,
          rtl: locale.rtl,
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...screen.keys.map((key) {
          final val = _lookupFlat(flat, key) ?? '—';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    val,
                    textDirection: locale.rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 12,
                    ),
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

class _SamplePreview extends StatelessWidget {
  const _SamplePreview({
    required this.screen,
    required this.flat,
    required this.rtl,
  });

  final _SampleScreen screen;
  final Map<String, String> flat;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final direction = rtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: direction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kAccent.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(screen.icon, size: 16, color: _kAccent),
                const SizedBox(width: 6),
                Text(
                  screen.label,
                  style: const TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            if (screen.id == 'home') ...[
              Text(
                _lookupFlat(flat, 'tagline') ?? '',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                _lookupFlat(flat, 'home.status_safe') ?? '',
                style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.sm),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(backgroundColor: ZapColors.danger),
                child: Text(_lookupFlat(flat, 'sos.trigger') ?? 'SOS'),
              ),
            ] else if (screen.id == 'sos') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lookupFlat(flat, 'sos.active') ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ZapColors.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                _lookupFlat(flat, 'sos.countdown') ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZapColors.textSecondary),
              ),
              TextButton(
                onPressed: () {},
                child: Text(_lookupFlat(flat, 'sos.cancel') ?? ''),
              ),
            ] else if (screen.id == 'settings') ...[
              Text(
                _lookupFlat(flat, 'settings.title') ?? '',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_lookupFlat(flat, 'settings.language') ?? ''),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ] else ...[
              Text(
                _lookupFlat(flat, 'app_name') ?? 'ZapSafe',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(_lookupFlat(flat, 'auth.verify') ?? ''),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                _lookupFlat(flat, 'premium.title') ?? '',
                style: const TextStyle(color: ZapColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab({required this.strings});

  final Map<String, Map<String, String>> strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklist = ref.watch(_d268ChecklistProvider);

    var applicable = 0;
    var done = 0;
    for (final locale in _kQaLocales) {
      for (final screen in _kSampleScreens) {
        for (final check in _kCheckItems) {
          if (check.$1 == 'rtl_mirror' && !locale.rtl) continue;
          applicable++;
          if (checklist[_checklistKey(locale.code, screen.id, check.$1)] ==
              true) {
            done++;
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        LinearProgressIndicator(
          value: applicable == 0 ? 0 : done / applicable,
          minHeight: 8,
          backgroundColor: ZapColors.border,
          color: done == applicable ? ZapColors.safe : _kAccent,
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          '$done/$applicable screenshot checks · translator QA checklist',
          style: TextStyle(
            color: done == applicable ? ZapColors.safe : ZapColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kQaLocales.map((locale) {
          return ExpansionTile(
            initiallyExpanded: locale.code == 'fa',
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: ZapSpacing.md),
            title: Row(
              children: [
                Text(locale.flag),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  '${locale.name} (${locale.code})',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (locale.rtl) ...[
                  const SizedBox(width: ZapSpacing.sm),
                  const Text(
                    'RTL',
                    style: TextStyle(color: ZapColors.warning, fontSize: 10),
                  ),
                ],
              ],
            ),
            children: _kSampleScreens.map((screen) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZapColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(screen.icon, size: 14, color: _kAccent),
                        const SizedBox(width: 6),
                        Text(
                          screen.label,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._kCheckItems.map((check) {
                      if (check.$1 == 'rtl_mirror' && !locale.rtl) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                          child: Text(
                            '${check.$2} · N/A (LTR)',
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }
                      final key =
                          _checklistKey(locale.code, screen.id, check.$1);
                      final checked = checklist[key] ?? false;
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: checked,
                        activeColor: ZapColors.safe,
                        title: Text(
                          check.$2,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onChanged: (v) {
                          final next = {...checklist};
                          if (v == true) {
                            next[key] = true;
                          } else {
                            next.remove(key);
                          }
                          ref.read(_d268ChecklistProvider.notifier).state = next;
                        },
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
          );
        }),
        FilledButton.icon(
          onPressed: done == applicable
              ? null
              : () {
                  final next = <String, bool>{...checklist};
                  for (final locale in _kQaLocales) {
                    for (final screen in _kSampleScreens) {
                      for (final check in _kCheckItems) {
                        if (check.$1 == 'rtl_mirror' && !locale.rtl) continue;
                        next[_checklistKey(
                          locale.code,
                          screen.id,
                          check.$1,
                        )] = true;
                      }
                    }
                  }
                  ref.read(_d268ChecklistProvider.notifier).state = next;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All checklist items marked.')),
                  );
                },
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Mark all complete'),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.safe,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            final report = _buildChecklistReport(checklist);
            Clipboard.setData(ClipboardData(text: _kJsonEncoder.convert(report)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QA checklist report copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy checklist report'),
        ),
      ],
    );
  }
}

Map<String, dynamic> _buildChecklistReport(Map<String, bool> checklist) {
  final locales = <Map<String, dynamic>>[];
  for (final locale in _kQaLocales) {
    final screens = <Map<String, dynamic>>[];
    for (final screen in _kSampleScreens) {
      final checks = <String, dynamic>{};
      for (final check in _kCheckItems) {
        if (check.$1 == 'rtl_mirror' && !locale.rtl) {
          checks[check.$1] = 'n/a';
        } else {
          checks[check.$1] =
              checklist[_checklistKey(locale.code, screen.id, check.$1)] ??
                  false;
        }
      }
      screens.add({'screen': screen.id, 'checks': checks});
    }
    locales.add({
      'locale': locale.code,
      'rtl': locale.rtl,
      'screens': screens,
    });
  }
  return {
    'report': 'multilang_qa_checklist',
    'generated_at': DateTime.now().toIso8601String(),
    'locales': locales,
  };
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab({
    required this.strings,
    required this.doneChecks,
    required this.totalChecks,
  });

  final Map<String, Map<String, String>> strings;
  final int doneChecks;
  final int totalChecks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycling = ref.watch(_d268CyclingProvider);
    final cycleSeconds = ref.watch(_d268CycleSecondsProvider);

    final payload = {
      'endpoint': 'POST /api/v1/i18n/qa-runner/session/',
      'locales': _kQaLocales.map((l) => l.code).toList(),
      'sample_screens': _kSampleScreens.map((s) => s.id).toList(),
      'cycle_interval_seconds': cycleSeconds,
      'cycling': cycling,
      'checklist_progress': '$doneChecks/$totalChecks',
      'workflow':
          'Days 263-267 packs → Day 268 QA runner → translator screenshots',
      'export': 'Copy checklist report JSON for Jira / Lokalise handoff',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.play_circle_rounded,
          title: 'Auto-cycle locales',
          subtitle:
              'Timer-driven locale rotation on 4 mock sample screens (Home, SOS, '
              'Settings, Onboarding) · loads fa/id/vi/ja/ko from assets.',
        ),
        const _PolicyRow(
          icon: Icons.checklist_rounded,
          title: 'Screenshot checklist',
          subtitle:
              'Per-locale × per-screen QA matrix · layout, truncation, screenshot, '
              'RTL mirror checks · exportable JSON report.',
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
            borderRadius: BorderRadius.circular(8),
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
              const SnackBar(content: Text('QA runner spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy runner spec'),
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
              label: const Text('Day 267 Korean Pack'),
              onPressed: () => context.push(AppRoutes.koreanPack),
            ),
            ActionChip(
              label: const Text('Day 266 Japanese Pack'),
              onPressed: () => context.push(AppRoutes.japanesePack),
            ),
            ActionChip(
              label: const Text('Day 263 Persian RTL'),
              onPressed: () => context.push(AppRoutes.persianRtl),
            ),
            ActionChip(
              label: const Text('Day 261 Language Hub'),
              onPressed: () => context.push(AppRoutes.languageExpansionHub),
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
