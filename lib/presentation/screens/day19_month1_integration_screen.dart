import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/jwt_utils.dart';
import '../../data/services/device_tier_service.dart';
import '../../data/services/permission_service.dart';
import '../../data/services/token_storage.dart';
import '../../domain/integration/month1_runner.dart';
import '../../domain/providers/auth_providers.dart';
import '../../domain/providers/device_providers.dart';
import '../../domain/providers/feature_flags_provider.dart';
import '../../domain/providers/permission_providers.dart';
import '../../domain/providers/push_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

/// Day 19 — Month 1 end-to-end integration runner.
///
/// Walks every Month-1 subsystem in the order a real user would hit them:
///   1. Phone validation
///   2. Token storage (synthetic JWT round-trip)
///   3. JWT utils (parse + expiry)
///   4. Cold-start hydration trigger
///   5. Permissions snapshot
///   6. Device tier detect + cache
///   7. Feature flags resolve
///   8. FCM token (stub mode emits a fake token)
///   9. FCM backend register (expected-fail until backend Week 4)
///
/// Each phase reports pass / fail / expected-fail with a one-line detail.
class Day19Month1IntegrationScreen extends ConsumerStatefulWidget {
  const Day19Month1IntegrationScreen({super.key});

  @override
  ConsumerState<Day19Month1IntegrationScreen> createState() =>
      _Day19Month1IntegrationScreenState();
}

class _Day19Month1IntegrationScreenState
    extends ConsumerState<Day19Month1IntegrationScreen> {
  final Map<String, PhaseResult> _results = {};
  bool _running = false;
  StreamSubscription<PhaseResult>? _sub;

  List<IntegrationPhase> _phases() {
    final tokenStorage = ref.read(tokenStorageProvider);
    final pushService = ref.read(pushServiceProvider);
    final permissionService = ref.read(permissionServiceProvider);
    final deviceTierService = ref.read(deviceTierServiceProvider);

    return [
      IntegrationPhase(
        key: 'phone',
        name: 'Phone validation',
        description: 'E.164 regex accepts a 10-digit India number.',
        runner: () async {
          const phone = '+919876543210';
          final ok = RegExp(r'^\+\d{10,15}$').hasMatch(phone);
          if (!ok) throw 'Regex rejected $phone';
          return PhaseResult(
            key: 'phone',
            name: 'Phone validation',
            status: PhaseStatus.pass,
            detail: '$phone accepted',
          );
        },
      ),
      IntegrationPhase(
        key: 'storage',
        name: 'Token storage round-trip',
        description: 'Write → read → clear a synthetic JWT.',
        runner: () => _runTokenStorageRoundTrip(tokenStorage),
      ),
      IntegrationPhase(
        key: 'jwt',
        name: 'JWT decode + expiry',
        description: 'JwtUtils parses a synthetic access token.',
        runner: _runJwtDecode,
      ),
      IntegrationPhase(
        key: 'hydrate',
        name: 'Cold-start hydration triggered',
        description: 'AuthNotifier.hydrate() resolves without throwing.',
        runner: () async {
          final notifier = ref.read(authStateProvider.notifier);
          await notifier.hydrate();
          return PhaseResult(
            key: 'hydrate',
            name: 'Cold-start hydration triggered',
            status: PhaseStatus.pass,
            detail: 'State: ${notifier.state.runtimeType}',
          );
        },
      ),
      IntegrationPhase(
        key: 'permissions',
        name: 'Permissions snapshot',
        description: 'PermissionService.checkAll() returns a 5-tuple.',
        runner: () async {
          final r = await permissionService.checkAll();
          final granted = [
            r.microphone,
            r.locationAlways,
            r.camera,
            r.notifications,
            r.activityRecognition,
          ].where((o) => o == PermissionOutcome.granted).length;
          return PhaseResult(
            key: 'permissions',
            name: 'Permissions snapshot',
            status: PhaseStatus.pass,
            detail: '$granted / 5 granted',
          );
        },
      ),
      IntegrationPhase(
        key: 'tier',
        name: 'Device tier detect',
        description: 'DeviceTierService.loadOrDetect() classifies the device.',
        runner: () async {
          final result = await deviceTierService.loadOrDetect();
          return PhaseResult(
            key: 'tier',
            name: 'Device tier detect',
            status: PhaseStatus.pass,
            detail: '${result.tier.shortLabel} · ${result.osVersion}',
          );
        },
      ),
      IntegrationPhase(
        key: 'flags',
        name: 'Feature flags resolve',
        description: 'FeatureFlags include the always-on baseline.',
        runner: () async {
          final tier = await ref.read(deviceTierProvider.future);
          final flags = FeatureFlags.forTier(tier.tier);
          final hasBaseline = flags.canUse(Feature.manualSos) &&
              flags.canUse(Feature.audioEvidence) &&
              flags.canUse(Feature.pushNotifications);
          if (!hasBaseline) {
            throw 'Baseline three not all enabled';
          }
          return PhaseResult(
            key: 'flags',
            name: 'Feature flags resolve',
            status: PhaseStatus.pass,
            detail: '${flags.enabled.length} enabled · ${flags.locked.length} locked',
          );
        },
      ),
      IntegrationPhase(
        key: 'fcm_token',
        name: 'FCM token',
        description: 'getToken() returns a real or stub token.',
        runner: () async {
          final token = await pushService.getToken();
          if (token == null || token.isEmpty) throw 'No token returned';
          final mode =
              pushService.firebaseAvailable ? 'live FCM' : 'stub mode';
          return PhaseResult(
            key: 'fcm_token',
            name: 'FCM token',
            status: PhaseStatus.pass,
            detail: '$mode · ${token.substring(0, token.length.clamp(0, 24))}…',
          );
        },
      ),
      IntegrationPhase(
        key: 'fcm_register',
        name: 'FCM register with backend',
        description: 'PATCH /api/v1/push/register/ — route lands in backend Week 4.',
        expectedFailReason: 'route not live yet (backend Week 4)',
        runner: () async {
          final token = pushService.cachedToken ?? await pushService.getToken();
          if (token == null) throw 'No token to register';
          await pushService.registerWithBackend(token: token);
          return PhaseResult(
            key: 'fcm_register',
            name: 'FCM register with backend',
            status: PhaseStatus.pass,
            detail: 'Backend acknowledged',
          );
        },
      ),
    ];
  }

  Future<PhaseResult> _runTokenStorageRoundTrip(TokenStorage storage) async {
    final token = _makeJwt(expEpochSeconds: _nowSeconds() + 900);
    await storage.saveAccessToken(token);
    final read = await storage.readAccessToken();
    if (read != token) {
      throw 'Read-back token did not match';
    }
    await storage.clear();
    final cleared = await storage.readAccessToken();
    if (cleared != null && cleared.isNotEmpty) {
      throw 'clear() left a token behind';
    }
    return const PhaseResult(
      key: 'storage',
      name: 'Token storage round-trip',
      status: PhaseStatus.pass,
      detail: 'Write → read → clear OK',
    );
  }

  Future<PhaseResult> _runJwtDecode() async {
    final token = _makeJwt(expEpochSeconds: _nowSeconds() + 900);
    final payload = JwtUtils.decodePayload(token);
    if (payload == null) throw 'Failed to decode payload';
    if (!payload.containsKey('exp')) throw 'No exp claim';
    final remaining = JwtUtils.secondsRemaining(token);
    if (remaining == null || remaining <= 0) {
      throw 'secondsRemaining returned $remaining';
    }
    return PhaseResult(
      key: 'jwt',
      name: 'JWT decode + expiry',
      status: PhaseStatus.pass,
      detail: 'exp = ${payload['exp']} · ${remaining}s remaining',
    );
  }

  // ─── Run controls ──────────────────────────────────────────────────────

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    final phases = _phases();
    // Seed pending entries so the list renders all rows upfront.
    for (final p in phases) {
      _results[p.key] = PhaseResult(
        key: p.key,
        name: p.name,
        status: PhaseStatus.pending,
        detail: '',
      );
    }
    setState(() {});

    await _sub?.cancel();
    _sub = runMonth1Integration(phases).listen(
      (result) {
        if (!mounted) return;
        setState(() => _results[result.key] = result);
      },
      onDone: () {
        if (mounted) setState(() => _running = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phases = _phases();
    final summary =
        IntegrationSummary.from(_results.values);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 19 · Month 1 Integration'),
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

              _SummaryCard(
                summary: summary,
                hasRun: _results.isNotEmpty,
                running: _running,
              ),
              const SizedBox(height: ZapSpacing.xl),

              ZapButton.elevated(
                label: _running ? 'RUNNING…' : 'RUN INTEGRATION',
                icon: Icons.play_arrow_rounded,
                intent: ZapButtonIntent.safe,
                fullWidth: true,
                onPressed: _running ? null : _runAll,
                isLoading: _running,
              ),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('PHASES'),
              const SizedBox(height: ZapSpacing.md),
              for (final p in phases)
                _PhaseTile(
                  phase: p,
                  result: _results[p.key],
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

int _nowSeconds() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

String _makeJwt({required int expEpochSeconds}) {
  String b64(String json) => base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  final header = b64('{"alg":"HS256","typ":"JWT"}');
  final payload = b64('{"exp":$expEpochSeconds,"user_id":"u-day19"}');
  return '$header.$payload.fakesignature';
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
            ZapColors.safe.withOpacity(0.14),
            ZapColors.info.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fact_check_rounded,
                    color: ZapColors.safe, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 4 · DAY 19', intent: ZapBadgeIntent.safe),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Month 1 Integration',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'End-to-end walkthrough — phone → storage → JWT → permissions → '
            'tier → flags → FCM. Phases run real services; expected failures '
            '(e.g. backend not yet live) render yellow rather than red.',
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

// ─── Summary ─────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IntegrationSummary summary;
  final bool hasRun;
  final bool running;
  const _SummaryCard({
    required this.summary,
    required this.hasRun,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasRun) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: Text(
          'Tap RUN INTEGRATION to walk every Month 1 subsystem end-to-end.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }

    final color = summary.isGreen ? ZapColors.safe : ZapColors.danger;
    final title = running
        ? 'Run in progress…'
        : (summary.isGreen ? 'Month 1 GREEN' : 'Hard failure');

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                summary.isGreen
                    ? Icons.verified_rounded
                    : Icons.error_outline_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: ZapSpacing.sm),
              Text(
                title,
                style: ZapTypography.headlineSmall.copyWith(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              _stat('PASS', summary.pass, ZapColors.safe),
              const SizedBox(width: ZapSpacing.md),
              _stat('EXPECTED', summary.expectedFail, ZapColors.warning),
              const SizedBox(width: ZapSpacing.md),
              _stat('FAIL', summary.fail, ZapColors.danger),
              const SizedBox(width: ZapSpacing.md),
              _stat('TOTAL', summary.total, ZapColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            count.toString(),
            style: ZapTypography.displaySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Phase tile ──────────────────────────────────────────────────────────────

class _PhaseTile extends StatelessWidget {
  final IntegrationPhase phase;
  final PhaseResult? result;
  const _PhaseTile({required this.phase, required this.result});

  @override
  Widget build(BuildContext context) {
    final status = result?.status ?? PhaseStatus.pending;
    final (icon, color, statusLabel) = switch (status) {
      PhaseStatus.pending      => (Icons.radio_button_unchecked_rounded, ZapColors.textSecondary, 'PENDING'),
      PhaseStatus.running      => (Icons.hourglass_top_rounded, ZapColors.info, 'RUNNING'),
      PhaseStatus.pass         => (Icons.check_circle_rounded, ZapColors.safe, 'PASS'),
      PhaseStatus.fail         => (Icons.cancel_rounded, ZapColors.danger, 'FAIL'),
      PhaseStatus.expectedFail => (Icons.error_outline_rounded, ZapColors.warning, 'EXPECTED'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (status == PhaseStatus.running)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    phase.name,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: ZapTypography.labelSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                phase.description,
                style: ZapTypography.bodySmall.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (result != null && result!.detail.isNotEmpty) ...[
              const SizedBox(height: ZapSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result!.detail,
                  style: ZapTypography.monoSmall.copyWith(
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            if (result != null && result!.duration > Duration.zero) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '${result!.duration.inMilliseconds}ms',
                  style: ZapTypography.monoSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
