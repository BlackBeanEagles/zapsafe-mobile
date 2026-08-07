/// Day 356 — Police Dispatch Production Wire
///
/// Wires Days 221-223's mock police screens (`day221_police_dashboard_
/// screen.dart`, `day222_police_dispatch_status_screen.dart`,
/// `day223_police_weblink_preview_screen.dart` — read first) to the REAL
/// backend endpoint, verified real by reading
/// `zapsafe_backend/police/dispatch_views.py` + `dispatch_serializers.py`
/// + `models.py` directly:
///
///   GET /api/v1/police/dispatch/{sos_id}/
///     -> {"sos_id","reference_number","status","timeline","is_mock"}
///
/// This endpoint is real and always 200s — but honestly, its *data* is
/// itself a real/mock hybrid by design: if a real `PoliceDispatch` row
/// exists for the SOS it's returned (`is_mock: false`); if none does
/// (true for every SOS today — no live police dispatch integration
/// exists yet), the view falls back to a deterministic simulated
/// timeline (`is_mock: true`), per the view's own documented "mock mode"
/// note. This screen surfaces `is_mock` as-is rather than hiding it, so
/// polling a real SOS you own will currently always show the simulated
/// timeline — that's the real, correct behavior of a real endpoint, not
/// a wiring gap.
///
/// Polling: a real SOS id can be entered, or one pulled from
/// [AppRoutes.sosActive]'s state if available. "Poll every 5s" re-fires
/// the real GET request on a timer — genuine polling against the live
/// endpoint, not a local countdown animation.
///
/// Tag: 🔵 EXISTING-API — real backend, real wire (mock-shaped data by
/// design until a live police integration exists).
///
/// Route: [AppRoutes.policeDispatchWire] → `/day-356-police-dispatch-wire`
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/police_dispatch_api_service.dart';
import '../../domain/providers/police_dispatch_api_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

final _d356SosIdProvider = StateProvider<String>((ref) => '');
final _d356PollingProvider = StateProvider<bool>((ref) => false);

class Day356PoliceDispatchWireScreen extends ConsumerStatefulWidget {
  const Day356PoliceDispatchWireScreen({super.key});

  @override
  ConsumerState<Day356PoliceDispatchWireScreen> createState() => _State();
}

class _State extends ConsumerState<Day356PoliceDispatchWireScreen> {
  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _togglePolling(String sosId) {
    final polling = !ref.read(_d356PollingProvider);
    ref.read(_d356PollingProvider.notifier).state = polling;
    _timer?.cancel();
    if (polling && sosId.isNotEmpty) {
      // Real polling — re-fires the actual GET request on the backend on
      // every tick, not a local countdown animation.
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        ref.invalidate(policeDispatchStatusProvider(sosId));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sosId = ref.watch(_d356SosIdProvider);
    final polling = ref.watch(_d356PollingProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(title: Text('day351_360.police_wire_title'.tr())),
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
                    '🔵 REAL API · Section K Day 6/10 · GET /api/v1/police/dispatch/'
                    '{sos_id}/ is real and always 200s — but returns a real '
                    '`is_mock` flag: no live police dispatch integration exists yet, '
                    'so it will currently return a deterministic SIMULATED timeline '
                    'for any real SOS you own. That is correct real behavior, shown '
                    'as-is below.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('day351_360.police_wire_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xl),
          TextField(
            controller: _controller,
            style: const TextStyle(color: ZapColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'SOS id (UUID) to poll',
              labelStyle: const TextStyle(color: ZapColors.textMuted),
              hintText: 'e.g. from an active SOS you triggered',
              hintStyle: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
              filled: true,
              fillColor: ZapColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ZapColors.border),
              ),
            ),
            onChanged: (v) => ref.read(_d356SosIdProvider.notifier).state = v.trim(),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ZapButton.outlined(
                  label: 'Fetch once',
                  icon: Icons.refresh_rounded,
                  onPressed: sosId.isEmpty
                      ? null
                      : () => ref.invalidate(policeDispatchStatusProvider(sosId)),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton(
                  label: polling ? 'Stop polling' : 'Poll every 5s',
                  icon: polling ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                  intent: polling ? ZapButtonIntent.warning : ZapButtonIntent.safe,
                  onPressed: sosId.isEmpty ? null : () => _togglePolling(sosId),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xl),
          if (sosId.isEmpty)
            const _EmptyState(message: 'Enter a real SOS id above to query the real endpoint.')
          else
            Consumer(builder: (context, ref, _) {
              final status = ref.watch(policeDispatchStatusProvider(sosId));
              return status.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    _ErrorCard(error: e, onRetry: () => ref.invalidate(policeDispatchStatusProvider(sosId))),
                data: (d) => _DispatchCard(status: d),
              );
            }),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.tonal(
            label: 'Open Day 221 police dashboard',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.policeDashboard),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.tonal(
            label: 'Open Day 222 dispatch status (mock)',
            icon: Icons.open_in_new_rounded,
            fullWidth: true,
            onPressed: () => context.push(AppRoutes.policeDispatchStatus),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({required this.status});
  final PoliceDispatchStatus status;

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Ref: ${status.referenceNumber}',
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
              ),
              ZapBadge(
                label: status.isMock ? 'SIMULATED' : 'REAL DISPATCH',
                intent: status.isMock ? ZapBadgeIntent.warning : ZapBadgeIntent.safe,
                size: ZapBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Status: ${status.status}',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.md),
          const Divider(color: ZapColors.divider),
          const SizedBox(height: ZapSpacing.sm),
          for (final t in status.timeline)
            Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: ZapColors.info),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.status,
                            style: ZapTypography.bodySmall
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                        if (t.note != null)
                          Text(t.note!, style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
                        Text(t.at?.toLocal().toString() ?? '—',
                            style: ZapTypography.labelSmall.copyWith(color: ZapColors.textMuted)),
                      ],
                    ),
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
            child: Text(message, style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
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
    if (s.contains('404')) return 'SOS not found (SOS_NOT_FOUND) — check the id and that it belongs to you.';
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
          Expanded(child: Text(_label, style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
