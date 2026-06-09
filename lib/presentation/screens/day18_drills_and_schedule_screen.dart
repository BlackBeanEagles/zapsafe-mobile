import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/push_service.dart';
import '../../domain/providers/push_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_dialog.dart';
import '../widgets/zap_snackbar.dart';

/// Day 18 — Scheduled local notifications + silent notifications + drill mode.
///
/// Three independent panels:
///   1. Schedule — fire a notification at a chosen future time, cancel any
///      pending ones from the live list.
///   2. Silent — fires a no-sound / no-vibration notification.
///   3. Drill — re-uses the SOS notification template prefixed with [DRILL]
///      and tagged with `data.drill = true` so backend dispatch short-circuits.
class Day18DrillsAndScheduleScreen extends ConsumerStatefulWidget {
  const Day18DrillsAndScheduleScreen({super.key});

  @override
  ConsumerState<Day18DrillsAndScheduleScreen> createState() =>
      _Day18DrillsAndScheduleScreenState();
}

class _Day18DrillsAndScheduleScreenState
    extends ConsumerState<Day18DrillsAndScheduleScreen> {
  List<PendingNotificationRequest> _pending = const [];
  PushPayload? _lastDrill;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final service = ref.read(pushServiceProvider);
    final list = await service.listScheduled();
    if (mounted) setState(() => _pending = list);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(pushServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 18 · Drills & Schedule'),
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

              // ─── Schedule ──────────────────────────────────────────────
              const _SectionLabel('SCHEDULE A NOTIFICATION'),
              const SizedBox(height: ZapSpacing.md),
              _ScheduleCard(
                onSchedule5s: () => _scheduleIn(service, const Duration(seconds: 5)),
                onSchedule1m: () => _scheduleIn(service, const Duration(minutes: 1)),
                onScheduleTomorrow9am: () => _scheduleCheckIn9am(service),
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ─── Pending list ──────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: _SectionLabel('PENDING SCHEDULED')),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZapColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_pending.length}',
                      style: ZapTypography.labelSmall.copyWith(
                        color: ZapColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              _PendingList(
                pending: _pending,
                onCancel: (id) async {
                  await service.cancelScheduled(id);
                  await _refreshPending();
                  if (mounted) ZapSnackbar.info(context, 'Scheduled #$id cancelled');
                },
                onCancelAll: () async {
                  await service.cancelAllScheduled();
                  await _refreshPending();
                  if (mounted) ZapSnackbar.info(context, 'All scheduled notifications cancelled');
                },
                onRefresh: _refreshPending,
              ),
              const SizedBox(height: ZapSpacing.xl),

              // ─── Silent ────────────────────────────────────────────────
              const _SectionLabel('SILENT NOTIFICATION'),
              const SizedBox(height: ZapSpacing.md),
              _SilentCard(onFire: () => _fireSilent(service)),
              const SizedBox(height: ZapSpacing.xl),

              // ─── Drill ─────────────────────────────────────────────────
              const _SectionLabel('DRILL MODE'),
              const SizedBox(height: ZapSpacing.md),
              _DrillCard(
                lastDrill: _lastDrill,
                onFireDrill: () => _confirmAndFireDrill(service),
              ),
              const SizedBox(height: ZapSpacing.xxl),

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

  // ─── Handlers ────────────────────────────────────────────────────────────

  Future<void> _scheduleIn(PushService service, Duration delay) async {
    final when = DateTime.now().add(delay);
    final id = await service.scheduleNotification(
      payload: PushPayload(
        messageId: 'sched_${when.millisecondsSinceEpoch}',
        category: PushCategory.checkInReminder,
        title: 'Scheduled reminder',
        body:
            'Fired at ${when.hour.toString().padLeft(2, "0")}:${when.minute.toString().padLeft(2, "0")} · scheduled +${delay.inSeconds}s',
      ),
      when: when,
    );
    await _refreshPending();
    if (!mounted) return;
    ZapSnackbar.success(
      context,
      'Scheduled #$id · fires in ${delay.inSeconds}s',
    );
  }

  Future<void> _scheduleCheckIn9am(PushService service) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, 9, 0);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    final id = await service.scheduleNotification(
      payload: const PushPayload(
        messageId: 'daily_checkin',
        category: PushCategory.checkInReminder,
        title: 'Good morning',
        body: 'Quick wellness check-in: tap to mark yourself safe.',
      ),
      when: when,
    );
    await _refreshPending();
    if (!mounted) return;
    ZapSnackbar.success(
      context,
      'Daily check-in scheduled #$id · ${when.day}/${when.month} at 09:00',
    );
  }

  Future<void> _fireSilent(PushService service) async {
    await service.showSilent(
      title: 'ZapSafe sync',
      body: 'Evidence pipeline reconciled · no action needed.',
    );
    if (!mounted) return;
    ZapSnackbar.info(context, 'Silent notification posted · no sound or vibration');
  }

  Future<void> _confirmAndFireDrill(PushService service) async {
    final ok = await ZapDialog.confirm(
      context,
      title: 'Fire drill SOS?',
      message:
          'A drill notification will render exactly like a real SOS — same '
          'channel, same action buttons, same routing — but tagged so the '
          'backend never escalates. Use this to rehearse the SOS flow.',
      confirmLabel: 'FIRE DRILL',
      intent: ZapDialogIntent.warning,
    );
    if (ok != true) return;
    final payload = await service.fireDrill(
      scenario: 'Late-night walk home rehearsal',
    );
    if (!mounted) return;
    setState(() => _lastDrill = payload);
    ZapSnackbar.warning(
      context,
      'Drill SOS fired · check your notification tray',
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
                child: const Icon(Icons.schedule_rounded,
                    color: ZapColors.warning, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 4 · DAY 18', intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Drills & Scheduled Pushes',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'zonedSchedule via the timezone DB · silent low-importance channel · '
            'drill mode reuses the SOS template prefixed [DRILL] so backend '
            'dispatch short-circuits.',
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

// ─── Schedule card ───────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final VoidCallback onSchedule5s;
  final VoidCallback onSchedule1m;
  final VoidCallback onScheduleTomorrow9am;

  const _ScheduleCard({
    required this.onSchedule5s,
    required this.onSchedule1m,
    required this.onScheduleTomorrow9am,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        children: [
          ZapButton.elevated(
            label: 'IN 5 SECONDS',
            icon: Icons.timer_rounded,
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: onSchedule5s,
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'IN 1 MINUTE',
            icon: Icons.av_timer_rounded,
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: onSchedule1m,
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'TOMORROW AT 9 AM',
            icon: Icons.wb_sunny_rounded,
            intent: ZapButtonIntent.safe,
            fullWidth: true,
            onPressed: onScheduleTomorrow9am,
          ),
        ],
      ),
    );
  }
}

// ─── Pending list ────────────────────────────────────────────────────────────

class _PendingList extends StatelessWidget {
  final List<PendingNotificationRequest> pending;
  final void Function(int id) onCancel;
  final VoidCallback onCancelAll;
  final VoidCallback onRefresh;

  const _PendingList({
    required this.pending,
    required this.onCancel,
    required this.onCancelAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'No pending scheduled notifications.',
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ),
            ZapButton.text(
              label: 'REFRESH',
              icon: Icons.refresh_rounded,
              onPressed: onRefresh,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final p in pending)
          Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: ZapCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title ?? '(no title)',
                          style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.body ?? '',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'id: ${p.id}  ·  payload: ${p.payload ?? "—"}',
                          style: ZapTypography.monoSmall.copyWith(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onCancel(p.id),
                    tooltip: 'Cancel',
                    color: ZapColors.danger,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ZapButton.outlined(
                label: 'CANCEL ALL',
                icon: Icons.delete_sweep_rounded,
                intent: ZapButtonIntent.danger,
                onPressed: onCancelAll,
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: ZapButton.outlined(
                label: 'REFRESH',
                icon: Icons.refresh_rounded,
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Silent card ─────────────────────────────────────────────────────────────

class _SilentCard extends StatelessWidget {
  final VoidCallback onFire;
  const _SilentCard({required this.onFire});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Channel: zapsafe_silent · importance: LOW',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'No sound, no vibration, no LED. Used for background sync confirmations '
            'and status updates that should not interrupt the user.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          ZapButton.outlined(
            label: 'POST SILENT NOTIFICATION',
            icon: Icons.notifications_off_rounded,
            fullWidth: true,
            onPressed: onFire,
          ),
        ],
      ),
    );
  }
}

// ─── Drill card ──────────────────────────────────────────────────────────────

class _DrillCard extends StatelessWidget {
  final PushPayload? lastDrill;
  final VoidCallback onFireDrill;
  const _DrillCard({required this.lastDrill, required this.onFireDrill});

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PRACTICE · NO REAL ESCALATION',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.warning,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Drill mode reuses the SOS notification template:',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          _bullet('Same channel · bypass DND · max priority'),
          _bullet('Same iOS + Android action buttons'),
          _bullet('Same /sos-active routing'),
          _bullet('Title prefixed [DRILL]'),
          _bullet('`data.drill = true` → backend never dispatches'),
          const SizedBox(height: ZapSpacing.md),
          if (lastDrill != null) ...[
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: ZapColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last drill: ${lastDrill!.title}',
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(lastDrill!.body ?? '',
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                      )),
                  const SizedBox(height: 4),
                  Text('data: ${lastDrill!.data}',
                      style: ZapTypography.monoSmall.copyWith(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
          ],
          ZapButton.elevated(
            label: 'FIRE DRILL SOS',
            icon: Icons.bolt_rounded,
            intent: ZapButtonIntent.warning,
            fullWidth: true,
            onPressed: onFireDrill,
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 4, color: ZapColors.warning),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─── Section label ───────────────────────────────────────────────────────────

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
