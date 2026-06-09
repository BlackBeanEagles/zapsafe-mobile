import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/interpreter.dart';
import '../../data/services/model_registry.dart';
import '../../domain/providers/inference_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 31 — TFLite model registry surface.
///
/// Lists the 4 ZapSafe models, their asset paths, their on-disk status
/// (PLACEHOLDER / MISSING / REAL), and whether the real `tflite_flutter`
/// interpreter could be constructed from each. Today every entry should
/// say PLACEHOLDER and the realInterpreterProvider should resolve to null
/// — that's the expected pre-Month-3 behaviour.
class Day31TfliteModelsScreen extends ConsumerWidget {
  const Day31TfliteModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(modelAssetStatusesProvider);
    final realAsync = ref.watch(realInterpreterProvider);
    final activeInterpreter = ref.watch(interpreterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 31 · TFLite Models'),
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

              const _SectionLabel('ACTIVE INTERPRETER'),
              const SizedBox(height: ZapSpacing.md),
              _ActiveCard(
                active: activeInterpreter,
                realAsync: realAsync,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('MODEL ASSETS · 4 SLOTS'),
              const SizedBox(height: ZapSpacing.md),
              statusesAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (list) => Column(
                  children: [
                    for (final s in list) _AssetRow(status: s),
                  ],
                ),
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('FALLBACK CONTRACT'),
              const SizedBox(height: ZapSpacing.md),
              _ContractCard(),

              const SizedBox(height: ZapSpacing.xxl),

              ZapButton.outlined(
                label: 'OPEN DAY 29 · INFERENCE',
                icon: Icons.psychology_rounded,
                fullWidth: true,
                onPressed: () => context.go('/inference'),
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
            ZapColors.warning.withOpacity(0.12),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.warning.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.precision_manufacturing_rounded,
                    color: ZapColors.warning, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 7 · DAY 31',
                  intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'TFLite Model Registry',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            '`tflite_flutter ^0.10.4` wired · 4 model slots declared · 1 KB '
            'placeholder bytes in every slot until backend Month 3. The '
            'interpreter tries to load each, fails on the stub bytes, and '
            'gracefully falls back to the EnergyStubInterpreter.',
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

// ─── Active interpreter card ─────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final Interpreter active;
  final AsyncValue<Interpreter?> realAsync;
  const _ActiveCard({required this.active, required this.realAsync});

  @override
  Widget build(BuildContext context) {
    final realResult = realAsync.valueOrNull;
    final isReal = realResult != null;
    final color = isReal ? ZapColors.safe : ZapColors.warning;
    final tag = isReal
        ? 'REAL TFLITE'
        : (realAsync.isLoading ? 'PROBING…' : 'STUB FALLBACK');

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReal ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  active.modelLabel,
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: ZapTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('Input size', '${active.expectedInputSize} × Float32'),
          _kv('Classes', active.classLabels.join(' · ')),
          _kv('Real load probe',
              realAsync.isLoading
                  ? 'in flight'
                  : isReal
                      ? 'succeeded'
                      : realAsync.hasError
                          ? 'error · ${realAsync.error}'
                          : 'returned null — placeholder detected'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                v,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Asset rows ──────────────────────────────────────────────────────────────

class _AssetRow extends StatelessWidget {
  final ModelAssetStatus status;
  const _AssetRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = status.sizeBytes == 0
        ? ('MISSING', ZapColors.danger, Icons.error_outline_rounded)
        : status.isPlaceholder
            ? ('PLACEHOLDER', ZapColors.warning, Icons.science_rounded)
            : ('REAL · ${(status.sizeBytes / 1024).toStringAsFixed(1)} KB',
               ZapColors.safe, Icons.check_circle_rounded);

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    status.definition.displayName,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: ZapTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.definition.assetPath,
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.info,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.definition.purpose,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Real ETA: ${status.definition.realModelEta} · ~${status.definition.realSizeMb} MB',
                    style: ZapTypography.labelSmall.copyWith(
                      color: ZapColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (status.isPlaceholder) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${status.previewSnippet}"',
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.warning,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fallback contract ───────────────────────────────────────────────────────

class _ContractCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = <(String, String)>[
      ('1.', 'realInterpreterProvider calls TfliteInterpreter.tryLoad()'),
      ('2.', 'Asset bundle loads the .tflite bytes'),
      ('3.', 'tflite_flutter parses the header — fails on placeholder text'),
      ('4.', 'tryLoad() returns null'),
      ('5.', 'interpreterProvider keeps EnergyStubInterpreter active'),
      ('6.', 'AudioFeatureService never notices — same Interpreter contract'),
      ('7.', 'Month 3: real .tflite ships → step 3 succeeds → step 5 swaps'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: steps.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    s.$1,
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.info,
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
          );
        }).toList(),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: ZapSpacing.md),
          Text('Loading model registry…'),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        message,
        style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
      ),
    );
  }
}
