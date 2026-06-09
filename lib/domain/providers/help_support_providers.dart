/// Day 99 — Help & Support state.
///
/// FAQ catalogue (10 items, 4 categories), single-open accordion,
/// contact form with topic selector and 1.2 s send mock,
/// and static app-info block (version, server status).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── FAQ category ─────────────────────────────────────────────────────────────

enum FaqCategory { all, sos, privacy, subscription, technical }

extension FaqCategoryX on FaqCategory {
  String get label {
    switch (this) {
      case FaqCategory.all:          return 'All';
      case FaqCategory.sos:          return 'SOS & Emergency';
      case FaqCategory.privacy:      return 'Privacy & Data';
      case FaqCategory.subscription: return 'Subscription';
      case FaqCategory.technical:    return 'Technical';
    }
  }
}

// ─── FAQ model ────────────────────────────────────────────────────────────────

class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  final String      id;
  final String      question;
  final String      answer;
  final FaqCategory category;
}

const kFaqItems = <FaqItem>[
  // ── SOS & Emergency ────────────────────────────────────────────────────────
  FaqItem(
    id:       'faq_01',
    question: 'How do I trigger an SOS?',
    answer:   'Press and hold the red SOS button for 2 seconds. A 15-second countdown begins — your Tier 1 contact is notified immediately. If you do nothing, full escalation fires automatically.',
    category: FaqCategory.sos,
  ),
  FaqItem(
    id:       'faq_02',
    question: 'What happens when SOS is triggered?',
    answer:   'ZapSafe simultaneously sends a high-priority SMS to all Tier 1 contacts, begins GPS location streaming, starts audio + video evidence capture, and triggers the on-device DCS alarm. Your Tier 1 contact can acknowledge within 30 seconds to pause escalation.',
    category: FaqCategory.sos,
  ),
  FaqItem(
    id:       'faq_03',
    question: 'Can I cancel a false alarm?',
    answer:   'Yes — tap "Cancel SOS" on the active alert screen within the 15-second countdown. After that window your Tier 1 contact must send a "Safe" response to stop further escalation. You can also use your duress PIN to silently flag the cancellation as coerced.',
    category: FaqCategory.sos,
  ),
  // ── Privacy & Data ──────────────────────────────────────────────────────────
  FaqItem(
    id:       'faq_04',
    question: 'Where is my data stored?',
    answer:   'All personal data is AES-256 encrypted at rest and stored on servers located in India (Mumbai AWS region). Evidence recordings are stored in a separate tamper-evident vault with SHA-256 integrity hashing.',
    category: FaqCategory.privacy,
  ),
  FaqItem(
    id:       'faq_05',
    question: 'How do I delete my account and all data?',
    answer:   'Go to Account → Privacy & Consent → Request Data Deletion. A 7-day grace period applies before permanent deletion. You can cancel the request at any time during this window.',
    category: FaqCategory.privacy,
  ),
  // ── Subscription ───────────────────────────────────────────────────────────
  FaqItem(
    id:       'faq_06',
    question: 'What does Premium include?',
    answer:   'Premium unlocks unlimited emergency contacts (vs 3 on Free), 5 GB evidence vault (vs 500 MB), priority SMS delivery, 10 check-in timers (vs 1), 10 safe zones (vs 1), and direct support with 4-hour response time.',
    category: FaqCategory.subscription,
  ),
  FaqItem(
    id:       'faq_07',
    question: 'How do I cancel my subscription?',
    answer:   'Go to Account → Subscription Management → Cancel Subscription. Your access continues until the end of the current billing period. Annual plans are non-refundable after 14 days.',
    category: FaqCategory.subscription,
  ),
  // ── Technical ──────────────────────────────────────────────────────────────
  FaqItem(
    id:       'faq_08',
    question: 'ZapSafe is draining my battery',
    answer:   'ZapSafe uses adaptive detection — on lower-tier devices it switches from AI to heuristic mode, reducing CPU usage by ~60%. Go to Settings → DCS Sensitivity → Low if battery life is critical. Enabling Battery Saver mode disables background audio capture.',
    category: FaqCategory.technical,
  ),
  FaqItem(
    id:       'faq_09',
    question: "I'm not receiving SOS notifications",
    answer:   'Check that ZapSafe has Notification permission (phone Settings → Apps → ZapSafe → Notifications). Also confirm Do Not Disturb is disabled or has ZapSafe as an exception. If issues persist, re-register your FCM token in Settings → Notifications → Re-register.',
    category: FaqCategory.technical,
  ),
  FaqItem(
    id:       'faq_10',
    question: 'How accurate is the AI detection?',
    answer:   'The DCS engine achieves 94.2% precision on our validation set (scream detection: 96.1%, fall detection: 91.3%, scene classification: 95.0%). A 3-window voting mechanism filters false positives — only repeated high-confidence events trigger SOS.',
    category: FaqCategory.technical,
  ),
];

// ─── Support topic ────────────────────────────────────────────────────────────

enum SupportTopic { sosIssue, accountIssue, billing, bugReport, other }

extension SupportTopicX on SupportTopic {
  String get label {
    switch (this) {
      case SupportTopic.sosIssue:     return 'SOS Not Working';
      case SupportTopic.accountIssue: return 'Account Issue';
      case SupportTopic.billing:      return 'Billing & Subscription';
      case SupportTopic.bugReport:    return 'App Crash / Bug';
      case SupportTopic.other:        return 'Other';
    }
  }
}

// ─── App info ─────────────────────────────────────────────────────────────────

class AppInfo {
  const AppInfo({
    required this.version,
    required this.build,
    required this.serverStatus,
    required this.lastSync,
  });

  final String version;
  final String build;
  final String serverStatus; // 'operational' | 'degraded' | 'outage'
  final String lastSync;
}

const kAppInfo = AppInfo(
  version:      '1.0.0-beta',
  build:        '2026.05.28',
  serverStatus: 'operational',
  lastSync:     'Just now',
);

// ─── State ───────────────────────────────────────────────────────────────────

class HelpSupportState {
  const HelpSupportState({
    required this.activeCategory,
    required this.expandedFaqId,
    required this.selectedTopic,
    required this.message,
    required this.isSending,
    required this.sentSuccess,
  });

  final FaqCategory  activeCategory;
  final String?      expandedFaqId;
  final SupportTopic? selectedTopic;
  final String       message;
  final bool         isSending;
  final bool         sentSuccess;

  bool get canSend =>
      selectedTopic != null &&
      message.trim().length >= 10 &&
      !isSending &&
      !sentSuccess;

  HelpSupportState copyWith({
    FaqCategory?   activeCategory,
    String?        expandedFaqId,
    bool           clearExpandedFaqId = false,
    SupportTopic?  selectedTopic,
    bool           clearSelectedTopic = false,
    String?        message,
    bool?          isSending,
    bool?          sentSuccess,
  }) {
    return HelpSupportState(
      activeCategory: activeCategory ?? this.activeCategory,
      expandedFaqId:  clearExpandedFaqId ? null : (expandedFaqId ?? this.expandedFaqId),
      selectedTopic:  clearSelectedTopic ? null : (selectedTopic ?? this.selectedTopic),
      message:        message        ?? this.message,
      isSending:      isSending      ?? this.isSending,
      sentSuccess:    sentSuccess    ?? this.sentSuccess,
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class HelpSupportNotifier extends StateNotifier<HelpSupportState> {
  HelpSupportNotifier()
      : super(const HelpSupportState(
          activeCategory: FaqCategory.all,
          expandedFaqId:  null,
          selectedTopic:  null,
          message:        '',
          isSending:      false,
          sentSuccess:    false,
        ));

  void setCategory(FaqCategory c) =>
      state = state.copyWith(activeCategory: c, clearExpandedFaqId: true);

  void toggleFaq(String id) {
    final next = state.expandedFaqId == id ? null : id;
    state = next == null
        ? state.copyWith(clearExpandedFaqId: true)
        : state.copyWith(expandedFaqId: next);
  }

  void setTopic(SupportTopic t) =>
      state = state.copyWith(selectedTopic: t);

  void setMessage(String m) =>
      state = state.copyWith(message: m);

  Future<void> sendMessage() async {
    if (!state.canSend) return;
    state = state.copyWith(isSending: true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    state = state.copyWith(isSending: false, sentSuccess: true);
  }

  void resetForm() => state = state.copyWith(
        clearSelectedTopic: true,
        message: '',
        sentSuccess: false,
      );
}

// ─── Derived providers ────────────────────────────────────────────────────────

final helpSupportProvider =
    StateNotifierProvider<HelpSupportNotifier, HelpSupportState>(
  (ref) => HelpSupportNotifier(),
);

final filteredFaqProvider = Provider<List<FaqItem>>((ref) {
  final cat = ref
      .watch(helpSupportProvider.select((s) => s.activeCategory));
  if (cat == FaqCategory.all) return kFaqItems;
  return kFaqItems.where((f) => f.category == cat).toList();
});
