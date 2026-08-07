/// Day 387 — Year in Review v2
///
/// Section O (Days 381-390, Project Close): extends Day 275's Year in
/// Review (`day275_year_in_review_screen.dart` — read directly before
/// building this) with a new "Launch Month" section.
///
/// **Since there is no real launch month yet, this extends the
/// TEMPLATE/structure only** — not real launch-month numbers. Day 275's
/// existing mock badges/summary are left as-is (still clearly labeled
/// mock data, per its own header); this screen adds a genuinely new tab
/// showing what a real launch-month section would look like, wired to
/// the same real analytics endpoints Day 386 uses
/// (`day386_analytics_month1_screen.dart`), so it will show real zeros
/// today and real numbers automatically once a genuine launch month
/// exists — no code change required at that point.
///
/// Tag: 🟢 FRONTEND-ONLY structural extension + real (currently empty)
/// analytics wiring for the new Launch Month tab · no fabricated
/// launch-month numbers anywhere.
///
/// Route: [AppRoutes.yearInReviewV2] → `/day-387-year-in-review-v2`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/analytics_api_providers.dart';
import '../navigation/app_router.dart';

const _kAccent = Color(0xFFF59E0B);
const _kTabs = ['Year Template', 'Launch Month (new)', 'Info'];

class Day387YearInReviewV2Screen extends ConsumerWidget {
  const Day387YearInReviewV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day381_390.year_in_review_v2_title'.tr())),
      body: Column(
        children: [
          _TabBar(tab: ref.watch(_d387TabProvider), onSelect: (i) => ref.read(_d387TabProvider.notifier).state = i),
          Expanded(
            child: switch (ref.watch(_d387TabProvider)) {
              0 => const _YearTemplateTab(),
              1 => const _LaunchMonthTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

final _d387TabProvider = StateProvider<int>((ref) => 0);

class _YearTemplateTab extends StatelessWidget {
  const _YearTemplateTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _kAccent.withOpacity(0.3))),
          child: const Text(
            'Day 275\'s original Year in Review (summary card, 12 gamified badges, '
            'monthly chart) is unchanged and still clearly labeled mock data — see '
            'that screen directly. This v2 screen adds ONE new thing: a Launch '
            'Month tab, wired to real (currently empty) analytics.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.yearInReview),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open Day 275 (original template)'),
          style: FilledButton.styleFrom(backgroundColor: _kAccent, minimumSize: const Size(double.infinity, 48)),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('What Day 275 already provides', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        const _FeatureRow(icon: Icons.summarize_rounded, label: 'Annual summary card (mock stats)'),
        const _FeatureRow(icon: Icons.emoji_events_rounded, label: '12 gamified badges, 8 mock-earned'),
        const _FeatureRow(icon: Icons.bar_chart_rounded, label: 'Monthly journeys bar chart (mock)'),
        const _FeatureRow(icon: Icons.share_rounded, label: 'Shareable summary card (clipboard mock)'),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: _kAccent),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12))),
      ]),
    );
  }
}

class _LaunchMonthTab extends StatelessWidget {
  const _LaunchMonthTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(color: ZapColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.danger.withOpacity(0.35), width: 2)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gpp_bad_rounded, color: ZapColors.danger, size: 20),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'No real launch month exists yet. This is the STRUCTURE only, wired '
                  'to the same real endpoints Day 386 uses — it will show real numbers '
                  'automatically once a genuine launch month happens, no code change '
                  'needed here.',
                  style: TextStyle(color: ZapColors.textPrimary, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Launch month at a glance (real, currently empty)', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: ZapSpacing.sm),
        Consumer(builder: (context, ref, _) {
          final raw = ref.watch(sosSummaryRawProvider);
          return raw.when(
            data: (s) => _StatRow(label: 'SOS activations in launch month', value: '${s.totalSos}'),
            loading: () => const _StatRow(label: 'SOS activations in launch month', value: '…'),
            error: (e, _) => const _StatRow(label: 'SOS activations in launch month', value: 'no data'),
          );
        }),
        Consumer(builder: (context, ref, _) {
          final raw = ref.watch(contactResponseRateRawProvider);
          return raw.when(
            data: (r) => _StatRow(label: 'Trusted contact response rate', value: r.totalNotifications == 0 ? 'no data' : '${r.overallResponseRate}%'),
            loading: () => const _StatRow(label: 'Trusted contact response rate', value: '…'),
            error: (e, _) => const _StatRow(label: 'Trusted contact response rate', value: 'no data'),
          );
        }),
        const _StatRow(label: 'Days protected in launch month', value: '0 (no launch yet)'),
        const _StatRow(label: 'New badges this month', value: '0 (no launch yet)'),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(color: ZapColors.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: ZapColors.border)),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: ZapColors.textSecondary, fontSize: 12))),
        Text(value, style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text('Year in Review v2', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        const Text('Section O · extends Day 275\'s template with a Launch Month tab.', style: TextStyle(color: ZapColors.textMuted, fontSize: 11)),
        const SizedBox(height: ZapSpacing.lg),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(label: const Text('Day 275 Original'), onPressed: () => context.push(AppRoutes.yearInReview)),
          ActionChip(label: const Text('Day 386 Month 1 Report'), onPressed: () => context.push(AppRoutes.analyticsMonth1)),
        ]),
      ],
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
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _kAccent : Colors.transparent, width: 2))),
                child: Text(_kTabs[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? _kAccent : ZapColors.textMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
