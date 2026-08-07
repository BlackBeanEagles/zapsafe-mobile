/// Day 357 — Group Journey Production Wire
///
/// Wires Day 250-252's mock group journey screens
/// (`day250_group_journey_create_screen.dart`,
/// `day251_group_journey_live_map_screen.dart`,
/// `day252_group_panic_screen.dart` — read first: create flow, live map
/// with member pins, panic button) to the REAL backend endpoints,
/// verified real by reading `zapsafe_backend/journey/views.py` +
/// `serializers.py` + `models.py` directly:
///
///   POST /api/v1/journey/group/create/        creator auto-joined, 201
///   POST /api/v1/journey/group/join/           body: {"token"}
///   GET  /api/v1/journey/group/{session_id}/   members-only (404 if not a member)
///   POST /api/v1/journey/group/{session_id}/panic/  202 — real SOS per member
///
/// All four are real, working Django views (Days 221-223) — not stubs.
/// The panic endpoint is the most consequential real wire in this whole
/// section: `POST .../panic/` genuinely creates a real `SOSEvent` row
/// (`trigger_type=GROUP_PANIC`) and dispatches `dispatch_sos_task` for
/// every JOINED member, not just the caller — same production code path
/// a real emergency would hit. This screen makes that explicit with a
/// confirmation step before firing it for real.
///
/// Tag: 🔵 EXISTING-API — real backend, real wire, real side effects.
///
/// Route: [AppRoutes.groupJourneyWire] → `/day-357-group-journey-wire`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/group_journey_api_service.dart';
import '../../domain/providers/group_journey_api_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day357GroupJourneyWireScreen extends ConsumerStatefulWidget {
  const Day357GroupJourneyWireScreen({super.key});

  @override
  ConsumerState<Day357GroupJourneyWireScreen> createState() => _State();
}

class _State extends ConsumerState<Day357GroupJourneyWireScreen> {
  final _destinationController = TextEditingController(text: 'Home');
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _destinationController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupJourneyWireProvider);
    final controller = ref.read(groupJourneyWireProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.journey_wire_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.danger.withOpacity(0.08),
            borderColor: ZapColors.danger.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: ZapColors.danger, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    '🔵 REAL API + REAL SIDE EFFECTS · Section K Day 7/10 · all 4 '
                    'group journey endpoints verified real (Days 221-223). The '
                    'panic button below creates a REAL SOSEvent and dispatches it '
                    'for every joined member — only trigger it if you mean to.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.journey_wire_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xl),
          if (state.session == null) ...[
            Text('POST /api/v1/journey/group/create/',
                style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
            const SizedBox(height: ZapSpacing.sm),
            TextField(
              controller: _destinationController,
              style: const TextStyle(color: ZapColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Destination name (optional)',
                labelStyle: const TextStyle(color: ZapColors.textMuted),
                filled: true,
                fillColor: ZapColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ZapColors.border),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            ZapButton.elevated(
              label: state.isLoading ? 'Creating…' : 'Create real session',
              icon: Icons.add_circle_rounded,
              intent: ZapButtonIntent.info,
              isLoading: state.isLoading,
              fullWidth: true,
              onPressed: state.isLoading
                  ? null
                  : () => controller.create(destinationName: _destinationController.text.trim()),
            ),
            const SizedBox(height: ZapSpacing.lg),
            Text('— or —', style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
            const SizedBox(height: ZapSpacing.lg),
            Text('POST /api/v1/journey/group/join/',
                style: ZapTypography.monoSmall.copyWith(color: ZapColors.textMuted)),
            const SizedBox(height: ZapSpacing.sm),
            TextField(
              controller: _tokenController,
              style: const TextStyle(color: ZapColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Invite token',
                labelStyle: const TextStyle(color: ZapColors.textMuted),
                filled: true,
                fillColor: ZapColors.bgElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ZapColors.border),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.sm),
            ZapButton.outlined(
              label: 'Join real session',
              icon: Icons.group_add_rounded,
              fullWidth: true,
              onPressed: state.isLoading || _tokenController.text.trim().isEmpty
                  ? null
                  : () => controller.join(_tokenController.text.trim()),
            ),
          ] else ...[
            _SessionCard(
              session: state.session!,
              isLoading: state.isLoading,
              onRefresh: controller.refreshState,
              onPanic: () => _confirmPanic(context, controller),
              onReset: controller.reset,
            ),
          ],
          if (state.panicResult != null) ...[
            const SizedBox(height: ZapSpacing.lg),
            ZapCard(
              backgroundColor: ZapColors.danger.withOpacity(0.1),
              borderColor: ZapColors.danger.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emergency_rounded, color: ZapColors.danger, size: 20),
                      SizedBox(width: 8),
                      Text('Group panic triggered — REAL',
                          style: TextStyle(color: ZapColors.danger, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    '${state.panicResult!.triggeredSosIds.length} real SOS event(s) '
                    'triggered · ${state.panicResult!.skippedUserIds.length} member(s) '
                    'skipped (already had a live SOS) · '
                    '${state.panicResult!.memberCount} member(s) in session',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: ZapSpacing.lg),
            _ErrorCard(error: state.error!),
          ],
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.tonal(
            label: 'Open Day 250 create screen (mock)',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.groupJourneyCreate),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.tonal(
            label: 'Open Day 251 live map screen (mock)',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.groupJourneyLiveMap),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.tonal(
            label: 'Open Day 252 panic screen (mock)',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.groupJourneyPanic),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }

  Future<void> _confirmPanic(BuildContext context, GroupJourneyWireController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        title: const Text('Trigger REAL group panic?', style: TextStyle(color: ZapColors.danger)),
        content: const Text(
          'This calls the real POST .../panic/ endpoint and creates a real '
          'SOSEvent for every joined member of this session. This is not a '
          'simulation.',
          style: TextStyle(color: ZapColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trigger for real', style: TextStyle(color: ZapColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.panic();
    }
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isLoading,
    required this.onRefresh,
    required this.onPanic,
    required this.onReset,
  });

  final GroupJourneySession session;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onPanic;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Session ${session.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
              ),
              ZapBadge(
                label: session.status.toUpperCase(),
                intent: session.status == 'active' ? ZapBadgeIntent.safe : ZapBadgeIntent.neutral,
                size: ZapBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text('Invite link: ${session.inviteLink}',
              style: ZapTypography.labelSmall.copyWith(color: ZapColors.info)),
          const SizedBox(height: ZapSpacing.sm),
          Text('${session.members.length} member(s)',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.outlined(
                  label: 'Refresh state',
                  icon: Icons.refresh_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : onRefresh,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton(
                  label: 'PANIC (real)',
                  icon: Icons.emergency_rounded,
                  intent: ZapButtonIntent.danger,
                  onPressed: isLoading ? null : onPanic,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.text(label: 'Start over', onPressed: onReset),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final Object error;

  String get _label {
    final s = error.toString();
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('404')) return 'Journey session not found (or you\'re not a member).';
    if (s.contains('409')) return 'This journey is no longer active.';
    if (s.contains('500')) return 'Server error.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Request failed: $s';
  }

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      backgroundColor: ZapColors.danger.withOpacity(0.08),
      borderColor: ZapColors.danger.withOpacity(0.3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ZapColors.danger, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(_label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger))),
        ],
      ),
    );
  }
}
