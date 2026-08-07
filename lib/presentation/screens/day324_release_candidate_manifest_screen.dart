/// Day 324 — Release Candidate Build Manifest
///
/// Lists the real inputs a v9.2 RC build is made of:
///   • App version + build number — read live off `pubspec.yaml`
///     (`AppVersionInfo.load()`), not a hardcoded Dart copy.
///   • Git commit hash — a real build-time `--dart-define=GIT_COMMIT_HASH`
///     constant (`kGitCommitHash`). This session cannot invoke
///     `flutter build` with that define, so the honest fallback string
///     shows instead of a fabricated hash — see `app_version_info.dart`.
///   • Model versions — real, from `kZapsafeModels`
///     (`model_registry.dart`). This repo versions models by asset
///     filename suffix (e.g. `_v1`), not a separate semver field, so that
///     filename is shown as-is rather than inventing a semver scheme that
///     doesn't exist in the codebase.
///   • Feature flags — real, from `app_flags.dart`
///     (`kUseMockData`, `kProductionShell`).
///   • QR code — a clearly-labelled MOCK placeholder. No `qr_flutter`
///     dependency was added for this; the box is a deterministic decorative
///     pattern, not a scannable code, and says so on-screen.
///   • RC checklist — links to the real Day 310 Section F milestone
///     screen's live-computed state (`seedIntegrationAudit()`). A "Day
///     320" milestone was specced but does not exist in this worktree —
///     Days 311-320 are still in progress on a separate parallel branch
///     (see this repo's own session instructions) — so it is honestly
///     listed as NOT YET AVAILABLE rather than linked to a route that
///     doesn't exist or given a fabricated green checkmark.
///
/// Tag: 🟢
///
/// Route: AppRoutes.releaseCandidateManifest
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_flags.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/app_version_info.dart';
import '../../data/services/model_registry.dart';
import 'day301_backend_integration_audit_screen.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

final _appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) {
  return AppVersionInfo.load();
});

class Day324ReleaseCandidateManifestScreen extends ConsumerWidget {
  const Day324ReleaseCandidateManifestScreen({super.key});

  static const _mockDownloadUrl =
      'https://mock.zapsafe.example/rc/v9.2/zapsafe.apk';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(_appVersionInfoProvider);
    final audit = seedIntegrationAudit();
    final live = audit.where((e) => e.status == AuditStatus.live).length;

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.rc_manifest_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day321_330.rc_manifest_heading'.tr(),
              style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.lg),

          Text('BUILD IDENTITY',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                versionAsync.when(
                  data: (v) => _KvRow(label: 'App version', value: v.versionName),
                  loading: () => const _KvRow(label: 'App version', value: 'loading…'),
                  error: (e, _) => const _KvRow(label: 'App version', value: 'unknown'),
                ),
                versionAsync.when(
                  data: (v) => _KvRow(label: 'Build number', value: '${v.buildNumber}'),
                  loading: () => const _KvRow(label: 'Build number', value: 'loading…'),
                  error: (e, _) => const _KvRow(label: 'Build number', value: 'unknown'),
                ),
                const _KvRow(label: 'Git commit hash', value: kGitCommitHash, mono: true),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('MODEL VERSIONS (kZapsafeModels)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final m in kZapsafeModels)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.displayName,
                      style: ZapTypography.bodyMedium
                          .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(m.assetPath,
                      style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
                  Text(m.realModelEta,
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.lg),

          Text('FEATURE FLAGS (app_flags.dart)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KvRow(label: 'kUseMockData', value: '$kUseMockData'),
                _KvRow(label: 'kProductionShell', value: '$kProductionShell'),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('APK / IPA DOWNLOAD',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: Column(
              children: [
                const _MockQrBox(),
                const SizedBox(height: ZapSpacing.sm),
                const ZapBadge(label: 'MOCK PLACEHOLDER — NOT A REAL QR CODE', intent: ZapBadgeIntent.warning),
                const SizedBox(height: ZapSpacing.sm),
                SelectableText(_mockDownloadUrl,
                    style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          Text('RC CHECKLIST',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            onTap: () => context.go(AppRoutes.sectionFMilestone),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: ZapColors.safe, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text('Day 310 · Section F Milestone — $live/${audit.length} APIs live',
                      style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                ),
                const Icon(Icons.chevron_right_rounded, color: ZapColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            backgroundColor: ZapColors.textMuted.withOpacity(0.06),
            child: Row(
              children: [
                const Icon(Icons.pending_rounded, color: ZapColors.textMuted, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Day 320 · Section G Milestone — NOT YET AVAILABLE in '
                    'this worktree (Days 311-320 are in progress on a '
                    'separate parallel branch; no route exists here to '
                    'link, so none is fabricated).',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: (mono ? ZapTypography.monoSmall : ZapTypography.bodyMedium)
                  .copyWith(color: ZapColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deterministic decorative grid — visually QR-shaped but NOT a real
/// scannable code. Avoids adding a `qr_flutter` dependency for a
/// placeholder the spec explicitly allows to be mocked.
class _MockQrBox extends StatelessWidget {
  const _MockQrBox();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxWidth),
            painter: _MockQrPainter(seed: Day324ReleaseCandidateManifestScreen._mockDownloadUrl),
          );
        },
      ),
    );
  }
}

class _MockQrPainter extends CustomPainter {
  const _MockQrPainter({required this.seed});
  final String seed;

  static const int _cells = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = ZapColors.bgSurface;
    canvas.drawRect(Offset.zero & size, bg);

    final cellSize = size.width / _cells;
    final fg = Paint()..color = ZapColors.textPrimary;
    var hash = seed.hashCode;
    for (var row = 0; row < _cells; row++) {
      for (var col = 0; col < _cells; col++) {
        // Cheap deterministic pseudo-random bit from a rolling hash — purely
        // decorative, not a real QR encoding.
        hash = (hash * 1103515245 + 12345) & 0x7fffffff;
        final on = (hash % 5) < 2;
        // Corner "finder" squares, like a real QR code's, for visual
        // familiarity only.
        final isFinder = (row < 3 && col < 3) ||
            (row < 3 && col >= _cells - 3) ||
            (row >= _cells - 3 && col < 3);
        if (on || isFinder) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize, row * cellSize, cellSize * 0.9, cellSize * 0.9),
            fg,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MockQrPainter oldDelegate) => oldDelegate.seed != seed;
}
