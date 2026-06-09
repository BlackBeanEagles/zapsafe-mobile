import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 28 — iOS audio capture parity surface.
///
/// Day 26 wired the Android path. Day 28 mirrors it on iOS via
/// `AVAudioEngine` + an input tap + `AVAudioConverter` (re-sampling the
/// device mic from its native rate to 16 kHz mono int16). This screen
/// surfaces the cross-platform parity matrix so a glance tells you which
/// native implementation is live on this device.
class Day28IosAudioScreen extends ConsumerWidget {
  const Day28IosAudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioChannelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 28 · iOS Audio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBanner(),
              const SizedBox(height: ZapSpacing.xl),

              _PlatformBadge(),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('CROSS-PLATFORM PARITY'),
              const SizedBox(height: ZapSpacing.md),
              _ParityCard(
                captureSupported: audio.supported,
                featuresSupported: audio.featuresSupported,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('iOS PIPELINE'),
              const SizedBox(height: ZapSpacing.md),
              _IosPipelineCard(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('iOS · USAGE-DESCRIPTION STRINGS'),
              const SizedBox(height: ZapSpacing.md),
              _UsageStringsCard(),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'OPEN DAY 26 · CAPTURE',
                icon: Icons.graphic_eq_rounded,
                fullWidth: true,
                onPressed: () => context.go('/audio-capture'),
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'BACK TO INDEX',
                icon: Icons.arrow_back_rounded,
                fullWidth: true,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.info.withOpacity(0.12),
            ZapColors.safe.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apple_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 6 · DAY 28',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'iOS AudioCaptureEngine',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'AVAudioEngine + input-tap on the mic, re-sampled to 16 kHz mono '
            'int16 via AVAudioConverter, fed through the same 450 ms sliding '
            'window + RMS-gated VAD as Android. Same EventChannel payload — '
            'Flutter sees one schema across both platforms.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Platform badge ──────────────────────────────────────────────────────────

class _PlatformBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = Platform.isIOS
        ? ('RUNNING ON iOS · capture LIVE', ZapColors.safe, Icons.check_circle_rounded)
        : Platform.isAndroid
            ? ('RUNNING ON ANDROID · iOS parity built', ZapColors.info, Icons.android_rounded)
            : ('HOST VM · code-only view', ZapColors.textSecondary, Icons.computer_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            label,
            style: ZapTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parity card ─────────────────────────────────────────────────────────────

class _ParityCard extends StatelessWidget {
  final bool captureSupported;
  final bool featuresSupported;
  const _ParityCard({
    required this.captureSupported,
    required this.featuresSupported,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String)>[
      ('AudioRecord-equiv capture', 'AudioRecord.kt · Day 26', 'AVAudioEngine · Day 28'),
      ('Sample rate',               '16 kHz mono',              '16 kHz mono (via AVAudioConverter)'),
      ('Window length',             '450 ms · 7 200 samples',   '450 ms · 7 200 samples'),
      ('VAD threshold (RMS)',       '300',                      '300'),
      ('Hann window',               'pre-computed once',        'pre-computed once'),
      ('MFCC features (Day 27)',    'live',                     'Day 29 (planned)'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 4,
                child: _columnLabel('ANDROID', ZapColors.safe, Icons.android_rounded),
              ),
              Expanded(
                flex: 4,
                child: _columnLabel('iOS', ZapColors.info, Icons.apple_rounded),
              ),
            ],
          ),
          const Divider(color: ZapColors.border),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.$1,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.textSecondary,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      r.$2,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      r.$3,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _columnLabel(String label, Color color, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Pipeline explainer ──────────────────────────────────────────────────────

class _IosPipelineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = <(String, String)>[
      ('1. AVAudioSession',
       'category .record · mode .measurement · low-latency, no gain boost'),
      ('2. inputNode.installTap',
       '1024-sample buffer at the hardware\'s native format'),
      ('3. AVAudioConverter',
       'Resamples to 16 kHz mono int16 · matches Android byte-for-byte'),
      ('4. Sliding buffer',
       'Accumulates converted samples into a 7 200-sample window'),
      ('5. RMS · VAD · Hann',
       'Same threshold (300) and Hann window as Android — shared schema'),
      ('6. EventChannel emit',
       'DispatchQueue.main.async ensures sink is touched on main thread'),
    ];

    return ZapCard(
      child: Column(
        children: [
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      s.$1,
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.info,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.$2,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                        height: 1.4,
                      ),
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

// ─── Usage strings explainer ─────────────────────────────────────────────────

class _UsageStringsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_rounded,
              color: ZapColors.warning, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'iOS rejects builds that touch the mic without an '
              'NSMicrophoneUsageDescription string. Day 22 already added '
              'that key to Info.plist — no extra work today. Same for '
              'NSLocationAlwaysAndWhenInUseUsageDescription, NSCameraUsage'
              'Description, and NSMotionUsageDescription.',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}
