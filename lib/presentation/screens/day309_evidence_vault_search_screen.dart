/// Day 309 — Production Evidence Vault Search
///
/// Documents the filter bar added directly to the production evidence
/// vault (`day82_evidence_vault_screen.dart`, route `AppRoutes.evidenceVault`,
/// `/evidence-vault`).
///
/// What's real:
///   • Filter chips — date range (any/7d/30d), trigger type
///     (manual/AI/fall), status (resolved/false positive/drill), tamper
///     flag toggle. All backed by real `StateProvider`s in
///     `vault_providers.dart` and combined with AND logic in
///     [filteredVaultEvidenceProvider].
///   • Search by SOS id prefix (case-insensitive `startsWith`, not fuzzy).
///   • Two distinct empty states: a genuinely-empty vault (existing Day
///     82 behaviour, unchanged) vs "filters matched nothing" (new, with a
///     "Clear filters" action) — checked this repo for a Day 212 screen
///     first (none exists) before building the "no matches" state in the
///     same visual language as the Day 82 empty-vault state.
///   • Everything operates on the same local/offline `vaultEvidenceProvider`
///     mock list the vault screen already rendered before this — no new
///     network dependency, matching the "filters work on local Hive/cache
///     data offline" acceptance criterion literally (this vault has been
///     local-only mock data since Day 82; "Hive" in the spec text is
///     read as "local storage" generically here, same as it is
///     everywhere else in Section F — see Day 306's ack-storage header
///     for the fuller Hive-vs-SharedPreferences note).
///
/// Real finding surfaced while auditing this area (documented, not
/// silently fixed): `GET /api/v1/evidence/search/` is a real, live Day
/// 209 backend endpoint (`zapsafe_backend/evidence/search_views.py`,
/// `q`/`type`/`from`/`to` query params) that was missing from the Day
/// 301 audit's seed list entirely. Added there now as `missing` for an
/// accurate count. Wiring it is out of scope here — Day 309's own spec
/// asks for *offline* filtering, not another live-wire day — but it's a
/// natural Month-4-style follow-up once the vault's mock list is
/// replaced by `GET /api/v1/vault/`.
/// Tag: 🟣 POLISH
///
/// Route: AppRoutes.evidenceVaultSearchPolish
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/vault_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day309EvidenceVaultSearchScreen extends ConsumerWidget {
  const Day309EvidenceVaultSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(vaultEvidenceProvider);
    final filtered = ref.watch(filteredVaultEvidenceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('day306_310.vault_search_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day306_310.vault_search_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'The real filter bar lives on the production evidence vault — '
            'this screen just shows what the same providers currently '
            'compute so the wiring is verifiable at a glance.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${filtered.length} of ${all.length} evidence entries match current filters',
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'Filters are StateProviders in vault_providers.dart: '
                  'vaultDateRangeFilterProvider, vaultTriggerFilterProvider, '
                  'vaultStatusFilterProvider, vaultTamperOnlyFilterProvider, '
                  'vaultSearchQueryProvider — combined by '
                  'filteredVaultEvidenceProvider with AND logic.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            borderColor: ZapColors.warning.withOpacity(0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search_rounded, color: ZapColors.warning, size: 18),
                    const SizedBox(width: ZapSpacing.sm),
                    Text('Real finding, documented',
                        style: ZapTypography.labelMedium.copyWith(color: ZapColors.warning)),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  'GET /api/v1/evidence/search/ (Day 209) is a real, live '
                  'backend endpoint that was missing from the Day 301 '
                  'audit\'s seed list. Added there now as "missing" for an '
                  'accurate count — this polish day intentionally kept '
                  'filtering local/offline instead of wiring it.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open production evidence vault',
            intent: ZapButtonIntent.safe,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.evidenceVault),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Back to integration audit',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
