/// Day 256 — Home Screen Widget — SOS
///
/// Section C (Days 241-260): mock preview + setup guide for Android/iOS home
/// screen SOS widget — one-tap emergency trigger (platform code documented;
/// this screen is spec + interactive preview only).
///
/// Tag: 🟢 FRONTEND-ONLY · widget mock · configuration checklist.
///
/// Route: [AppRoutes.homeWidgetSos] → `/home-widget-sos`
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
const _kAccent = Color(0xFFDC2626);
const _kTabs = ['Preview', 'Setup', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

const _kAndroidSteps = [
  _SetupStep(
    title: 'Long-press home screen',
    detail: 'On launcher home screen, long-press empty area.',
  ),
  _SetupStep(
    title: 'Open Widgets menu',
    detail: 'Tap Widgets · search "ZapSafe".',
  ),
  _SetupStep(
    title: 'Add SOS Quick Trigger',
    detail: 'Drag "ZapSafe SOS" widget (2×2 or 4×2) to home screen.',
  ),
  _SetupStep(
    title: 'Grant permissions',
    detail: 'Allow location + notifications when prompted (one-time).',
  ),
  _SetupStep(
    title: 'Test tap',
    detail: 'Tap widget SOS button · app opens alert-pending flow.',
  ),
];

const _kIosSteps = [
  _SetupStep(
    title: 'Edit Home Screen',
    detail: 'Long-press wallpaper · tap Edit · + button.',
  ),
  _SetupStep(
    title: 'Find ZapSafe widget',
    detail: 'Search ZapSafe · choose SOS Widget.',
  ),
  _SetupStep(
    title: 'Pick size',
    detail: 'Small (2×2) or Medium (4×2) · Add Widget.',
  ),
  _SetupStep(
    title: 'Critical alerts',
    detail: 'Enable Critical Alerts for SOS notifications (iOS).',
  ),
  _SetupStep(
    title: 'Test tap',
    detail: 'Tap widget · deep link zapsafe://sos/trigger (mock).',
  ),
];

enum _WidgetPlatform { android, ios }

enum _WidgetSize { small, medium }

// ── Models ────────────────────────────────────────────────────────────────────
class _SetupStep {
  const _SetupStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d256TabProvider = StateProvider<int>((ref) => 0);
final _d256PlatformProvider =
    StateProvider<_WidgetPlatform>((ref) => _WidgetPlatform.android);
final _d256SizeProvider =
    StateProvider<_WidgetSize>((ref) => _WidgetSize.small);
final _d256AndroidStepsDoneProvider =
    StateProvider<Set<int>>((ref) => {0, 1});
final _d256IosStepsDoneProvider = StateProvider<Set<int>>((ref) => {});
final _d256TapCountProvider = StateProvider<int>((ref) => 0);
final _d256LastTriggerProvider = StateProvider<DateTime?>((ref) => null);

List<_SetupStep> _stepsForPlatform(_WidgetPlatform platform) {
  return platform == _WidgetPlatform.android ? _kAndroidSteps : _kIosSteps;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day256HomeWidgetSosScreen extends ConsumerWidget {
  const Day256HomeWidgetSosScreen({super.key});

  void _triggerWidgetSos(BuildContext context, WidgetRef ref) {
    ref.read(_d256TapCountProvider.notifier).state =
        ref.read(_d256TapCountProvider) + 1;
    ref.read(_d256LastTriggerProvider.notifier).state = DateTime.now();
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Widget SOS tapped · opening alert-pending flow (mock).',
        ),
        action: SnackBarAction(
          label: 'Day 76',
          onPressed: () => context.push(AppRoutes.sosActive),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d256TabProvider);
    final tapCount = ref.watch(_d256TapCountProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 256 · SOS Widget'),
        actions: [
          if (tapCount > 0)
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
                    '$tapCount TAP${tapCount == 1 ? '' : 'S'}',
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
            onSelect: (i) => ref.read(_d256TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => _PreviewTab(onSosTap: () => _triggerWidgetSos(context, ref)),
              1 => const _SetupTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Preview ────────────────────────────────────────────────────────────
class _PreviewTab extends ConsumerWidget {
  const _PreviewTab({required this.onSosTap});

  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d256PlatformProvider);
    final size = ref.watch(_d256SizeProvider);
    final lastTrigger = ref.watch(_d256LastTriggerProvider);
    final isAndroid = platform == _WidgetPlatform.android;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section C Day 16/20 · mock widget preview',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SegmentedButton<_WidgetPlatform>(
          segments: const [
            ButtonSegment(
              value: _WidgetPlatform.android,
              label: Text('Android'),
              icon: Icon(Icons.android_rounded, size: 16),
            ),
            ButtonSegment(
              value: _WidgetPlatform.ios,
              label: Text('iOS'),
              icon: Icon(Icons.phone_iphone_rounded, size: 16),
            ),
          ],
          selected: {platform},
          onSelectionChanged: (s) =>
              ref.read(_d256PlatformProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Small 2×2'),
              selected: size == _WidgetSize.small,
              onSelected: (_) =>
                  ref.read(_d256SizeProvider.notifier).state = _WidgetSize.small,
            ),
            ChoiceChip(
              label: const Text('Medium 4×2'),
              selected: size == _WidgetSize.medium,
              onSelected: (_) => ref.read(_d256SizeProvider.notifier).state =
                  _WidgetSize.medium,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        Center(
          child: _PhoneMockFrame(
            isAndroid: isAndroid,
            child: _SosWidgetPreview(
              size: size,
              isAndroid: isAndroid,
              onSosTap: onSosTap,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (lastTrigger != null)
          Text(
            'Last widget tap: ${lastTrigger.toIso8601String()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Tap the red SOS button in the widget preview to simulate '
          'home-screen quick trigger.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Tab 1: Setup ──────────────────────────────────────────────────────────────
class _SetupTab extends ConsumerWidget {
  const _SetupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d256PlatformProvider);
    final steps = _stepsForPlatform(platform);
    final done = platform == _WidgetPlatform.android
        ? ref.watch(_d256AndroidStepsDoneProvider)
        : ref.watch(_d256IosStepsDoneProvider);
    final progress = done.length / steps.length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        SegmentedButton<_WidgetPlatform>(
          segments: const [
            ButtonSegment(
              value: _WidgetPlatform.android,
              label: Text('Android'),
              icon: Icon(Icons.android_rounded, size: 16),
            ),
            ButtonSegment(
              value: _WidgetPlatform.ios,
              label: Text('iOS'),
              icon: Icon(Icons.phone_iphone_rounded, size: 16),
            ),
          ],
          selected: {platform},
          onSelectionChanged: (s) =>
              ref.read(_d256PlatformProvider.notifier).state = s.first,
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: ZapColors.bgCard,
                  color: _kAccent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${done.length}/${steps.length}',
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final checked = done.contains(i);
          return _SetupStepTile(
            index: i + 1,
            step: step,
            checked: checked,
            onChanged: (v) {
              if (platform == _WidgetPlatform.android) {
                final set = Set<int>.from(
                  ref.read(_d256AndroidStepsDoneProvider),
                );
                if (v) {
                  set.add(i);
                } else {
                  set.remove(i);
                }
                ref.read(_d256AndroidStepsDoneProvider.notifier).state = set;
              } else {
                final set = Set<int>.from(ref.read(_d256IosStepsDoneProvider));
                if (v) {
                  set.add(i);
                } else {
                  set.remove(i);
                }
                ref.read(_d256IosStepsDoneProvider.notifier).state = set;
              }
            },
          );
        }),
        if (progress >= 1.0) ...[
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
            ),
            child: const Text(
              'Setup checklist complete · test widget on Preview tab.',
              style: TextStyle(color: ZapColors.safe, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => ref.read(_d256TabProvider.notifier).state = 0,
          icon: const Icon(Icons.widgets_rounded),
          label: const Text('Open widget preview'),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(_d256PlatformProvider);
    final tapCount = ref.watch(_d256TapCountProvider);

    final spec = {
      'widget_id': 'zapsafe_sos_quick_v1',
      'platforms': ['android', 'ios'],
      'sizes': ['2x2', '4x2'],
      'action': 'zapsafe://sos/trigger',
      'opens': 'alert_pending_screen',
      'requires_auth': true,
      'preview_taps': tapCount,
      'implementation': platform == _WidgetPlatform.android
          ? 'AppWidgetProvider + RemoteViews (Kotlin)'
          : 'WidgetKit + AppIntent (Swift)',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Home Screen Widget — SOS',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'One-tap SOS from the home screen without unlocking the full app. '
          'This day-screen documents configuration and shows a mock preview — '
          'production widgets require native Android AppWidget + iOS WidgetKit '
          'code (not shipped in Flutter-only build).',
          style: TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Widget spec (mock)',
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
            _kJsonEncoder.convert(spec),
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
              ClipboardData(text: _kJsonEncoder.convert(spec)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Widget spec JSON copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy widget spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _PolicyRow(
          icon: Icons.code_rounded,
          title: 'Platform implementation',
          subtitle:
              'Android: AppWidgetProvider broadcasts to Flutter via deep link. '
              'iOS: WidgetKit AppIntent opens zapsafe://sos/trigger URL scheme.',
        ),
        const _PolicyRow(
          icon: Icons.security_rounded,
          title: 'Safety',
          subtitle:
              'Widget bypasses app UI but still runs 15s alert-pending gate '
              '(Day 71) · duress PIN unchanged (Day 76).',
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
              label: const Text('Day 257 Score Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetScore),
            ),
            ActionChip(
              label: const Text('Day 248 Siri Shortcuts'),
              onPressed: () => context.push(AppRoutes.siriShortcuts),
            ),
            ActionChip(
              label: const Text('Day 255 Child Admin Lock'),
              onPressed: () => context.push(AppRoutes.childModeAdmin),
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

// ── Preview widgets ───────────────────────────────────────────────────────────
class _PhoneMockFrame extends StatelessWidget {
  const _PhoneMockFrame({
    required this.isAndroid,
    required this.child,
  });

  final bool isAndroid;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ZapColors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ZapColors.textMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: double.infinity,
            height: 360,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAndroid
                    ? [
                        const Color(0xFF312E81),
                        const Color(0xFF1E1B4B),
                      ]
                    : [
                        const Color(0xFF0F172A),
                        const Color(0xFF334155),
                      ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white.withOpacity(0.25),
                    size: 28,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.white.withOpacity(0.25),
                    size: 28,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SosWidgetPreview extends StatelessWidget {
  const _SosWidgetPreview({
    required this.size,
    required this.isAndroid,
    required this.onSosTap,
  });

  final _WidgetSize size;
  final bool isAndroid;
  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    final isSmall = size == _WidgetSize.small;
    final radius = isAndroid ? 16.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: isSmall ? 120 : 220,
        height: isSmall ? 120 : 100,
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: ZapColors.bgCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
            ),
          ],
        ),
        child: isSmall ? _SmallWidgetBody(onSosTap: onSosTap) : _MediumWidgetBody(onSosTap: onSosTap),
      ),
    );
  }
}

class _SmallWidgetBody extends StatelessWidget {
  const _SmallWidgetBody({required this.onSosTap});

  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ZapSafe',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
        const Spacer(),
        Material(
          color: _kAccent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onSosTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'SOS',
          style: TextStyle(
            color: _kAccent,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _MediumWidgetBody extends StatelessWidget {
  const _MediumWidgetBody({required this.onSosTap});

  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ZapSafe SOS',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to trigger emergency',
                style: TextStyle(
                  color: ZapColors.textMuted.withOpacity(0.9),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: _kAccent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onSosTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupStepTile extends StatelessWidget {
  const _SetupStepTile({
    required this.index,
    required this.step,
    required this.checked,
    required this.onChanged,
  });

  final int index;
  final _SetupStep step;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked ? _kAccent.withOpacity(0.06) : ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? _kAccent.withOpacity(0.35) : ZapColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: _kAccent,
        title: Text(
          '$index. ${step.title}',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          step.detail,
          style: const TextStyle(
            color: ZapColors.textSecondary,
            fontSize: 11,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
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
      padding: const EdgeInsets.only(bottom: 12),
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
