/// SOS delivery status service (MSG91/FCM cascade) — backend Day 75/101,
/// wired for real Day 304.
///
/// GET /api/v1/sos/<sos_id>/delivery-status/
///
/// IMPORTANT contract note: the Day 304 spec describes the response as a
/// flat per-contact list of `{channel, provider, status, timestamp}`. The
/// REAL backend (`SOSDeliveryStatusView` in `zapsafe_backend/sos/views.py`,
/// read directly since Docker was unavailable in this sandbox) instead
/// returns, per contact, two nested optional objects — `push` and `sms` —
/// each with its own `status`, `provider`, `sent_at`, `delivered_at`,
/// `acked_at`, `error_message`. This service and its models match the REAL
/// shape, not the spec's simplified guess. See
/// DAY301_305_INTEGRATION_WIRING.md for the full discrepancy note.
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class ChannelDeliveryStatus {
  const ChannelDeliveryStatus({
    required this.status,
    required this.provider,
    this.sentAt,
    this.deliveredAt,
    this.ackedAt,
    this.errorMessage,
  });

  final String status; // e.g. sent | delivered | failed | acked
  final String provider; // fcm | msg91 | twilio | ''
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? ackedAt;
  final String? errorMessage;

  factory ChannelDeliveryStatus.fromJson(Map<String, dynamic> j) => ChannelDeliveryStatus(
        status: j['status'] as String? ?? 'unknown',
        provider: j['provider'] as String? ?? '',
        sentAt: j['sent_at'] != null ? DateTime.tryParse(j['sent_at'] as String) : null,
        deliveredAt:
            j['delivered_at'] != null ? DateTime.tryParse(j['delivered_at'] as String) : null,
        ackedAt: j['acked_at'] != null ? DateTime.tryParse(j['acked_at'] as String) : null,
        errorMessage: j['error_message'] as String?,
      );
}

class ContactDeliveryStatus {
  const ContactDeliveryStatus({
    required this.name,
    required this.phone,
    this.push,
    this.sms,
  });

  final String name;
  final String phone;
  final ChannelDeliveryStatus? push;
  final ChannelDeliveryStatus? sms;

  /// India numbers (+91) route SMS through MSG91; everything else through
  /// Twilio — matches the real backend's provider-selection logic
  /// documented in the Day 304 spec.
  bool get isIndiaNumber => phone.startsWith('+91');

  factory ContactDeliveryStatus.fromJson(Map<String, dynamic> j) => ContactDeliveryStatus(
        name: j['name'] as String? ?? j['phone'] as String? ?? 'Unknown',
        phone: j['phone'] as String? ?? '',
        push: j['push'] != null
            ? ChannelDeliveryStatus.fromJson(j['push'] as Map<String, dynamic>)
            : null,
        sms: j['sms'] != null
            ? ChannelDeliveryStatus.fromJson(j['sms'] as Map<String, dynamic>)
            : null,
      );
}

class SosDeliveryStatus {
  const SosDeliveryStatus({
    required this.sosId,
    required this.totalContacts,
    required this.contacts,
  });

  final String sosId;
  final int totalContacts;
  final List<ContactDeliveryStatus> contacts;

  factory SosDeliveryStatus.fromJson(Map<String, dynamic> j) => SosDeliveryStatus(
        sosId: j['sos_id'] as String? ?? '',
        totalContacts: (j['total_contacts'] as num?)?.toInt() ?? 0,
        contacts: ((j['contacts'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ContactDeliveryStatus.fromJson)
            .toList(),
      );
}

class SosDeliveryService {
  const SosDeliveryService(this._client);
  final ApiClient _client;

  /// GET /api/v1/sos/<sos_id>/delivery-status/
  Future<SosDeliveryStatus> fetchDeliveryStatus(String sosId) async {
    final res = await _client.dio.get(ApiConfig.sosDeliveryStatusFor(sosId));
    return SosDeliveryStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
