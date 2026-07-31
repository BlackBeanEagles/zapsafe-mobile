/// Day 83 — Contact Management state.
///
/// Wired to GET/POST/PUT/DELETE /api/v1/contacts/ when [kUseMockData] is false.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../data/services/contacts_service.dart';
import 'auth_providers.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.tier,
    required this.isVerified,
    required this.notifyOrder,
    this.email,
  });

  final String id;
  final String name;
  final String phone;      // E.164 stored, displayed masked
  final int    tier;       // 1 | 2 | 3
  final bool   isVerified;
  final int    notifyOrder;

  /// Day 257 — optional SOS email fallback.
  ///
  /// Delivery order is push -> SMS -> email. A contact without the app can
  /// only be reached by SMS, and SMS to Indian numbers is blocked until DLT
  /// registration completes — so for those contacts this is currently the
  /// only way to reach them at all.
  final String? email;

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
    String? email,
  }) {
    return Contact(
      id:          id,
      name:        name        ?? this.name,
      phone:       phone       ?? this.phone,
      tier:        tier        ?? this.tier,
      isVerified:  isVerified  ?? this.isVerified,
      notifyOrder: notifyOrder ?? this.notifyOrder,
      email:       email       ?? this.email,
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

// ─── Service ──────────────────────────────────────────────────────────────────

final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService(ref.watch(apiClientProvider));
});

Contact _fromDto(EmergencyContactDto dto) => Contact(
      id: dto.id,
      name: dto.name,
      phone: dto.phone,
      tier: dto.tier,
      isVerified: dto.isVerified,
      notifyOrder: dto.notifyOrder,
      email: dto.email,
    );

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ContactsNotifier extends StateNotifier<List<Contact>> {
  ContactsNotifier(this._ref) : super(List.from(_mockContacts));

  final Ref _ref;

  ContactsService? get _service =>
      kUseMockData ? null : _ref.read(contactsServiceProvider);

  Future<void> loadFromBackend() async {
    final svc = _service;
    if (svc == null) return;
    try {
      final list = await svc.fetchAll();
      state = list.map(_fromDto).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[contacts] load failed, keeping mock: $e');
    }
  }

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
  Future<ContactsError?> add({
    required String name,
    required String phone,
    required int    tier,
    String? email,
  }) async {
    if (tier == 1 && tier1.length >= kTier1Max) return ContactsError.tier1Full;
    if (tier == 2 && tier2.length >= kTier2Max) return ContactsError.tier2Full;

    final svc = _service;
    if (svc != null) {
      try {
        final created =
            await svc.create(name: name, phone: phone, tier: tier, email: email);
        state = [...state, _fromDto(created)];
        return null;
      } catch (e) {
        if (kDebugMode) debugPrint('[contacts] create failed: $e');
      }
    }

    final newId = 'c${DateTime.now().millisecondsSinceEpoch}';
    state = [
      ...state,
      Contact(
        id:          newId,
        name:        name,
        phone:       phone,
        tier:        tier,
        isVerified:  false,
        notifyOrder: _nextOrder(tier),
      ),
    ];
    return null;
  }

  /// Returns null on success, [ContactsError] if target tier limit exceeded.
  Future<ContactsError?> update(Contact updated) async {
    final old = state.firstWhere((c) => c.id == updated.id);
    if (old.tier != updated.tier) {
      if (updated.tier == 1 && tier1.where((c) => c.id != updated.id).length >= kTier1Max) {
        return ContactsError.tier1Full;
      }
      if (updated.tier == 2 && tier2.where((c) => c.id != updated.id).length >= kTier2Max) {
        return ContactsError.tier2Full;
      }
    }
    final svc = _service;
    if (svc != null) {
      try {
        final saved = await svc.update(
          id: updated.id,
          name: updated.name,
          phone: updated.phone,
          tier: updated.tier,
          notifyOrder: updated.notifyOrder,
          email: updated.email,
        );
        state = [for (final c in state) c.id == updated.id ? _fromDto(saved) : c];
        return null;
      } catch (e) {
        if (kDebugMode) debugPrint('[contacts] update failed: $e');
      }
    }
    state = [for (final c in state) c.id == updated.id ? updated : c];
    return null;
  }

  Future<void> delete(String id) async {
    final svc = _service;
    if (svc != null) {
      try {
        await svc.delete(id: id);
      } catch (e) {
        if (kDebugMode) debugPrint('[contacts] delete failed: $e');
      }
    }
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> batchDelete(Set<String> ids) async {
    for (final id in ids) {
      await delete(id);
    }
  }

  /// Returns ids that failed due to tier limits.
  Future<Set<String>> batchSetTier(Set<String> ids, int tier) async {
    final failed = <String>{};
    for (final id in ids) {
      final contact = state.firstWhere((c) => c.id == id);
      final err = await update(
        contact.copyWith(tier: tier, notifyOrder: _nextOrder(tier)),
      );
      if (err != null) failed.add(id);
    }
    return failed;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, List<Contact>>(
  (ref) {
    final notifier = ContactsNotifier(ref);
    if (ref.watch(isLoggedInProvider)) {
      unawaited(notifier.loadFromBackend());
    }
    return notifier;
  },
);

/// IDs of contacts selected in batch mode.
final contactSelectionProvider = StateProvider<Set<String>>((ref) => {});

/// Whether batch-select mode is active.
final batchModeProvider = StateProvider<bool>((ref) => false);

/// Current search query.
final contactSearchProvider = StateProvider<String>((ref) => '');
