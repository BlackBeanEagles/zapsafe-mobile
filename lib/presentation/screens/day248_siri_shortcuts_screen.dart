/// Day 248 — Siri Shortcuts Setup
///
/// Section C (Days 241-260): guide to add "Hey Siri, ZapSafe SOS" and related
/// voice phrases; iOS Shortcuts app steps + deep link; Android → Day 249.
///
/// Tag: 🟢 FRONTEND-ONLY · in-app phrase list · mock install checklist.
///
/// Route: [AppRoutes.siriShortcuts] → `/siri-shortcuts`
library;

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF007AFF);
const _kTabs = ['Phrases', 'Setup', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kShortcutsAppUri = 'shortcuts://';

const _kPhrases = [
  _SiriPhrase(
    id: 'sos_primary',
    phrase: 'Hey Siri, ZapSafe SOS',
    action: 'Trigger SOS immediately (15s alert pending)',
    intent: 'com.zapsafe.sos.trigger',
    primary: true,
  ),
  _SiriPhrase(
    id: 'sos_emergency',
    phrase: 'Hey Siri, start ZapSafe emergency',
    action: 'Same as primary SOS — alternate wording',
    intent: 'com.zapsafe.sos.trigger',
  ),
  _SiriPhrase(
    id: 'help',
    phrase: 'Hey Siri, ZapSafe help',
    action: 'Open app to safety dashboard',
    intent: 'com.zapsafe.open.dashboard',
  ),
  _SiriPhrase(
    id: 'journey',
    phrase: 'Hey Siri, start my ZapSafe journey',
    action: 'Open Journey Mode planner (Day 241)',
    intent: 'com.zapsafe.journey.start',
  ),
  _SiriPhrase(
    id: 'checkin',
    phrase: 'Hey Siri, ZapSafe check in',
    action: 'Send journey check-in to notify contact',
    intent: 'com.zapsafe.journey.checkin',
  ),
  _SiriPhrase(
    id: 'drill',
    phrase: 'Hey Siri, ZapSafe safety drill',
    action: 'Start practice drill (no live dispatch mock)',
    intent: 'com.zapsafe.drill.start',
  ),
];

const _kSetupSteps = [
  _SetupStep(
    title: 'Open the Shortcuts app',
    detail: 'Tap the button below or find Shortcuts on your Home Screen.',
  ),
  _SetupStep(
    title: 'Create a new shortcut',
    detail: 'Tap + in the top-right → Add Action.',
  ),
  _SetupStep(
    title: 'Add "Open App" action',
    detail: 'Search Open App → choose ZapSafe from the list.',
  ),
  _SetupStep(
    title: 'Add ZapSafe SOS intent',
    detail:
        'Search ZapSafe → add Run ZapSafe SOS (requires ZapSafe 2.0+ on device).',
  ),
  _SetupStep(
    title: 'Name the shortcut',
    detail: 'Rename to "ZapSafe SOS" — Siri uses this name in phrases.',
  ),
  _SetupStep(
    title: 'Add to Siri',
    detail:
        'Tap shortcut → Share → Add to Siri → record "Hey Siri, ZapSafe SOS".',
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
enum _VoicePlatform { ios, android, other }

class _SiriPhrase {
  const _SiriPhrase({
    required this.id,
    required this.phrase,
    required this.action,
    required this.intent,
    this.primary = false,
  });

  final String id;
  final String phrase;
  final String action;
  final String intent;
  final bool primary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phrase': phrase,
        'action': action,
        'intent': intent,
        'primary': primary,
      };
}

class _SetupStep {
  const _SetupStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d248TabProvider = StateProvider<int>((ref) => 0);
final _d248PlatformOverrideProvider =
    StateProvider<_VoicePlatform?>((ref) => null);
final _d248InstalledPhrasesProvider =
    StateProvider<Set<String>>((ref) => {'sos_primary'});
final _d248CompletedStepsProvider = StateProvider<Set<int>>((ref) => {0});
final _d248SelectedPhraseProvider =
    StateProvider<String>((ref) => 'sos_primary');

// ── Helpers ───────────────────────────────────────────────────────────────────
_VoicePlatform _detectVoicePlatform() {
  if (kIsWeb) return _VoicePlatform.other;
  if (Platform.isIOS) return _VoicePlatform.ios;
  if (Platform.isAndroid) return _VoicePlatform.android;
  return _VoicePlatform.other;
}

String _platformLabel(_VoicePlatform p) => switch (p) {
      _VoicePlatform.ios => 'iOS · Siri',
      _VoicePlatform.android => 'Android · see Day 249',
      _VoicePlatform.other => 'Other · manual setup',
    };

_SiriPhrase _phraseById(String id) {
  return _kPhrases.firstWhere(
    (p) => p.id == id,
    orElse: () => _kPhrases.first,
  );
}

Future<void> _openShortcutsApp(BuildContext context) async {
  final uri = Uri.parse(_kShortcutsAppUri);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Shortcuts app — open manually on iOS.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Shortcuts deep link unavailable on this device (mock).'),
        ),
      );
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day248SiriShortcutsScreen extends ConsumerWidget {
  const Day248SiriShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d248TabProvider);
    final platform =
        ref.watch(_d248PlatformOverrideProvider) ?? _detectVoicePlatform();
    final installed = ref.watch(_d248InstalledPhrasesProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 248 · Siri Shortcuts'),
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
                  '${installed.length}/${_kPhrases.length} PHRASES',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
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
            onSelect: (i) => ref.read(_d248TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _PhrasesTab(),
              1 => _SetupTab(platform: platform),
              _ => _InfoTab(platform: platform),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Phrases ──────────────────────────────────────────────────────────
class _PhrasesTab extends ConsumerWidget {
  const _PhrasesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(_d248InstalledPhrasesProvider);
    final selected = ref.watch(_d248SelectedPhraseProvider);

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
            '🟢 FRONTEND-ONLY · Section C Day 8/20 · Siri phrase library · tap to copy',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccent.withOpacity(0.2),
                _kAccent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.4)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mic_rounded, color: _kAccent),
                  SizedBox(width: ZapSpacing.sm),
                  Text(
                    'Primary phrase',
                    style: TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                '"Hey Siri, ZapSafe SOS"',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: ZapSpacing.xs),
              Text(
                'Hands-free SOS when you cannot reach the screen.',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'All supported phrases',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kPhrases.map(
          (p) => _PhraseTile(
            phrase: p,
            installed: installed.contains(p.id),
            selected: selected == p.id,
            onSelect: () =>
                ref.read(_d248SelectedPhraseProvider.notifier).state = p.id,
            onToggleInstalled: () {
              final next = Set<String>.from(installed);
              if (next.contains(p.id)) {
                next.remove(p.id);
              } else {
                next.add(p.id);
              }
              ref.read(_d248InstalledPhrasesProvider.notifier).state = next;
            },
          ),
        ),
      ],
    );
  }
}

class _PhraseTile extends StatelessWidget {
  const _PhraseTile({
    required this.phrase,
    required this.installed,
    required this.selected,
    required this.onSelect,
    required this.onToggleInstalled,
  });

  final _SiriPhrase phrase;
  final bool installed;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onToggleInstalled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _kAccent.withOpacity(0.1) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _kAccent : ZapColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (phrase.primary)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _kAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  color: _kAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          Text(
                            phrase.phrase,
                            style: const TextStyle(
                              color: ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: ZapSpacing.xs),
                          Text(
                            phrase.action,
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                          installed ? 'Mark not installed' : 'Mark installed',
                      onPressed: onToggleInstalled,
                      icon: Icon(
                        installed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: installed ? ZapColors.safe : ZapColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phrase.intent,
                        style: const TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: phrase.phrase),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied: ${phrase.phrase}')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: Setup ──────────────────────────────────────────────────────────────
class _SetupTab extends ConsumerWidget {
  const _SetupTab({required this.platform});

  final _VoicePlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(_d248CompletedStepsProvider);
    final override = ref.watch(_d248PlatformOverrideProvider);

    if (platform == _VoicePlatform.android) {
      return ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          _PlatformPicker(
            current: override ?? _detectVoicePlatform(),
            onSelect: (p) =>
                ref.read(_d248PlatformOverrideProvider.notifier).state = p,
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZapColors.info.withOpacity(0.35)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.android_rounded, color: ZapColors.info),
                    SizedBox(width: ZapSpacing.sm),
                    Text(
                      'Android detected',
                      style: TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ZapSpacing.sm),
                Text(
                  'Siri Shortcuts are iOS-only. On Android use Google Assistant '
                  'voice commands — built on Day 249.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            icon: const Icon(Icons.record_voice_over_rounded),
            label: const Text('Day 249 · Google Assistant & Alexa'),
            style: FilledButton.styleFrom(
              backgroundColor: ZapColors.info,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Tip: use platform picker above to preview iOS Shortcuts flow on any device.',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 10),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _PlatformPicker(
          current: override ?? _detectVoicePlatform(),
          onSelect: (p) =>
              ref.read(_d248PlatformOverrideProvider.notifier).state = p,
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openShortcutsApp(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open Shortcuts app'),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Deep link: shortcuts:// (iOS only)',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZapColors.textMuted, fontSize: 9),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Setup checklist (${completed.length}/${_kSetupSteps.length})',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...List.generate(_kSetupSteps.length, (i) {
          final step = _kSetupSteps[i];
          final done = completed.contains(i);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: done ? _kAccent.withOpacity(0.08) : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              child: CheckboxListTile(
                value: done,
                onChanged: (v) {
                  final next = Set<int>.from(completed);
                  if (v == true) {
                    next.add(i);
                  } else {
                    next.remove(i);
                  }
                  ref.read(_d248CompletedStepsProvider.notifier).state = next;
                },
                activeColor: _kAccent,
                title: Text(
                  '${i + 1}. ${step.title}',
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  step.detail,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.sosActive),
          icon: const Icon(Icons.emergency_rounded, size: 18),
          label: const Text('Day 76 · SOS Active target'),
        ),
      ],
    );
  }
}

class _PlatformPicker extends StatelessWidget {
  const _PlatformPicker({
    required this.current,
    required this.onSelect,
  });

  final _VoicePlatform current;
  final ValueChanged<_VoicePlatform> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform preview · ${_platformLabel(current)}',
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('iOS'),
                selected: current == _VoicePlatform.ios,
                onSelected: (_) => onSelect(_VoicePlatform.ios),
              ),
              ChoiceChip(
                label: const Text('Android'),
                selected: current == _VoicePlatform.android,
                onSelected: (_) => onSelect(_VoicePlatform.android),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.platform});

  final _VoicePlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(_d248InstalledPhrasesProvider);
    final completed = ref.watch(_d248CompletedStepsProvider);
    final selected = ref.watch(_d248SelectedPhraseProvider);
    final phrase = _phraseById(selected);

    final payload = {
      'feature': 'siri_shortcuts_setup',
      'version': '1.0.0',
      'section': 'C',
      'day': 248,
      'platform': platform.name,
      'shortcuts_app_uri': _kShortcutsAppUri,
      'installed_phrase_ids': installed.toList(),
      'setup_steps_completed': completed.length,
      'setup_steps_total': _kSetupSteps.length,
      'selected_phrase': phrase.toJson(),
      'phrases': _kPhrases.map((p) => p.toJson()).toList(),
      'sos_active_route': AppRoutes.sosActive,
      'android_alternative_day': 249,
    };

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
            '🟢 FRONTEND-ONLY · Voice activation · iOS Shortcuts · Android → Day 249',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Platform notes',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.phone_iphone_rounded,
          title: 'iOS · Siri + Shortcuts',
          subtitle:
              'User records custom phrase linked to ZapSafe SOS intent in Shortcuts app.',
        ),
        const _PolicyRow(
          icon: Icons.android_rounded,
          title: 'Android · Day 249',
          subtitle:
              'Google Assistant / Alexa setup cards — not Siri Shortcuts.',
        ),
        const _PolicyRow(
          icon: Icons.security_rounded,
          title: 'Voice trigger safety',
          subtitle:
              'SOS still runs 15s alert pending · duress PIN unchanged (Day 76).',
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
              const SnackBar(content: Text('Siri shortcuts JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy setup JSON'),
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
            'Next: Day 365 — Global Launch Milestone.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 252 Group Panic'),
              onPressed: () => context.push(AppRoutes.groupJourneyPanic),
            ),
            ActionChip(
              label: const Text('Day 251 Live Map'),
              onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
            ),
            ActionChip(
              label: const Text('Day 250 Group Journey'),
              onPressed: () => context.push(AppRoutes.groupJourneyCreate),
            ),
            ActionChip(
              label: const Text('Day 249 Voice Assistants'),
              onPressed: () => context.push(AppRoutes.voiceAssistantSetup),
            ),
            ActionChip(
              label: const Text('Day 247 Haptic Patterns'),
              onPressed: () => context.push(AppRoutes.hapticPatterns),
            ),
            ActionChip(
              label: const Text('Day 76 SOS Active'),
              onPressed: () => context.push(AppRoutes.sosActive),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZapColors.info, size: 20),
          const SizedBox(width: 10),
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
