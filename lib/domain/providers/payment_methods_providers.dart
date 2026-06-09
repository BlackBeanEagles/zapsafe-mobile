/// Day 94-95 — Payment Methods state.
///
/// Fully self-contained mock Riverpod state — no API calls, no Stripe SDK.
/// Covers card/UPI storage, set-default, remove, and add flows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Card brand ───────────────────────────────────────────────────────────────

enum CardBrand { visa, mastercard, amex, rupay, unknown }

extension CardBrandX on CardBrand {
  String get label {
    switch (this) {
      case CardBrand.visa:       return 'Visa';
      case CardBrand.mastercard: return 'Mastercard';
      case CardBrand.amex:       return 'Amex';
      case CardBrand.rupay:      return 'RuPay';
      case CardBrand.unknown:    return 'Card';
    }
  }

  Color get color {
    switch (this) {
      case CardBrand.visa:       return const Color(0xFF1A1F71);
      case CardBrand.mastercard: return const Color(0xFFEB001B);
      case CardBrand.amex:       return const Color(0xFF007BC1);
      case CardBrand.rupay:      return const Color(0xFF00833E);
      case CardBrand.unknown:    return ZapColors.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case CardBrand.visa:       return Icons.credit_card_rounded;
      case CardBrand.mastercard: return Icons.credit_card_rounded;
      case CardBrand.amex:       return Icons.credit_card_rounded;
      case CardBrand.rupay:      return Icons.credit_card_rounded;
      case CardBrand.unknown:    return Icons.credit_card_rounded;
    }
  }
}

CardBrand detectBrand(String number) {
  final digits = number.replaceAll(' ', '');
  if (digits.startsWith('4')) {
    return CardBrand.visa;
  }
  if (digits.startsWith('5') || digits.startsWith('2')) {
    return CardBrand.mastercard;
  }
  if (digits.startsWith('37') || digits.startsWith('34')) {
    return CardBrand.amex;
  }
  if (digits.startsWith('60') || digits.startsWith('65') ||
      digits.startsWith('81') || digits.startsWith('82')) {
    return CardBrand.rupay;
  }
  return CardBrand.unknown;
}

// ─── Payment method type ──────────────────────────────────────────────────────

enum PaymentMethodType { card, upi }

extension PaymentMethodTypeX on PaymentMethodType {
  String get label {
    switch (this) {
      case PaymentMethodType.card: return 'Card';
      case PaymentMethodType.upi:  return 'UPI';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethodType.card: return Icons.credit_card_rounded;
      case PaymentMethodType.upi:  return Icons.account_balance_rounded;
    }
  }
}

// ─── Payment method model ─────────────────────────────────────────────────────

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.isDefault,
    this.brand,
    this.last4,
    this.holderName,
    this.expiryMonth,
    this.expiryYear,
    this.upiId,
  });

  final String             id;
  final PaymentMethodType  type;
  final bool               isDefault;

  // Card fields
  final CardBrand? brand;
  final String?    last4;
  final String?    holderName;
  final int?       expiryMonth;
  final int?       expiryYear;

  // UPI fields
  final String? upiId;

  String get displayTitle {
    if (type == PaymentMethodType.upi) {
      return upiId ?? 'UPI';
    }
    return '${brand?.label ?? 'Card'} •••• ${last4 ?? '????'}';
  }

  String get displaySubtitle {
    if (type == PaymentMethodType.upi) {
      return 'UPI ID';
    }
    final m = expiryMonth?.toString().padLeft(2, '0') ?? '--';
    final y = expiryYear?.toString() ?? '--';
    return 'Expires $m/$y';
  }

  bool get isExpired {
    if (type != PaymentMethodType.card) {
      return false;
    }
    if (expiryMonth == null || expiryYear == null) {
      return false;
    }
    final now = DateTime.now();
    if (expiryYear! < now.year) {
      return true;
    }
    if (expiryYear! == now.year && expiryMonth! < now.month) {
      return true;
    }
    return false;
  }

  PaymentMethod copyWith({bool? isDefault}) {
    return PaymentMethod(
      id:          id,
      type:        type,
      isDefault:   isDefault   ?? this.isDefault,
      brand:       brand,
      last4:       last4,
      holderName:  holderName,
      expiryMonth: expiryMonth,
      expiryYear:  expiryYear,
      upiId:       upiId,
    );
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class PaymentState {
  const PaymentState({
    required this.methods,
    required this.isSaving,
    required this.removingIds,
  });

  final List<PaymentMethod> methods;
  final bool                isSaving;
  final Set<String>         removingIds;

  PaymentState copyWith({
    List<PaymentMethod>? methods,
    bool?                isSaving,
    Set<String>?         removingIds,
  }) {
    return PaymentState(
      methods:     methods     ?? this.methods,
      isSaving:    isSaving    ?? this.isSaving,
      removingIds: removingIds ?? this.removingIds,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier()
      : super(const PaymentState(
          methods: [
            PaymentMethod(
              id:          'pm_visa_4242',
              type:        PaymentMethodType.card,
              isDefault:   true,
              brand:       CardBrand.visa,
              last4:       '4242',
              holderName:  'Alex Morgan',
              expiryMonth: 12,
              expiryYear:  2026,
            ),
            PaymentMethod(
              id:          'pm_mc_1234',
              type:        PaymentMethodType.card,
              isDefault:   false,
              brand:       CardBrand.mastercard,
              last4:       '1234',
              holderName:  'Alex Morgan',
              expiryMonth: 8,
              expiryYear:  2025,
            ),
            PaymentMethod(
              id:          'pm_upi_alex',
              type:        PaymentMethodType.upi,
              isDefault:   false,
              upiId:       'alex.morgan@upi',
            ),
          ],
          isSaving:    false,
          removingIds: {},
        ));

  void setDefault(String id) {
    state = state.copyWith(
      methods: state.methods.map((m) {
        return m.copyWith(isDefault: m.id == id);
      }).toList(),
    );
  }

  Future<void> removeMethod(String id) async {
    final next = Set<String>.from(state.removingIds)..add(id);
    state = state.copyWith(removingIds: next);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final updated = state.methods.where((m) => m.id != id).toList();
    // If we removed the default, promote the first remaining
    final hasDefault = updated.any((m) => m.isDefault);
    final finalList  = !hasDefault && updated.isNotEmpty
        ? [updated.first.copyWith(isDefault: true), ...updated.skip(1)]
        : updated;

    final nextRemoving = Set<String>.from(state.removingIds)..remove(id);
    state = state.copyWith(
      methods:     finalList,
      removingIds: nextRemoving,
    );
  }

  Future<void> addCard({
    required String holderName,
    required String number,
    required int    expiryMonth,
    required int    expiryYear,
  }) async {
    state = state.copyWith(isSaving: true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final brand = detectBrand(number);
    final last4 = number.replaceAll(' ', '');
    final last4str = last4.length >= 4
        ? last4.substring(last4.length - 4)
        : last4;
    final newMethod = PaymentMethod(
      id:          'pm_new_${DateTime.now().millisecondsSinceEpoch}',
      type:        PaymentMethodType.card,
      isDefault:   state.methods.isEmpty,
      brand:       brand,
      last4:       last4str,
      holderName:  holderName,
      expiryMonth: expiryMonth,
      expiryYear:  expiryYear,
    );
    state = state.copyWith(
      methods:  [...state.methods, newMethod],
      isSaving: false,
    );
  }

  Future<void> addUpi({required String upiId}) async {
    state = state.copyWith(isSaving: true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final newMethod = PaymentMethod(
      id:        'pm_upi_${DateTime.now().millisecondsSinceEpoch}',
      type:      PaymentMethodType.upi,
      isDefault: state.methods.isEmpty,
      upiId:     upiId,
    );
    state = state.copyWith(
      methods:  [...state.methods, newMethod],
      isSaving: false,
    );
  }
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>(
  (ref) => PaymentNotifier(),
);
