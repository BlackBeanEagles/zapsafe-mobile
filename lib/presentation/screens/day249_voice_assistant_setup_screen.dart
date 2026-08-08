/// Day 249 — Google Assistant & Alexa Setup
///
/// Section C (Days 241-260): setup cards for Google Assistant voice commands
/// and Alexa skill (mock links); phrase list with copy; links Day 248 Siri.
///
/// Tag: 🟢 FRONTEND-ONLY · Android voice · Alexa skill mock.
///
/// Route: [AppRoutes.voiceAssistantSetup] → `/voice-assistant-setup`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kGoogleBlue = Color(0xFF4285F4);
const _kAlexaTeal = Color(0xFF00CAFF);
const _kTabs = ['Assistants', 'Commands', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kGoogleAssistantUri = 'https://assistant.google.com/';
const _kAlexaSkillsUri = 'https://www.amazon.com/alexa-skills/';

const _kVoiceCommands = [
  _VoiceCommand(
    id: 'google_sos',
    assistant: 'google',
    phrase: 'OK Google, open ZapSafe emergency',
    action: 'Launch app → SOS alert pending flow',
    primary: true,
  ),
  _VoiceCommand(
    id: 'google_start',
    assistant: 'google',
    phrase: 'OK Google, start ZapSafe SOS',
    action: 'Same as emergency — alternate phrasing',
  ),
  _VoiceCommand(
    id: 'google_journey',
    assistant: 'google',
    phrase: 'OK Google, start my ZapSafe journey',
    action: 'Open Journey Mode (Day 241)',
  ),
  _VoiceCommand(
    id: 'alexa_open',
    assistant: 'alexa',
    phrase: 'Alexa, open ZapSafe',
    action: 'Launch ZapSafe skill home',
    primary: true,
  ),
  _VoiceCommand(
    id: 'alexa_sos',
    assistant: 'alexa',
    phrase: 'Alexa, tell ZapSafe to start emergency',
    action: 'Trigger SOS via skill intent (mock)',
  ),
  _VoiceCommand(
    id: 'alexa_checkin',
    assistant: 'alexa',
    phrase: 'Alexa, ask ZapSafe to check in',
    action: 'Journey check-in notify contact (Day 241)',
  ),
];

const _kGoogleSteps = [
  _SetupStep(
    title: 'Open Google Assistant settings',
    detail: 'Google app → Profile → Settings → Google Assistant.',
  ),
  _SetupStep(
    title: 'Create a Routine or shortcut',
    detail: 'Assistant → Routines → Add action → Open app.',
  ),
  _SetupStep(
    title: 'Choose ZapSafe',
    detail: 'Select ZapSafe from installed apps list.',
  ),
  _SetupStep(
    title: 'Set voice phrase',
    detail: 'Record: "OK Google, open ZapSafe emergency".',
  ),
  _SetupStep(
    title: 'Test the command',
    detail: 'Say phrase aloud — app should open to SOS flow.',
  ),
];

const _kAlexaSteps = [
  _SetupStep(
    title: 'Open Alexa app',
    detail: 'Skills & Games → search "ZapSafe Safety".',
  ),
  _SetupStep(
    title: 'Enable the skill',
    detail: 'Tap Enable · sign in with ZapSafe account (mock).',
  ),
  _SetupStep(
    title: 'Link account',
    detail: 'Grant location + contact permissions for SOS dispatch.',
  ),
  _SetupStep(
    title: 'Try the invocation',
    detail: '"Alexa, open ZapSafe" or "Alexa, tell ZapSafe emergency".',
  ),
];

// ── Models ────────────────────────────────────────────────────────────────────
class _VoiceCommand {
  const _VoiceCommand({
    required this.id,
    required this.assistant,
    required this.phrase,
    required this.action,
    this.primary = false,
  });

  final String id;
  final String assistant;
  final String phrase;
  final String action;
  final bool primary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assistant': assistant,
        'phrase': phrase,
        'action': action,
        'primary': primary,
      };
}

class _SetupStep {
  const _SetupStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d249TabProvider = StateProvider<int>((ref) => 0);
final _d249GoogleConfiguredProvider = StateProvider<bool>((ref) => false);
final _d249AlexaConfiguredProvider = StateProvider<bool>((ref) => false);
final _d249GoogleStepsDoneProvider = StateProvider<Set<int>>((ref) => {0});
final _d249AlexaStepsDoneProvider = StateProvider<Set<int>>((ref) => {});
final _d249FilterProvider = StateProvider<String>((ref) => 'all');

// ── Helpers ───────────────────────────────────────────────────────────────────
Future<void> _openExternalUri(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link unavailable on this device: $url')),
      );
    }
  }
}

List<_VoiceCommand> _filteredCommands(String filter) {
  if (filter == 'all') return _kVoiceCommands;
  return _kVoiceCommands.where((c) => c.assistant == filter).toList();
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day249VoiceAssistantSetupScreen extends ConsumerWidget {
  const Day249VoiceAssistantSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d249TabProvider);
    final googleOk = ref.watch(_d249GoogleConfiguredProvider);
    final alexaOk = ref.watch(_d249AlexaConfiguredProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 249 · Voice Assistants'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (googleOk || alexaOk
                          ? ZapColors.safe
                          : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (googleOk || alexaOk
                            ? ZapColors.safe
                            : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  '${(googleOk ? 1 : 0) + (alexaOk ? 1 : 0)}/2 SET UP',
                  style: TextStyle(
                    color: googleOk || alexaOk
                        ? ZapColors.safe
                        : ZapColors.textMuted,
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
            onSelect: (i) => ref.read(_d249TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _AssistantsTab(),
              1 => const _CommandsTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Assistants ─────────────────────────────────────────────────────────
class _AssistantsTab extends ConsumerWidget {
  const _AssistantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleOk = ref.watch(_d249GoogleConfiguredProvider);
    final alexaOk = ref.watch(_d249AlexaConfiguredProvider);
    final googleSteps = ref.watch(_d249GoogleStepsDoneProvider);
    final alexaSteps = ref.watch(_d249AlexaStepsDoneProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kGoogleBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kGoogleBlue.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 9/20 · Google Assistant + Alexa skill cards',
            style: TextStyle(color: _kGoogleBlue, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _AssistantCard(
          title: 'Google Assistant',
          subtitle: 'Android · "OK Google, open ZapSafe emergency"',
          color: _kGoogleBlue,
          icon: Icons.assistant_rounded,
          configured: googleOk,
          stepsDone: googleSteps.length,
          stepsTotal: _kGoogleSteps.length,
          onOpenExternal: () =>
              _openExternalUri(context, _kGoogleAssistantUri),
          openLabel: 'Open Google Assistant',
          steps: _kGoogleSteps,
          completedSteps: googleSteps,
          onStepToggle: (i, v) {
            final next = Set<int>.from(googleSteps);
            if (v) {
              next.add(i);
            } else {
              next.remove(i);
            }
            ref.read(_d249GoogleStepsDoneProvider.notifier).state = next;
            if (next.length == _kGoogleSteps.length) {
              ref.read(_d249GoogleConfiguredProvider.notifier).state = true;
            }
          },
          onMarkConfigured: () {
            ref.read(_d249GoogleConfiguredProvider.notifier).state =
                !googleOk;
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        _AssistantCard(
          title: 'Amazon Alexa',
          subtitle: 'Echo devices · ZapSafe skill (mock store link)',
          color: _kAlexaTeal,
          icon: Icons.speaker_group_rounded,
          configured: alexaOk,
          stepsDone: alexaSteps.length,
          stepsTotal: _kAlexaSteps.length,
          onOpenExternal: () => _openExternalUri(context, _kAlexaSkillsUri),
          openLabel: 'Open Alexa Skills store',
          steps: _kAlexaSteps,
          completedSteps: alexaSteps,
          onStepToggle: (i, v) {
            final next = Set<int>.from(alexaSteps);
            if (v) {
              next.add(i);
            } else {
              next.remove(i);
            }
            ref.read(_d249AlexaStepsDoneProvider.notifier).state = next;
            if (next.length == _kAlexaSteps.length) {
              ref.read(_d249AlexaConfiguredProvider.notifier).state = true;
            }
          },
          onMarkConfigured: () {
            ref.read(_d249AlexaConfiguredProvider.notifier).state = !alexaOk;
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.siriShortcuts),
          icon: const Icon(Icons.phone_iphone_rounded, size: 18),
          label: const Text('Day 248 · Siri Shortcuts (iOS)'),
        ),
      ],
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.configured,
    required this.stepsDone,
    required this.stepsTotal,
    required this.onOpenExternal,
    required this.openLabel,
    required this.steps,
    required this.completedSteps,
    required this.onStepToggle,
    required this.onMarkConfigured,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool configured;
  final int stepsDone;
  final int stepsTotal;
  final VoidCallback onOpenExternal;
  final String openLabel;
  final List<_SetupStep> steps;
  final Set<int> completedSteps;
  final void Function(int index, bool value) onStepToggle;
  final VoidCallback onMarkConfigured;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: configured ? color : ZapColors.border,
          width: configured ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
            trailing: configured
                ? Icon(Icons.check_circle_rounded, color: color)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stepsTotal == 0 ? 0 : stepsDone / stepsTotal,
                minHeight: 6,
                backgroundColor: ZapColors.bgPrimary,
                color: color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(openLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            return CheckboxListTile(
              value: completedSteps.contains(i),
              onChanged: (v) => onStepToggle(i, v ?? false),
              activeColor: color,
              dense: true,
              title: Text(
                step.title,
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                step.detail,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMarkConfigured,
              child: Text(
                configured ? 'Mark not configured' : 'Mark configured',
                style: TextStyle(color: color, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Commands ───────────────────────────────────────────────────────────
class _CommandsTab extends ConsumerWidget {
  const _CommandsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_d249FilterProvider);
    final commands = _filteredCommands(filter);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Voice command phrases',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('All'),
              selected: filter == 'all',
              onSelected: (_) =>
                  ref.read(_d249FilterProvider.notifier).state = 'all',
            ),
            FilterChip(
              label: const Text('Google'),
              selected: filter == 'google',
              onSelected: (_) =>
                  ref.read(_d249FilterProvider.notifier).state = 'google',
            ),
            FilterChip(
              label: const Text('Alexa'),
              selected: filter == 'alexa',
              onSelected: (_) =>
                  ref.read(_d249FilterProvider.notifier).state = 'alexa',
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...commands.map(
          (c) => _CommandTile(command: c),
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.command});

  final _VoiceCommand command;

  @override
  Widget build(BuildContext context) {
    final color = command.assistant == 'google' ? _kGoogleBlue : _kAlexaTeal;
    final label = command.assistant == 'google' ? 'GOOGLE' : 'ALEXA';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: command.primary ? color : ZapColors.border,
          ),
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
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (command.primary) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZapColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRIMARY',
                      style: TextStyle(
                        color: ZapColors.warning,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              command.phrase,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: ZapSpacing.xs),
            Text(
              command.action,
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: command.phrase));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied: ${command.phrase}')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleOk = ref.watch(_d249GoogleConfiguredProvider);
    final alexaOk = ref.watch(_d249AlexaConfiguredProvider);
    final googleSteps = ref.watch(_d249GoogleStepsDoneProvider);
    final alexaSteps = ref.watch(_d249AlexaStepsDoneProvider);

    final payload = {
      'feature': 'voice_assistant_setup',
      'version': '1.0.0',
      'section': 'C',
      'day': 249,
      'google_configured': googleOk,
      'alexa_configured': alexaOk,
      'google_steps_done': googleSteps.length,
      'google_steps_total': _kGoogleSteps.length,
      'alexa_steps_done': alexaSteps.length,
      'alexa_steps_total': _kAlexaSteps.length,
      'google_assistant_uri': _kGoogleAssistantUri,
      'alexa_skills_uri': _kAlexaSkillsUri,
      'commands': _kVoiceCommands.map((c) => c.toJson()).toList(),
      'siri_shortcuts_route': AppRoutes.siriShortcuts,
      'sos_active_route': AppRoutes.sosActive,
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAlexaTeal.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAlexaTeal.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Voice activation · Android + smart speakers',
            style: TextStyle(color: _kAlexaTeal, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Platform map',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.assistant_rounded,
          title: 'Google Assistant (Android)',
          subtitle:
              'Routines / app shortcuts · "OK Google, open ZapSafe emergency".',
        ),
        const _PolicyRow(
          icon: Icons.speaker_group_rounded,
          title: 'Amazon Alexa',
          subtitle: 'ZapSafe skill · mock Alexa Skills store deep link.',
        ),
        const _PolicyRow(
          icon: Icons.phone_iphone_rounded,
          title: 'Apple Siri',
          subtitle: 'See Day 248 — Shortcuts app + custom phrases.',
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
              const SnackBar(content: Text('Voice assistant JSON copied.')),
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
            borderRadius: BorderRadius.circular(8),
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
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 241 Journey Mode'),
              onPressed: () => context.push(AppRoutes.journeyModeV2),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kGoogleBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kGoogleBlue : ZapColors.textMuted,
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
