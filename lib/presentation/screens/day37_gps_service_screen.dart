import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/app_state.dart';
import '../../data/models/gps_sample.dart';
import '../../data/services/gps_polling_profile.dart';
import '../../domain/providers/gps_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 37 — GPS service live surface.
class Day37GpsServiceScreen extends ConsumerStatefulWidget {
  const Day37GpsServiceScreen({super.key});

  @override
  ConsumerState<Day37GpsServiceScreen> createState() =>
      _Day37GpsServiceScreenState();
}

class _Day37GpsServiceScreenState
    extends ConsumerState<Day37GpsServiceScreen> {
  Timer? _uiTicker;
  GpsSample? _latest;
  ProviderSubscription<AsyncValue<GpsSample>>? _sampleSub;

  @override
  void initState() {
    super.initState();
    // 1 Hz UI refresh — for the "age" counter on the latest-fix card.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _sampleSub = ref.listenManual<AsyncValue<GpsSample>>(
      gpsSamplesStreamProvider,
      (_, next) {
        next.whenData((s) {
          if (!mounted) return;
          setState(() => _latest = s);
        });
      },
    );
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _sampleSub?.close();
    super.dispose();
  }

  Future<void> _start() async {
    await ref.read(gpsServiceProvider).start();
    if (mounted) ZapSnackbar.success(context, 'GPS polling started');
  }

  void _stop() {
    ref.read(gpsServiceProvider).stop();
    if (mounted) ZapSnackbar.info(context, 'GPS polling stopped');
  }

  Future<void> _pollOnce() async {
    final svc = ref.read(gpsServiceProvider);
    final s = await svc.pollOnce();
    if (!mounted) return;
    if (s != null) {
      ZapSnackbar.success(context,
          'Fix: ${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}');
    } else {
      ZapSnackbar.warning(context,
          'Poll failed — permission denied / no GPS / host VM');
    }
  }

  Future<void> _flush() async {
    final ok = await ref.read(gpsServiceProvider).flushBatch();
    if (!mounted) return;
    if (ok) {
      ZapSnackbar.success(context, 'Batch uploaded');
    } else {
      ZapSnackbar.warning(context,
          'Upload failed — route lands in backend Week 4+, expected');
    }
  }

  void _inject() {
    final svc = ref.read(gpsServiceProvider);
    svc.injectSample(GpsSample(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      lat: 12.9716,
      lng: 77.5946,
      accuracyM: 8,
      speedMps: 1.4,
      headingDeg: 90,
    ));
    if (mounted) ZapSnackbar.info(context, 'Synthetic Bangalore fix injected');
  }

  void _setMode(AppState s) {
    ref.read(gpsAppStateProvider.notifier).state = s;
    ref.read(gpsServiceProvider).setAppState(s);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(gpsServiceProvider);
    final appState = ref.watch(gpsAppStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 37 · GPS Service'),
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

              const _SectionLabel('LATEST FIX'),
              const SizedBox(height: ZapSpacing.md),
              _LatestFixCard(sample: _latest),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('CADENCE · BASED ON APP STATE'),
              const SizedBox(height: ZapSpacing.md),
              _CadenceCard(
                appState: appState,
                profile: svc.profile,
                running: svc.isRunning,
                fixesAttempted: svc.fixesAttempted,
                fixesSucceeded: svc.fixesSucceeded,
                fixesFailed: svc.fixesFailed,
                pendingBatch: svc.pendingBatchSize,
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('MODE SELECTOR'),
              const SizedBox(height: ZapSpacing.md),
              _ModeButtons(active: appState, onPick: _setMode),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('CONTROLS'),
              const SizedBox(height: ZapSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ZapButton.elevated(
                      label: 'START',
                      icon: Icons.play_arrow_rounded,
                      intent: ZapButtonIntent.safe,
                      onPressed: svc.isRunning ? null : _start,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: ZapButton.outlined(
                      label: 'STOP',
                      icon: Icons.stop_rounded,
                      intent: ZapButtonIntent.warning,
                      onPressed: svc.isRunning ? _stop : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'POLL ONCE',
                icon: Icons.my_location_rounded,
                fullWidth: true,
                onPressed: _pollOnce,
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'INJECT SYNTHETIC FIX',
                icon: Icons.bolt_rounded,
                intent: ZapButtonIntent.info,
                fullWidth: true,
                onPressed: _inject,
              ),
              const SizedBox(height: ZapSpacing.sm),
              ZapButton.outlined(
                label: 'FLUSH BATCH · POST /api/v1/gps/batch/',
                icon: Icons.cloud_upload_rounded,
                fullWidth: true,
                onPressed: _flush,
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
            ZapColors.info.withOpacity(0.12),
            ZapColors.safe.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(
                  label: 'MONTH 2 · WEEK 8 · DAY 37',
                  intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'GPS · Adaptive Polling',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'MONITORING 5 min low-accuracy · ELEVATED 30 s high · SOS-TIME 10 s '
            'best. Last fix persists across app kills via SharedPreferences. '
            'Batch uploads to POST /api/v1/gps/batch/ when 6+ samples queued.',
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

// ─── Latest fix card ─────────────────────────────────────────────────────────

class _LatestFixCard extends StatelessWidget {
  final GpsSample? sample;
  const _LatestFixCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    if (sample == null) {
      return _EmptyCard(
        message: 'No fix yet · press START or POLL ONCE.',
      );
    }
    final s = sample!;
    final age = s.ageMs() ~/ 1000;
    final qualityColor = s.isHighQuality ? ZapColors.safe : ZapColors.warning;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.lat.toStringAsFixed(5)}, ${s.lng.toStringAsFixed(5)}',
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.isHighQuality ? 'HIGH QUALITY' : 'LOW QUALITY',
                  style: ZapTypography.labelSmall.copyWith(
                    color: qualityColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('accuracy', '±${s.accuracyM.toStringAsFixed(1)} m'),
          _kv('altitude',
              s.altitudeM == null ? '—' : '${s.altitudeM!.toStringAsFixed(1)} m'),
          _kv('speed',
              s.speedMps == null ? '—' : '${s.speedMps!.toStringAsFixed(2)} m/s'),
          _kv('heading',
              s.headingDeg == null ? '—' : '${s.headingDeg!.toStringAsFixed(0)}°'),
          _kv('age', '${age}s'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(v,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                )),
          ],
        ),
      );
}

// ─── Cadence card ───────────────────────────────────────────────────────────

class _CadenceCard extends StatelessWidget {
  final AppState appState;
  final GpsPollingProfile profile;
  final bool running;
  final int fixesAttempted;
  final int fixesSucceeded;
  final int fixesFailed;
  final int pendingBatch;
  const _CadenceCard({
    required this.appState,
    required this.profile,
    required this.running,
    required this.fixesAttempted,
    required this.fixesSucceeded,
    required this.fixesFailed,
    required this.pendingBatch,
  });

  @override
  Widget build(BuildContext context) {
    final color = running ? ZapColors.safe : ZapColors.textSecondary;
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(running ? Icons.timer_rounded : Icons.timer_off_rounded,
                  color: color, size: 22),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                running ? 'POLLING' : 'IDLE',
                style: ZapTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  profile.label,
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.info,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          _kv('App state', appState.label),
          _kv('Profile', profile.label),
          _kv('Interval', _formatInterval(profile.interval)),
          _kv('Accuracy hint', profile.accuracy.name),
          const SizedBox(height: ZapSpacing.sm),
          _kv('Fixes attempted', fixesAttempted.toString()),
          _kv('Fixes succeeded', fixesSucceeded.toString()),
          _kv('Fixes failed', fixesFailed.toString()),
          _kv('Pending batch', '$pendingBatch / 6 → auto-flush'),
        ],
      ),
    );
  }

  String _formatInterval(Duration d) {
    if (d == Duration.zero) return 'off';
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} s';
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(v,
                style: ZapTypography.monoSmall.copyWith(
                  color: ZapColors.textPrimary,
                )),
          ],
        ),
      );
}

// ─── Mode buttons ───────────────────────────────────────────────────────────

class _ModeButtons extends StatelessWidget {
  final AppState active;
  final void Function(AppState) onPick;
  const _ModeButtons({required this.active, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final modes = const [
      (AppState.idle,         '5 min off',     ZapButtonIntent.neutral),
      (AppState.monitoring,   'MONITORING',    ZapButtonIntent.safe),
      (AppState.elevated,     'ELEVATED',      ZapButtonIntent.warning),
      (AppState.sosActive,    'SOS_ACTIVE',    ZapButtonIntent.danger),
    ];
    return Column(
      children: [
        for (final m in modes)
          Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.xs),
            child: ZapButton.outlined(
              label: m.$1 == active
                  ? '✓  ${m.$1.label}'
                  : 'SWITCH TO ${m.$1.label}',
              intent: m.$3,
              fullWidth: true,
              onPressed: m.$1 == active ? null : () => onPick(m.$1),
            ),
          ),
      ],
    );
  }
}

// ─── Empty + Section ────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border),
      ),
      child: Text(
        message,
        style: ZapTypography.bodySmall.copyWith(
          color: ZapColors.textSecondary,
        ),
      ),
    );
  }
}

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
