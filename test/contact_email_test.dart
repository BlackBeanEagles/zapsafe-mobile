import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/contacts_service.dart';
import 'package:zapsafe_mobile/domain/providers/contacts_providers.dart';

/// Day 257 — emergency-contact email, the SOS fallback channel.
///
/// Delivery order is push -> SMS -> email. A contact without the app can
/// only be reached by SMS, and SMS to Indian numbers is blocked until DLT
/// registration completes — so for those contacts this address is currently
/// the only way to reach them at all.
///
/// What matters here is that the value survives the whole round trip. A
/// field that looks saved and silently isn't would leave someone believing
/// a contact can be reached when they cannot.
void main() {
  group('EmergencyContactDto', () {
    test('parses email from the API', () {
      final dto = EmergencyContactDto.fromJson(const {
        'id': 'c1',
        'name': 'Priya',
        'phone': '+919876543210',
        'tier': 1,
        'notify_order': 1,
        'is_verified': true,
        'email': 'priya@example.com',
      });
      expect(dto.email, 'priya@example.com');
    });

    test('tolerates a contact with no email', () {
      final dto = EmergencyContactDto.fromJson(const {
        'id': 'c1',
        'name': 'Priya',
        'phone': '+919876543210',
        'tier': 1,
        'notify_order': 1,
        'is_verified': true,
      });
      expect(dto.email, isNull);
    });
  });

  group('Contact model', () {
    Contact base() => const Contact(
          id: 'c1',
          name: 'Priya',
          phone: '+919876543210',
          tier: 1,
          isVerified: true,
          notifyOrder: 1,
          email: 'priya@example.com',
        );

    test('carries email', () {
      expect(base().email, 'priya@example.com');
    });

    test('copyWith can set an email on a contact that had none', () {
      const without = Contact(
        id: 'c2', name: 'Ravi', phone: '+919000000000',
        tier: 2, isVerified: false, notifyOrder: 2,
      );
      expect(without.copyWith(email: 'ravi@example.com').email, 'ravi@example.com');
    });

    test('copyWith preserves email when not supplied', () {
      expect(base().copyWith(name: 'Priya S').email, 'priya@example.com');
    });

    test('email is optional so pre-existing contacts still construct', () {
      const c = Contact(
        id: 'c3', name: 'Old', phone: '+919111111111',
        tier: 2, isVerified: false, notifyOrder: 3,
      );
      expect(c.email, isNull);
    });
  });
}
