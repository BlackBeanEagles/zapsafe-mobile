import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/phone_capability_detector.dart';
import '../../domain/providers/detection_settings_provider.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 46 — Detection Settings Screen.
///
/// Route: /detection-settings
///
/// Lets the user enable/disable each AI detection model individually and
/// shows which capability tier (AI vs heuristic) the phone is using.
///
/// Wires to [detectionSettingsProvider] (persisted) and reads the cached
/// [PhoneCapabilityTier] to show the phone capability chip.
class Day46DetectionSettingsScreen extends ConsumerStatefulWidget {
  const Day46DetectionSettingsScreen({super.key});

  @override
  ConsumerState<Day46DetectionSettingsScreen> createState() =>
      _Day46DetectionSettingsScreenState();
}

class _Day46DetectionSettingsScreenState
    extends ConsumerState<Day46DetectionSettingsScreen> {
  PhoneCapabilityTier? _tier;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _loadCachedTier();
  }

  Future<void> _loadCachedTier() async {
    final t = await PhoneCapabilityDetector.cachedTier();
    if (mounted) setState(() => _tier = t);
  }

  Future<void> _reprobe() async {
    setState(() => _probing = true);
    final result = await PhoneCapabilityDetector().detect(forceReprobe: true);
    if (mounted) {
      setState(() {
        _tier    = result.tier;
        _probing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(detectionSettingsProvider);
    final notifier  = ref.read(detectionSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Text('Detection Settings', style: ZapTypography.labelLarge),
        actions: [
          ZapBadge(
            label: 'DAY 46',
            intent: ZapBadgeIntent.info,
          ),
          const SizedBox(width: ZapSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg,
            vertical: ZapSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Master AI toggle ─────────────────────────────────────────
              _SectionHeader('AI DETECTION'),
              const SizedBox(height: ZapSpacing.sm),
              _MasterToggleCard(
                enabled: settings.aiEnabled,
                onChanged: notifier.setAiEnabled,
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ── Per-model toggles ────────────────────────────────────────
              _SectionHeader('DETECTION MODELS'),
              const SizedBox(height: ZapSpacing.sm),
              _ModelToggleCard(
                icon: Icons.record_voice_over_rounded,
                accent: ZapColors.danger,
                title: 'Scream Detection',
                description:
                    'Detects screams and distress calls via the microphone. '
                    'Uses audio MFCC features to classify audio in real time.',
                enabled: settings.aiEnabled && settings.screamEnabled,
                masterDisabled: !settings.aiEnabled,
                onChanged: notifier.setScreamEnabled,
              ),
              const SizedBox(height: ZapSpacing.md),
              _ModelToggleCard(
                icon: Icons.vibration_rounded,
                accent: ZapColors.warning,
                title: 'Motion Detection',
                description:
                    'Detects sudden falls and impact patterns via the '
                    'accelerometer and gyroscope sensors.',
                enabled: settings.aiEnabled && settings.motionEnabled,
                masterDisabled: !settings.aiEnabled,
                onChanged: notifier.setMotionEnabled,
              ),
              const SizedBox(height: ZapSpacing.md),
              _ModelToggleCard(
                icon: Icons.remove_red_eye_rounded,
                accent: ZapColors.info,
                title: 'Scene Detection',
                description:
                    'Analyses camera frames to identify threatening environments. '
                    'Runs in the background during active SOS.',
                enabled: settings.aiEnabled && settings.sceneEnabled,
                masterDisabled: !settings.aiEnabled,
                onChanged: notifier.setSceneEnabled,
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ── Phone capability ─────────────────────────────────────────
              _SectionHeader('PHONE CAPABILITY'),
              const SizedBox(height: ZapSpacing.sm),
              _PhoneCapabilityCard(
                tier:    _tier,
                probing: _probing,
                onReprobe: _reprobe,
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ── Heuristic fallback info ──────────────────────────────────
              _SectionHeader('HEURISTIC FALLBACK'),
              const SizedBox(height: ZapSpacing.sm),
              ZapCard(
                child: Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security_rounded,
                          color: ZapColors.safe, size: 22),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Always Active',
                                style: ZapTypography.labelMedium.copyWith(
                                    color: ZapColors.safe)),
                            const SizedBox(height: ZapSpacing.xs),
                            Text(
                              'The heuristic fallback (simple audio + motion '
                              'thresholds) is always running alongside AI. '
                              'On older phones it becomes the primary detector. '
                              'It cannot be disabled — it is your last line of defence.',
                              style: ZapTypography.bodySmall.copyWith(
                                  color: ZapColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ── Reset ────────────────────────────────────────────────────
              ZapButton(
                label: 'Reset to Defaults',
                variant: ZapButtonVariant.text,
                onPressed: () async {
                  await notifier.resetToDefaults();
                },
              ),
              const SizedBox(height: ZapSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: ZapTypography.labelSmall.copyWith(
        color: ZapColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MasterToggleCard extends StatelessWidget {
  const _MasterToggleCard({
    required this.enabled,
    required this.onChanged,
  });
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md,
          vertical: ZapSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.psychology_rounded : Icons.psychology_alt_rounded,
              color: enabled ? ZapColors.safe : ZapColors.textMuted,
              size: 26,
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI-Powered Detection',
                      style: ZapTypography.labelMedium.copyWith(
                          color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? 'Using on-device ML models for high accuracy'
                        : 'Heuristic fallback only (lower accuracy)',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeColor: ZapColors.safe,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelToggleCard extends StatelessWidget {
  const _ModelToggleCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.enabled,
    required this.masterDisabled,
    required this.onChanged,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final bool enabled;
  final bool masterDisabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: masterDisabled ? 0.45 : 1.0,
      child: ZapCard(
        child: Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ZapTypography.labelMedium.copyWith(
                            color: ZapColors.textPrimary)),
                    const SizedBox(height: ZapSpacing.xs),
                    Text(description,
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary)),
                    if (masterDisabled) ...[
                      const SizedBox(height: ZapSpacing.xs),
                      Text('Enable AI detection to use this model',
                          style: ZapTypography.bodySmall.copyWith(
                              color: ZapColors.warning,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              Switch(
                value: enabled && !masterDisabled,
                onChanged: masterDisabled ? null : onChanged,
                activeColor: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneCapabilityCard extends StatelessWidget {
  const _PhoneCapabilityCard({
    required this.tier,
    required this.probing,
    required this.onReprobe,
  });

  final PhoneCapabilityTier? tier;
  final bool probing;
  final VoidCallback onReprobe;

  Color get _tierColor {
    switch (tier) {
      case PhoneCapabilityTier.high:
        return ZapColors.safe;
      case PhoneCapabilityTier.medium:
        return ZapColors.warning;
      case PhoneCapabilityTier.low:
        return ZapColors.danger;
      case null:
        return ZapColors.textMuted;
    }
  }

  String get _tierLabel {
    if (probing) return 'Testing…';
    switch (tier) {
      case PhoneCapabilityTier.high:
        return 'HIGH — AI Models Active';
      case PhoneCapabilityTier.medium:
        return 'MEDIUM — AI Models Active';
      case PhoneCapabilityTier.low:
        return 'LOW — Heuristic Fallback';
      case null:
        return 'NOT TESTED';
    }
  }

  String get _tierDescription {
    if (probing) return 'Running inference probe…';
    switch (tier) {
      case PhoneCapabilityTier.high:
        return 'Your phone handles AI models in <100 ms. Full detection '
            'accuracy on all 3 models.';
      case PhoneCapabilityTier.medium:
        return 'AI models run in 100-500 ms. Accurate detection with a '
            'slight response-time trade-off.';
      case PhoneCapabilityTier.low:
        return 'AI models are too slow on this device. The heuristic '
            'detector (>85% accuracy) is used instead.';
      case null:
        return 'Tap "Test Now" to measure this phone\'s capability.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: _tierColor, size: 22),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    _tierLabel,
                    style: ZapTypography.labelMedium.copyWith(color: _tierColor),
                  ),
                ),
                if (probing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ZapColors.safe,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              _tierDescription,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
            const SizedBox(height: ZapSpacing.md),
            ZapButton(
              label: tier == null ? 'Test Now' : 'Re-Test Phone',
              variant: ZapButtonVariant.outlined,
              isLoading: probing,
              onPressed: probing ? null : onReprobe,
            ),
          ],
        ),
      ),
    );
  }
}
