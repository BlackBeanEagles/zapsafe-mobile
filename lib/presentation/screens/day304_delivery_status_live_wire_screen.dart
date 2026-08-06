/// Day 304 — Wire SOS Delivery Status (MSG91 Cascade)
///
/// Polls the real GET /api/v1/sos/<id>/delivery-status/ endpoint every 5s
/// for 60s (via `sosDeliveryPollProvider`), demonstrating the full push →
/// SMS cascade story for a given SOS id. Enter a real SOS id from this
/// account (e.g. one returned by Day 302/303's own trigger flows, or any
/// id visible in `/api/v1/sos/dashboard/`) or leave the seeded mock id to
/// see `kUseMockData` fallback data offline.
///
/// Provider badge shows `msg91` for +91 numbers and `twilio` for others —
/// matching the real cascade routing. Hindi push-template selection
/// (`user.language == 'hi'`) is a notification-content detail on the
/// backend's send path, not something this GET-only status endpoint can
/// verify directly; documented here rather than faked.
/// Tag: 🔵 EXISTING-API
///
/// Route: AppRoutes.deliveryStatusLiveWire
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../data/services/sos_delivery_service.dart';
import '../../domain/providers/sos_delivery_providers.dart';
import '../navigation/app_router.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_button.dart';
import '../widgets/zap_card.dart';

class Day304DeliveryStatusLiveWireScreen extends ConsumerStatefulWidget {
  const Day304DeliveryStatusLiveWireScreen({super.key});

  @override
  ConsumerState<Day304DeliveryStatusLiveWireScreen> createState() =>
      _Day304DeliveryStatusLiveWireScreenState();
}

class _Day304DeliveryStatusLiveWireScreenState
    extends ConsumerState<Day304DeliveryStatusLiveWireScreen> {
  final _controller = TextEditingController(text: '00000000-0000-0000-0000-000000000000');
  String? _activeSosId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSosId = _activeSosId;
    final pollAsync = activeSosId == null
        ? null
        : ref.watch(sosDeliveryPollProvider(activeSosId));

    return Scaffold(
      appBar: AppBar(title: Text('day301_305.delivery_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Text('day301_305.delivery_heading'.tr(),
              style: ZapTypography.headlineMedium
                  .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            'GET /api/v1/sos/<id>/delivery-status/ — polled every 5s for 60s '
            'after entering an SOS id, matching the real MSG91/FCM cascade '
            'the Day 75 Delivery Confirmation screen is wired to.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary),
          ),
          const SizedBox(height: ZapSpacing.lg),
          ZapCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SOS id', style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
                const SizedBox(height: ZapSpacing.xs),
                TextField(
                  controller: _controller,
                  style: ZapTypography.monoSmall.copyWith(color: ZapColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'uuid — real id, or leave the zeroed mock id',
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                ZapButton.elevated(
                  label: 'Start polling',
                  intent: ZapButtonIntent.info,
                  fullWidth: true,
                  onPressed: () => setState(() => _activeSosId = _controller.text.trim()),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          if (pollAsync != null)
            pollAsync.when(
              data: (status) => _DeliveryResult(status: status),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: ZapSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ZapCard(
                borderColor: ZapColors.danger.withOpacity(0.4),
                child: Text(_friendlyError(e),
                    style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger)),
              ),
            ),
          const SizedBox(height: ZapSpacing.xl),
          ZapButton.elevated(
            label: 'Back to integration audit',
            intent: ZapButtonIntent.info,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.integrationAudit),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('404') || s.contains('SOS_NOT_FOUND')) {
      return 'No SOS event with that id on this account (real 404 from '
          'SOSDeliveryStatusView — expected for a made-up id).';
    }
    if (s.contains('401')) return 'Session expired — please log in again.';
    if (s.contains('NETWORK') || s.contains('Cannot reach server')) {
      return 'Backend unreachable (is Django running?).';
    }
    return 'Request failed: $s';
  }
}

class _DeliveryResult extends StatelessWidget {
  const _DeliveryResult({required this.status});
  final SosDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.contacts.isEmpty) {
      return ZapCard(
        child: Text('No delivery logs yet for this SOS id.',
            style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textSecondary)),
      );
    }
    return Column(
      children: [
        for (final c in status.contacts)
          ZapCard(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.name,
                          style: ZapTypography.bodyMedium
                              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w600)),
                    ),
                    ZapBadge(
                      label: c.isIndiaNumber ? 'MSG91' : 'TWILIO',
                      intent: c.isIndiaNumber ? ZapBadgeIntent.info : ZapBadgeIntent.neutral,
                      size: ZapBadgeSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                if (c.push != null) _channelRow('push', c.push!),
                if (c.sms != null) _channelRow('sms', c.sms!),
                if (c.push == null && c.sms == null)
                  Text('No channel logs yet.',
                      style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _channelRow(String channel, ChannelDeliveryStatus s) {
    final color = switch (s.status) {
      'delivered' || 'acked' => ZapColors.safe,
      'sent' => ZapColors.warning,
      'failed' => ZapColors.danger,
      _ => ZapColors.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.xs),
          Text('$channel · ${s.provider.isEmpty ? '—' : s.provider} · ${s.status}',
              style: ZapTypography.monoSmall.copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}
