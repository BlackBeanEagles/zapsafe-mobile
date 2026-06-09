/// Day 83 — Contact Management state.
///
/// [ContactsNotifier] holds the full contact list and exposes CRUD,
/// tier assignment, and batch operations.  Tier limits (1 max Tier-1,
/// 5 max Tier-2) are enforced and surfaced as [ContactsError].
///
/// API integration: GET/POST/PATCH/DELETE /api/v1/contacts/ — Month 4.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.isVerified,
    required this.notifyOrder,
  });

  final String id;
  final String name;
  final String phone;      // E.164 stored, displayed masked
  final int    tier;       // 1 | 2 | 3
  final bool   isVerified;
  final int    notifyOrder;

  String get maskedPhone {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, phone.length - 4).replaceAll(RegExp(r'\d'), '•')}${phone.substring(phone.length - 4)}';
  }

  Contact copyWith({
    String? name,
    String? phone,
    int?    tier,
    bool?   isVerified,
    int?    notifyOrder,
  }) {
    return Contact(
      id:          id,
      name:        name        ?? this.name,
      phone:       phone       ?? this.phone,
      tier:        tier        ?? this.tier,
      isVerified:  isVerified  ?? this.isVerified,
      notifyOrder: notifyOrder ?? this.notifyOrder,
    );
  }
}

// ─── Tier limits ──────────────────────────────────────────────────────────────

const kTier1Max = 1;
const kTier2Max = 5;

enum ContactsError { tier1Full, tier2Full }

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockContacts = [
  const Contact(id: 'c1', name: 'Priya Sharma',    phone: '+919876543210', tier: 1, isVerified: true,  notifyOrder: 1),
  const Contact(id: 'c2', name: 'Rahul Gupta',     phone: '+919812345678', tier: 2, isVerified: true,  notifyOrder: 1),
  const Contact(id: 'c3', name: 'Anjali Mehta',    phone: '+919988776655', tier: 2, isVerified: false, notifyOrder: 2),
  const Contact(id: 'c4', name: 'Vikram Nair',     phone: '+919123456789', tier: 2, isVerified: true,  notifyOrder: 3),
  const Contact(id: 'c5', name: 'Sunita Patel',    phone: '+919871234567', tier: 3, isVerified: true,  notifyOrder: 1),
  const Contact(id: 'c6', name: 'Deepak Singh',    phone: '+919765432109', tier: 3, isVerified: false, notifyOrder: 2),
  const Contact(id: 'c7', name: 'Meera Krishnan',  phone: '+919654321098', tier: 3, isVerified: true,  notifyOrder: 3),
];

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ContactsNotifier extends StateNotifier<List<Contact>> {
  ContactsNotifier() : super(List.from(_mockContacts));

  List<Contact> get tier1 =>
      state.where((c) => c.tier == 1).toList()
        ..sort((a, b) => a.notifyOrder.compareTo(b.notifyOrder));

  List<Contact> get tier2 =>
      state.where((c) => c.tier == 2).toList()
        ..sort((a, b) => a.notifyOrder.compareTo(b.notifyOrder));

  List<Contact> get tier3 =>
      state.where((c) => c.tier == 3).toList()
        ..sort((a, b) => a.notifyOrder.compareTo(b.notifyOrder));

  int _nextOrder(int tier) {
    final inTier = state.where((c) => c.tier == tier);
    if (inTier.isEmpty) return 1;
    return inTier.map((c) => c.notifyOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Returns null on success, [ContactsError] if tier limit exceeded.
  ContactsError? add({
    required String name,
    required String phone,
    required int    tier,
  }) {
    if (tier == 1 && tier1.length >= kTier1Max) return ContactsError.tier1Full;
    if (tier == 2 && tier2.length >= kTier2Max) return ContactsError.tier2Full;

    final newId = 'c${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Contact(
        id:          newId,
        name:        name,
        phone:       phone,
        tier:        tier,
        isVerified:  false, // must verify via SMS OTP in prod
        notifyOrder: _nextOrder(tier),
      ),
    ];
    return null;
  }

  /// Returns null on success, [ContactsError] if target tier limit exceeded.
  ContactsError? update(Contact updated) {
    final old = state.firstWhere((c) => c.id == updated.id);
    if (old.tier != updated.tier) {
      if (updated.tier == 1 && tier1.where((c) => c.id != updated.id).length >= kTier1Max) {
        return ContactsError.tier1Full;
      }
      if (updated.tier == 2 && tier2.where((c) => c.id != updated.id).length >= kTier2Max) {
        return ContactsError.tier2Full;
      }
    }
    state = [for (final c in state) c.id == updated.id ? updated : c];
    return null;
  }

  void delete(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  void batchDelete(Set<String> ids) {
    state = state.where((c) => !ids.contains(c.id)).toList();
  }

  /// Returns ids that failed due to tier limits.
  Set<String> batchSetTier(Set<String> ids, int tier) {
    final failed = <String>{};
    for (final id in ids) {
      final contact = state.firstWhere((c) => c.id == id);
      final err = update(contact.copyWith(tier: tier, notifyOrder: _nextOrder(tier)));
      if (err != null) failed.add(id);
    }
    return failed;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, List<Contact>>(
  (ref) => ContactsNotifier(),
);

/// IDs of contacts selected in batch mode.
final contactSelectionProvider = StateProvider<Set<String>>((ref) => {});

/// Whether batch-select mode is active.
final batchModeProvider = StateProvider<bool>((ref) => false);

/// Current search query.
final contactSearchProvider = StateProvider<String>((ref) => '');
