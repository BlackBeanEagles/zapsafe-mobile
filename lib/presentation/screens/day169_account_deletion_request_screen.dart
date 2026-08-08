/// Day 169 — Account Deletion: Request Screen
///
/// First day of the Days 169-172 Account Deletion block.
/// Day 169: Deletion request — warnings, what gets deleted,
///           reason picker, re-auth gate, submit → 30-day grace start.
/// Day 170: Grace period UI — countdown, cancel, notifications.
/// Day 171: Permanent deletion confirmation + account wiped state.
/// Day 172: Edge cases — active SOS, evidence hold, DPDP retention.
///
/// 🟡 MOCK-NOW — backend at Day 78. No DELETE /api/v1/account endpoint yet.
///    Full API contract documented in Tab 3.
///    Replace _MockDeletionService calls when backend is ready.
///
/// Legal basis:
///   DPDP Act 2023 §13  — right to erasure of personal data.
///   GDPR Art. 17       — right to erasure ("right to be forgotten").
///   Retention caveat   — some data retained 30 days post-request
///                        for legal compliance before hard-delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider     = StateProvider<int>((ref) => 0);
final _flowStepProvider      = StateProvider<int>((ref) => 0);        // 0-3
final _ack1Provider          = StateProvider<bool>((ref) => false);
final _ack2Provider          = StateProvider<bool>((ref) => false);
final _ack3Provider          = StateProvider<bool>((ref) => false);
final _selectedReasonProvider= StateProvider<_DeletionReason?>((ref) => null);
final _otherReasonProvider   = StateProvider<String>((ref) => '');
final _phoneEnteredProvider  = StateProvider<String>((ref) => '');
final _otpEnteredProvider    = StateProvider<String>((ref) => '');
final _otpSentProvider       = StateProvider<bool>((ref) => false);
final _submitStateProvider   = StateProvider<_SubmitState>((ref) => _SubmitState.idle);
final _expandedDataProvider  = StateProvider<int?>((ref) => null);

// ── Enums ──────────────────────────────────────────────────────────────────────
enum _DeletionReason {
  privacyConcern,
  switchingApps,
  notUseful,
  tooManyNotifications,
  safetyCompleted,
  other,
}

enum _SubmitState { idle, sendingOtp, verifyingOtp, submitting, done, error }

// ── Data ───────────────────────────────────────────────────────────────────────
const _kReasons = [
  (_DeletionReason.privacyConcern,       'Privacy or data concern'),
  (_DeletionReason.switchingApps,        'Switching to another app'),
  (_DeletionReason.notUseful,            'App isn\'t useful for me'),
  (_DeletionReason.tooManyNotifications, 'Too many notifications'),
  (_DeletionReason.safetyCompleted,      'My safety situation has resolved'),
  (_DeletionReason.other,               'Other reason'),
];

class _DataCategory {
  final String   name;
  final IconData icon;
  final Color    color;
  final String   deletionTiming;   // "Immediately" | "After 30 days" | "Retained"
  final Color    timingColor;
  final List<String> items;
  const _DataCategory({
    required this.name, required this.icon, required this.color,
    required this.deletionTiming, required this.timingColor,
    required this.items,
  });
}

const _kDataCategories = [
  _DataCategory(
    name: 'Profile & Account',
    icon: Icons.account_circle_rounded,
    color: Color(0xFF3B82F6),
    deletionTiming: 'After 30 days',
    timingColor: Color(0xFFF59E0B),
    items: [
      'Name and display preferences',
      'Phone number and verification status',
      'Subscription / payment information',
      'App settings and language preferences',
    ],
  ),
  _DataCategory(
    name: 'Emergency Contacts',
    icon: Icons.people_rounded,
    color: Color(0xFF10B981),
    deletionTiming: 'After 30 days',
    timingColor: Color(0xFFF59E0B),
    items: [
      'All tier 1, 2, 3 contact records',
      'Contact verification status',
      'Escalation policy assignments',
    ],
  ),
  _DataCategory(
    name: 'SOS Events & Incidents',
    icon: Icons.warning_rounded,
    color: Color(0xFFEF4444),
    deletionTiming: 'After 30 days',
    timingColor: Color(0xFFF59E0B),
    items: [
      'SOS event timeline and metadata',
      'Dispatch records and contact responses',
      'DCS scores and detection logs',
      'Incident reports (if not filed with authorities)',
    ],
  ),
  _DataCategory(
    name: 'Evidence Vault',
    icon: Icons.lock_rounded,
    color: Color(0xFFF59E0B),
    deletionTiming: 'After 30 days',
    timingColor: Color(0xFFF59E0B),
    items: [
      'Audio recordings from SOS events',
      'GPS traces and location history',
      'IMU and sensor data streams',
      'SHA-256 integrity hashes',
    ],
  ),
  _DataCategory(
    name: 'Location & Safe Zones',
    icon: Icons.location_on_rounded,
    color: Color(0xFF10B981),
    deletionTiming: 'Immediately',
    timingColor: Color(0xFFEF4444),
    items: [
      'All defined safe zones (home/work/custom)',
      'Location history (GPS batch cache)',
      'Auto-learned location patterns',
    ],
  ),
  _DataCategory(
    name: 'Analytics & Consent Records',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF8B5CF6),
    deletionTiming: 'After 30 days',
    timingColor: Color(0xFFF59E0B),
    items: [
      'Usage analytics (if consented)',
      'Crash reports linked to account',
      'Consent timestamps and policy versions',
    ],
  ),
  _DataCategory(
    name: 'Legal / Compliance Hold',
    icon: Icons.gavel_rounded,
    color: Color(0xFF6B7280),
    deletionTiming: 'Retained — legal basis',
    timingColor: Color(0xFF6B7280),
    items: [
      'Evidence shared with law enforcement (if any)',
      'Billing records — required 7 years (GST Act)',
      'Anonymised crash logs (no personal linkage)',
      'Data Protection Board complaint records (if any)',
    ],
  ),
];

// ── Mock service ───────────────────────────────────────────────────────────────
class _MockDeletionService {
  /// Simulates POST /api/v1/account/send-otp (re-auth before deletion)
  static Future<void> sendOtp(String phone) =>
      Future.delayed(const Duration(milliseconds: 900));

  /// Simulates POST /api/v1/account/verify-otp
  static Future<bool> verifyOtp(String otp) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return otp == '123456' || otp.length == 6; // mock: any 6-digit passes
  }

  /// Simulates POST /api/v1/account/deletion-request
  /// Real: creates deletion job, sets status="pending_grace",
  ///       starts 30-day countdown, emails user, notifies emergency contacts.
  static Future<String> requestDeletion({
    required String reason,
    required String? otherNote,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return 'del_${DateTime.now().millisecondsSinceEpoch}';
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day169AccountDeletionRequestScreen extends ConsumerWidget {
  const Day169AccountDeletionRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Delete Account'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            ),
            child: const Text('DANGER ZONE',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) => ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _WhatGetsDeletedTab(),
            if (tab == 1) const _RequestFlowTab(),
            if (tab == 2) const _ApiContractTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF120808), Color(0xFF0A0505), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.55), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 169',         const Color(0xFFEF4444)),
          _badge('🟡 MOCK-NOW',         const Color(0xFFF59E0B)),
          _badge('Account Deletion  ·  Day 1/4', const Color(0xFF8B5CF6)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Delete Account\nRequest',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'DPDP Act 2023 §13 + GDPR Art. 17 right to erasure. '
          '30-day grace period before hard delete. Re-auth required. '
          'Some data retained for legal compliance.',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('4',    '4 warnings',     Color(0xFFEF4444)),
          _HStat('6',    '6 reasons',      Color(0xFFF59E0B)),
          _HStat('Re-auth', 'OTP gate',   Color(0xFF8B5CF6)),
          _HStat('30d',  'Grace period',   Color(0xFF10B981)),
        ]),
      ]),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]));
}

// ── Shared labels / TabBar ─────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _TabBar extends StatelessWidget {
  final int active; final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.delete_sweep_rounded, Color(0xFFEF4444), 'What\'s Deleted'),
      (Icons.assignment_rounded,   Color(0xFF8B5CF6), 'Request Flow'),
      (Icons.code_rounded,         Color(0xFFF59E0B), 'API Contract'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(right: i < 2 ? ZapSpacing.sm : 0),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isActive ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                    width: isActive ? 2 : 1)),
            child: Column(children: [
              Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
              const SizedBox(height: ZapSpacing.xs),
              Text(label, style: TextStyle(
                  color: isActive ? color : const Color(0xFF6B7280),
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        ),
      );
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — What Gets Deleted
// ══════════════════════════════════════════════════════════════════════════════
class _WhatGetsDeletedTab extends ConsumerWidget {
  const _WhatGetsDeletedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedDataProvider);

    final immediateCount = _kDataCategories
        .where((c) => c.deletionTiming == 'Immediately').length;
    final after30Count = _kDataCategories
        .where((c) => c.deletionTiming == 'After 30 days').length;
    final retainedCount = _kDataCategories
        .where((c) => c.deletionTiming.startsWith('Retained')).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFFEF4444),
          text: 'A full breakdown of every data type ZapSafe holds and exactly '
              'when it is deleted. Tap any category to expand. '
              '"After 30 days" means the grace period — you can cancel deletion '
              'before day 30 to keep all data.'),
      const SizedBox(height: ZapSpacing.lg),

      // Legend strip
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Row(children: [
            _legendDot(const Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Expanded(child: Text('Immediately ($immediateCount category) '
                '— deleted as soon as request is confirmed.',
                style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            _legendDot(const Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Expanded(child: Text('After 30 days ($after30Count categories) '
                '— kept during grace period, hard-deleted on day 30.',
                style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            _legendDot(const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Expanded(child: Text('Retained — legal basis ($retainedCount category) '
                '— never deleted (GST billing / law enforcement).',
                style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11))),
          ]),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('7 DATA CATEGORIES  ·  TAP TO EXPAND'),
      const SizedBox(height: ZapSpacing.md),

      ..._kDataCategories.asMap().entries.map((e) {
        final i   = e.key;
        final cat = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedDataProvider.notifier).state =
              isExp ? null : i,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
                color: isExp ? cat.color.withOpacity(0.06) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isExp ? cat.color.withOpacity(0.4) : const Color(0xFF2A2A2A),
                    width: isExp ? 2 : 1)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(cat.icon, color: cat.color, size: 16)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cat.name, style: const TextStyle(color: Colors.white,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: cat.timingColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text(cat.deletionTiming, style: TextStyle(
                          color: cat.timingColor, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ])),
                  Icon(isExp ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF4B5563), size: 16),
                ]),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isExp
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                            ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                        child: Container(
                          padding: const EdgeInsets.all(ZapSpacing.md),
                          decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius:
                                  BorderRadius.circular(ZapSpacing.radiusSmall),
                              border: Border.all(color: const Color(0xFF2A2A2A))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: cat.items.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Icon(Icons.circle, color: cat.color,
                                          size: 5),
                                      const SizedBox(width: ZapSpacing.sm),
                                      Expanded(child: Text(item,
                                          style: const TextStyle(
                                              color: Color(0xFFD1D5DB),
                                              fontSize: 11, height: 1.5))),
                                    ]),
                                  )).toList()),
                        ))
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        );
      }),

      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.gavel_rounded, color: const Color(0xFF6B7280),
          text: 'Billing records are retained for 7 years under the GST Act 2017 '
              'regardless of account deletion. Evidence shared with law enforcement '
              'cannot be deleted once submitted. Anonymised crash logs have no '
              'personal linkage — they remain for product safety.'),
    ]);
  }

  static Widget _legendDot(Color c) => Container(
      width: 10, height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Request Flow (4-step wizard)
// ══════════════════════════════════════════════════════════════════════════════
class _RequestFlowTab extends ConsumerWidget {
  const _RequestFlowTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step        = ref.watch(_flowStepProvider);
    final submitState = ref.watch(_submitStateProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.assignment_rounded, color: const Color(0xFF8B5CF6),
          text: 'Four-step deletion wizard. Each step must be completed before '
              'proceeding. Re-authentication (OTP) is required in Step 3 to '
              'prevent accidental or unauthorised deletions.'),
      const SizedBox(height: ZapSpacing.lg),

      // Step indicator
      _StepIndicator(current: step),
      const SizedBox(height: ZapSpacing.xl),

      // Step content
      if (step == 0) _Step0Warnings(ref: ref),
      if (step == 1) _Step1Reason(ref: ref),
      if (step == 2) _Step2ReAuth(ref: ref),
      if (step == 3) _Step3Confirm(ref: ref, submitState: submitState),
    ]);
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    const labels = ['Warnings', 'Reason', 'Verify', 'Confirm'];
    return Row(children: List.generate(labels.length * 2 - 1, (i) {
      if (i.isOdd) {
        final passed = current > i ~/ 2;
        return Expanded(child: Container(height: 2,
            color: passed ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A)));
      }
      final idx    = i ~/ 2;
      final isDone = current > idx;
      final isNow  = current == idx;
      final color  = isDone || isNow ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A);
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: color.withOpacity(isNow ? 0.15 : isDone ? 0.08 : 0.0),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isNow ? 2 : 1.5)),
          child: isDone
              ? const Icon(Icons.check, color: Color(0xFFEF4444), size: 14)
              : Center(child: Text('${idx + 1}',
                  style: TextStyle(color: color, fontSize: 11,
                      fontWeight: FontWeight.w800)))),
        const SizedBox(height: ZapSpacing.xs),
        Text(labels[idx], style: TextStyle(
            color: isNow || isDone ? const Color(0xFFEF4444) : const Color(0xFF4B5563),
            fontSize: 8, fontWeight: isNow ? FontWeight.w700 : FontWeight.w400)),
      ]);
    }));
  }
}

// ── Step 0: Warnings ───────────────────────────────────────────────────────────
class _Step0Warnings extends ConsumerWidget {
  final WidgetRef ref;
  const _Step0Warnings({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ack1 = ref.watch(_ack1Provider);
    final ack2 = ref.watch(_ack2Provider);
    final ack3 = ref.watch(_ack3Provider);
    final allAcked = ack1 && ack2 && ack3;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('STEP 1 OF 4  ·  READ ALL WARNINGS'),
      const SizedBox(height: ZapSpacing.md),

      // Big warning header
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5), width: 2),
        ),
        child: const Column(children: [
          Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 40),
          SizedBox(height: ZapSpacing.md),
          Text('This action starts the 30-day deletion process.',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'After 30 days, your account and nearly all personal data will be '
            'permanently and irreversibly deleted. You can cancel at any time '
            'before day 30 to restore your account fully.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Three acknowledgement checkboxes
      const _SectionLabel('ACKNOWLEDGEMENTS  ·  ALL 3 REQUIRED'),
      const SizedBox(height: ZapSpacing.md),
      _AckRow(
        checked: ack1,
        text: 'I understand that after 30 days, my SOS history, evidence vault, '
            'emergency contacts, and all personal data will be permanently deleted.',
        onChanged: (v) => ref.read(_ack1Provider.notifier).state = v,
      ),
      const SizedBox(height: ZapSpacing.sm),
      _AckRow(
        checked: ack2,
        text: 'I understand that once deleted, ZapSafe cannot recover my data. '
            'I should download a copy now (Settings → Download My Data) if I want it.',
        onChanged: (v) => ref.read(_ack2Provider.notifier).state = v,
      ),
      const SizedBox(height: ZapSpacing.sm),
      _AckRow(
        checked: ack3,
        text: 'I understand that my emergency contacts will receive a notification '
            'that I am leaving ZapSafe, and they will be removed from my contact list.',
        onChanged: (v) => ref.read(_ack3Provider.notifier).state = v,
      ),
      const SizedBox(height: ZapSpacing.xl),

      _primaryBtn(
        label: allAcked ? 'Continue  →  Select Reason' : 'Acknowledge all 3 warnings to continue',
        color: allAcked ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A),
        onTap: allAcked
            ? () => ref.read(_flowStepProvider.notifier).state = 1
            : null,
      ),
    ]);
  }
}

class _AckRow extends StatelessWidget {
  final bool checked;
  final String text;
  final ValueChanged<bool> onChanged;
  const _AckRow({required this.checked, required this.text, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: checked
                ? const Color(0xFFEF4444).withOpacity(0.07)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: checked
                    ? const Color(0xFFEF4444).withOpacity(0.4)
                    : const Color(0xFF2A2A2A),
                width: checked ? 2 : 1)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22, height: 22,
            decoration: BoxDecoration(
                color: checked ? const Color(0xFFEF4444) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: checked ? const Color(0xFFEF4444) : const Color(0xFF3A3A3A),
                    width: 2)),
            child: checked
                ? const Icon(Icons.check, color: Colors.white, size: 13)
                : null),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Text(text, style: const TextStyle(
              color: Color(0xFFD1D5DB), fontSize: 12, height: 1.5))),
        ]),
      ),
    );
  }
}

// ── Step 1: Reason ─────────────────────────────────────────────────────────────
class _Step1Reason extends ConsumerWidget {
  final WidgetRef ref;
  const _Step1Reason({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected    = ref.watch(_selectedReasonProvider);
    final otherNote   = ref.watch(_otherReasonProvider);
    final canContinue = selected != null &&
        (selected != _DeletionReason.other || otherNote.trim().isNotEmpty);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('STEP 2 OF 4  ·  REASON FOR LEAVING'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.help_outline_rounded, color: const Color(0xFF8B5CF6),
          text: 'Your reason helps ZapSafe improve. This is optional data and '
              'will be deleted with your account. It is never used for advertising.'),
      const SizedBox(height: ZapSpacing.lg),

      ..._kReasons.map((r) {
        final (reason, label) = r;
        final isSelected = selected == reason;
        return GestureDetector(
          onTap: () => ref.read(_selectedReasonProvider.notifier).state = reason,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 13),
            decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B5CF6).withOpacity(0.1)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B5CF6).withOpacity(0.5)
                        : const Color(0xFF2A2A2A),
                    width: isSelected ? 2 : 1)),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 20, height: 20,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF3A3A3A),
                        width: 2),
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.transparent)),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Text(label, style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400))),
            ]),
          ),
        );
      }),

      // "Other" text field
      if (selected == _DeletionReason.other) ...[
        const SizedBox(height: ZapSpacing.sm),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4))),
          child: TextField(
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
                hintText: 'Please tell us more (optional but helpful)…',
                hintStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 12),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
            onChanged: (v) =>
                ref.read(_otherReasonProvider.notifier).state = v,
          ),
        ),
      ],
      const SizedBox(height: ZapSpacing.xl),

      Row(children: [
        Expanded(child: _outlineBtn('← Back', const Color(0xFF6B7280),
            () => ref.read(_flowStepProvider.notifier).state = 0)),
        const SizedBox(width: ZapSpacing.md),
        Expanded(flex: 2, child: _primaryBtn(
          label: canContinue ? 'Continue  →  Verify Identity' : 'Select a reason',
          color: canContinue ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A),
          onTap: canContinue
              ? () => ref.read(_flowStepProvider.notifier).state = 2
              : null,
        )),
      ]),
    ]);
  }
}

// ── Step 2: Re-Auth ────────────────────────────────────────────────────────────
class _Step2ReAuth extends ConsumerWidget {
  final WidgetRef ref;
  const _Step2ReAuth({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone       = ref.watch(_phoneEnteredProvider);
    final otp         = ref.watch(_otpEnteredProvider);
    final otpSent     = ref.watch(_otpSentProvider);
    final submitState = ref.watch(_submitStateProvider);

    final phoneValid  = phone.replaceAll(RegExp(r'\D'), '').length >= 10;
    final otpValid    = otp.length == 6;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('STEP 3 OF 4  ·  VERIFY YOUR IDENTITY'),
      const SizedBox(height: ZapSpacing.md),
      _infoBox(icon: Icons.security_rounded, color: const Color(0xFF8B5CF6),
          text: 'ZapSafe requires OTP verification before processing a deletion '
              'request to prevent unauthorised account deletions. '
              'Enter the phone number on your account and the OTP sent to it.'),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('PHONE NUMBER (on your account)'),
      const SizedBox(height: ZapSpacing.md),
      _inputField(
        hint: '+91 98765 43210',
        keyboardType: TextInputType.phone,
        onChanged: (v) => ref.read(_phoneEnteredProvider.notifier).state = v,
      ),
      const SizedBox(height: ZapSpacing.md),

      if (!otpSent) ...[
        _primaryBtn(
          label: submitState == _SubmitState.sendingOtp
              ? 'Sending OTP…'
              : 'Send OTP',
          color: phoneValid ? const Color(0xFF8B5CF6) : const Color(0xFF2A2A2A),
          loading: submitState == _SubmitState.sendingOtp,
          onTap: phoneValid && submitState != _SubmitState.sendingOtp
              ? () async {
                  ref.read(_submitStateProvider.notifier).state =
                      _SubmitState.sendingOtp;
                  await _MockDeletionService.sendOtp(phone);
                  if (context.mounted) {
                    ref.read(_otpSentProvider.notifier).state = true;
                    ref.read(_submitStateProvider.notifier).state =
                        _SubmitState.idle;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Mock OTP: 123456'),
                      backgroundColor: Color(0xFF8B5CF6),
                      duration: Duration(seconds: 3)));
                  }
                }
              : null,
        ),
      ],

      if (otpSent) ...[
        const SizedBox(height: ZapSpacing.lg),
        const _SectionLabel('ENTER OTP (sent to your phone)'),
        const SizedBox(height: ZapSpacing.md),
        _OtpInput(onChanged: (v) =>
            ref.read(_otpEnteredProvider.notifier).state = v),
        const SizedBox(height: ZapSpacing.sm),
        const Text('Mock OTP is 123456',
            style: TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
        const SizedBox(height: ZapSpacing.xl),
        Row(children: [
          Expanded(child: _outlineBtn('← Back', const Color(0xFF6B7280),
              () => ref.read(_flowStepProvider.notifier).state = 1)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(flex: 2, child: _primaryBtn(
            label: submitState == _SubmitState.verifyingOtp
                ? 'Verifying…'
                : (otpValid ? 'Verify & Continue →' : 'Enter 6-digit OTP'),
            color: otpValid ? const Color(0xFFEF4444) : const Color(0xFF2A2A2A),
            loading: submitState == _SubmitState.verifyingOtp,
            onTap: otpValid && submitState != _SubmitState.verifyingOtp
                ? () async {
                    ref.read(_submitStateProvider.notifier).state =
                        _SubmitState.verifyingOtp;
                    final ok = await _MockDeletionService.verifyOtp(otp);
                    if (context.mounted) {
                      if (ok) {
                        ref.read(_flowStepProvider.notifier).state = 3;
                        ref.read(_submitStateProvider.notifier).state =
                            _SubmitState.idle;
                      } else {
                        ref.read(_submitStateProvider.notifier).state =
                            _SubmitState.error;
                      }
                    }
                  }
                : null,
          )),
        ]),
      ],

      if (!otpSent) ...[
        const SizedBox(height: ZapSpacing.md),
        _outlineBtn('← Back', const Color(0xFF6B7280),
            () => ref.read(_flowStepProvider.notifier).state = 1),
      ],
    ]);
  }
}

class _OtpInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _OtpInput({required this.onChanged});
  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4))),
      child: TextField(
        controller: _ctrl,
        maxLength: 6,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 22,
            fontWeight: FontWeight.w700, letterSpacing: 8),
        decoration: const InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: Color(0xFF2A2A2A), fontSize: 22,
                letterSpacing: 8),
            border: InputBorder.none,
            counterText: ''),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ── Step 3: Final Confirm ──────────────────────────────────────────────────────
class _Step3Confirm extends ConsumerWidget {
  final WidgetRef ref;
  final _SubmitState submitState;
  const _Step3Confirm({required this.ref, required this.submitState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason      = ref.watch(_selectedReasonProvider);
    final submitState = ref.watch(_submitStateProvider);

    if (submitState == _SubmitState.done) {
      return _SuccessCard();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('STEP 4 OF 4  ·  FINAL CONFIRMATION'),
      const SizedBox(height: ZapSpacing.md),

      // Summary card
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your deletion request summary',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: ZapSpacing.md),
          _kv('Account', '+91 98765 43210'),
          _kv('Identity', 'Verified via OTP ✅'),
          _kv('Reason', _reasonLabel(reason)),
          _kv('Grace period', '30 days'),
          _kv('Hard-delete on', _thirtyDaysFromNow()),
          _kv('DPDP basis', '§13 — Right to Erasure'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),

      // Timeline visual
      const _SectionLabel('WHAT HAPPENS NEXT'),
      const SizedBox(height: ZapSpacing.md),
      _TimelineCard(),
      const SizedBox(height: ZapSpacing.xl),

      // Final warning
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5))),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 18),
          SizedBox(width: ZapSpacing.sm),
          Expanded(child: Text(
            'After you tap "Start 30-Day Deletion" below, your account will enter '
            'the grace period immediately. Emergency contacts will be notified. '
            'You can still cancel at any point before day 30.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
        ]),
      ),
      const SizedBox(height: ZapSpacing.xl),

      if (submitState == _SubmitState.submitting)
        _statusCard(Icons.hourglass_top_rounded, const Color(0xFFEF4444),
            'Submitting deletion request…',
            'Creating grace-period job. Notifying emergency contacts.',
            loading: true)
      else if (submitState == _SubmitState.error)
        _statusCard(Icons.error_outline_rounded, const Color(0xFFEF4444),
            'Request failed',
            'Network error. Tap "Try Again" to retry.',
            loading: false)
      else
        _primaryBtn(
          label: 'Start 30-Day Deletion  ⚠',
          color: const Color(0xFFEF4444),
          onTap: () async {
            ref.read(_submitStateProvider.notifier).state = _SubmitState.submitting;
            try {
              await _MockDeletionService.requestDeletion(
                  reason: reason?.name ?? 'other', otherNote: null);
              if (context.mounted) {
                ref.read(_submitStateProvider.notifier).state = _SubmitState.done;
              }
            } catch (_) {
              if (context.mounted) {
                ref.read(_submitStateProvider.notifier).state = _SubmitState.error;
              }
            }
          },
        ),

      if (submitState == _SubmitState.error) ...[
        const SizedBox(height: ZapSpacing.sm),
        _outlineBtn('← Back', const Color(0xFF6B7280),
            () => ref.read(_submitStateProvider.notifier).state = _SubmitState.idle),
      ],
      const SizedBox(height: ZapSpacing.md),
      if (submitState != _SubmitState.submitting && submitState != _SubmitState.done)
        _outlineBtn('← Back', const Color(0xFF6B7280),
            () => ref.read(_flowStepProvider.notifier).state = 2),
    ]);
  }

  static String _reasonLabel(_DeletionReason? r) => switch (r) {
    _DeletionReason.privacyConcern       => 'Privacy or data concern',
    _DeletionReason.switchingApps        => 'Switching to another app',
    _DeletionReason.notUseful            => 'App isn\'t useful for me',
    _DeletionReason.tooManyNotifications => 'Too many notifications',
    _DeletionReason.safetyCompleted      => 'Safety situation resolved',
    _DeletionReason.other                => 'Other',
    null                                 => '—',
  };

  static String _thirtyDaysFromNow() {
    final d = DateTime.now().add(const Duration(days: 30));
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _TimelineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const events = [
      (Color(0xFFEF4444), 'Now',       'Request submitted. Grace period starts. '
          'Emergency contacts notified by email.'),
      (Color(0xFFF59E0B), 'Days 1-29', 'Account is suspended but data intact. '
          '"Cancel Deletion" available in app. Export still available.'),
      (Color(0xFF8B5CF6), 'Day 30',    'Hard-delete executed. All data erased '
          'except billing records (legal retention). Account gone.'),
      (Color(0xFF6B7280), 'Day 30+',   'Anonymised aggregate stats and billing '
          'records retained. No personal data. Account cannot be recovered.'),
    ];
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(children: events.asMap().entries.map((e) {
        final i = e.key;
        final (color, label, body) = e.value;
        return Padding(
          padding: EdgeInsets.only(bottom: i < events.length - 1 ? ZapSpacing.md : 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              if (i < events.length - 1)
                Container(width: 2, height: 36, color: const Color(0xFF2A2A2A)),
            ]),
            const SizedBox(width: ZapSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: color, fontSize: 10,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
                  fontSize: 11, height: 1.5)),
            ])),
          ]),
        );
      }).toList()),
    );
  }
}

class _SuccessCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFEF4444).withOpacity(0.10),
          const Color(0xFFEF4444).withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.45), width: 2),
      ),
      child: Column(children: [
        const Text('⏳', style: TextStyle(fontSize: 44)),
        const SizedBox(height: ZapSpacing.md),
        const Text('30-Day Grace Period Started',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 15,
                fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          'Deletion request ID: del_${DateTime.now().millisecondsSinceEpoch}\n'
          'Your account and data will be permanently deleted in 30 days.\n'
          'You can cancel at any time from Settings → Account.',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, height: 1.6),
          textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.lg),
        const Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _Chip('Grace period ⏳', Color(0xFFF59E0B)),
          _Chip('Contacts notified 📧', Color(0xFF3B82F6)),
          _Chip('Exports still available 📦', Color(0xFF8B5CF6)),
          _Chip('Cancel before day 30 ↩', Color(0xFF10B981)),
        ]),
        const SizedBox(height: ZapSpacing.lg),
        const Text('Day 170 → Grace Period UI with live countdown',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.md),
        GestureDetector(
          onTap: () {
            ref.read(_flowStepProvider.notifier).state = 0;
            ref.read(_submitStateProvider.notifier).state = _SubmitState.idle;
            ref.read(_ack1Provider.notifier).state = false;
            ref.read(_ack2Provider.notifier).state = false;
            ref.read(_ack3Provider.notifier).state = false;
            ref.read(_selectedReasonProvider.notifier).state = null;
            ref.read(_otpSentProvider.notifier).state = false;
            ref.read(_otpEnteredProvider.notifier).state = '';
            ref.read(_phoneEnteredProvider.notifier).state = '';
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF2A2A2A))),
            child: const Text('Reset demo',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 11))),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w600)));
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — API Contract
// ══════════════════════════════════════════════════════════════════════════════
class _ApiContractTab extends StatelessWidget {
  const _ApiContractTab();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.code_rounded, color: const Color(0xFFF59E0B),
          text: 'Backend at Day 78. No account-deletion endpoints exist yet. '
              'Document here for zero-conflict implementation. '
              'Replace _MockDeletionService calls in _Step2ReAuth and _Step3Confirm.'),
      const SizedBox(height: ZapSpacing.lg),

      const _SectionLabel('ENDPOINT 1 — SEND OTP (RE-AUTH)'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// POST /api/v1/account/send-deletion-otp
// Auth: Bearer JWT required
// Purpose: Re-authenticate user before accepting deletion request.
//          Separate endpoint from normal login OTP to make auditable.

// REQUEST
{ "phone": "+919876543210" }

// RESPONSE 200
{
  "otp_sent": true,
  "expires_in_seconds": 300,
  "masked_phone": "+91 ****3210"
}

// RESPONSE 429  (OTP rate limit — max 3 per hour)
{ "error": "otp_rate_limit", "retry_after_seconds": 3600 }'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 2 — VERIFY OTP'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// POST /api/v1/account/verify-deletion-otp
// Auth: Bearer JWT required

// REQUEST
{ "phone": "+919876543210", "otp": "123456" }

// RESPONSE 200
{
  "verified": true,
  "deletion_token": "dtok_abc123",  // short-lived, used in Step 3
  "token_expires_at": "2026-05-30T14:50:00Z"
}

// RESPONSE 400  (wrong OTP)
{ "error": "otp_invalid", "attempts_remaining": 2 }

// RESPONSE 403  (too many wrong attempts)
{ "error": "otp_locked", "unlock_at": "2026-05-30T15:00:00Z" }'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 3 — SUBMIT DELETION REQUEST'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// POST /api/v1/account/deletion-request
// Auth: Bearer JWT required
// Requires: deletion_token from Endpoint 2 (expires in 10 min)

// REQUEST
{
  "deletion_token": "dtok_abc123",
  "reason": "privacy_concern",       // enum from _DeletionReason
  "other_note": null                 // string | null (if reason == "other")
}

// RESPONSE 202 Accepted
{
  "deletion_id": "del_20260530_xyz",
  "status": "pending_grace",
  "grace_period_ends_at": "2026-06-29T14:30:00Z",
  "hard_delete_at": "2026-06-29T14:30:00Z",
  "contacts_notified": true
}

// RESPONSE 409 — active SOS event in progress
{ "error": "active_sos", "sos_id": "sos_001", "message": "Resolve active SOS first" }

// RESPONSE 409 — evidence under legal hold
{ "error": "evidence_hold", "hold_until": "2026-12-01", "reason": "law_enforcement" }'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 4 — GET DELETION STATUS'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// GET /api/v1/account/deletion-status
// Auth: Bearer JWT required
// Used by Day 170 Grace Period screen to show countdown.

// RESPONSE 200  (grace period active)
{
  "deletion_id": "del_20260530_xyz",
  "status": "pending_grace",          // "pending_grace" | "deleted" | "cancelled"
  "requested_at": "2026-05-30T14:30:00Z",
  "grace_period_ends_at": "2026-06-29T14:30:00Z",
  "days_remaining": 29,
  "can_cancel": true
}

// RESPONSE 200  (cancelled)
{
  "deletion_id": "del_20260530_xyz",
  "status": "cancelled",
  "cancelled_at": "2026-06-01T09:00:00Z",
  "cancelled_by": "user"
}

// RESPONSE 404  (no active deletion)
{ "error": "no_deletion_request" }'''),

      const SizedBox(height: ZapSpacing.lg),
      const _SectionLabel('ENDPOINT 5 — CANCEL DELETION'),
      const SizedBox(height: ZapSpacing.md),
      _code(context, '''// DELETE /api/v1/account/deletion-request
// Auth: Bearer JWT required
// Used by Day 170 "Cancel Deletion" button.

// RESPONSE 200
{
  "deletion_id": "del_20260530_xyz",
  "status": "cancelled",
  "account_restored": true,
  "message": "Your account has been fully restored."
}

// RESPONSE 409  (too late — past grace period)
{
  "error": "deletion_completed",
  "deleted_at": "2026-06-29T14:30:00Z",
  "message": "Account has already been permanently deleted."
}'''),

      const SizedBox(height: ZapSpacing.lg),
      // Integration map
      const _SectionLabel('FRONTEND INTEGRATION MAP'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          _integRow(const Color(0xFF8B5CF6), '_MockDeletionService.sendOtp()',
              'POST /api/v1/account/send-deletion-otp'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _integRow(const Color(0xFF3B82F6), '_MockDeletionService.verifyOtp()',
              'POST /api/v1/account/verify-deletion-otp'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _integRow(const Color(0xFFEF4444), '_MockDeletionService.requestDeletion()',
              'POST /api/v1/account/deletion-request'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _integRow(const Color(0xFFF59E0B), 'Day 170 countdown provider',
              'GET /api/v1/account/deletion-status'),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          _integRow(const Color(0xFF10B981), 'Day 170 cancel button',
              'DELETE /api/v1/account/deletion-request'),
        ]),
      ),
      const SizedBox(height: ZapSpacing.lg),
      _infoBox(icon: Icons.info_outline_rounded, color: const Color(0xFF3B82F6),
          text: 'Day 170 builds the Grace Period countdown screen. '
              'Day 171 covers the permanent deletion confirmation. '
              'Day 172 covers edge cases: active SOS block, evidence hold, '
              'DPDP 30-day retention requirement.'),
    ]);
  }

  static Widget _integRow(Color color, String mock, String real) => Padding(
      padding: const EdgeInsets.all(ZapSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mock, style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        const SizedBox(height: 3),
        Text('→ Replace with: $real',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
      ]));
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color,
    VoidCallback? onTap, bool loading = false}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            gradient: onTap != null
                ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                : null,
            color: onTap == null ? const Color(0xFF1A1A1A) : null,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: onTap != null
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                    offset: const Offset(0, 4))]
                : null,
            border: onTap == null
                ? Border.all(color: const Color(0xFF2A2A2A)) : null),
        child: loading
            ? const Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: TextStyle(
                    color: onTap != null ? Colors.white : const Color(0xFF4B5563),
                    fontSize: 13, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ]),
      ),
    );

Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label,
            style: TextStyle(color: color, fontSize: 12,
                fontWeight: FontWeight.w600)))));

Widget _inputField({required String hint,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: TextField(
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
            border: InputBorder.none),
        onChanged: onChanged,
      ));

Widget _statusCard(IconData icon, Color color, String title, String body,
    {required bool loading}) =>
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          loading
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(title, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(body, style: const TextStyle(color: Color(0xFF9CA3AF),
            fontSize: 11, height: 1.5)),
      ]));

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text, style: const TextStyle(
            color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]));

Widget _code(BuildContext context, String code) => GestureDetector(
    onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Copied'), backgroundColor: Color(0xFF1A1A1A),
        duration: Duration(seconds: 1))),
    child: Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF2A2A2A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('long-press to copy',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 9))),
          Icon(Icons.copy_rounded, color: Color(0xFF4B5563), size: 12),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        Text(code, style: const TextStyle(color: Color(0xFF86EFAC),
            fontSize: 10, fontFamily: 'monospace', height: 1.6)),
      ])));

Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 100, child: Text(k, style: const TextStyle(
          color: Color(0xFF6B7280), fontSize: 10))),
      Expanded(child: Text(v, style: const TextStyle(
          color: Color(0xFFD1D5DB), fontSize: 10, fontFamily: 'monospace'))),
    ]));
