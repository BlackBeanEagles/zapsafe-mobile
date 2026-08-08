/// Day 214 — Accessibility Re-Audit (Screen Reader)
///
/// Section A (Days 201-220): WCAG 2.1 AA manual checklist for TalkBack /
/// VoiceOver — labels, focus order, live regions on SOS countdown.
///
/// Tag: 🟢 FRONTEND-ONLY — QA meta-screen, not an automatic scan score.
///
/// Route: [AppRoutes.a11yScreenReaderAudit] → `/a11y-screen-reader-audit`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum A11yVerdict { unchecked, pass, fail }

enum A11yCategory {
  all,
  labels,
  focus,
  liveRegion,
  roles,
  sosFlow,
}

extension A11yCategoryX on A11yCategory {
  String get label => switch (this) {
        A11yCategory.all => 'All',
        A11yCategory.labels => 'Labels',
        A11yCategory.focus => 'Focus',
        A11yCategory.liveRegion => 'Live regions',
        A11yCategory.roles => 'Roles',
        A11yCategory.sosFlow => 'SOS flow',
      };

  Color get accent => switch (this) {
        A11yCategory.all => ZapColors.textSecondary,
        A11yCategory.labels => ZapColors.info,
        A11yCategory.focus => const Color(0xFF8B5CF6),
        A11yCategory.liveRegion => ZapColors.warning,
        A11yCategory.roles => ZapColors.safe,
        A11yCategory.sosFlow => ZapColors.danger,
      };
}

class A11yCheckItem {
  final String id;
  final A11yCategory category;
  final String title;
  final String wcag;
  final String description;
  final String screen;
  final String talkBackExpected;
  final String voiceOverExpected;
  final bool critical;

  const A11yCheckItem({
    required this.id,
    required this.category,
    required this.title,
    required this.wcag,
    required this.description,
    required this.screen,
    required this.talkBackExpected,
    required this.voiceOverExpected,
    this.critical = false,
  });
}

const _kItems = [
  A11yCheckItem(
    id: 'lbl_dashboard',
    category: A11yCategory.labels,
    title: 'Dashboard title announced',
    wcag: '2.4.2 Page Titled',
    description:
        'Screen reader announces screen purpose on landing — not just "Scaffold".',
    screen: 'Dashboard / Day 145 cold start',
    talkBackExpected: '"ZapSafe dashboard" or equivalent heading',
    voiceOverExpected: '"ZapSafe dashboard" heading',
    critical: true,
  ),
  A11yCheckItem(
    id: 'lbl_mode_card',
    category: A11yCategory.labels,
    title: 'Mode status card combined label',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'ModeStatusCard reads mode + battery + DCS in one swipe — not three silent views.',
    screen: 'Day 204 ModeStatusCard',
    talkBackExpected:
        '"MONITORING mode. Battery 82 percent. Last distress score 12 percent."',
    voiceOverExpected: 'Combined status string with expand hint',
    critical: true,
  ),
  A11yCheckItem(
    id: 'lbl_sos_hold',
    category: A11yCategory.labels,
    title: 'SOS hold duration in label',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'Long-press SOS exposes hold duration and early-release cancel in Semantics.',
    screen: 'Day 203 SosLongPressRingButton',
    talkBackExpected:
        '"Emergency SOS. Press and hold for 2 seconds to activate. Release early to cancel."',
    voiceOverExpected: 'Button with custom hint for hold gesture',
    critical: true,
  ),
  A11yCheckItem(
    id: 'lbl_nav_tabs',
    category: A11yCategory.labels,
    title: 'Bottom nav unique labels',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'Each tab has distinct label + selected state — not "Button" × 5.',
    screen: 'Production shell / GoRouter tabs',
    talkBackExpected: '"Home tab, selected" / "Contacts tab"',
    voiceOverExpected: 'Tab trait with selected announcement',
  ),
  A11yCheckItem(
    id: 'lbl_icon_buttons',
    category: A11yCategory.labels,
    title: 'Icon-only controls have text',
    wcag: '1.1.1 Non-text Content',
    description:
        'Settings gear, close X, filter icons wrapped in Semantics or Tooltip.',
    screen: 'All screens with IconButton',
    talkBackExpected: '"Open settings" not "Button"',
    voiceOverExpected:
        'Descriptive accessibility label on every icon tap target',
  ),
  A11yCheckItem(
    id: 'foc_top_down',
    category: A11yCategory.focus,
    title: 'Dashboard focus top-to-bottom',
    wcag: '2.4.3 Focus Order',
    description:
        'Swipe order: mode card → notifications → protection score → SOS — logical reading order.',
    screen: 'Dashboard stack',
    talkBackExpected: 'Focus moves down the visual hierarchy',
    voiceOverExpected: 'Rotor navigation matches visual layout',
    critical: true,
  ),
  A11yCheckItem(
    id: 'foc_sos_reachable',
    category: A11yCategory.focus,
    title: 'SOS reachable in ≤ 8 swipes',
    wcag: '2.1.1 Keyboard / 2.4.3 Focus Order',
    description:
        'From dashboard entry, SOS is reachable without excessive exploration.',
    screen: 'Dashboard → SOS',
    talkBackExpected: 'SOS heard within 8 swipe-right gestures from top',
    voiceOverExpected: 'Same swipe budget from first focus',
    critical: true,
  ),
  A11yCheckItem(
    id: 'foc_modal_trap',
    category: A11yCategory.focus,
    title: 'Dialogs trap focus',
    wcag: '2.4.3 Focus Order',
    description:
        'Confirm dialogs keep focus inside until dismissed — no focus behind modal.',
    screen: 'SOS confirm / account deletion dialogs',
    talkBackExpected: 'Cannot swipe to content under dialog',
    voiceOverExpected: 'VoiceOver cursor stays in modal layer',
  ),
  A11yCheckItem(
    id: 'foc_back_restore',
    category: A11yCategory.focus,
    title: 'Back restores prior focus',
    wcag: '2.4.3 Focus Order',
    description:
        'Popping a route returns screen reader focus to triggering control.',
    screen: 'Any pushed detail screen',
    talkBackExpected: 'After back, focus on element that opened screen',
    voiceOverExpected: 'Focus returns to originating control',
  ),
  A11yCheckItem(
    id: 'live_sos_countdown',
    category: A11yCategory.liveRegion,
    title: 'SOS countdown liveRegion',
    wcag: '4.1.3 Status Messages',
    description:
        'Countdown ticks announce via Semantics(liveRegion: true) without moving focus.',
    screen: 'ALERT_PENDING / Day 109 liveRegion demo',
    talkBackExpected: '"5 seconds remaining" updates automatically',
    voiceOverExpected: 'Polite status announcements during countdown',
    critical: true,
  ),
  A11yCheckItem(
    id: 'live_alert_status',
    category: A11yCategory.liveRegion,
    title: 'Alert status polite updates',
    wcag: '4.1.3 Status Messages',
    description:
        'Mode elevation / DCS changes announce without stealing focus from SOS.',
    screen: 'Day 204 mode transitions',
    talkBackExpected: '"Mode changed to ELEVATED" as status message',
    voiceOverExpected: 'Layout change notification, focus unchanged',
  ),
  A11yCheckItem(
    id: 'live_snackbar',
    category: A11yCategory.liveRegion,
    title: 'Snackbars as live regions',
    wcag: '4.1.3 Status Messages',
    description: 'Retry / offline queue messages announced when shown.',
    screen: 'Day 207 chat offline / Day 210 error retry',
    talkBackExpected: 'Toast text read once when displayed',
    voiceOverExpected: 'Announcement without requiring focus move',
  ),
  A11yCheckItem(
    id: 'live_sos_triggered',
    category: A11yCategory.liveRegion,
    title: 'SOS triggered assertive announce',
    wcag: '4.1.3 Status Messages',
    description: 'Successful SOS trigger uses assertive/priority announcement.',
    screen: 'SOS triggered state',
    talkBackExpected: '"Emergency SOS activated" interrupts politely',
    voiceOverExpected: 'Priority announcement on trigger complete',
    critical: true,
  ),
  A11yCheckItem(
    id: 'role_custom_toggle',
    category: A11yCategory.roles,
    title: 'Custom toggles use switch role',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'SwitchListTile and custom toggles expose checked state changes.',
    screen: 'Day 97 Accessibility Settings',
    talkBackExpected: '"Reduce motion, switch, off" → "on"',
    voiceOverExpected: 'Switch trait with value change announcement',
  ),
  A11yCheckItem(
    id: 'role_decorative_exclude',
    category: A11yCategory.roles,
    title: 'Decorative icons excluded',
    wcag: '1.1.1 Non-text Content',
    description:
        'Purely decorative icons use ExcludeSemantics — not read twice.',
    screen: 'Contact avatars / tier badges',
    talkBackExpected: 'Avatar not read if name is in parent MergeSemantics',
    voiceOverExpected: 'Single combined label per list row',
  ),
  A11yCheckItem(
    id: 'role_tap_hint',
    category: A11yCategory.roles,
    title: 'onTapHint on custom gestures',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'Non-standard gestures (long-press, swipe actions) expose hints.',
    screen: 'Day 109 onTapHint pattern',
    talkBackExpected: 'Hint explains double-tap or long-press action',
    voiceOverExpected: 'Custom actions listed in rotor when applicable',
  ),
  A11yCheckItem(
    id: 'role_section_headers',
    category: A11yCategory.roles,
    title: 'Section headers marked',
    wcag: '1.3.1 Info & Relationships',
    description:
        'Settings sections use Semantics(header: true) for heading navigation.',
    screen: 'Settings / onboarding steps',
    talkBackExpected: 'Heading navigation jumps between sections',
    voiceOverExpected: 'Rotor headings list populated',
  ),
  A11yCheckItem(
    id: 'sos_cancel_flash',
    category: A11yCategory.sosFlow,
    title: 'Early release cancel announced',
    wcag: '4.1.3 Status Messages',
    description:
        'Releasing SOS hold early announces "Cancelled" — visual flash also readable.',
    screen: 'Day 203 cancelled phase',
    talkBackExpected: '"Cancelled" or equivalent status on early release',
    voiceOverExpected: 'Status message when hold aborted',
    critical: true,
  ),
  A11yCheckItem(
    id: 'sos_hold_progress',
    category: A11yCategory.sosFlow,
    title: 'Hold progress feedback',
    wcag: '4.1.2 Name, Role, Value',
    description:
        'Optional periodic progress during 2s hold (every 500ms) for blind users.',
    screen: 'Day 203 + production SOS',
    talkBackExpected: 'Progress updates or haptic-only with label refresh',
    voiceOverExpected: 'Audible progress without requiring sight',
  ),
  A11yCheckItem(
    id: 'sos_eyes_closed_script',
    category: A11yCategory.sosFlow,
    title: 'Eyes-closed script completable',
    wcag: '2.1.1 Keyboard (equivalent)',
    description:
        'Manual test script Dashboard → SOS flow passes with eyes closed.',
    screen: 'Full flow — see Test Script tab',
    talkBackExpected: 'All steps in Test Script tab achievable without vision',
    voiceOverExpected: 'Same script on iOS with VoiceOver',
    critical: true,
  ),
];

class _TestScriptStep {
  final int step;
  final String action;
  final String expected;
  final String tip;

  const _TestScriptStep({
    required this.step,
    required this.action,
    required this.expected,
    this.tip = '',
  });
}

const _kTestScript = [
  _TestScriptStep(
    step: 1,
    action:
        'Enable TalkBack (Android) or VoiceOver (iOS). Set speech rate to normal.',
    expected: 'Screen reader is active before opening ZapSafe.',
    tip:
        'Android: Volume Up + Down 3s. iOS: Settings → Accessibility → VoiceOver.',
  ),
  _TestScriptStep(
    step: 2,
    action: 'Cold-launch ZapSafe. Wait on Dashboard until first focus lands.',
    expected:
        'Announces dashboard title or first focusable header — not silence.',
  ),
  _TestScriptStep(
    step: 3,
    action:
        'Swipe right through top region: mode card → notifications → score ring.',
    expected: 'Each block has a unique, descriptive label in logical order.',
  ),
  _TestScriptStep(
    step: 4,
    action: 'Continue swiping until you hear the SOS hold label (2 seconds).',
    expected:
        '"Emergency SOS. Press and hold for 2 seconds…" within 8 swipes from top.',
  ),
  _TestScriptStep(
    step: 5,
    action: 'Double-tap and hold SOS. Count to 1, then release finger early.',
    expected:
        'Announces cancellation — "Cancelled" or equivalent status message.',
  ),
  _TestScriptStep(
    step: 6,
    action:
        'Find SOS again. Double-tap and hold for full 2 seconds without releasing.',
    expected: 'Trigger confirmation announced. Focus may move to alert UI.',
  ),
  _TestScriptStep(
    step: 7,
    action:
        'If countdown appears, listen for liveRegion ticks without swiping.',
    expected: 'Seconds remaining update audibly — focus not stolen each tick.',
  ),
  _TestScriptStep(
    step: 8,
    action:
        'Dismiss or complete flow. Navigate back to Dashboard with system back.',
    expected:
        'Returns to dashboard; prior focus restored or logical first focus.',
  ),
  _TestScriptStep(
    step: 9,
    action:
        'Open Settings via screen reader. Jump headings to "Accessibility".',
    expected:
        'Heading navigation finds accessibility section in ≤ 3 heading jumps.',
  ),
  _TestScriptStep(
    step: 10,
    action:
        'Mark checklist item "Eyes-closed script completable" Pass or Fail.',
    expected: 'Record blockers in notes — route + missing label + step number.',
  ),
];

// ── Providers ─────────────────────────────────────────────────────────────────
final _d214TabProvider = StateProvider<int>((ref) => 0);
final _d214VerdictsProvider = StateProvider<Map<String, A11yVerdict>>(
  (ref) => {for (final i in _kItems) i.id: A11yVerdict.unchecked},
);
final _d214NotesProvider = StateProvider<Map<String, String>>((ref) => {});
final _d214ExpandedProvider = StateProvider<String?>((ref) => null);
final _d214CategoryProvider =
    StateProvider<A11yCategory>((ref) => A11yCategory.all);
final _d214ScriptExpandedProvider = StateProvider<Set<int>>((ref) => {1});

const _kTabs = ['Checklist', 'Test Script', 'Export'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day214A11yScreenReaderAuditScreen extends ConsumerWidget {
  const Day214A11yScreenReaderAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d214TabProvider);
    final verdicts = ref.watch(_d214VerdictsProvider);
    final passed = verdicts.values.where((v) => v == A11yVerdict.pass).length;
    final failed = verdicts.values.where((v) => v == A11yVerdict.fail).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 214 · Screen Reader Audit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$passed/${_kItems.length}',
                style: TextStyle(
                  color: passed == _kItems.length
                      ? ZapColors.safe
                      : ZapColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d214TabProvider.notifier).state = i,
          ),
          if (tab == 0)
            _ProgressStrip(
              passed: passed,
              failed: failed,
              total: _kItems.length,
            ),
          Expanded(
            child: switch (tab) {
              0 => const _ChecklistTab(),
              1 => const _TestScriptTab(),
              _ => const _ExportTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  final int passed;
  final int failed;
  final int total;

  const _ProgressStrip({
    required this.passed,
    required this.failed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.sm,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      color: ZapColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'WCAG 2.1 AA audit progress',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (failed > 0)
                Text(
                  '$failed fail',
                  style: const TextStyle(color: ZapColors.danger, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: passed / total,
              minHeight: 6,
              backgroundColor: ZapColors.bgElevated,
              color: passed >= total ? ZapColors.safe : ZapColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Checklist ──────────────────────────────────────────────────────────
class _ChecklistTab extends ConsumerWidget {
  const _ChecklistTab();

  List<A11yCheckItem> _filtered(A11yCategory filter) {
    if (filter == A11yCategory.all) return _kItems;
    return _kItems.where((i) => i.category == filter).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verdicts = ref.watch(_d214VerdictsProvider);
    final notes = ref.watch(_d214NotesProvider);
    final expanded = ref.watch(_d214ExpandedProvider);
    final category = ref.watch(_d214CategoryProvider);
    final items = _filtered(category);
    final allPass = verdicts.values.every((v) => v == A11yVerdict.pass);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section A Day 14/20 · TalkBack + VoiceOver manual QA',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          '20 WCAG 2.1 AA checks for screen readers. Tap ✅/❌ after testing on '
          'a physical device — not an automatic scan.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: A11yCategory.values.map((c) {
              final selected = category == c;
              final count = c == A11yCategory.all
                  ? _kItems.length
                  : _kItems.where((i) => i.category == c).length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${c.label} ($count)'),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(_d214CategoryProvider.notifier).state = c,
                  selectedColor: c.accent.withOpacity(0.25),
                  checkmarkColor: c.accent,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...items.map((item) {
          final verdict = verdicts[item.id] ?? A11yVerdict.unchecked;
          final isExpanded = expanded == item.id;
          return _CheckItemCard(
            item: item,
            verdict: verdict,
            note: notes[item.id] ?? '',
            expanded: isExpanded,
            onToggleExpand: () {
              ref.read(_d214ExpandedProvider.notifier).state =
                  isExpanded ? null : item.id;
            },
            onPass: () {
              ref.read(_d214VerdictsProvider.notifier).update(
                    (m) => {...m, item.id: A11yVerdict.pass},
                  );
            },
            onFail: () {
              ref.read(_d214VerdictsProvider.notifier).update(
                    (m) => {...m, item.id: A11yVerdict.fail},
                  );
            },
            onReset: () {
              ref.read(_d214VerdictsProvider.notifier).update(
                    (m) => {...m, item.id: A11yVerdict.unchecked},
                  );
            },
            onNoteChanged: (v) {
              ref.read(_d214NotesProvider.notifier).update(
                    (m) => {...m, item.id: v},
                  );
            },
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Mark all checks pass',
                button: true,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(_d214VerdictsProvider.notifier).state = {
                      for (final i in _kItems) i.id: A11yVerdict.pass,
                    };
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 75),
                  ),
                  child: const Text('Mark all pass'),
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Semantics(
                label: 'Clear all verdicts',
                button: true,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(_d214VerdictsProvider.notifier).state = {
                      for (final i in _kItems) i.id: A11yVerdict.unchecked,
                    };
                    ref.read(_d214NotesProvider.notifier).state = {};
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 75),
                  ),
                  child: const Text('Clear all'),
                ),
              ),
            ),
          ],
        ),
        if (allPass) ...[
          const SizedBox(height: ZapSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.hearing_rounded, color: ZapColors.safe, size: 40),
                SizedBox(height: ZapSpacing.sm),
                Text(
                  'All 20 checks passed',
                  style: TextStyle(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: ZapSpacing.xs),
                Text(
                  'Screen reader audit complete for this pass.',
                  style:
                      TextStyle(color: ZapColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckItemCard extends StatelessWidget {
  final A11yCheckItem item;
  final A11yVerdict verdict;
  final String note;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onPass;
  final VoidCallback onFail;
  final VoidCallback onReset;
  final ValueChanged<String> onNoteChanged;

  const _CheckItemCard({
    required this.item,
    required this.verdict,
    required this.note,
    required this.expanded,
    required this.onToggleExpand,
    required this.onPass,
    required this.onFail,
    required this.onReset,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final verdictColor = switch (verdict) {
      A11yVerdict.pass => ZapColors.safe,
      A11yVerdict.fail => ZapColors.danger,
      A11yVerdict.unchecked => ZapColors.textMuted,
    };
    final verdictLabel = switch (verdict) {
      A11yVerdict.pass => 'Pass',
      A11yVerdict.fail => 'Fail',
      A11yVerdict.unchecked => 'Unchecked',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(
          color: verdict == A11yVerdict.fail
              ? ZapColors.danger.withOpacity(0.5)
              : ZapColors.border,
          width: verdict == A11yVerdict.fail ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            label: '${item.title}. $verdictLabel. WCAG ${item.wcag}',
            button: true,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.category.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.label,
                        style: TextStyle(
                          color: item.category.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: ZapColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (item.critical)
                                const Icon(
                                  Icons.priority_high_rounded,
                                  size: 16,
                                  color: ZapColors.danger,
                                ),
                            ],
                          ),
                          Text(
                            item.screen,
                            style: const TextStyle(
                              color: ZapColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ZapColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZapSpacing.md,
              0,
              ZapSpacing.md,
              ZapSpacing.sm,
            ),
            child: Row(
              children: [
                _VerdictChip(
                  label: 'Pass',
                  selected: verdict == A11yVerdict.pass,
                  color: ZapColors.safe,
                  onTap: onPass,
                ),
                const SizedBox(width: ZapSpacing.sm),
                _VerdictChip(
                  label: 'Fail',
                  selected: verdict == A11yVerdict.fail,
                  color: ZapColors.danger,
                  onTap: onFail,
                ),
                const Spacer(),
                if (verdict != A11yVerdict.unchecked)
                  Semantics(
                    label: 'Reset ${item.title}',
                    button: true,
                    child: TextButton(
                      onPressed: onReset,
                      child: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: verdictColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZapSpacing.md,
                0,
                ZapSpacing.md,
                ZapSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.sm),
                  _ExpectRow(
                    icon: Icons.android_rounded,
                    label: 'TalkBack',
                    text: item.talkBackExpected,
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  _ExpectRow(
                    icon: Icons.phone_iphone_rounded,
                    label: 'VoiceOver',
                    text: item.voiceOverExpected,
                  ),
                  const SizedBox(height: ZapSpacing.xs),
                  Text(
                    'WCAG ${item.wcag}',
                    style: const TextStyle(
                      color: ZapColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _NoteField(
              initialNote: note,
              onChanged: onNoteChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpectRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _ExpectRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: ZapColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerdictChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _VerdictChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
          constraints: const BoxConstraints(minHeight: 75, minWidth: 75),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : ZapColors.bgElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? color : ZapColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : ZapColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatefulWidget {
  final String initialNote;
  final ValueChanged<String> onChanged;

  const _NoteField({
    required this.initialNote,
    required this.onChanged,
  });

  @override
  State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void didUpdateWidget(covariant _NoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNote != oldWidget.initialNote &&
        widget.initialNote != _controller.text) {
      _controller.text = widget.initialNote;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        0,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
        maxLines: 2,
        decoration: InputDecoration(
          hintText: 'Notes — device, route, blocker step…',
          hintStyle: const TextStyle(color: ZapColors.textMuted),
          filled: true,
          fillColor: ZapColors.bgElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            borderSide: const BorderSide(color: ZapColors.border),
          ),
          contentPadding: const EdgeInsets.all(ZapSpacing.sm),
        ),
      ),
    );
  }
}

// ── Tab 1: Test Script ────────────────────────────────────────────────────────
class _TestScriptTab extends ConsumerWidget {
  const _TestScriptTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedSteps = ref.watch(_d214ScriptExpandedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility_off_rounded,
                      color: ZapColors.danger, size: 20),
                  SizedBox(width: ZapSpacing.sm),
                  Text(
                    'Eyes-closed test script',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ZapSpacing.sm),
              Text(
                'Dashboard → SOS flow. Perform on a physical device with '
                'TalkBack or VoiceOver. Expand each step for details.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Expand all test script steps',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(_d214ScriptExpandedProvider.notifier).state = {
                for (final s in _kTestScript) s.step,
              };
            },
            icon: const Icon(Icons.unfold_more_rounded, size: 18),
            label: const Text('Expand all'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Semantics(
          label: 'Collapse all test script steps',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(_d214ScriptExpandedProvider.notifier).state = {};
            },
            icon: const Icon(Icons.unfold_less_rounded, size: 18),
            label: const Text('Collapse all'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kTestScript.map((step) {
          final isOpen = expandedSteps.contains(step.step);
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Column(
              children: [
                Semantics(
                  label: 'Step ${step.step}. ${step.action}',
                  button: true,
                  expanded: isOpen,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: ZapColors.danger.withOpacity(0.15),
                      child: Text(
                        '${step.step}',
                        style: const TextStyle(
                          color: ZapColors.danger,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      step.action,
                      maxLines: isOpen ? null : 2,
                      overflow: isOpen ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Icon(
                      isOpen
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ZapColors.textMuted,
                    ),
                    onTap: () {
                      ref.read(_d214ScriptExpandedProvider.notifier).update(
                        (set) {
                          final next = {...set};
                          if (isOpen) {
                            next.remove(step.step);
                          } else {
                            next.add(step.step);
                          }
                          return next;
                        },
                      );
                    },
                  ),
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ZapSpacing.lg,
                      0,
                      ZapSpacing.lg,
                      ZapSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Expected result',
                          style: TextStyle(
                            color: ZapColors.safe,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: ZapSpacing.xs),
                        Text(
                          step.expected,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        if (step.tip.isNotEmpty) ...[
                          const SizedBox(height: ZapSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(ZapSpacing.sm),
                            decoration: BoxDecoration(
                              color: ZapColors.info.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: ZapColors.info.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              'Tip: ${step.tip}',
                              style: const TextStyle(
                                color: ZapColors.info,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgSurface,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: const Text(
            'Reference: Day 109 Semantics patterns · Day 203 SOS ring labels · '
            'Day 204 ModeStatusCard combined Semantics.',
            style: TextStyle(color: ZapColors.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Export ─────────────────────────────────────────────────────────────
class _ExportTab extends ConsumerWidget {
  const _ExportTab();

  String _buildSummary(
    Map<String, A11yVerdict> verdicts,
    Map<String, String> notes,
  ) {
    final passed = verdicts.values.where((v) => v == A11yVerdict.pass).length;
    final failed = verdicts.values.where((v) => v == A11yVerdict.fail).length;
    final unchecked =
        verdicts.values.where((v) => v == A11yVerdict.unchecked).length;
    final buf = StringBuffer()
      ..writeln('ZapSafe Screen Reader Audit — Day 214')
      ..writeln('WCAG 2.1 AA · TalkBack + VoiceOver')
      ..writeln(
          'Score: $passed/${_kItems.length} pass · $failed fail · $unchecked unchecked')
      ..writeln('')
      ..writeln('── Checklist ──');
    for (final item in _kItems) {
      final v = verdicts[item.id] ?? A11yVerdict.unchecked;
      final mark = switch (v) {
        A11yVerdict.pass => 'PASS',
        A11yVerdict.fail => 'FAIL',
        A11yVerdict.unchecked => '—',
      };
      buf.writeln('[${item.category.label}] $mark · ${item.title}');
      final note = notes[item.id];
      if (note != null && note.isNotEmpty) {
        buf.writeln('  Note: $note');
      }
    }
    return buf.toString();
  }

  String _buildCsv(
    Map<String, A11yVerdict> verdicts,
    Map<String, String> notes,
  ) {
    final buf = StringBuffer()
      ..writeln('id,category,title,wcag,screen,verdict,notes');
    for (final item in _kItems) {
      final v = verdicts[item.id] ?? A11yVerdict.unchecked;
      final verdict = switch (v) {
        A11yVerdict.pass => 'pass',
        A11yVerdict.fail => 'fail',
        A11yVerdict.unchecked => 'unchecked',
      };
      final note = (notes[item.id] ?? '').replaceAll(',', ';');
      buf.writeln(
        '${item.id},${item.category.label},"${item.title}",${item.wcag},'
        '"${item.screen}",$verdict,"$note"',
      );
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verdicts = ref.watch(_d214VerdictsProvider);
    final notes = ref.watch(_d214NotesProvider);
    final summary = _buildSummary(verdicts, notes);
    final csv = _buildCsv(verdicts, notes);
    final passed = verdicts.values.where((v) => v == A11yVerdict.pass).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Export audit summary',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'Copy for QA sign-off or paste into release checklist.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$passed / ${_kItems.length} passed',
                style: TextStyle(
                  color: passed == _kItems.length
                      ? ZapColors.safe
                      : ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: ZapSpacing.sm),
              Text(
                summary,
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy audit summary to clipboard',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy summary'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.safe,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Copy CSV to clipboard',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied')),
              );
            },
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Copy CSV'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 216 — i18n coverage audit (15 languages × namespaces).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.safe : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
