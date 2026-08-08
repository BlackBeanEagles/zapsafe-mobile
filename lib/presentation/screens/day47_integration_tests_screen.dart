import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_card.dart';

/// Day 47 — Integration Tests summary screen.
///
/// Route: /day47-integration-tests
///
/// Day 47 is a test-only day — no new runtime feature. This screen documents
/// what was tested in [test/unit/day47_ml_pipeline_integration_test.dart].
class Day47IntegrationTestsScreen extends StatelessWidget {
  const Day47IntegrationTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ZapColors.textPrimary),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: Row(
          children: [
            const Text('Integration Tests',
                style: TextStyle(color: ZapColors.textPrimary)),
            const SizedBox(width: ZapSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DAY 47',
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZapCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: ZapColors.safe, size: 22),
                      const SizedBox(width: ZapSpacing.sm),
                      Text('41 / 41 tests passed',
                          style: ZapTypography.labelLarge.copyWith(
                              color: ZapColors.safe,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    'test/unit/day47_ml_pipeline_integration_test.dart',
                    style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                        fontFamily: 'IBMPlexMono'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('TEST GROUPS'),
            const SizedBox(height: ZapSpacing.sm),
            ..._testGroups.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: _GroupCard(group: g),
                )),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final _TestGroup group;
  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: ZapColors.safe, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name,
                    style: ZapTypography.labelMedium.copyWith(
                        color: ZapColors.textPrimary)),
                const SizedBox(height: 2),
                Text(group.description,
                    style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary)),
              ],
            ),
          ),
          Text('${group.count}',
              style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.safe, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TestGroup {
  final String name;
  final String description;
  final int count;
  const _TestGroup(this.name, this.description, this.count);
}

const _testGroups = [
  _TestGroup('Scream detector end-to-end',
      'Threat/safe fixtures → InferenceResult shape, isConfident, severity', 8),
  _TestGroup('Motion detector end-to-end',
      'Impact/calm fixtures → well-formed result, threat classScore', 5),
  _TestGroup('Scene detector end-to-end',
      'Dark/bright fixtures → threat classScore, expectedInputSize', 4),
  _TestGroup('Cross-modality consistency',
      'All 3 implement Interpreter, distinct labels, dispose safe', 4),
  _TestGroup('HeuristicDetectionEngine routing',
      'Tier × null-AI combos, full inference via engine slot', 5),
  _TestGroup('DetectionSettings × engine mode',
      'aiEnabled/screamEnabled gates → heuristic fallback', 3),
  _TestGroup('ModelBundleResult integrity',
      'Current asset state: 0 AI / 3 heuristic, end-to-end slot inference', 6),
  _TestGroup('InferenceResult severity ladder',
      'Score thresholds → high/medium/low/none, isConfident boundary', 6),
];
