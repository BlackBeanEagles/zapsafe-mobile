import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/models/quiet_hours.dart';
import '../../data/services/push_service.dart';
import '../../domain/providers/push_providers.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';
import '../widgets/zap_snackbar.dart';

/// Day 17 — Push category routing + iOS action buttons + quiet hours.
///
/// Live test surface for the per-category navigation matrix and the SOS
/// notification action buttons. Tapping a category tile fires a real local
/// notification with category-specific action buttons; tapping any of those
/// (or the body) drives the GoRouter via the [pushNavigationListenerProvider].
class Day17PushRoutingScreen extends ConsumerStatefulWidget {
  const Day17PushRoutingScreen({super.key});

  @override
  ConsumerState<Day17PushRoutingScreen> createState() =>
      _Day17PushRoutingScreenState();
}

class _Day17PushRoutingScreenState
    extends ConsumerState<Day17PushRoutingScreen> {
  PushNavIntent? _lastInPageIntent;

  @override
  Widget build(BuildContext context) {
    // Keep the navigation listener alive (side-effect subscription provider).
    ref.watch(pushNavigationListenerProvider);
    final lastIntent = ref.watch(lastPushNavIntentProvider);
    final quietHours = ref.watch(quietHoursProvider);
    final service = ref.watch(pushServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 17 · Push Routing'),
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

              const _SectionLabel('CATEGORY ROUTING MATRIX'),
              const SizedBox(height: ZapSpacing.md),
              _RoutingMatrix(
                onSimulate: (cat) async {
                  final shown = await service.showLocal(PushPayload(
                    messageId:
                        'sim_${cat.wireName}_${DateTime.now().millisecondsSinceEpoch}',
                    category: cat,
                    title: '[SIM] ${cat.label}',
                    body: _bodyFor(cat),
                  ));
                  if (!context.mounted) return;
                  if (shown) {
                    ZapSnackbar.info(context,
                        '${cat.label} fired · tap notification to route to ${cat.destinationRoute}');
                  } else {
                    ZapSnackbar.warning(context,
                        '${cat.label} suppressed by quiet hours · disable to fire');
                  }
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('SOS ACTION BUTTONS · iOS + ANDROID'),
              const SizedBox(height: ZapSpacing.md),
              _ActionButtonsCard(),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('QUIET HOURS'),
              const SizedBox(height: ZapSpacing.md),
              _QuietHoursCard(
                config: quietHours,
                onToggle: (enabled) {
                  ref.read(quietHoursProvider.notifier).state =
                      quietHours.copyWith(enabled: enabled);
                },
                onChangeStart: (h) {
                  ref.read(quietHoursProvider.notifier).state =
                      quietHours.copyWith(startHour: h);
                },
                onChangeEnd: (h) {
                  ref.read(quietHoursProvider.notifier).state =
                      quietHours.copyWith(endHour: h);
                },
              ),

              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('LAST DELIVERED NAV INTENT'),
              const SizedBox(height: ZapSpacing.md),
              _IntentCard(intent: lastIntent ?? _lastInPageIntent),

              const SizedBox(height: ZapSpacing.xl),

              ZapButton.outlined(
                label: 'EMIT FAKE SOS NAV INTENT',
                icon: Icons.bolt_rounded,
                fullWidth: true,
                onPressed: () {
                  service.emitNavigationIntent(const PushNavIntent(
                    route: '/sos-active',
                    category: PushCategory.sosAlert,
                    trigger: PushNavTrigger.responding,
                  ));
                  if (mounted) {
                    setState(() => _lastInPageIntent = const PushNavIntent(
                          route: '/sos-active',
                          category: PushCategory.sosAlert,
                          trigger: PushNavTrigger.responding,
                        ));
                  }
                },
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

  String _bodyFor(PushCategory cat) => switch (cat) {
        PushCategory.sosAlert        => 'Riya triggered an SOS. Tap to respond.',
        PushCategory.contactAck      => 'Amma acknowledged your SOS.',
        PushCategory.batteryWarning  => 'Phone battery at 18% — Mode B evidence active.',
        PushCategory.checkInReminder => 'Wellness check-in due in 10 minutes.',
        PushCategory.unknown         => 'Generic push.',
      };
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
            ZapColors.info.withOpacity(0.14),
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
                child: const Icon(Icons.call_split_rounded,
                    color: ZapColors.info, size: 22),
              ),
              const SizedBox(width: ZapSpacing.md),
              const ZapBadge(label: 'WEEK 4 · DAY 17', intent: ZapBadgeIntent.info),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Push Routing & Actions',
            style: ZapTypography.displaySmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Tapping a notification deep-links to the right screen. SOS '
            'notifications carry two action buttons ("I\'m Responding" / "Call 112") '
            'on both iOS and Android. Quiet hours suppress check-in reminders '
            'but never SOS.',
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

// ─── Routing matrix ──────────────────────────────────────────────────────────

class _RoutingMatrix extends StatelessWidget {
  final void Function(PushCategory) onSimulate;
  const _RoutingMatrix({required this.onSimulate});

  @override
  Widget build(BuildContext context) {
    final rows = PushCategory.values
        .where((c) => c != PushCategory.unknown)
        .toList();

    return Column(
      children: rows.map((cat) {
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: ZapCard(
            onTap: () => onSimulate(cat),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent(cat).withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                  ),
                  child: Icon(_icon(cat), color: _accent(cat), size: 20),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.label,
                        style: ZapTypography.bodyMedium.copyWith(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cat.wireName} · ${cat.priority}',
                        style: ZapTypography.monoSmall.copyWith(
                          color: ZapColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent(cat).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cat.destinationRoute,
                    style: ZapTypography.monoSmall.copyWith(
                      color: _accent(cat),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _accent(PushCategory c) => switch (c) {
        PushCategory.sosAlert        => ZapColors.danger,
        PushCategory.contactAck      => ZapColors.safe,
        PushCategory.batteryWarning  => ZapColors.warning,
        PushCategory.checkInReminder => ZapColors.info,
        PushCategory.unknown         => ZapColors.textSecondary,
      };

  IconData _icon(PushCategory c) => switch (c) {
        PushCategory.sosAlert        => Icons.warning_amber_rounded,
        PushCategory.contactAck      => Icons.check_circle_rounded,
        PushCategory.batteryWarning  => Icons.battery_alert_rounded,
        PushCategory.checkInReminder => Icons.access_time_rounded,
        PushCategory.unknown         => Icons.notifications_rounded,
      };
}

// ─── Action buttons card ─────────────────────────────────────────────────────

class _ActionButtonsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category: ZAPSAFE_SOS_ALERT',
            style: ZapTypography.monoSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          _ActionRow(
            id: PushService.actionResponding,
            label: "I'm Responding",
            description: 'Foreground action · routes to /sos-active',
            accent: ZapColors.safe,
            icon: Icons.flag_rounded,
          ),
          const SizedBox(height: ZapSpacing.sm),
          _ActionRow(
            id: PushService.actionCall112,
            label: 'Call 112',
            description: 'Destructive · routes to /sos-active (dialer hook on a future day)',
            accent: ZapColors.danger,
            icon: Icons.phone_rounded,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String id;
  final String label;
  final String description;
  final Color accent;
  final IconData icon;

  const _ActionRow({
    required this.id,
    required this.label,
    required this.description,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'id: $id',
                  style: ZapTypography.monoSmall.copyWith(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
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

// ─── Quiet hours card ────────────────────────────────────────────────────────

class _QuietHoursCard extends StatelessWidget {
  final QuietHoursConfig config;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChangeStart;
  final ValueChanged<int> onChangeEnd;

  const _QuietHoursCard({
    required this.config,
    required this.onToggle,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final inWindow = config.covers(DateTime.now());

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiet hours',
                      style: ZapTypography.headlineSmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.enabled
                          ? '${config.prettyRange} · ${inWindow ? "ACTIVE NOW" : "off-window"}'
                          : 'Disabled — all notifications fire',
                      style: ZapTypography.bodySmall.copyWith(
                        color: inWindow
                            ? ZapColors.warning
                            : ZapColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: config.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          if (config.enabled) ...[
            const SizedBox(height: ZapSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _HourPicker(
                    label: 'Start',
                    hour: config.startHour,
                    onChanged: onChangeStart,
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: _HourPicker(
                    label: 'End',
                    hour: config.endHour,
                    onChanged: onChangeEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'Only CHECK_IN_REMINDER is suppressed. SOS pushes always fire.',
              style: ZapTypography.bodySmall.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;
  const _HourPicker({
    required this.label,
    required this.hour,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        Row(
          children: [
            IconButton.outlined(
              onPressed: () => onChanged((hour + 23) % 24),
              icon: const Icon(Icons.remove_rounded),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: () => onChanged((hour + 1) % 24),
              icon: const Icon(Icons.add_rounded),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Intent card ─────────────────────────────────────────────────────────────

class _IntentCard extends StatelessWidget {
  final PushNavIntent? intent;
  const _IntentCard({required this.intent});

  @override
  Widget build(BuildContext context) {
    if (intent == null) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: Text(
          'No nav intent received yet · tap any category above to emit one.',
          style: ZapTypography.bodySmall.copyWith(
            color: ZapColors.textSecondary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('route', intent!.route),
          _kv('category', intent!.category.wireName),
          _kv('trigger', intent!.trigger.name),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                k,
                style: ZapTypography.labelSmall.copyWith(
                  color: ZapColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              v,
              style: ZapTypography.monoSmall.copyWith(
                color: ZapColors.textPrimary,
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
