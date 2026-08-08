/// Day 283 — Demo Video Storyboard
///
/// Section E (Days 281-300): 6-scene storyboard for a 60-second promo video
/// covering SOS flow, evidence vault, and privacy messaging.
///
/// Tag: 🟢 FRONTEND-ONLY · mock storyboard · no video export.
///
/// Route: [AppRoutes.demoVideoStoryboard] → `/demo-video-storyboard`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF7C3AED);
const _kTabs = ['Storyboard', 'Timeline', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');
const _kTotalSeconds = 60;

class _StoryScene {
  const _StoryScene({
    required this.id,
    required this.number,
    required this.title,
    required this.startSec,
    required this.durationSec,
    required this.visual,
    required this.voiceover,
    required this.onScreenText,
    required this.color,
    required this.icon,
  });

  final String id;
  final int number;
  final String title;
  final int startSec;
  final int durationSec;
  final String visual;
  final String voiceover;
  final String onScreenText;
  final Color color;
  final IconData icon;
}

const _kScenes = [
  _StoryScene(
    id: 'hook',
    number: 1,
    title: 'Hook — walking alone',
    startSec: 0,
    durationSec: 10,
    visual: 'Night street · woman checks phone · subtle tension',
    voiceover:
        'Every woman deserves to feel safe walking home — even at 11 PM.',
    onScreenText: 'Safety in your pocket',
    color: Color(0xFF6366F1),
    icon: Icons.nightlight_round,
  ),
  _StoryScene(
    id: 'sos',
    number: 2,
    title: 'SOS long-press',
    startSec: 10,
    durationSec: 10,
    visual: 'Close-up · 2-second ring fill · haptic pulse',
    voiceover:
        'One long-press — two seconds — and your trusted contacts are alerted.',
    onScreenText: 'Hold 2s to trigger SOS',
    color: ZapColors.danger,
    icon: Icons.emergency_rounded,
  ),
  _StoryScene(
    id: 'journey',
    number: 3,
    title: 'Journey mode live',
    startSec: 20,
    durationSec: 10,
    visual: 'Map tracking · live share link · Tier 1 notified',
    voiceover:
        'Journey mode shares your route in real time — only with people you trust.',
    onScreenText: 'Live journey sharing',
    color: Color(0xFF3B82F6),
    icon: Icons.map_rounded,
  ),
  _StoryScene(
    id: 'evidence',
    number: 4,
    title: 'Evidence vault',
    startSec: 30,
    durationSec: 10,
    visual: 'Encrypted audio waveform · location trail · timestamp chain',
    voiceover:
        'Evidence is captured automatically — encrypted before it ever leaves your phone.',
    onScreenText: 'Encrypted evidence vault',
    color: Color(0xFF8B5CF6),
    icon: Icons.folder_special_rounded,
  ),
  _StoryScene(
    id: 'privacy',
    number: 5,
    title: 'Privacy on-device',
    startSec: 40,
    durationSec: 10,
    visual: 'On-device AI chip graphic · consent gates · no cloud upload',
    voiceover:
        'AI listens on your device — not in the cloud. You control every permission.',
    onScreenText: 'Privacy-first · on-device AI',
    color: ZapColors.safe,
    icon: Icons.shield_rounded,
  ),
  _StoryScene(
    id: 'cta',
    number: 6,
    title: 'CTA + logo',
    startSec: 50,
    durationSec: 10,
    visual: 'ZapSafe logo · App Store badges · zapsafe.github.io',
    voiceover: 'Download ZapSafe free — because your safety should never wait.',
    onScreenText: 'Get ZapSafe · Free',
    color: _kAccent,
    icon: Icons.download_rounded,
  ),
];

String _formatTime(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _buildScript() {
  final buf = StringBuffer('ZapSafe 60s Promo — Storyboard Script\n\n');
  for (final scene in _kScenes) {
    buf.writeln(
      'Scene ${scene.number} · ${_formatTime(scene.startSec)}–'
      '${_formatTime(scene.startSec + scene.durationSec)} · ${scene.title}',
    );
    buf.writeln('  Visual: ${scene.visual}');
    buf.writeln('  VO: "${scene.voiceover}"');
    buf.writeln('  Text: ${scene.onScreenText}');
    buf.writeln();
  }
  return buf.toString();
}

Map<String, dynamic> _storyboardPayload({
  required int selectedScene,
  required Set<String> approved,
  required double playbackSec,
}) =>
    {
      'endpoint': 'GET /api/v1/marketing/video-storyboard/',
      'total_duration_sec': _kTotalSeconds,
      'scene_count': _kScenes.length,
      'selected_scene': _kScenes[selectedScene].id,
      'playback_position_sec': playbackSec.round(),
      'scenes_approved': approved.length,
      'scenes': _kScenes
          .map(
            (s) => {
              'id': s.id,
              'start': s.startSec,
              'duration': s.durationSec,
              'approved': approved.contains(s.id),
            },
          )
          .toList(),
      'wire_note': 'Mock storyboard · export to production brief PDF later',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d283TabProvider = StateProvider<int>((ref) => 0);
final _d283SceneIndexProvider = StateProvider<int>((ref) => 0);
final _d283ApprovedProvider = StateProvider<Set<String>>((ref) => {});
final _d283PlaybackProvider = StateProvider<double>((ref) => 0);
final _d283PlayingProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day283DemoVideoStoryboardScreen extends ConsumerWidget {
  const Day283DemoVideoStoryboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approved = ref.watch(_d283ApprovedProvider);
    final playing = ref.watch(_d283PlayingProvider);
    final playback = ref.watch(_d283PlaybackProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 283 · Video Storyboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  playing
                      ? _formatTime(playback.round())
                      : '${approved.length}/6 OK',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
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
            tab: ref.watch(_d283TabProvider),
            onSelect: (i) => ref.read(_d283TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d283TabProvider)) {
              0 => const _StoryboardTab(),
              1 => const _TimelineTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Storyboard ─────────────────────────────────────────────────────────
class _StoryboardTab extends ConsumerWidget {
  const _StoryboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d283SceneIndexProvider);
    final approved = ref.watch(_d283ApprovedProvider);
    final scene = _kScenes[selected];

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
            '🟢 FRONTEND-ONLY · Section E Day 3/20 · 6 scenes · 60s promo · SOS · evidence · privacy',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _kScenes.length,
            separatorBuilder: (_, __) => const SizedBox(width: ZapSpacing.sm),
            itemBuilder: (context, i) {
              final s = _kScenes[i];
              final isSelected = selected == i;
              final isApproved = approved.contains(s.id);
              return GestureDetector(
                onTap: () =>
                    ref.read(_d283SceneIndexProvider.notifier).state = i,
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? s.color.withOpacity(0.15)
                        : ZapColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? s.color : ZapColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(s.icon, size: 20, color: s.color),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(
                        '${s.number}',
                        style: TextStyle(
                          color: s.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      if (isApproved)
                        const Icon(Icons.check_rounded,
                            size: 12, color: ZapColors.safe),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scene.color.withOpacity(0.2),
                scene.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scene.color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scene.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(scene.icon, color: scene.color, size: 24),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scene ${scene.number} · ${scene.title}',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${_formatTime(scene.startSec)} – '
                          '${_formatTime(scene.startSec + scene.durationSec)} · '
                          '${scene.durationSec}s',
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              _DetailRow(label: 'Visual', value: scene.visual),
              _DetailRow(label: 'Voiceover', value: '"${scene.voiceover}"'),
              _DetailRow(label: 'On-screen', value: scene.onScreenText),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final next = {...approved};
                        if (next.contains(scene.id)) {
                          next.remove(scene.id);
                        } else {
                          next.add(scene.id);
                        }
                        ref.read(_d283ApprovedProvider.notifier).state = next;
                      },
                      icon: Icon(
                        approved.contains(scene.id)
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: approved.contains(scene.id)
                            ? ZapColors.safe
                            : ZapColors.textMuted,
                      ),
                      label: Text(
                        approved.contains(scene.id) ? 'Approved' : 'Approve scene',
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  IconButton.filled(
                    onPressed: selected < _kScenes.length - 1
                        ? () => ref
                            .read(_d283SceneIndexProvider.notifier)
                            .state = selected + 1
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    style: IconButton.styleFrom(backgroundColor: _kAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Timeline ───────────────────────────────────────────────────────────
class _TimelineTab extends ConsumerStatefulWidget {
  const _TimelineTab();

  @override
  ConsumerState<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<_TimelineTab> {

  Future<void> _playPreview(WidgetRef ref) async {
    if (ref.read(_d283PlayingProvider)) return;
    ref.read(_d283PlayingProvider.notifier).state = true;
    ref.read(_d283PlaybackProvider.notifier).state = 0;

    for (var t = 0; t <= _kTotalSeconds; t++) {
      if (!ref.read(_d283PlayingProvider)) break;
      ref.read(_d283PlaybackProvider.notifier).state = t.toDouble();
      final sceneIdx = _kScenes.indexWhere(
        (s) => t >= s.startSec && t < s.startSec + s.durationSec,
      );
      if (sceneIdx >= 0) {
        ref.read(_d283SceneIndexProvider.notifier).state = sceneIdx;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    ref.read(_d283PlayingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final playback = ref.watch(_d283PlaybackProvider);
        final playing = ref.watch(_d283PlayingProvider);
        final progress = playback / _kTotalSeconds;

        return ListView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          children: [
            const _SectionTitle(
              title: '60-second timeline',
              subtitle: '6 scenes × 10s each · mock playback scrubber',
            ),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.lg),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ZapColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    _formatTime(playback.round()),
                    style: const TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(
                    '/ 01:00',
                    style: TextStyle(color: ZapColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: ZapSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: ZapColors.border,
                      color: _kAccent,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: playing
                              ? () => ref
                                  .read(_d283PlayingProvider.notifier)
                                  .state = false
                              : () => _playPreview(ref),
                          icon: Icon(
                            playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(playing ? 'Stop preview' : 'Play preview'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),
            ..._kScenes.map((scene) {
              final active = playback >= scene.startSec &&
                  playback < scene.startSec + scene.durationSec;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: active
                      ? scene.color.withOpacity(0.12)
                      : ZapColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active
                        ? scene.color.withOpacity(0.5)
                        : ZapColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scene.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${scene.number}',
                        style: TextStyle(
                          color: scene.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scene.title,
                            style: TextStyle(
                              color: active
                                  ? ZapColors.textPrimary
                                  : ZapColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_formatTime(scene.startSec)} · ${scene.durationSec}s',
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (active)
                      Icon(Icons.play_circle_rounded,
                          color: scene.color, size: 20),
                  ],
                ),
              );
            }),
            const SizedBox(height: ZapSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _buildScript()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Full storyboard script copied.')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy full script'),
            ),
          ],
        );
      },
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d283SceneIndexProvider);
    final approved = ref.watch(_d283ApprovedProvider);
    final playback = ref.watch(_d283PlaybackProvider);
    final payload = _storyboardPayload(
      selectedScene: selected,
      approved: approved,
      playbackSec: playback,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.movie_creation_rounded,
          title: 'Demo video storyboard',
          subtitle:
              '6-scene 60s promo covering SOS long-press, journey mode, '
              'evidence vault, and on-device privacy — production brief mock.',
        ),
        const _PolicyRow(
          icon: Icons.timer_rounded,
          title: 'Timeline preview',
          subtitle:
              'Mock playback advances scene selection · copy full VO script '
              'for video production vendor.',
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
              const SnackBar(content: Text('Storyboard spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy storyboard spec'),
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
              label: const Text('Day 282 Press Kit'),
              onPressed: () => context.push(AppRoutes.pressKit),
            ),
            ActionChip(
              label: const Text('Day 203 SOS Ring'),
              onPressed: () => context.push(AppRoutes.sosLongPressRing),
            ),
            ActionChip(
              label: const Text('Day 281 Landing Preview'),
              onPressed: () => context.push(AppRoutes.landingPreview),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
