import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/platform_channel_providers.dart';
import '../../native/platform_channels.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 24 — LP4 watchdog UI.
///
/// Surfaces the periodic WorkManager watchdog plus the engine's heartbeat,
/// so the user (and the developer) can confirm the LP4 contract is alive:
/// if 30 seconds pass without a ping, the worker restarts the engine.
class Day24Lp4WatchdogScreen extends ConsumerStatefulWidget {
  const Day24Lp4WatchdogScreen({super.key});

  @override
  ConsumerState<Day24Lp4WatchdogScreen> createState() =>
      _Day24Lp4WatchdogScreenState();
}

class _Day24Lp4WatchdogScreenState
    extends ConsumerState<Day24Lp4WatchdogScreen> {
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    // Re-read the heartbeat every 2s so the "seconds since" counter
    // visibly counts up. Cheap — it's just a SharedPreferences read.
    _autoRefresh = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) ref.invalidate(watchdogStatusProvider);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(watchdogChannelProvider);
    final statusAsync = ref.watch(watchdogStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 24 · LP4 Watchdog'),
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
              _HeroBanner(supported: channel.supported),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('HEARTBEAT'),
              const SizedBox(height: ZapSpacing.md),
              statusAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (s) => _HeartbeatCard(status: s),
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('WORKMANAGER · 15-MINUTE PERIODIC'),
              const SizedBox(height: ZapSpacing.md),
              _WorkManagerCard(
                supported: channel.supported,
                onEnqueue: () async {
                  final ok = await channel.enqueue();
                  ref.invalidate(watchdogStatusProvider);
                  if (!context.mounted) return;
                  if (ok) {
                    ZapSnackbar.success(
                        context, 'Watchdog enqueued · 15-min KEEP policy');
                  } else {
                    ZapSnackbar.warning(context, 'Enqueue failed or unsupported here');
                  }
                },
                onCancel: () async {
                  final ok = await channel.cancel();
                  if (!context.mounted) return;
                  if (ok) {
                    ZapSnackbar.info(context, 'Watchdog cancelled');
                  } else {
                    ZapSnackbar.warning(context, 'Cancel failed');
                  }
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('LP4 CONTRACT'),
              const SizedBox(height: ZapSpacing.md),
              _ContractCard(),

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
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool supported;
  const _HeroBanner({required this.supported});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.danger.withOpacity(0.10),
            ZapColors.warning.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.danger.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: ZapColors.danger, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 5 · DAY 24',
                  intent: ZapBadgeIntent.danger),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'LP4 Watchdog',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'ZapSafeService writes a heartbeat every 10s. A 15-minute '
            'WorkManager job re-checks it and restarts the service if the '
            'engine has been silent longer than 30s. Defense-in-depth on top '
            'of START_STICKY + BootReceiver (Day 21–22).',
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

// ─── Heartbeat card ──────────────────────────────────────────────────────────

class _HeartbeatCard extends StatelessWidget {
  final WatchdogStatus status;
  const _HeartbeatCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final stale = status.isStale;
    final color = stale ? ZapColors.danger : ZapColors.safe;

    final lastStr = status.lastHeartbeatMs == null
        ? 'never written'
        : DateTime.fromMillisecondsSinceEpoch(status.lastHeartbeatMs!)
            .toIso8601String();
    final sinceStr = status.secondsSinceLastPing == null
        ? '—'
        : '${status.secondsSinceLastPing}s ago';
    final thrStr = '${status.thresholdMs}ms (= ${status.thresholdMs ~/ 1000}s)';

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stale
                    ? Icons.warning_amber_rounded
                    : Icons.favorite_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                stale ? 'STALE · watchdog will restart' : 'ALIVE',
                style: ZapTypography.headlineSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('Last heartbeat', lastStr),
          _kv('Time since last ping', sinceStr),
          _kv('LP4 threshold', thrStr),
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
              width: 150,
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

// ─── WorkManager card ────────────────────────────────────────────────────────

class _WorkManagerCard extends StatelessWidget {
  final bool supported;
  final VoidCallback onEnqueue;
  final VoidCallback onCancel;
  const _WorkManagerCard({
    required this.supported,
    required this.onEnqueue,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supported
                ? 'Use the buttons below to enqueue or cancel the periodic '
                    'work. KEEP policy is in effect — re-enqueueing is a no-op.'
                : 'WorkManager is Android-only. On other platforms the '
                    'buttons stay disabled; iOS uses BGProcessingTask (Day 22) '
                    'for the equivalent watchdog.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.elevated(
                  label: 'ENQUEUE',
                  icon: Icons.event_repeat_rounded,
                  intent: ZapButtonIntent.safe,
                  onPressed: supported ? onEnqueue : null,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: ZapButton.outlined(
                  label: 'CANCEL',
                  icon: Icons.cancel_rounded,
                  intent: ZapButtonIntent.warning,
                  onPressed: supported ? onCancel : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Contract explainer ──────────────────────────────────────────────────────

class _ContractCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, Color)>[
      (
        'Heartbeat period',
        'Service writes "last_heartbeat_ms" every 10 s',
        ZapColors.info,
      ),
      (
        'LP4 threshold',
        '30 s — if exceeded, watchdog acts',
        ZapColors.warning,
      ),
      (
        'Recovery latency',
        'Android target ≤ 30 s · iOS target ≤ 45 s',
        ZapColors.safe,
      ),
      (
        'Defense stack',
        'START_STICKY → BootReceiver → WorkManager',
        ZapColors.danger,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Column(
        children: rows.map((r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: r.$3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                SizedBox(
                  width: 130,
                  child: Text(
                    r.$1,
                    style: ZapTypography.labelSmall.copyWith(
                      color: r.$3,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: ZapTypography.bodySmall.copyWith(
                      color: ZapColors.textPrimary,
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
          Text('Reading heartbeat…'),
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
