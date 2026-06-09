import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../data/services/permission_service.dart';
import '../../../domain/providers/permission_providers.dart';
import '../../widgets/zap_badge.dart';
import '../../widgets/zap_button.dart';
import '../../widgets/zap_card.dart';
import '../../widgets/zap_snackbar.dart';

/// Day 12 — Onboarding · Permissions
///
/// Walks the user through the five safety-critical permissions ONE AT A TIME
/// (NOT batched), with plain-language explanations and an expandable
/// "Why we need this" detail per row. Each row has its own "Allow" or
/// "Skip" affordance. Compared to the Day 11 debug screen, this one is the
/// real user-facing surface that the onboarding flow drives through.
class OnboardingPermissionsScreen extends ConsumerStatefulWidget {
  const OnboardingPermissionsScreen({super.key});

  @override
  ConsumerState<OnboardingPermissionsScreen> createState() =>
      _OnboardingPermissionsScreenState();
}

class _OnboardingPermissionsScreenState
    extends ConsumerState<OnboardingPermissionsScreen> {
  PermissionService get _svc => ref.read(permissionServiceProvider);

  final _outcomes = <_PermId, PermissionOutcome>{};
  final _expanded = <_PermId, bool>{};
  bool _busy = false;
  _PermId? _busyId;

  @override
  void initState() {
    super.initState();
    for (final p in _permissions) {
      _outcomes[p.id] = PermissionOutcome.denied;
      _expanded[p.id] = false;
    }
    _hydrate();
  }

  Future<void> _hydrate() async {
    final res = await _svc.checkAll();
    if (!mounted) return;
    setState(() {
      _outcomes[_PermId.microphone] = res.microphone;
      _outcomes[_PermId.locationAlways] = res.locationAlways;
      _outcomes[_PermId.camera] = res.camera;
      _outcomes[_PermId.notifications] = res.notifications;
      _outcomes[_PermId.activity] = res.activityRecognition;
    });
  }

  Future<void> _request(_PermMeta meta) async {
    setState(() {
      _busy = true;
      _busyId = meta.id;
    });
    try {
      final result = await meta.request(_svc);
      if (!mounted) return;
      setState(() => _outcomes[meta.id] = result);

      if (result == PermissionOutcome.granted) {
        ZapSnackbar.success(context, '${meta.name} access granted');
      } else if (result == PermissionOutcome.deniedForever) {
        ZapSnackbar.warning(
          context,
          '${meta.name} blocked — open device Settings to enable',
          action: 'SETTINGS',
          onAction: () => _svc.openSettings(),
        );
      } else {
        ZapSnackbar.info(context, '${meta.name} skipped — ${meta.impact}');
      }
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _busyId = null;
      });
    }
  }

  int get _grantedCount =>
      _outcomes.values.where((v) => v == PermissionOutcome.granted).length;

  bool get _canContinue => _grantedCount >= _permissions.length;

  @override
  Widget build(BuildContext context) {
    final progress = _grantedCount / _permissions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up safety'),
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
              _ProgressHero(
                grantedCount: _grantedCount,
                total: _permissions.length,
                progress: progress,
              ),
              const SizedBox(height: ZapSpacing.xl),

              for (final meta in _permissions)
                _PermRow(
                  meta: meta,
                  outcome: _outcomes[meta.id] ?? PermissionOutcome.denied,
                  expanded: _expanded[meta.id] ?? false,
                  busy: _busy && _busyId == meta.id,
                  onToggleExpand: () => setState(
                      () => _expanded[meta.id] = !(_expanded[meta.id] ?? false)),
                  onAllow: _busy ? null : () => _request(meta),
                  onOpenSettings: () => _svc.openSettings(),
                ),

              const SizedBox(height: ZapSpacing.xl),

              ZapButton.elevated(
                label: _canContinue
                    ? 'CONTINUE'
                    : 'CONTINUE ($_grantedCount / ${_permissions.length})',
                icon: Icons.arrow_forward_rounded,
                intent: _canContinue
                    ? ZapButtonIntent.safe
                    : ZapButtonIntent.neutral,
                fullWidth: true,
                onPressed: _canContinue
                    ? () {
                        ZapSnackbar.success(
                            context, 'All permissions granted — onboarding ready');
                        context.go('/');
                      }
                    : null,
              ),
              const SizedBox(height: ZapSpacing.md),
              ZapButton.text(
                label: 'Skip for now',
                onPressed: () => context.go('/'),
                fullWidth: true,
              ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Permission catalogue ─────────────────────────────────────────────────────

enum _PermId { microphone, locationAlways, camera, notifications, activity }

class _PermMeta {
  final _PermId id;
  final IconData icon;
  final String name;
  final String oneLiner;
  final String why;
  final String impact;
  final Color accent;
  final Future<PermissionOutcome> Function(PermissionService) request;

  const _PermMeta({
    required this.id,
    required this.icon,
    required this.name,
    required this.oneLiner,
    required this.why,
    required this.impact,
    required this.accent,
    required this.request,
  });
}

const _permissions = <_PermMeta>[
  _PermMeta(
    id: _PermId.microphone,
    icon: Icons.mic_rounded,
    name: 'Microphone',
    oneLiner: 'Capture audio evidence and listen for the voice SOS keyword.',
    why:
        'Audio is the most reliable evidence stream — captured continuously '
        'during an active SOS. The microphone is also how ZapSafe detects your '
        'pre-set voice trigger word when the phone is in your pocket.',
    impact: 'Voice trigger and audio evidence will be unavailable.',
    accent: ZapColors.danger,
    request: _requestMicrophone,
  ),
  _PermMeta(
    id: _PermId.locationAlways,
    icon: Icons.my_location_rounded,
    name: 'Location (Always)',
    oneLiner: 'Share your live location with contacts while an SOS is active.',
    why:
        'During an SOS, your Tier 1 contacts receive a link that shows your '
        'real-time location. "Always" is required because location must keep '
        'updating even if the app is in the background or the screen is off.',
    impact: 'Real-time location sharing with contacts will be disabled.',
    accent: ZapColors.warning,
    request: _requestLocation,
  ),
  _PermMeta(
    id: _PermId.camera,
    icon: Icons.camera_alt_rounded,
    name: 'Camera',
    oneLiner: 'Record video evidence and detect the blink-code trigger.',
    why:
        'Video evidence is captured silently during an SOS. The camera is also '
        'used by the blink-code trigger — a passive eye-blink pattern that can '
        'fire an SOS without touching the phone.',
    impact: 'Video evidence and blink-code trigger will be disabled.',
    accent: ZapColors.info,
    request: _requestCamera,
  ),
  _PermMeta(
    id: _PermId.notifications,
    icon: Icons.notifications_rounded,
    name: 'Notifications',
    oneLiner: 'Receive SOS updates, contact responses, and critical alerts.',
    why:
        'Push notifications are how you learn that a contact has acknowledged '
        'your SOS, when a drill is scheduled, and when the app needs your '
        'attention (e.g. low battery during an active SOS).',
    impact: 'You may miss critical updates during an active SOS.',
    accent: ZapColors.safe,
    request: _requestNotifications,
  ),
  _PermMeta(
    id: _PermId.activity,
    icon: Icons.directions_run_rounded,
    name: 'Physical Activity',
    oneLiner: 'Use IMU sensors to detect impacts and motion-based triggers.',
    why:
        'The accelerometer and gyroscope detect falls, sudden impacts, and '
        'shake-to-trigger patterns. Without this permission, ZapSafe can only '
        'fire an SOS when you press the button.',
    impact: 'Impact detection and shake-triggers will be unavailable.',
    accent: ZapColors.info,
    request: _requestActivity,
  ),
];

// Individual single-permission requesters. We can't call PermissionService's
// requestAll() one-at-a-time, so we expose them via a thin wrapper. These
// re-use the service's outcome mapping by routing through checkAll() after
// the request lands.
Future<PermissionOutcome> _requestMicrophone(PermissionService s) =>
    _requestAndRead(s, (r) => r.microphone, _PermId.microphone);
Future<PermissionOutcome> _requestLocation(PermissionService s) =>
    _requestAndRead(s, (r) => r.locationAlways, _PermId.locationAlways);
Future<PermissionOutcome> _requestCamera(PermissionService s) =>
    _requestAndRead(s, (r) => r.camera, _PermId.camera);
Future<PermissionOutcome> _requestNotifications(PermissionService s) =>
    _requestAndRead(s, (r) => r.notifications, _PermId.notifications);
Future<PermissionOutcome> _requestActivity(PermissionService s) =>
    _requestAndRead(s, (r) => r.activityRecognition, _PermId.activity);

Future<PermissionOutcome> _requestAndRead(
  PermissionService s,
  PermissionOutcome Function(PermissionsResult) read,
  _PermId id,
) async {
  // Use the permission_handler types directly so we only request one.
  // We import permission_handler here via the service's re-exported types.
  await s.requestOne(id);
  final r = await s.checkAll();
  return read(r);
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _ProgressHero extends StatelessWidget {
  final int grantedCount;
  final int total;
  final double progress;

  const _ProgressHero({
    required this.grantedCount,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = grantedCount >= total;
    final color = allDone ? ZapColors.safe : ZapColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allDone ? Icons.verified_user_rounded : Icons.security_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 3 · DAY 12', intent: ZapBadgeIntent.warning),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            allDone ? 'You\'re all set' : 'Set up your safety net',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            allDone
                ? 'All five permissions granted. ZapSafe is ready to protect you.'
                : 'ZapSafe needs five permissions to keep you safe. We\'ll ask one at a time — tap "Why we need this" before each to learn how it\'s used.',
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: ZapColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            '$grantedCount of $total granted',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final _PermMeta meta;
  final PermissionOutcome outcome;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggleExpand;
  final VoidCallback? onAllow;
  final VoidCallback onOpenSettings;

  const _PermRow({
    required this.meta,
    required this.outcome,
    required this.expanded,
    required this.busy,
    required this.onToggleExpand,
    required this.onAllow,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final granted = outcome == PermissionOutcome.granted;
    final blocked = outcome == PermissionOutcome.deniedForever;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ZapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: meta.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: Icon(meta.icon, color: meta.accent, size: 22),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meta.name,
                              style: ZapTypography.headlineSmall.copyWith(
                                color: ZapColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _StatusChip(outcome: outcome),
                        ],
                      ),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(
                        meta.oneLiner,
                        style: ZapTypography.bodySmall.copyWith(
                          color: ZapColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Expand toggle
            const SizedBox(height: ZapSpacing.sm),
            InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: meta.accent,
                      size: 18,
                    ),
                    const SizedBox(width: ZapSpacing.xs),
                    Text(
                      expanded ? 'Hide details' : 'Why we need this',
                      style: ZapTypography.labelMedium.copyWith(
                        color: meta.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (expanded) ...[
              const SizedBox(height: ZapSpacing.xs),
              Container(
                padding: const EdgeInsets.all(ZapSpacing.md),
                decoration: BoxDecoration(
                  color: meta.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(color: meta.accent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.why,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      'If denied: ${meta.impact}',
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.warning,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: ZapSpacing.md),
            if (!granted)
              Row(
                children: [
                  Expanded(
                    child: blocked
                        ? ZapButton.outlined(
                            label: 'OPEN SETTINGS',
                            icon: Icons.settings_rounded,
                            intent: ZapButtonIntent.warning,
                            onPressed: onOpenSettings,
                          )
                        : ZapButton.elevated(
                            label: 'ALLOW',
                            icon: Icons.check_rounded,
                            intent: ZapButtonIntent.safe,
                            onPressed: onAllow,
                            isLoading: busy,
                          ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: ZapColors.safe, size: 18),
                  const SizedBox(width: ZapSpacing.xs),
                  Text(
                    'Granted',
                    style: ZapTypography.labelMedium.copyWith(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PermissionOutcome outcome;
  const _StatusChip({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (outcome) {
      PermissionOutcome.granted        => ('GRANTED', ZapColors.safe),
      PermissionOutcome.denied         => ('NEEDED', ZapColors.warning),
      PermissionOutcome.deniedForever  => ('BLOCKED', ZapColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: ZapTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
