/// Day 307 — Production SOS Long-Press Ring
///
/// Meta/QA screen for [SosTriggerButton]
/// (`lib/presentation/widgets/sos_trigger_button.dart`) — the real
/// production widget now wired onto the dashboard (route
/// `AppRoutes.dashboard`, `/dashboard`), built Day 307.
///
/// What it does, for real:
///   • 2-second long-press, clockwise ring fill gray → red
///     (`CustomPainter` sweeping from 12 o'clock, `Color.lerp` per frame).
///   • Haptic ramp — `HapticFeedback.lightImpact()` on press-start,
///     `.mediumImpact()` at 50% progress, `.heavyImpact()` at 85%. Uses
///     only `package:flutter/services.dart`, which is already a single
///     cross-platform API for both Android and iOS (see the widget's own
///     header for why there's no separate per-OS branch).
///   • Release before 2s → ring reverses + a "CANCELLED" label flashes
///     for 300ms inside the button.
///   • On completion: calls the real
///     `TriggerOrchestrator.dispatchManual(TriggerMethod.manual)` (Day 39)
///     — the exact same `AppStateNotifier.onManualTrigger` path every
///     other manual-trigger surface uses — then navigates to
///     `AppRoutes.sosActive` (the Day 76 SOS_ACTIVE screen).
///   • `Semantics(label: 'Hold to activate SOS, 2 seconds remaining')` on
///     the button at rest, plus live `SemanticsService.announce()` calls
///     each second while held ("1 second remaining", "Cancelled", "SOS
///     activated") for TalkBack/VoiceOver.
///
/// Known, honestly-documented gap: the Day 76 SOS_ACTIVE screen this
/// button navigates to is self-contained (its own local PIN/timer state)
/// and does **not** read `appStateProvider` — so triggering from this
/// button does start the real state machine (`AppState.alertPending` →
/// 15s countdown → `sosActive` → real `POST /api/v1/sos/trigger/` via the
/// `sos_providers.dart` bridge) independently of what the Day 76 screen
/// visually shows. Rewiring Day 76 to consume the state machine directly
/// is a larger change than this Day 307 polish task scopes to; flagged
/// here rather than silently left unmentioned.
///
/// Device verification: no emulator/physical device is attached to this
/// build session, so the haptic ramp and TalkBack announcements are
/// verified by reading the real Flutter API surface they call
/// (`HapticFeedback`, `SemanticsService`) rather than by an on-device
/// recording — documented per the task's "acceptance criteria you can't
/// physically verify" rule rather than claimed as device-tested.
/// Tag: 🟣 POLISH
///
/// Route: AppRoutes.sosLongPressRingPolish
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../navigation/app_router.dart';
import '../widgets/sos_trigger_button.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day307SosLongpressRingScreen extends StatelessWidget {
  const Day307SosLongpressRingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day306_310.sos_ring_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day306_310.sos_ring_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'Try it below — hold for 2 seconds to see the real ring fill + '
            'haptic ramp, or release early to see the cancel flash. This is '
            'the exact same SosTriggerButton widget live on the dashboard.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.xxl),
          Center(
            child: SosTriggerButton(
              onTriggered: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Real trigger dispatched — see dashboard mode badge')),
                );
              },
            ),
          ),
          const SizedBox(height: ZapSpacing.xxl),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What this button really does',
                    style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary)),
                const SizedBox(height: ZapSpacing.sm),
                _bullet('2s clockwise gray→red ring fill'),
                _bullet('Haptic ramp: light (start) → medium (50%) → heavy (85%)'),
                _bullet('Release early → 300ms "CANCELLED" flash'),
                _bullet('On completion: real TriggerOrchestrator.dispatchManual()'),
                _bullet('Semantics: "Hold to activate SOS, 2 seconds remaining"'),
                _bullet('Known gap: Day 76 SOS_ACTIVE screen doesn\'t read appStateProvider yet — documented in this screen\'s file header'),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Open production dashboard',
            intent: ZapButtonIntent.danger,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
          const SizedBox(height: ZapSpacing.sm),
          ZapButton.outlined(
            label: 'Back to integration audit',
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: ZapColors.textMuted, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(text,
                  style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.4)),
            ),
          ],
        ),
      );
}
