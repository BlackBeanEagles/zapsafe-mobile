/// Day 325 — OTA Model Update UI
///
/// 🔵 EXISTING-API. `POST /api/v1/models/get-version/` is real and already
/// live on the backend (Day 71, `ml/urls_models.py` →
/// `ModelVersionCheckView`) — verified by reading the view source. It had
/// never been wired into the Flutter app before this screen: no
/// `ApiConfig` constant, no service, nothing referenced it. This screen +
/// `model_version_service.dart` / `model_version_providers.dart` are the
/// first real wire.
///
/// Compares the bundled model versions (`kZapsafeModels`, this repo's
/// real-if-informal `_vN` asset-filename versioning — see
/// `model_version_service.dart`'s header for why there's no separate
/// semver field to read) against the live server response, and shows an
/// update-available banner per model.
///
/// Download progress is a UI mock — this repo has no
/// `OTA_UPDATES_FOR_LATER.md` (checked; no such file exists here), so
/// there's no prior "explicitly out of scope" doc to cite. Real OTA model
/// download/replace is still out of scope for this Day 325 screen on its
/// own merits: it would need a background download manager, on-disk model
/// swap, and interpreter hot-reload, none of which exist yet in this
/// codebase. That gap is stated here honestly rather than silently
/// implied by a fake progress bar with no label.
///
/// Tag: 🔵 EXISTING-API
///
/// Route: AppRoutes.otaModelUpdate
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/model_version_service.dart';
import '../../domain/providers/model_version_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day325OtaModelUpdateScreen extends ConsumerStatefulWidget {
  const Day325OtaModelUpdateScreen({super.key});

  @override
  ConsumerState<Day325OtaModelUpdateScreen> createState() =>
      _Day325OtaModelUpdateScreenState();
}

class _Day325OtaModelUpdateScreenState
    extends ConsumerState<Day325OtaModelUpdateScreen> {
  String? _downloadingType;
  double _downloadProgress = 0;
  Timer? _downloadTimer;

  @override
  void dispose() {
    _downloadTimer?.cancel();
    super.dispose();
  }

  void _mockDownload(String modelType) {
    _downloadTimer?.cancel();
    setState(() {
      _downloadingType = modelType;
      _downloadProgress = 0;
    });
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      setState(() => _downloadProgress += 0.08);
      if (_downloadProgress >= 1.0) {
        t.cancel();
        setState(() {
          _downloadProgress = 1.0;
          _downloadingType = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkAsync = ref.watch(modelVersionCheckProvider);

    return Scaffold(
      appBar: AppBar(title: Text('day321_330.ota_model_update_title'.tr())),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(modelVersionCheckProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('day321_330.ota_model_update_heading'.tr(),
                      style: ZapTypography.headlineSmall
                          .copyWith(color: ZapColors.textPrimary)),
                ),
                const ZapBadge(label: 'EXISTING-API', intent: ZapBadgeIntent.info),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              'POST /api/v1/models/get-version/ — real, existing since Day '
              '71, wired to the app for the first time today.',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
            ),
            const SizedBox(height: ZapSpacing.lg),

            checkAsync.when(
              data: (resp) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZapCard(
                    backgroundColor: (resp.allUpToDate ? ZapColors.safe : ZapColors.warning)
                        .withOpacity(0.08),
                    borderColor: (resp.allUpToDate ? ZapColors.safe : ZapColors.warning)
                        .withOpacity(0.3),
                    child: Row(
                      children: [
                        Icon(
                          resp.allUpToDate ? Icons.check_circle_rounded : Icons.update_rounded,
                          color: resp.allUpToDate ? ZapColors.safe : ZapColors.warning,
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Text(
                            resp.allUpToDate
                                ? 'All bundled models up to date.'
                                : 'Updates available for '
                                    '${resp.results.where((r) => r.updateAvailable).length} model(s).',
                            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.lg),
                  if (resp.results.isEmpty)
                    ZapCard(
                      child: Text(
                        'No results — either offline (kUseMockData / '
                        'network error, see below) or the backend has no '
                        'active MLModel rows for these types yet.',
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                      ),
                    )
                  else
                    for (final r in resp.results)
                      _ModelVersionRow(
                        result: r,
                        downloading: _downloadingType == r.modelType,
                        progress: _downloadProgress,
                        onDownload: () => _mockDownload(r.modelType),
                      ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: ZapSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ZapCard(
                backgroundColor: ZapColors.danger.withOpacity(0.08),
                borderColor: ZapColors.danger.withOpacity(0.3),
                child: Text(
                  'Check failed: $e\n\nExpected when offline or the '
                  'backend is unreachable — this is a real network call, '
                  'not a mock.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4),
                ),
              ),
            ),

            const SizedBox(height: ZapSpacing.lg),
            ZapButton.outlined(
              label: 'Check for updates',
              icon: Icons.refresh_rounded,
              fullWidth: true,
              onPressed: () => ref.invalidate(modelVersionCheckProvider),
            ),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

class _ModelVersionRow extends StatelessWidget {
  const _ModelVersionRow({
    required this.result,
    required this.downloading,
    required this.progress,
    required this.onDownload,
  });

  final ModelVersionResult result;
  final bool downloading;
  final double progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.modelType,
                        style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                    Text(
                      'bundled ${result.clientVersion ?? '(none)'} → server '
                      '${result.serverVersion ?? '(none)'}',
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted),
                    ),
                  ],
                ),
              ),
              ZapBadge(
                label: result.updateAvailable ? 'UPDATE AVAILABLE' : 'UP TO DATE',
                intent: result.updateAvailable ? ZapBadgeIntent.warning : ZapBadgeIntent.safe,
                size: ZapBadgeSize.small,
              ),
            ],
          ),
          if (result.updateAvailable) ...[
            const SizedBox(height: ZapSpacing.sm),
            if (downloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress.clamp(0, 1)),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    'Downloading (UI mock) · ${(progress.clamp(0, 1) * 100).round()}%',
                    style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                  ),
                ],
              )
            else
              ZapButton.tonal(
                label: 'Download update (UI mock)',
                fullWidth: true,
                onPressed: onDownload,
              ),
          ],
        ],
      ),
    );
  }
}
