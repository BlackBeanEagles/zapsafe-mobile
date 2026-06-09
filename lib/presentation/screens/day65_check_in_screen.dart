/// Day 65 — Safety Check-in Timer Screen
///
/// Dead-man's switch: start a countdown, tap "I'm Safe" before it expires.
/// If the timer runs out without a check-in, the app can escalate via the
/// linked EscalationPolicy.
///
/// • Create timer (POST /api/v1/check-ins/)
/// • List timers with status filter — active shown with live countdown
/// • "I'm Safe" / Cancel / Expire actions per timer
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/check_in_service.dart';
import '../../data/services/escalation_service.dart';
import '../../domain/providers/check_in_providers.dart';
import '../../domain/providers/escalation_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day65CheckInScreen extends ConsumerStatefulWidget {
  const Day65CheckInScreen({super.key});

  @override
  ConsumerState<Day65CheckInScreen> createState() =>
      _Day65CheckInScreenState();
}

class _Day65CheckInScreenState extends ConsumerState<Day65CheckInScreen> {
  // ── Create-form state ──────────────────────────────────────────────────────
  final _labelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int     _duration        = 30;      // minutes
  String? _selectedPolicyId;
  bool    _creating        = false;
  String? _createError;
  String? _createSuccessLabel;

  // ── Filter ─────────────────────────────────────────────────────────────────
  String _statusFilter = 'active';

  // ── Live countdown (id → remaining seconds) ────────────────────────────────
  Timer?            _ticker;
  Map<String, int>  _countdown = {};

  // ── Action state ───────────────────────────────────────────────────────────
  String? _actingId;
  String? _actingOp;  // 'checkin' | 'cancel' | 'expire'
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _countdown.updateAll((_, secs) => secs > 0 ? secs - 1 : 0);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _labelCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Sync countdown from freshly loaded data ────────────────────────────────
  void _syncCountdown(List<CheckInListEntry> items) {
    final Map<String, int> next = {};
    for (final ci in items) {
      if (ci.status == 'active') {
        // Prefer existing local count (already ticking) over API snapshot
        next[ci.id] = _countdown.containsKey(ci.id)
            ? _countdown[ci.id]!
            : ci.remainingSeconds;
      }
    }
    if (next.toString() != _countdown.toString()) {
      setState(() => _countdown = next);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmt(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _countdownColor(int secs, bool overdue) {
    if (overdue || secs == 0) return ZapColors.danger;
    if (secs < 300)            return ZapColors.warning;   // < 5 min
    return ZapColors.safe;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _createError = null;
      _createSuccessLabel = null;
    });
    try {
      final created = await ref.read(checkInServiceProvider).create(
            durationMinutes:  _duration,
            label:            _labelCtrl.text.trim(),
            escalationPolicy: _selectedPolicyId,
            notes:            _notesCtrl.text.trim(),
          );
      ref.invalidate(checkInListProvider);
      _labelCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _createSuccessLabel  = created.label.isEmpty ? 'Timer' : created.label;
        _duration            = 30;
        _selectedPolicyId    = null;
        // Seed countdown immediately
        _countdown[created.id] = created.remainingSeconds;
        // Switch to active filter to show the new timer
        _statusFilter = 'active';
      });
    } catch (e) {
      setState(() => _createError = e.toString());
    } finally {
      setState(() => _creating = false);
    }
  }

  Future<void> _act(String id, String op) async {
    setState(() {
      _actingId  = id;
      _actingOp  = op;
      _actionError = null;
    });
    try {
      final svc = ref.read(checkInServiceProvider);
      switch (op) {
        case 'checkin': await svc.checkIn(id); break;
        case 'cancel':  await svc.cancel(id);  break;
        case 'expire':  await svc.expire(id);  break;
      }
      ref.invalidate(checkInListProvider);
      setState(() => _countdown.remove(id));
    } catch (e) {
      setState(() => _actionError = e.toString());
    } finally {
      setState(() { _actingId = null; _actingOp = null; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(checkInListProvider(_statusFilter));
    final policiesAsync = ref.watch(escalationPolicyListProvider);

    // Sync countdown whenever list data arrives
    listAsync.whenData(_syncCountdown);

    final policies = policiesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        title: const Text('Check-in Timers',
            style: ZapTypography.headlineSmall),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.md),
        children: [
          // ── Create card ─────────────────────────────────────────────────
          _CreateCard(
            labelCtrl:        _labelCtrl,
            notesCtrl:        _notesCtrl,
            duration:         _duration,
            policies:         policies,
            selectedPolicyId: _selectedPolicyId,
            creating:         _creating,
            onDuration: (v) => setState(() => _duration = v),
            onPolicy:   (v) => setState(() => _selectedPolicyId = v),
            onCreate: _create,
          ),
          if (_createError != null) ...[
            const SizedBox(height: ZapSpacing.xs),
            _ErrorBanner(_createError!),
          ],
          if (_createSuccessLabel != null) ...[
            const SizedBox(height: ZapSpacing.xs),
            _SuccessBanner(
                'Timer started: "$_createSuccessLabel" · tap "I\'m Safe" when home'),
          ],
          const SizedBox(height: ZapSpacing.lg),

          // ── Filter + list ────────────────────────────────────────────────
          const _SectionLabel('YOUR TIMERS'),
          const SizedBox(height: ZapSpacing.sm),
          _StatusFilterChips(
            selected: _statusFilter,
            onSelect: (v) => setState(() {
              _statusFilter = v;
              _actionError  = null;
            }),
          ),
          const SizedBox(height: ZapSpacing.md),

          if (_actionError != null) ...[
            _ErrorBanner(_actionError!),
            const SizedBox(height: ZapSpacing.sm),
          ],

          listAsync.when(
            loading: () => const _Spinner(),
            error:   (e, _) => _ErrorBanner(e.toString()),
            data: (items) {
              if (items.isEmpty) {
                return _EmptyBox(
                  _statusFilter == 'active'
                      ? 'No active timers. Start one above.'
                      : 'No timers with status "$_statusFilter".',
                );
              }
              return Column(
                children: items.map((ci) {
                  final remaining = _countdown[ci.id] ?? ci.remainingSeconds;
                  final overdue   = ci.isOverdue || remaining == 0 && ci.status == 'active';
                  return _CheckInCard(
                    entry:       ci,
                    remaining:   remaining,
                    overdue:     overdue,
                    countdownFmt: _fmt(remaining),
                    countdownColor: _countdownColor(remaining, overdue),
                    actingId:   _actingId,
                    actingOp:   _actingOp,
                    onCheckIn:  ci.status == 'active'
                        ? () => _act(ci.id, 'checkin')
                        : null,
                    onCancel:   ci.status == 'active'
                        ? () => _act(ci.id, 'cancel')
                        : null,
                    onExpire:   ci.status == 'active'
                        ? () => _act(ci.id, 'expire')
                        : null,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Create card ──────────────────────────────────────────────────────────────

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.labelCtrl,
    required this.notesCtrl,
    required this.duration,
    required this.policies,
    required this.selectedPolicyId,
    required this.creating,
    required this.onDuration,
    required this.onPolicy,
    required this.onCreate,
  });

  final TextEditingController labelCtrl;
  final TextEditingController notesCtrl;
  final int      duration;
  final List<EscalationPolicy> policies;
  final String?  selectedPolicyId;
  final bool     creating;
  final ValueChanged<int>     onDuration;
  final ValueChanged<String?> onPolicy;
  final VoidCallback onCreate;

  static const _presets = [1, 5, 10, 15, 20, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZapColors.bgElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.timer_rounded, size: 18, color: ZapColors.safe),
            SizedBox(width: ZapSpacing.xs),
            Text('New Check-in Timer', style: ZapTypography.labelMedium),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Label
          const _FieldLabel('Label (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(
              controller: labelCtrl,
              hint: 'e.g. Walking home, Gym session'),
          const SizedBox(height: ZapSpacing.md),

          // Duration presets
          const _FieldLabel('Duration'),
          const SizedBox(height: ZapSpacing.xs),
          Wrap(
            spacing: ZapSpacing.xs,
            runSpacing: ZapSpacing.xs,
            children: _presets.map((min) {
              final selected = duration == min;
              return GestureDetector(
                onTap: () => onDuration(min),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? ZapColors.safe
                        : ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    min < 60 ? '${min}m' : '${min ~/ 60}h',
                    style: ZapTypography.labelSmall.copyWith(
                      color: selected
                          ? ZapColors.bgPrimary
                          : ZapColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.xs),
          // Custom stepper for fine adjustment
          Row(children: [
            _StepBtn(
              icon: Icons.remove,
              onTap: duration > 1
                  ? () => onDuration(duration - 1)
                  : null,
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              '$duration min',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.safe),
            ),
            const SizedBox(width: ZapSpacing.sm),
            _StepBtn(
              icon: Icons.add,
              onTap: duration < 480
                  ? () => onDuration(duration + 1)
                  : null,
            ),
          ]),
          const SizedBox(height: ZapSpacing.md),

          // Escalation policy (optional)
          if (policies.isNotEmpty) ...[
            const _FieldLabel('Escalation policy (optional)'),
            const SizedBox(height: ZapSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: ZapColors.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String?>(
                value:         selectedPolicyId,
                isExpanded:    true,
                underline:     const SizedBox.shrink(),
                dropdownColor: ZapColors.bgCard,
                style:         ZapTypography.bodySmall,
                hint: Text('None — use default at trigger time',
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary)),
                onChanged: onPolicy,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.textSecondary)),
                  ),
                  ...policies.map((p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Row(children: [
                          if (p.isDefault) ...[
                            const Icon(Icons.star_rounded,
                                size: 12, color: ZapColors.safe),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(p.name,
                                style: ZapTypography.bodySmall),
                          ),
                        ]),
                      )),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
          ],

          // Notes
          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: ZapSpacing.xs),
          _TextField(controller: notesCtrl, hint: 'e.g. back by 11 pm'),
          const SizedBox(height: ZapSpacing.md),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: creating ? null : onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.safe,
                foregroundColor: ZapColors.bgPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: creating
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ZapColors.bgPrimary))
                  : const Icon(Icons.timer_outlined, size: 18),
              label: Text(
                creating ? 'Starting…' : 'Start Timer',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.bgPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Check-in card ────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.entry,
    required this.remaining,
    required this.overdue,
    required this.countdownFmt,
    required this.countdownColor,
    required this.actingId,
    required this.actingOp,
    this.onCheckIn,
    this.onCancel,
    this.onExpire,
  });

  final CheckInListEntry entry;
  final int      remaining;
  final bool     overdue;
  final String   countdownFmt;
  final Color    countdownColor;
  final String?  actingId;
  final String?  actingOp;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCancel;
  final VoidCallback? onExpire;

  bool get _busy => actingId == entry.id;

  @override
  Widget build(BuildContext context) {
    final ci = entry;
    final isActive = ci.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? (overdue
                  ? ZapColors.danger
                  : countdownColor.withOpacity(0.5))
              : ZapColors.bgElevated,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ci.label.isEmpty ? 'Check-in' : ci.label,
                        style: ZapTypography.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ci.durationMinutes} min timer'
                        ' · started ${_timeAgo(ci.createdAt)}',
                        style: ZapTypography.labelSmall
                            .copyWith(color: ZapColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(ci.status),
              ],
            ),

            // ── Countdown (active only) ────────────────────────────────
            if (isActive) ...[
              const SizedBox(height: ZapSpacing.md),
              Center(
                child: Column(children: [
                  Text(
                    overdue ? 'OVERDUE' : countdownFmt,
                    style: ZapTypography.headlineSmall.copyWith(
                      color: countdownColor,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: overdue ? 2 : 0,
                    ),
                  ),
                  Text(
                    overdue
                        ? 'Timer has elapsed — check in or escalate'
                        : 'remaining · expires ${_fmtTime(ci.expiresAt)}',
                    style: ZapTypography.labelSmall
                        .copyWith(color: ZapColors.textSecondary),
                  ),
                ]),
              ),
              const SizedBox(height: ZapSpacing.md),

              // ── Action buttons ─────────────────────────────────────────
              Row(children: [
                // I'm Safe — primary CTA
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : onCheckIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _busy && actingOp == 'checkin'
                              ? ZapColors.safe.withOpacity(0.6)
                              : ZapColors.safe,
                      foregroundColor: ZapColors.bgPrimary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _busy && actingOp == 'checkin'
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZapColors.bgPrimary))
                        : const Icon(Icons.check_circle_rounded,
                            size: 18),
                    label: Text(
                      _busy && actingOp == 'checkin'
                          ? 'Checking in…'
                          : "I'm Safe",
                      style: ZapTypography.labelMedium
                          .copyWith(color: ZapColors.bgPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.xs),

                // Cancel
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.textSecondary,
                      side: const BorderSide(
                          color: ZapColors.bgElevated),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busy && actingOp == 'cancel'
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZapColors.textSecondary))
                        : Text('Cancel',
                            style: ZapTypography.labelSmall
                                .copyWith(
                                    color: ZapColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: ZapSpacing.xs),

                // Expire (manual — for testing / force-expire)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : onExpire,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.danger,
                      side: const BorderSide(
                          color: ZapColors.danger,
                          width: 0.8),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busy && actingOp == 'expire'
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZapColors.danger))
                        : Text('Expire',
                            style: ZapTypography.labelSmall
                                .copyWith(color: ZapColors.danger)),
                  ),
                ),
              ]),
            ],

            // ── Terminal state info ────────────────────────────────────
            if (!isActive) ...[
              const SizedBox(height: ZapSpacing.xs),
              if (ci.checkedInAt != null)
                _MetaRow(
                  icon:  Icons.check_circle_outline_rounded,
                  color: ZapColors.safe,
                  text:  'Checked in at ${_fmtTime(ci.checkedInAt!)}',
                )
              else if (ci.status == 'expired')
                _MetaRow(
                  icon:  Icons.timer_off_rounded,
                  color: ZapColors.danger,
                  text:  'Expired at ${_fmtTime(ci.expiresAt)}',
                )
              else
                const _MetaRow(
                  icon:  Icons.cancel_outlined,
                  color: ZapColors.textSecondary,
                  text:  'Cancelled',
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours  < 24)  return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = h < 12 ? 'AM' : 'PM';
    final h12    = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $suffix';
  }
}

// ─── Status filter chips ──────────────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.selected,
    required this.onSelect,
  });
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const opts = [
      ('active',     'Active',     ZapColors.safe),
      ('checked_in', 'Checked In', ZapColors.info),
      ('cancelled',  'Cancelled',  ZapColors.textSecondary),
      ('expired',    'Expired',    ZapColors.danger),
      ('',           'All',        ZapColors.warning),
    ];
    return Wrap(
      spacing: ZapSpacing.xs,
      runSpacing: ZapSpacing.xs,
      children: opts.map((o) {
        final active = selected == o.$1;
        return GestureDetector(
          onTap: () => onSelect(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: active ? o.$3 : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active ? o.$3 : ZapColors.bgElevated),
            ),
            child: Text(
              o.$2,
              style: ZapTypography.labelSmall.copyWith(
                color: active
                    ? ZapColors.bgPrimary
                    : ZapColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active'     => (ZapColors.safe,          'ACTIVE'),
      'checked_in' => (ZapColors.info,           'SAFE ✓'),
      'cancelled'  => (ZapColors.textSecondary,  'CANCELLED'),
      'expired'    => (ZapColors.danger,         'EXPIRED'),
      _            => (ZapColors.textSecondary,  status.toUpperCase()),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: ZapTypography.labelSmall.copyWith(color: color)),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color    color;
  final String   text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: ZapTypography.labelSmall.copyWith(color: color)),
      ]);
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26, height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onTap != null
                ? ZapColors.bgElevated
                : ZapColors.bgElevated.withOpacity(0.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13,
              color: onTap != null
                  ? ZapColors.textSecondary
                  : ZapColors.textSecondary.withOpacity(0.4)),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall.copyWith(
          color: ZapColors.textSecondary,
          letterSpacing: 1.1,
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: ZapTypography.labelSmall
            .copyWith(color: ZapColors.textSecondary),
      );
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, this.hint = ''});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style:      ZapTypography.bodySmall,
        decoration: InputDecoration(
          filled:    true,
          fillColor: ZapColors.bgElevated,
          hintText:  hint,
          hintStyle: ZapTypography.bodySmall
              .copyWith(color: ZapColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.danger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.danger.withOpacity(0.4)),
        ),
        child: Text(message,
            style:
                ZapTypography.bodySmall.copyWith(color: ZapColors.danger)),
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ZapSpacing.sm),
        decoration: BoxDecoration(
          color: ZapColors.safe.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: ZapColors.safe),
          const SizedBox(width: ZapSpacing.xs),
          Expanded(
            child: Text(message,
                style:
                    ZapTypography.bodySmall.copyWith(color: ZapColors.safe)),
          ),
        ]),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(ZapSpacing.lg),
          child: CircularProgressIndicator(
              color: ZapColors.safe, strokeWidth: 2),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
          child: Text(message,
              textAlign: TextAlign.center,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
        ),
      );
}
