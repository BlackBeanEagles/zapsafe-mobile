/// Day 246 — Hearing Impaired Mode — Visual Alerts
///
/// Section C (Days 241-260): high-intensity red screen flash pattern for alerts
/// when audio is disabled; test flash with accessibility warning; respects
/// reduced-motion system setting.
///
/// Tag: 🟢 FRONTEND-ONLY · links Day 97 Accessibility settings.
///
/// Route: [AppRoutes.hearingImpairedVisual] → `/hearing-impaired-visual`
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/accessibility_providers.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kFlashRed = ZapColors.danger;
const _kAccent = Color(0xFFEF4444);
const _kTabs = ['Settings', 'Preview', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// ── Providers ─────────────────────────────────────────────────────────────────
final _d246TabProvider = StateProvider<int>((ref) => 0);
final _d246VisualAlertsEnabledProvider = StateProvider<bool>((ref) => true);
final _d246AudioAlertsDisabledProvider = StateProvider<bool>((ref) => true);
final _d246FlashIntensityProvider = StateProvider<String>((ref) => 'high');
final _d246WarningAcknowledgedProvider = StateProvider<bool>((ref) => false);
final _d246FlashActiveProvider = StateProvider<bool>((ref) => false);
final _d246TestCountProvider = StateProvider<int>((ref) => 0);
final _d246UseReducedMotionFallbackProvider =
    StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day246HearingImpairedVisualScreen extends ConsumerStatefulWidget {
  const Day246HearingImpairedVisualScreen({super.key});

  @override
  ConsumerState<Day246HearingImpairedVisualScreen> createState() =>
      _Day246HearingImpairedVisualScreenState();
}

class _Day246HearingImpairedVisualScreenState
    extends ConsumerState<Day246HearingImpairedVisualScreen> {
  Timer? _flashTimer;
  int _flashStep = 0;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  bool _isReduceMotion(BuildContext context) {
    final a11y = ref.read(accessibilityProvider);
    return a11y.reduceMotion || MediaQuery.of(context).disableAnimations;
  }

  Future<void> _requestTestFlash() async {
    if (!ref.read(_d246VisualAlertsEnabledProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enable visual alerts in Settings first.')),
      );
      return;
    }

    if (!ref.read(_d246WarningAcknowledgedProvider)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ZapColors.bgCard,
          title: const Text(
            'Photosensitivity warning',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          content: const Text(
            'The test flash uses high-intensity red full-screen pulses. '
            'Do not use if you are photosensitive or prone to seizures. '
            'Reduced-motion mode uses a steady panel instead of rapid flashes.',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('I understand — test flash'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      ref.read(_d246WarningAcknowledgedProvider.notifier).state = true;
    }

    _runFlashSequence();
  }

  void _runFlashSequence() {
    _flashTimer?.cancel();
    final reduced = _isReduceMotion(context);
    ref.read(_d246UseReducedMotionFallbackProvider.notifier).state = reduced;
    ref.read(_d246FlashActiveProvider.notifier).state = true;
    ref.read(_d246TestCountProvider.notifier).state =
        ref.read(_d246TestCountProvider) + 1;
    _flashStep = 0;

    if (reduced) {
      HapticFeedback.mediumImpact();
      _flashTimer = Timer(const Duration(seconds: 2), _endFlash);
      setState(() {});
      return;
    }

    const flashes = 6; // 3 on/off cycles
    _flashTimer = Timer.periodic(const Duration(milliseconds: 350), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      _flashStep++;
      if (_flashStep >= flashes) {
        t.cancel();
        _endFlash();
      } else {
        if (_flashStep.isOdd) HapticFeedback.lightImpact();
        setState(() {});
      }
    });
    HapticFeedback.heavyImpact();
    setState(() {});
  }

  void _endFlash() {
    _flashTimer?.cancel();
    ref.read(_d246FlashActiveProvider.notifier).state = false;
    ref.read(_d246UseReducedMotionFallbackProvider.notifier).state = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_d246TabProvider);
    final flashActive = ref.watch(_d246FlashActiveProvider);
    final enabled = ref.watch(_d246VisualAlertsEnabledProvider);
    final reduceMotion = _isReduceMotion(context);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 246 · Visual Alerts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: (enabled ? ZapColors.safe : ZapColors.textMuted)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (enabled ? ZapColors.safe : ZapColors.textMuted)
                        .withOpacity(0.45),
                  ),
                ),
                child: Text(
                  enabled ? 'ENABLED' : 'OFF',
                  style: TextStyle(
                    color: enabled ? ZapColors.safe : ZapColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (reduceMotion)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.lg,
                    vertical: 6,
                  ),
                  color: ZapColors.warning.withOpacity(0.12),
                  child: const Text(
                    'Reduce motion active — flash test uses steady panel, not rapid pulses',
                    style: TextStyle(
                      color: ZapColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _TabBar(
                tab: tab,
                onSelect: (i) => ref.read(_d246TabProvider.notifier).state = i,
              ),
              Expanded(
                child: switch (tab) {
                  0 => const _SettingsTab(),
                  1 => _PreviewTab(onTestFlash: _requestTestFlash),
                  _ => const _InfoTab(),
                },
              ),
            ],
          ),
          if (flashActive) _FlashOverlay(step: _flashStep),
        ],
      ),
    );
  }
}

// ── Flash overlay ─────────────────────────────────────────────────────────────
class _FlashOverlay extends ConsumerWidget {
  const _FlashOverlay({required this.step});

  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduced = ref.watch(_d246UseReducedMotionFallbackProvider);
    final intensity = ref.watch(_d246FlashIntensityProvider);
    final opacity = intensity == 'high' ? 0.92 : 0.72;
    final flashOn = step.isOdd;

    if (reduced) {
      return Material(
        color: _kFlashRed.withOpacity(0.75),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 64,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(height: ZapSpacing.lg),
                const Text(
                  'VISUAL ALERT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Reduced motion · steady panel',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: flashOn ? _kFlashRed.withOpacity(opacity) : Colors.transparent,
      ),
    );
  }
}

// ── Tab 0: Settings ───────────────────────────────────────────────────────────
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(_d246VisualAlertsEnabledProvider);
    final audioOff = ref.watch(_d246AudioAlertsDisabledProvider);
    final intensity = ref.watch(_d246FlashIntensityProvider);
    final a11y = ref.watch(accessibilityProvider);
    final systemReduceMotion = MediaQuery.of(context).disableAnimations;

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
            '🟢 FRONTEND-ONLY · Section C Day 6/20 · hearing impaired visual SOS alerts',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: SwitchListTile(
            value: enabled,
            onChanged: (v) {
              ref.read(_d246VisualAlertsEnabledProvider.notifier).state = v;
              HapticFeedback.selectionClick();
            },
            secondary: Icon(
              Icons.flare_rounded,
              color: enabled ? _kAccent : ZapColors.textMuted,
            ),
            title: const Text(
              'Hearing impaired visual alerts',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'Full-screen red flash when SOS/drill fires and audio alerts are off',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
            activeColor: _kAccent,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: SwitchListTile(
            value: audioOff,
            onChanged: enabled
                ? (v) {
                    ref.read(_d246AudioAlertsDisabledProvider.notifier).state =
                        v;
                  }
                : null,
            secondary: Icon(
              Icons.volume_off_rounded,
              color: audioOff ? _kAccent : ZapColors.textMuted,
            ),
            title: const Text(
              'Audio alerts disabled',
              style: TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'When on, visual flash replaces sound for alert delivery',
              style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
            activeColor: _kAccent,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Flash intensity',
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
            ChoiceChip(
              label: const Text('Standard'),
              selected: intensity == 'standard',
              onSelected: (_) => ref
                  .read(_d246FlashIntensityProvider.notifier)
                  .state = 'standard',
              selectedColor: _kAccent.withOpacity(0.25),
            ),
            ChoiceChip(
              label: const Text('High'),
              selected: intensity == 'high',
              onSelected: (_) =>
                  ref.read(_d246FlashIntensityProvider.notifier).state = 'high',
              selectedColor: _kAccent.withOpacity(0.25),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings → Accessibility (Day 97)',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reduce motion: ${a11y.reduceMotion ? 'ON (app)' : 'OFF (app)'} · '
                'System: ${systemReduceMotion ? 'ON' : 'OFF'}',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: ZapSpacing.xs),
              const Text(
                'When reduce motion is active, rapid red flashes are replaced with a '
                'steady visual alert panel (WCAG / vestibular safety).',
                style: TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: ZapSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.accessibilitySettings),
                icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                label: const Text('Open Day 97 · Accessibility settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab 1: Preview ────────────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab({required this.onTestFlash});

  final Future<void> Function() onTestFlash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(_d246VisualAlertsEnabledProvider);
    final flashActive = ref.watch(_d246FlashActiveProvider);
    final tests = ref.watch(_d246TestCountProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations ||
        ref.watch(accessibilityProvider).reduceMotion;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Alert preview',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        const Text(
          'Simulates SOS visual alert when audio is unavailable. Full-screen overlay on test.',
          style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: ZapSpacing.lg),
        AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: ZapColors.bgCard,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hearing_disabled_rounded,
                        size: 48,
                        color: ZapColors.textMuted.withOpacity(0.5),
                      ),
                      const SizedBox(height: ZapSpacing.md),
                      const Text(
                        'App screen (mock)',
                        style: TextStyle(
                          color: ZapColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (enabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            reduceMotion
                                ? 'Steady red panel on alert'
                                : 'Red flash pattern on alert',
                            style: TextStyle(
                              color: _kAccent.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (flashActive) _MiniFlashPreview(reduceMotion: reduceMotion),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (enabled && !flashActive) ? onTestFlash : null,
            icon: const Icon(Icons.flare_rounded),
            label: Text(
              flashActive
                  ? 'Flash running…'
                  : enabled
                      ? 'Test flash'
                      : 'Enable visual alerts first',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              disabledBackgroundColor: ZapColors.textMuted.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Tests run: $tests',
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: ZapColors.warning, size: 20),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'Accessibility warning shown before first test. Users with '
                  'photosensitivity should keep reduce motion enabled.',
                  style: TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFlashPreview extends StatelessWidget {
  const _MiniFlashPreview({required this.reduceMotion});

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return Container(
        color: _kFlashRed.withOpacity(0.7),
        child: const Center(
          child: Text(
            'ALERT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      builder: (context, value, _) {
        final on = (value * 4).floor() % 2 == 0;
        return Container(
          color: on ? _kFlashRed.withOpacity(0.85) : Colors.transparent,
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
    final enabled = ref.watch(_d246VisualAlertsEnabledProvider);
    final audioOff = ref.watch(_d246AudioAlertsDisabledProvider);
    final intensity = ref.watch(_d246FlashIntensityProvider);
    final tests = ref.watch(_d246TestCountProvider);
    final a11y = ref.watch(accessibilityProvider);
    final systemReduce = MediaQuery.of(context).disableAnimations;

    final payload = {
      'feature': 'hearing_impaired_visual_alerts',
      'version': '1.0.0',
      'section': 'C',
      'day': 246,
      'visual_alerts_enabled': enabled,
      'audio_alerts_disabled': audioOff,
      'flash_intensity': intensity,
      'reduce_motion_app': a11y.reduceMotion,
      'reduce_motion_system': systemReduce,
      'flash_pattern': systemReduce || a11y.reduceMotion
          ? 'steady_panel'
          : 'triple_red_pulse',
      'test_count': tests,
      'accessibility_settings_route': AppRoutes.accessibilitySettings,
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
            '🟢 FRONTEND-ONLY · Visual substitute for audio SOS alerts',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'How it works',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const _PolicyRow(
          icon: Icons.flare_rounded,
          title: 'High-intensity red flash',
          subtitle:
              'Full-screen pulses grab attention when user cannot hear audio alerts.',
        ),
        const _PolicyRow(
          icon: Icons.accessibility_new_rounded,
          title: 'Reduce motion respected',
          subtitle:
              'System + Day 97 reduce motion → steady panel instead of rapid flash.',
        ),
        const _PolicyRow(
          icon: Icons.settings_accessibility_rounded,
          title: 'Settings → Accessibility toggle',
          subtitle:
              'Production stores preference alongside Day 97 accessibility bundle.',
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
              const SnackBar(content: Text('Visual alerts JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy settings JSON'),
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
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 247 Haptic Patterns'),
              onPressed: () => context.push(AppRoutes.hapticPatterns),
            ),
            ActionChip(
              label: const Text('Day 245 Offline SOS'),
              onPressed: () => context.push(AppRoutes.offlineSosUx),
            ),
            ActionChip(
              label: const Text('Day 97 Accessibility'),
              onPressed: () => context.push(AppRoutes.accessibilitySettings),
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
