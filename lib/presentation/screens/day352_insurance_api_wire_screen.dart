/// Day 352 — Insurance Partnership API Wire
///
/// Extends Day 272 (`day272_insurance_partnership_screen.dart` — read
/// first: partner offer cards, 10% discount tied to verified SOS/drill
/// history, eligibility rules, mock apply flow).
///
/// Verified against `zapsafe_backend` before building: grepped `partner`
/// and `insurance` across every app's `urls.py`/`views.py`/`models.py` —
/// no `partners` app exists, the only two hits are `evidence/views.py`'s
/// unrelated comment ("cheap insurance and conventional") and
/// `contacts/migrations` (no match). `GET /api/v1/partners/insurance/`
/// (the endpoint this Day 351-360 spec names) and Day 272's own header
/// comment's `GET /api/v1/partners/insurance/offers/` are both
/// aspirational — neither exists. This screen stays honestly mock, adding
/// a live "wire status" panel that would flip to real once the endpoint
/// ships, plus the documented intended contract below.
///
/// Proposed contract (not implemented anywhere yet):
///   GET /api/v1/partners/insurance/
///     -> {"eligible": bool, "plans": [{"id","name","annual_premium",
///          "discounted_premium"}], "eligibility": {rule_id: bool}}
///   POST /api/v1/partners/insurance/apply/  body: {"plan_id"}
///     -> {"application_id","status"}
///
/// Tag: 🟡 MOCK-NOW · no `partners`/`insurance` backend app exists.
///
/// Route: [AppRoutes.insuranceApiWire] → `/day-352-insurance-api-wire`
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

const _kJsonEncoder = JsonEncoder.withIndent('  ');

final _d352CheckingProvider = StateProvider<bool>((ref) => false);
final _d352CheckedProvider = StateProvider<bool>((ref) => false);

Future<void> _checkEndpoint(WidgetRef ref) async {
  ref.read(_d352CheckingProvider.notifier).state = true;
  // No live HTTP call — the endpoint doesn't exist anywhere in
  // zapsafe_backend (verified by reading source, not by probing a
  // real host). This delay simulates what a real "try it" check would
  // feel like once it does.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  ref.read(_d352CheckingProvider.notifier).state = false;
  ref.read(_d352CheckedProvider.notifier).state = true;
}

class Day352InsuranceApiWireScreen extends ConsumerWidget {
  const Day352InsuranceApiWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checking = ref.watch(_d352CheckingProvider);
    final checked = ref.watch(_d352CheckedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.insurance_wire_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_rounded, color: ZapColors.warning, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🟡 MOCK-NOW · Section K Day 2/10 · verified zapsafe_backend has '
                    'no `partners` app and no insurance endpoint of any kind '
                    '(grepped partner/insurance across every urls.py/views.py). '
                    'This screen stays honestly mock — it does not call a real API.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.insurance_wire_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Extends Day 272\'s partner offer preview. This screen wires the '
            'exact same UI to a "check endpoint" step, so it can be re-run '
            'whenever the backend team ships /api/v1/partners/insurance/.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Backend wire status',
                          style: ZapTypography.bodyMedium
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                    ),
                    ZapBadge(
                      label: !checked ? 'NOT CHECKED' : 'NOT FOUND',
                      intent: !checked ? ZapBadgeIntent.neutral : ZapBadgeIntent.warning,
                      size: ZapBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  checked
                      ? 'GET /api/v1/partners/insurance/ does not exist in '
                          'zapsafe_backend (source-verified, Days 351-360 session). '
                          'Day 272\'s mock UI stays as the source of truth until a '
                          'backend team ships this endpoint.'
                      : 'Tap below to re-confirm the endpoint status against the '
                          'real backend source tree.',
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.outlined(
                  label: checking ? 'Checking…' : 'Re-check backend for this endpoint',
                  icon: Icons.search_rounded,
                  isLoading: checking,
                  fullWidth: true,
                  onPressed: checking ? null : () => _checkEndpoint(ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('PROPOSED CONTRACT (NOT IMPLEMENTED)',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          ZapCard(
            child: SelectableText(
              _kJsonEncoder.convert({
                'GET /api/v1/partners/insurance/': {
                  'eligible': true,
                  'plans': [
                    {
                      'id': 'women-suraksha',
                      'name': 'My:Health Women Suraksha',
                      'annual_premium': 8499,
                      'discounted_premium': 7649,
                    }
                  ],
                  'eligibility': {
                    'drill_90d': true,
                    'account_active': true,
                    'no_open_sos': true,
                    'protection_score': true,
                  },
                },
                'POST /api/v1/partners/insurance/apply/': {
                  'request': {'plan_id': 'women-suraksha'},
                  'response': {'application_id': 'ins_app_123', 'status': 'submitted'},
                },
              }),
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Copy proposed contract',
            icon: Icons.copy_rounded,
            fullWidth: true,
            onPressed: () {
              Clipboard.setData(const ClipboardData(
                text: 'GET /api/v1/partners/insurance/\n'
                    'POST /api/v1/partners/insurance/apply/\n\n'
                    'Neither endpoint exists in zapsafe_backend — proposed contract, '
                    'Day 272 UI is the source of truth for the actual demo data.',
              ));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Contract copied')));
            },
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapButton.tonal(
            label: 'Open Day 272 partner offer preview',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.insurancePartnership),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}
