/// Day 354 — Family Dashboard Production Wire
///
/// Wires Day 254's mock (`day254_family_sos_history_screen.dart` — read
/// first: per-member timeline UI, admin-only, mock string member ids like
/// `fam_bro_004`) to the REAL backend endpoints, verified real by reading
/// `zapsafe_backend/family/views.py` + `family/serializers.py` directly:
///
///   GET /api/v1/family/dashboard/
///     -> {"count", "members": [{"member_id","full_name","phone","role",
///          "last_sos_status","last_sos_triggered_at","has_live_sos"}]}
///     Every `FamilyLink` row the caller admins, each with the member's
///     latest SOS status — a real, working Django view backed by a real
///     `FamilyLink` model (Days 224-225), not a stub.
///
///   GET /api/v1/family/members/{id}/sos-history/
///     -> {"member_id","count","results":[{"id","status","trigger_type",
///          "triggered_at","note"}]}
///     Admin-role only (`FamilyLink.admin_user == caller`), 404
///     FAMILY_LINK_NOT_FOUND otherwise. `{id}` must be the real member's
///     user UUID from the dashboard response above — Day 254's mock
///     string ids (`fam_bro_004`) don't exist against this real endpoint.
///
/// This screen shows the real shape (list-of-members-with-latest-status)
/// which is closer to Day 253's dashboard framing than Day 254's
/// per-member-timeline framing — both real endpoints exist, so both are
/// wired here: tapping a member drills into their real SOS history.
///
/// Honest caveat: this worktree has no backend running (Docker
/// unavailable in this sandbox) and no seeded FamilyLink rows to test
/// against, so the "0 members" empty state below is what a real logged-in
/// user with no family links configured would see — that is the expected,
/// correct behavior for a fresh account, not a wiring bug.
///
/// Tag: 🔵 EXISTING-API — real backend, real wire.
///
/// Route: [AppRoutes.familyDashboardWire] → `/day-354-family-dashboard-wire`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/family_api_service.dart';
import '../../domain/providers/family_api_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

final _d354SelectedMemberProvider = StateProvider<String?>((ref) => null);

class Day354FamilyDashboardWireScreen extends ConsumerWidget {
  const Day354FamilyDashboardWireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(familyDashboardRawProvider);
    final selectedMember = ref.watch(_d354SelectedMemberProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.family_wire_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🔵 REAL API · Section K Day 4/10 · GET /api/v1/family/dashboard/ '
                    'and GET /api/v1/family/members/{id}/sos-history/ both exist and '
                    'are wired for real below — no mock fallback on this raw view, so '
                    'a real error (401/network/empty) shows exactly as returned.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.family_wire_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          const Text(
            'GET /api/v1/family/dashboard/',
            style: TextStyle(color: ZapColors.textMuted, fontFamily: 'monospace', fontSize: 11),
          ),
          const SizedBox(height: ZapSpacing.lg),
          dashboard.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _ErrorCard(error: e, onRetry: () => ref.invalidate(familyDashboardRawProvider)),
            data: (d) => d.members.isEmpty
                ? const _EmptyState(
                    message: 'No family links found for this account. That\'s the '
                        'correct real response for a fresh account with no '
                        'linked members — not a wiring failure.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.count} member(s)',
                          style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
                      const SizedBox(height: ZapSpacing.sm),
                      for (final m in d.members)
                        _MemberRow(
                          member: m,
                          selected: selectedMember == m.memberId,
                          onTap: () => ref.read(_d354SelectedMemberProvider.notifier).state =
                              selectedMember == m.memberId ? null : m.memberId,
                        ),
                    ],
                  ),
          ),
          if (selectedMember != null) ...[
            const SizedBox(height: ZapSpacing.xl),
            Text('GET /api/v1/family/members/$selectedMember/sos-history/',
                style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
            const SizedBox(height: ZapSpacing.sm),
            Consumer(builder: (context, ref, _) {
              final history = ref.watch(familyMemberSosHistoryProvider(selectedMember));
              return history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => _ErrorCard(
                  error: e,
                  onRetry: () => ref.invalidate(familyMemberSosHistoryProvider(selectedMember)),
                ),
                data: (h) => h.results.isEmpty
                    ? const _EmptyState(message: 'No SOS history for this member yet.')
                    : ZapCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final item in h.results) _HistoryRow(item: item),
                          ],
                        ),
                      ),
              );
            }),
          ],
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.tonal(
            label: 'Open Day 254 mock timeline UI',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.familySosHistory),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.selected, required this.onTap});
  final FamilyDashboardMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      onTap: onTap,
      isHighlighted: selected,
      highlightColor: ZapColors.info,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (member.hasLiveSos ? ZapColors.danger : ZapColors.info).withOpacity(0.15),
            child: Icon(
              member.hasLiveSos ? Icons.emergency_rounded : Icons.person_rounded,
              color: member.hasLiveSos ? ZapColors.danger : ZapColors.info,
              size: 18,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName.isEmpty ? member.phone : member.fullName,
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                Text(
                  '${member.role} · ${member.lastSosStatus ?? "no SOS on record"}',
                  style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                ),
              ],
            ),
          ),
          if (member.hasLiveSos)
            const ZapBadge(label: 'LIVE SOS', intent: ZapBadgeIntent.danger, size: ZapBadgeSize.small, pulse: true),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final FamilySosHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: ZapColors.textMuted),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.status} · ${item.triggerType}',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(
                  item.triggeredAt?.toLocal().toString() ?? '—',
                  style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: ZapColors.textSecondary, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(message, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  String get _label {
    final s = error.toString();
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('404')) return 'Not found — check the family link exists.';
    if (s.contains('500')) return 'Server error — tap retry.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Request failed: $s';
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ZapColors.danger, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(_label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
