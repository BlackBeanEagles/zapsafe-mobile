/// Emergency contacts service — backend Day 7+ CRUD.
///
/// GET/POST    /api/v1/contacts/
/// PUT/DELETE  /api/v1/contacts/<uuid>/
library;

import '../../core/constants/api_config.dart';
import 'api_client.dart';

class EmergencyContactDto {
  const EmergencyContactDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.notifyOrder,
    required this.isVerified,
    this.relationship,
    this.status,
    this.email,
  });

  final String id;
  final String name;
  final String phone;
  final int tier;
  final int notifyOrder;
  final bool isVerified;
  final String? relationship;
  final String? status;

  /// Day 257 — optional SOS email fallback.
  ///
  /// The backend cascade is push -> SMS -> email. A contact without the app
  /// can only be reached by SMS, and SMS to Indian numbers is blocked until
  /// DLT registration completes, so for those contacts this address is
  /// currently the ONLY way to reach them at all.
  final String? email;

  factory EmergencyContactDto.fromJson(Map<String, dynamic> j) =>
      EmergencyContactDto(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        tier: (j['tier'] as num).toInt(),
        notifyOrder: (j['notify_order'] as num?)?.toInt() ?? 1,
        isVerified: (j['is_verified'] as bool?) ?? false,
        relationship: j['relationship'] as String?,
        status: j['status'] as String?,
        email: j['email'] as String?,
      );
}

class ContactsService {
  const ContactsService(this._client);
  final ApiClient _client;

  Future<List<EmergencyContactDto>> fetchAll() async {
    final res = await _client.dio.get(ApiConfig.contacts);
    final list = res.data as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(EmergencyContactDto.fromJson)
        .toList();
  }

  Future<EmergencyContactDto> create({
    required String name,
    required String phone,
    required int tier,
    int notifyOrder = 1,
    String? relationship,
    String? email,
    bool biometricVerified = true,
  }) async {
    final res = await _client.dio.post(
      ApiConfig.contacts,
      data: {
        'name': name,
        'phone': phone,
        'tier': tier,
        'notify_order': notifyOrder,
        if (relationship != null) 'relationship': relationship,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'biometric_verified': biometricVerified,
      },
    );
    return EmergencyContactDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<EmergencyContactDto> update({
    required String id,
    String? name,
    String? phone,
    int? tier,
    int? notifyOrder,
    String? relationship,
    // Day 257 — nullable so an omitted email leaves the stored value alone,
    // while an explicit empty string clears it. Existing contacts were
    // created before this field existed, so adding an address later is the
    // normal path, not the exception.
    String? email,
    bool biometricVerified = true,
  }) async {
    final res = await _client.dio.put(
      '${ApiConfig.contacts}$id/',
      data: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (tier != null) 'tier': tier,
        if (notifyOrder != null) 'notify_order': notifyOrder,
        if (relationship != null) 'relationship': relationship,
        if (email != null) 'email': email.trim(),
        'biometric_verified': biometricVerified,
      },
    );
    return EmergencyContactDto.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete({
    required String id,
    bool biometricVerified = true,
  }) async {
    await _client.dio.delete(
      '${ApiConfig.contacts}$id/',
      data: {'biometric_verified': biometricVerified},
    );
  }
}
