/// Day 304 — SOS delivery-status polling providers.
///
/// Polls GET /api/v1/sos/<id>/delivery-status/ every 5s for 60s after an
/// SOS trigger (12 polls total), matching the Day 304 spec. Stops early if
/// the widget using it is disposed (Riverpod `autoDispose` + timer cancel
/// in `onDispose`).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/sos_delivery_service.dart';
import 'auth_providers.dart';

final sosDeliveryServiceProvider = Provider<SosDeliveryService>((ref) {
  return SosDeliveryService(ref.watch(apiClientProvider));
});

SosDeliveryStatus _mockDeliveryStatus(String sosId) => SosDeliveryStatus(
      sosId: sosId,
      totalContacts: 2,
      contacts: [
        ContactDeliveryStatus(
          name: 'Priya Sharma (mock)',
          phone: '+919876543210',
          push: ChannelDeliveryStatus(
            status: 'delivered',
            provider: 'fcm',
            sentAt: DateTime.now().subtract(const Duration(seconds: 20)),
            deliveredAt: DateTime.now().subtract(const Duration(seconds: 18)),
          ),
          sms: ChannelDeliveryStatus(
            status: 'sent',
            provider: 'msg91',
            sentAt: DateTime.now().subtract(const Duration(seconds: 20)),
          ),
        ),
        ContactDeliveryStatus(
          name: 'Sam Miller (mock, US)',
          phone: '+14155550100',
          sms: ChannelDeliveryStatus(
            status: 'delivered',
            provider: 'twilio',
            sentAt: DateTime.now().subtract(const Duration(seconds: 22)),
            deliveredAt: DateTime.now().subtract(const Duration(seconds: 15)),
          ),
        ),
      ],
    );

/// Riverpod `.autoDispose.family` — one poller per SOS id, cleaned up when
/// the last listener (usually the Delivery Confirmation screen) goes away.
///
/// Polls every 5s for up to 60s (12 attempts), then stops issuing new
/// requests but keeps the last known state on the stream.
final sosDeliveryPollProvider =
    StreamProvider.autoDispose.family<SosDeliveryStatus, String>((ref, sosId) {
  final controller = StreamController<SosDeliveryStatus>();
  Timer? timer;
  var attempts = 0;
  const maxAttempts = 12; // 12 * 5s = 60s

  Future<void> poll() async {
    if (kUseMockData) {
      if (!controller.isClosed) controller.add(_mockDeliveryStatus(sosId));
      return;
    }
    try {
      final svc = ref.read(sosDeliveryServiceProvider);
      final status = await svc.fetchDeliveryStatus(sosId);
      if (!controller.isClosed) controller.add(status);
    } catch (e) {
      if (!controller.isClosed) controller.addError(e);
    }
  }

  // Fire immediately, then every 5s.
  unawaited(poll());
  timer = Timer.periodic(const Duration(seconds: 5), (t) {
    attempts++;
    if (attempts >= maxAttempts) {
      t.cancel();
    }
    unawaited(poll());
  });

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
