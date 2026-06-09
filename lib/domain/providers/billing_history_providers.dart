/// Day 95-96 — Billing History state.
///
/// Fully self-contained mock Riverpod state — no API calls, no Stripe SDK.
/// Covers invoice list, status/year filter, PDF download, email receipt.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';

// ─── Invoice status ───────────────────────────────────────────────────────────

enum InvoiceStatus { paid, refunded, failed, pending }

extension InvoiceStatusX on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.paid:      return 'Paid';
      case InvoiceStatus.refunded:  return 'Refunded';
      case InvoiceStatus.failed:    return 'Failed';
      case InvoiceStatus.pending:   return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case InvoiceStatus.paid:      return ZapColors.safe;
      case InvoiceStatus.refunded:  return ZapColors.info;
      case InvoiceStatus.failed:    return ZapColors.danger;
      case InvoiceStatus.pending:   return ZapColors.warning;
    }
  }

  IconData get icon {
    switch (this) {
      case InvoiceStatus.paid:      return Icons.check_circle_rounded;
      case InvoiceStatus.refunded:  return Icons.undo_rounded;
      case InvoiceStatus.failed:    return Icons.cancel_rounded;
      case InvoiceStatus.pending:   return Icons.schedule_rounded;
    }
  }
}

// ─── Billing cycle label ──────────────────────────────────────────────────────

enum InvoiceCycle { monthly, annual, oneTime }

extension InvoiceCycleX on InvoiceCycle {
  String get label {
    switch (this) {
      case InvoiceCycle.monthly:  return 'Monthly';
      case InvoiceCycle.annual:   return 'Annual';
      case InvoiceCycle.oneTime:  return 'One-time';
    }
  }
}

// ─── Invoice model ────────────────────────────────────────────────────────────

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.date,
    required this.description,
    required this.planName,
    required this.cycle,
    this.periodStart,
    this.periodEnd,
    this.refundReason,
    this.failureReason,
  });

  final String        id;
  final String        invoiceNumber;
  final InvoiceStatus status;
  final int           amountCents;   // e.g. 4788 = $47.88
  final String        currency;      // 'USD'
  final DateTime      date;
  final String        description;
  final String        planName;
  final InvoiceCycle  cycle;
  final DateTime?     periodStart;
  final DateTime?     periodEnd;
  final String?       refundReason;
  final String?       failureReason;

  String get displayAmount {
    final dollars = amountCents ~/ 100;
    final cents   = amountCents % 100;
    final sign    = status == InvoiceStatus.refunded ? '−' : '';
    return '$sign\$$dollars.${cents.toString().padLeft(2, '0')}';
  }

  int get year => date.year;
}

// ─── Mock data ────────────────────────────────────────────────────────────────

List<Invoice> _buildMockInvoices() {
  final now = DateTime.now();
  return [
    Invoice(
      id:            'inv_01',
      invoiceNumber: 'INV-2026-0001',
      status:        InvoiceStatus.paid,
      amountCents:   4788,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 14)),
      description:   'ZapSafe Premium — Annual subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.annual,
      periodStart:   now.subtract(const Duration(days: 14)),
      periodEnd:     now.add(const Duration(days: 351)),
    ),
    Invoice(
      id:            'inv_02',
      invoiceNumber: 'INV-2025-0009',
      status:        InvoiceStatus.paid,
      amountCents:   4788,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 379)),
      description:   'ZapSafe Premium — Annual subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.annual,
      periodStart:   now.subtract(const Duration(days: 379)),
      periodEnd:     now.subtract(const Duration(days: 14)),
    ),
    Invoice(
      id:            'inv_03',
      invoiceNumber: 'INV-2025-0008',
      status:        InvoiceStatus.refunded,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 384)),
      description:   'Partial refund — cycle overlap on plan upgrade',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      refundReason:  'Prorated credit on switch from monthly to annual.',
    ),
    Invoice(
      id:            'inv_04',
      invoiceNumber: 'INV-2025-0007',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 414)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 414)),
      periodEnd:     now.subtract(const Duration(days: 384)),
    ),
    Invoice(
      id:            'inv_05',
      invoiceNumber: 'INV-2025-0006',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 444)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 444)),
      periodEnd:     now.subtract(const Duration(days: 414)),
    ),
    Invoice(
      id:            'inv_06',
      invoiceNumber: 'INV-2025-0005',
      status:        InvoiceStatus.failed,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 474)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      failureReason: 'Card declined — insufficient funds.',
    ),
    Invoice(
      id:            'inv_07',
      invoiceNumber: 'INV-2025-0004',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 504)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 504)),
      periodEnd:     now.subtract(const Duration(days: 474)),
    ),
    Invoice(
      id:            'inv_08',
      invoiceNumber: 'INV-2025-0003',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 534)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 534)),
      periodEnd:     now.subtract(const Duration(days: 504)),
    ),
    Invoice(
      id:            'inv_09',
      invoiceNumber: 'INV-2025-0002',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 564)),
      description:   'ZapSafe Premium — Monthly subscription',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 564)),
      periodEnd:     now.subtract(const Duration(days: 534)),
    ),
    Invoice(
      id:            'inv_10',
      invoiceNumber: 'INV-2025-0001',
      status:        InvoiceStatus.paid,
      amountCents:   499,
      currency:      'USD',
      date:          now.subtract(const Duration(days: 594)),
      description:   'ZapSafe Premium — First month (trial conversion)',
      planName:      'Premium',
      cycle:         InvoiceCycle.monthly,
      periodStart:   now.subtract(const Duration(days: 594)),
      periodEnd:     now.subtract(const Duration(days: 564)),
    ),
  ];
}

// ─── Billing stats ────────────────────────────────────────────────────────────

class BillingStats {
  const BillingStats({
    required this.totalPaidCents,
    required this.thisYearCents,
    required this.invoiceCount,
    required this.refundCount,
  });

  final int totalPaidCents;
  final int thisYearCents;
  final int invoiceCount;
  final int refundCount;

  String get totalPaidDisplay {
    final d = totalPaidCents ~/ 100;
    final c = totalPaidCents % 100;
    return '\$$d.${c.toString().padLeft(2, '0')}';
  }

  String get thisYearDisplay {
    final d = thisYearCents ~/ 100;
    final c = thisYearCents % 100;
    return '\$$d.${c.toString().padLeft(2, '0')}';
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class BillingHistoryState {
  const BillingHistoryState({
    required this.invoices,
    required this.statusFilter,
    required this.yearFilter,
    required this.downloadingIds,
    required this.emailingIds,
  });

  final List<Invoice>  invoices;
  final InvoiceStatus? statusFilter;   // null = all
  final int?           yearFilter;     // null = all years
  final Set<String>    downloadingIds;
  final Set<String>    emailingIds;

  BillingHistoryState copyWith({
    List<Invoice>?  invoices,
    InvoiceStatus?  statusFilter,
    bool            clearStatusFilter = false,
    int?            yearFilter,
    bool            clearYearFilter   = false,
    Set<String>?    downloadingIds,
    Set<String>?    emailingIds,
  }) {
    return BillingHistoryState(
      invoices:       invoices       ?? this.invoices,
      statusFilter:   clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      yearFilter:     clearYearFilter   ? null : (yearFilter   ?? this.yearFilter),
      downloadingIds: downloadingIds ?? this.downloadingIds,
      emailingIds:    emailingIds    ?? this.emailingIds,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class BillingHistoryNotifier extends StateNotifier<BillingHistoryState> {
  BillingHistoryNotifier()
      : super(BillingHistoryState(
          invoices:       _buildMockInvoices(),
          statusFilter:   null,
          yearFilter:     null,
          downloadingIds: const {},
          emailingIds:    const {},
        ));

  void setStatusFilter(InvoiceStatus? status) {
    if (status == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  void setYearFilter(int? year) {
    if (year == null) {
      state = state.copyWith(clearYearFilter: true);
    } else {
      state = state.copyWith(yearFilter: year);
    }
  }

  Future<void> downloadPdf(String id) async {
    final next = Set<String>.from(state.downloadingIds)..add(id);
    state = state.copyWith(downloadingIds: next);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final done = Set<String>.from(state.downloadingIds)..remove(id);
    state = state.copyWith(downloadingIds: done);
  }

  Future<void> emailReceipt(String id) async {
    final next = Set<String>.from(state.emailingIds)..add(id);
    state = state.copyWith(emailingIds: next);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final done = Set<String>.from(state.emailingIds)..remove(id);
    state = state.copyWith(emailingIds: done);
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final billingHistoryProvider =
    StateNotifierProvider<BillingHistoryNotifier, BillingHistoryState>(
  (ref) => BillingHistoryNotifier(),
);

final filteredInvoicesProvider = Provider<List<Invoice>>((ref) {
  final state = ref.watch(billingHistoryProvider);
  return state.invoices.where((inv) {
    if (state.statusFilter != null && inv.status != state.statusFilter) {
      return false;
    }
    if (state.yearFilter != null && inv.year != state.yearFilter) {
      return false;
    }
    return true;
  }).toList();
});

final availableYearsProvider = Provider<List<int>>((ref) {
  final invoices = ref.watch(billingHistoryProvider).invoices;
  final years    = invoices.map((i) => i.year).toSet().toList();
  years.sort((a, b) => b.compareTo(a));
  return years;
});

final billingStatsProvider = Provider<BillingStats>((ref) {
  final invoices    = ref.watch(billingHistoryProvider).invoices;
  final currentYear = DateTime.now().year;

  var totalPaid    = 0;
  var thisYear     = 0;
  var invoiceCount = 0;
  var refundCount  = 0;

  for (final inv in invoices) {
    if (inv.status == InvoiceStatus.paid) {
      totalPaid    += inv.amountCents;
      invoiceCount += 1;
      if (inv.year == currentYear) {
        thisYear += inv.amountCents;
      }
    } else if (inv.status == InvoiceStatus.refunded) {
      refundCount += 1;
    }
  }

  return BillingStats(
    totalPaidCents: totalPaid,
    thisYearCents:  thisYear,
    invoiceCount:   invoiceCount,
    refundCount:    refundCount,
  );
});
