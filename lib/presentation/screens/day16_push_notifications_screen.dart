import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/zap_snackbar.dart';

/// Day 16 — FCM + Local Notifications wiring.
///
/// Live test surface for the push notification stack:
///   - Shows Firebase init mode (real / stub)
///   - Displays the FCM token (or deterministic stub)
///   - Re-runs permission requests
///   - Sends a simulated local notification per category to verify channels
///   - Stubs the backend registration call
class Day16PushNotificationsScreen extends ConsumerStatefulWidget {
  const Day16PushNotificationsScreen({super.key});

  @override
  ConsumerState<Day16PushNotificationsScreen> createState() =>
      _Day16PushNotificationsScreenState();
}

class _Day16PushNotificationsScreenState
    extends ConsumerState<Day16PushNotificationsScreen> {
  String? _registrationStatus;
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(pushServiceProvider);
    final tokenAsync = ref.watch(fcmTokenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 16 · Push Notifications'),
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
              _HeroBanner(firebaseAvailable: service.firebaseAvailable),
              const SizedBox(height: ZapSpacing.xl),

              if (!service.firebaseAvailable) _StubModeNotice(),
              if (!service.firebaseAvailable) const SizedBox(height: ZapSpacing.lg),

              // ─── FCM token card ────────────────────────────────────────
              const _SectionLabel('FCM TOKEN'),
              const SizedBox(height: ZapSpacing.md),
              _TokenCard(
                tokenAsync: tokenAsync,
                onCopy: (token) async {
                  await Clipboard.setData(ClipboardData(text: token));
                  if (mounted) ZapSnackbar.success(context, 'Token copied');
                },
                onRefresh: () => ref.invalidate(fcmTokenProvider),
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Backend registration ──────────────────────────────────
              const _SectionLabel('BACKEND REGISTRATION'),
              const SizedBox(height: ZapSpacing.md),
              _RegistrationCard(
                status: _registrationStatus,
                busy: _registering,
                onRegister: () => _register(service, tokenAsync.valueOrNull),
              ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Push categories ───────────────────────────────────────
              const _SectionLabel('PUSH CATEGORIES · TAP TO SIMULATE'),
              const SizedBox(height: ZapSpacing.md),
              for (final cat in PushCategory.values.where(
                  (c) => c != PushCategory.unknown))
                _CategoryTile(
                  category: cat,
                  onSimulate: () => _simulate(service, cat),
                ),

              const SizedBox(height: ZapSpacing.xl),

              // ─── Permission ────────────────────────────────────────────
              ZapButton.outlined(
                label: 'REQUEST NOTIFICATION PERMISSION',
                icon: Icons.notifications_active_rounded,
                fullWidth: true,
                onPressed: () => _requestPermission(service),
              ),
              const SizedBox(height: ZapSpacing.md),
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

  Future<void> _register(PushService service, String? token) async {
    if (token == null) {
      ZapSnackbar.warning(context, 'No token yet — wait for FCM to initialise');
      return;
    }
    setState(() {
      _registering = true;
      _registrationStatus = null;
    });
    try {
      final response =
          await service.registerWithBackend(token: token, deviceTier: 'tierA');
      if (!mounted) return;
      setState(() => _registrationStatus = 'Registered: $response');
      ZapSnackbar.success(context, 'Token registered with backend');
    } catch (e) {
      if (!mounted) return;
      setState(() => _registrationStatus = 'Failed: $e');
      // 404 is expected until backend Week 4 wires the route.
      ZapSnackbar.warning(
        context,
        'Backend registration failed — route may not be live yet (backend Week 4).',
      );
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _simulate(PushService service, PushCategory cat) async {
    final payload = PushPayload(
      messageId: 'sim_${cat.wireName}_${DateTime.now().millisecondsSinceEpoch}',
      category: cat,
      title: '[SIM] ${cat.label}',
      body: switch (cat) {
        PushCategory.sosAlert       => 'Riya triggered an SOS · tap to respond.',
        PushCategory.contactAck     => 'Amma acknowledged your SOS.',
        PushCategory.batteryWarning => 'Phone battery at 18% — Mode B evidence active.',
        PushCategory.checkInReminder => 'Wellness check-in due in 10 minutes.',
        PushCategory.unknown        => 'Generic push.',
      },
    );
    await service.showLocal(payload);
    if (mounted) {
      ZapSnackbar.info(
        context,
        'Simulated ${cat.label} · check your notification tray.',
      );
    }
  }

  Future<void> _requestPermission(PushService service) async {
    final outcome = await service.requestPermission();
    if (!mounted) return;
    final (msg, kind) = switch (outcome) {
      PushPermissionOutcome.granted       => ('Notification permission granted', 'success'),
      PushPermissionOutcome.provisional   => ('Provisional notifications enabled', 'info'),
      PushPermissionOutcome.denied        => ('Notification permission denied', 'warning'),
      PushPermissionOutcome.notDetermined => ('Permission prompt was dismissed', 'info'),
    };
    switch (kind) {
      case 'success': ZapSnackbar.success(context, msg); break;
      case 'warning': ZapSnackbar.warning(context, msg); break;
      default: ZapSnackbar.info(context, msg);
    }
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final bool firebaseAvailable;
  const _HeroBanner({required this.firebaseAvailable});

  @override
  Widget build(BuildContext context) {
    final color = firebaseAvailable ? ZapColors.safe : ZapColors.warning;
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
                  firebaseAvailable
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 4 · DAY 16', intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Push Notifications',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'FCM token + 4 categories (SOS · Ack · Battery · Check-in). '
            'Two Android channels (default + SOS bypass-DND). Graceful '
            'degradation to local-only when Firebase config is missing.',
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

// ─── Stub-mode notice ────────────────────────────────────────────────────────

class _StubModeNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: ZapColors.warning, size: 20),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STUB MODE',
                  style: ZapTypography.labelSmall.copyWith(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Firebase isn\'t configured yet. The service is running with a '
                  'deterministic stub token, and local notifications still work. '
                  'Drop `google-services.json` into `android/app/` to switch to live FCM.',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textPrimary,
                    height: 1.4,
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

// ─── Token card ──────────────────────────────────────────────────────────────

class _TokenCard extends StatelessWidget {
  final AsyncValue<String?> tokenAsync;
  final void Function(String) onCopy;
  final VoidCallback onRefresh;

  const _TokenCard({
    required this.tokenAsync,
    required this.onCopy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tokenAsync.when(
            loading: () => const Row(
              children: [
                SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: ZapSpacing.md),
                Text('Fetching token…'),
              ],
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
            ),
            data: (token) => SelectableText(
              token ?? '(no token available)',
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            children: [
              Expanded(
                child: ZapButton.outlined(
                  label: 'COPY',
                  icon: Icons.copy_rounded,
                  onPressed: tokenAsync.valueOrNull == null
                      ? null
                      : () => onCopy(tokenAsync.valueOrNull!),
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
      ),
    );
  }
}

// ─── Registration card ───────────────────────────────────────────────────────

class _RegistrationCard extends StatelessWidget {
  final String? status;
  final bool busy;
  final VoidCallback onRegister;

  const _RegistrationCard({
    required this.status,
    required this.busy,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PATCH /api/v1/push/register/',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Sends the FCM token + platform + device tier to the backend. '
            'Route lands in backend Week 4 — until then this is expected to 404.',
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: ZapSpacing.md),
            Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: status!.startsWith('Failed')
                    ? ZapColors.warning.withOpacity(0.1)
                    : ZapColors.safe.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Text(
                status!,
                style: ZapTypography.monoSmall.copyWith(
                  color: status!.startsWith('Failed')
                      ? ZapColors.warning
                      : ZapColors.safe,
                ),
              ),
            ),
          ],
          const SizedBox(height: ZapSpacing.md),
          ZapButton.elevated(
            label: 'REGISTER WITH BACKEND',
            icon: Icons.cloud_upload_rounded,
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: busy ? null : onRegister,
            isLoading: busy,
          ),
        ],
      ),
    );
  }
}

// ─── Category tile ───────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final PushCategory category;
  final VoidCallback onSimulate;
  const _CategoryTile({required this.category, required this.onSimulate});

  Color get _color => switch (category) {
        PushCategory.sosAlert        => ZapColors.danger,
        PushCategory.contactAck      => ZapColors.safe,
        PushCategory.batteryWarning  => ZapColors.warning,
        PushCategory.checkInReminder => ZapColors.info,
        PushCategory.unknown         => ZapColors.textSecondary,
      };

  IconData get _icon => switch (category) {
        PushCategory.sosAlert        => Icons.warning_amber_rounded,
        PushCategory.contactAck      => Icons.check_circle_rounded,
        PushCategory.batteryWarning  => Icons.battery_alert_rounded,
        PushCategory.checkInReminder => Icons.access_time_rounded,
        PushCategory.unknown         => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: ZapCard(
        onTap: onSimulate,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.wireName} · ${category.priority}',
                    style: ZapTypography.monoSmall.copyWith(
                      color: ZapColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded,
                color: ZapColors.textSecondary),
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
