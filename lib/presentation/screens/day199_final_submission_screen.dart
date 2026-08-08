/// Day 199 — Final Store Submission
///
/// First day of the Days 199-200 Final Submission block.
/// Day 198: QA pass, build signing, block sign-off          ✅
/// Day 199: Upload AAB → Play Console, upload IPA → App Store
///           Connect, fill all metadata, submit for review.
/// Day 200: Grand finale — project complete 🏆.
///
/// 🟢 FRONTEND-ONLY — submission workflow documentation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final _d199TabProvider        = StateProvider<int>((ref) => 0);
final _playStepProvider       = StateProvider<int>((ref) => 0);
final _appleStepProvider      = StateProvider<int>((ref) => 0);
final _playAutoProvider       = StateProvider<bool>((ref) => false);
final _appleAutoProvider      = StateProvider<bool>((ref) => false);
final _statusProvider         = StateProvider<_SubmitStatus>((ref) => _SubmitStatus.notSubmitted);
final _expandedPreProvider    = StateProvider<int?>((ref) => null);

enum _SubmitStatus { notSubmitted, inReview, approved }

// ── Play Store submission steps ───────────────────────────────────────────────
const _kPlaySteps = [
  _Step(
    title: 'Build signed AAB',
    detail: 'Run: flutter build appbundle --release\n'
        'Output: build/app/outputs/bundle/release/app-release.aab\n'
        'Verify: JAR signature present with jarsigner -verify',
    icon: Icons.build_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Create new release in Play Console',
    detail: 'Play Console → Production → Releases → Create new release\n'
        'Or use Internal Testing first for a soft launch.\n'
        'ZapSafe: submit directly to Production.',
    icon: Icons.add_circle_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Upload app-release.aab',
    detail: 'Drag and drop the AAB file into the upload zone.\n'
        'Play Console validates: signing, manifest, permissions.\n'
        'Google re-signs with Play App Signing key.',
    icon: Icons.upload_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Fill release notes (What\'s New)',
    detail: 'Add Day 194 "What\'s New — v1.0.0" text.\n'
        'Add for: en-IN (English), hi-IN (Hindi).\n'
        'Max 500 characters per locale.',
    icon: Icons.edit_note_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Verify Data Safety form',
    detail: 'Policy → App Content → Data Safety.\n'
        'All fields from Day 164 should already be filled.\n'
        'Verify: Location, Audio, Contacts, Device IDs declared.',
    icon: Icons.security_rounded, color: Color(0xFFF59E0B),
  ),
  _Step(
    title: 'Verify store listing completeness',
    detail: 'Store Presence → Main Store Listing:\n'
        '• Title: ZapSafe — Personal Safety SOS ✅ (Day 193)\n'
        '• Short description ✅\n'
        '• Full description ✅\n'
        '• Screenshots (6 × en-IN + 6 × hi-IN) ✅ (Days 191-192)\n'
        '• Feature graphic ✅\n'
        '• App icon ✅',
    icon: Icons.store_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Set pricing and distribution',
    detail: 'Pricing → Free\n'
        'Countries: India (primary) + all available.\n'
        'IAP: ZapSafe Premium configured in Play Products.',
    icon: Icons.attach_money_rounded, color: Color(0xFF3DDC84),
  ),
  _Step(
    title: 'Submit for review',
    detail: 'Review Release → Send for review.\n'
        'Play Store review: typically 1-3 days.\n'
        'First release may take up to 7 days.',
    icon: Icons.send_rounded, color: Color(0xFFEF4444),
  ),
];

// ── App Store steps ───────────────────────────────────────────────────────────
const _kAppleSteps = [
  _Step(
    title: 'Create new App Store version',
    detail: 'App Store Connect → ZapSafe → + New Version.\n'
        'Version: 1.0.0. Platform: iOS.\n'
        'This creates the version record before uploading.',
    icon: Icons.add_circle_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Build and archive in Xcode',
    detail: 'flutter build ipa --release\n'
        'Or: Xcode → Product → Archive.\n'
        'Then: Distribute App → App Store Connect.',
    icon: Icons.build_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Upload IPA via Transporter / Xcode',
    detail: 'Option A: Xcode Organizer → Distribute.\n'
        'Option B: Apple Transporter app (drag IPA).\n'
        'Option C: fastlane deliver (automated).\n'
        'Processing time: 5-15 minutes after upload.',
    icon: Icons.upload_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Select build in App Store Connect',
    detail: 'Once processed, select the build under "Build".\n'
        'If export compliance asked: ZapSafe uses HTTPS (standard). '
        'Select "Yes, qualifies for exemption".',
    icon: Icons.select_all_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Fill version metadata',
    detail: 'App Information → v1.0.0:\n'
        '• What\'s New (Day 194 text) ✅\n'
        '• Screenshots for 6.9" + 6.5" ✅ (Days 191-192)\n'
        '• App Preview video (optional)\n'
        '• Promotional text (Day 194 promo text) ✅',
    icon: Icons.edit_note_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Verify App Privacy / Privacy Nutrition Label',
    detail: 'App Privacy tab:\n'
        '• Location: Data Linked to You ✅\n'
        '• Crash Data: Data Not Linked to You ✅\n'
        '• Usage Data: Data Not Linked to You ✅\n'
        '(Verified in Day 164 + Day 196 alignment check)',
    icon: Icons.policy_rounded, color: Color(0xFFF59E0B),
  ),
  _Step(
    title: 'Add review information',
    detail: 'App Review Information:\n'
        '• Contact email: review@zapsafe.app\n'
        '• Phone: +91 98765 43210 (demo number)\n'
        '• Demo account: demo@zapsafe.app / Demo1234!\n'
        '• Notes: "Core feature is SOS. Demo account has '
        'pre-loaded contacts and SOS history."',
    icon: Icons.contact_page_rounded, color: Color(0xFF9CA3AF),
  ),
  _Step(
    title: 'Submit for App Review',
    detail: 'Save → Submit for Review.\n'
        'Select "No" for advertising identifier (IDFA).\n'
        'App Review time: typically 24-48 hours.\n'
        'Check App Store Connect app for status updates.',
    icon: Icons.send_rounded, color: Color(0xFFEF4444),
  ),
];

class _Step {
  final String   title, detail;
  final IconData icon;
  final Color    color;
  const _Step({
    required this.title, required this.detail,
    required this.icon, required this.color,
  });
}

// ── Pre-submission checklist ──────────────────────────────────────────────────
const _kPreChecklist = [
  ('Release build tested on real device (not emulator)', true),
  ('No debug flags or logging in release build', true),
  ('App does NOT crash on launch (Crashlytics/Sentry clean)', true),
  ('Privacy Policy URL accessible: zapsafe.app/privacy', true),
  ('All permissions declared in Data Safety + Privacy Label', true),
  ('Screenshots match the actual app UI (no fake UI)', true),
  ('App icon is 512×512 (Play) and 1024×1024 (Apple), no alpha', true),
  ('Version name: 1.0.0 · Version code: 1 (Android) / Build: 150 (iOS)', true),
  ('keystore.properties NOT committed to git', true),
  ('Certificates/provisioning profiles not expired', true),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day199FinalSubmissionScreen extends ConsumerWidget {
  const Day199FinalSubmissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d199TabProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Final Submission'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
            ),
            child: const Text('DAY 199 🚀',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 10,
                    fontWeight: FontWeight.w800)),
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
                onSelect: (t) => ref.read(_d199TabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _PlayStoreTab(),
            if (tab == 1) const _AppStoreTab(),
            if (tab == 2) const _StatusTab(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.14),
          const Color(0xFF3B82F6).withOpacity(0.07),
          const Color(0xFF0A0A0A),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm, children: [
          _badge('⚡  DAY 199',                const Color(0xFF10B981)),
          _badge('🟢 FRONTEND-ONLY',           const Color(0xFF10B981)),
          _badge('Section D  ·  Day 9/10',     const Color(0xFF3B82F6)),
          _badge('Final Submission  🚀',        const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        const Text('Final Store\nSubmission',
            style: TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          '8-step Play Store pipeline. '
          '8-step App Store pipeline. '
          'Pre-submission checklist. '
          'Submission status tracker. '
          'One day from Day 200 🏆',
          style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6)),
        const SizedBox(height: ZapSpacing.md),
        const Row(children: [
          _HStat('8',  'Play Store steps', Color(0xFF3DDC84)),
          _HStat('8',  'App Store steps',  Color(0xFF9CA3AF)),
          _HStat('10', 'Pre-checks',       Color(0xFFF59E0B)),
          _HStat('🏆', 'Day 200 next',    Color(0xFF10B981)),
        ]),
      ]));

  Widget _badge(String l, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4))),
      child: Text(l, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5)));
}

class _HStat extends StatelessWidget {
  final String value, label; final Color color;
  const _HStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 13,
        fontWeight: FontWeight.w800), textAlign: TextAlign.center),
    Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
        textAlign: TextAlign.center),
  ]));
}

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
      (Icons.android_rounded,  Color(0xFF3DDC84), 'Play Store'),
      (Icons.apple_rounded,    Color(0xFF9CA3AF), 'App Store'),
      (Icons.track_changes_rounded, Color(0xFF3B82F6), 'Status'),
    ];
    return Row(children: List.generate(3, (i) {
      final (icon, color, label) = items[i];
      final isActive = i == active;
      return Expanded(child: GestureDetector(
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
                color: isActive ? color : const Color(0xFF6B7280), fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ));
    }));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable Step Pipeline Widget
// ══════════════════════════════════════════════════════════════════════════════
class _StepPipeline extends ConsumerWidget {
  final List<_Step> steps;
  final StateProvider<int> stepProvider;
  final StateProvider<bool> autoProvider;
  final Color accentColor;
  final String storeName;

  const _StepPipeline({
    required this.steps, required this.stepProvider,
    required this.autoProvider, required this.accentColor,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(stepProvider);
    final isAuto      = ref.watch(autoProvider);
    final isDone      = currentStep >= steps.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Progress header
      Container(
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
            color: accentColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: accentColor.withOpacity(0.35))),
        child: Column(children: [
          Row(children: [
            Icon(isDone ? Icons.check_circle_rounded : Icons.adjust_rounded,
                color: isDone ? const Color(0xFF10B981) : accentColor, size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(child: Text(
              isDone
                  ? '$storeName submission complete ✅'
                  : 'Step ${currentStep + 1} of ${steps.length}: '
                    '${currentStep < steps.length ? steps[currentStep].title : ""}',
              style: TextStyle(
                  color: isDone ? const Color(0xFF10B981) : Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: currentStep / steps.length,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                      isDone ? const Color(0xFF10B981) : accentColor),
                  minHeight: 5)),
          const SizedBox(height: ZapSpacing.xs),
          Row(children: [
            Text('$currentStep / ${steps.length} steps',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 9)),
            const Spacer(),
            if (!isDone)
              Text(steps[currentStep].title,
                  style: TextStyle(color: accentColor, fontSize: 9),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ])),
      const SizedBox(height: ZapSpacing.md),

      // Controls
      if (!isDone) ...[
        Row(children: [
          if (currentStep > 0)
            Expanded(child: _outlineBtn('← Back', const Color(0xFF6B7280),
                () => ref.read(stepProvider.notifier).state = currentStep - 1)),
          if (currentStep > 0) const SizedBox(width: ZapSpacing.sm),
          Expanded(flex: 2, child: _primaryBtn(
            label: '${steps[currentStep].title} →',
            color: accentColor,
            onTap: isAuto ? null : () =>
                ref.read(stepProvider.notifier).state = currentStep + 1,
          )),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        if (!isAuto)
          _outlineBtn('⚡ Auto-run all steps', accentColor.withOpacity(0.7),
              () => _autoRun(ref)),
      ] else ...[
        _outlineBtn('Reset pipeline ↺', const Color(0xFF6B7280), () {
          ref.read(stepProvider.notifier).state = 0;
        }),
      ],
      const SizedBox(height: ZapSpacing.xl),

      // Step list
      const _SectionLabel('ALL STEPS  ·  TAP STEP TO MARK COMPLETE'),
      const SizedBox(height: ZapSpacing.md),
      ...steps.asMap().entries.map((e) {
        final i    = e.key;
        final step = e.value;
        final isDoneStep = i < currentStep;
        final isCurrent  = i == currentStep;

        return GestureDetector(
          onTap: isCurrent || isDoneStep
              ? () {
                  if (isCurrent) {
                    ref.read(stepProvider.notifier).state = currentStep + 1;
                  } else {
                    ref.read(stepProvider.notifier).state = i;
                  }
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
                color: isCurrent ? accentColor.withOpacity(0.08)
                    : isDoneStep ? accentColor.withOpacity(0.04)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                    color: isCurrent ? accentColor.withOpacity(0.5)
                        : isDoneStep ? accentColor.withOpacity(0.2)
                        : const Color(0xFF1E1E1E),
                    width: isCurrent ? 2 : 1)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Step indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26, height: 26,
                decoration: BoxDecoration(
                    color: isDoneStep ? accentColor : isCurrent
                        ? accentColor.withOpacity(0.12) : const Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: isDoneStep ? accentColor : isCurrent
                            ? accentColor : const Color(0xFF2A2A2A))),
                child: Center(
                    child: isDoneStep
                        ? const Icon(Icons.check, color: Colors.white, size: 13)
                        : Text('${i + 1}', style: TextStyle(
                            color: isCurrent ? accentColor : const Color(0xFF4B5563),
                            fontSize: 10, fontWeight: FontWeight.w800)))),
              const SizedBox(width: ZapSpacing.md),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(step.title, style: TextStyle(
                    color: isDoneStep
                        ? const Color(0xFF6B7280) : Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w600,
                    decoration: isDoneStep ? TextDecoration.lineThrough : null)),
                Text(step.detail, style: const TextStyle(
                    color: Color(0xFF4B5563), fontSize: 9, height: 1.4),
                    maxLines: isCurrent ? 10 : 1,
                    overflow: isCurrent ? TextOverflow.visible : TextOverflow.ellipsis),
              ])),
              Icon(step.icon, color: isDoneStep ? const Color(0xFF4B5563)
                  : isCurrent ? accentColor : const Color(0xFF2A2A2A),
                  size: 14),
            ]),
          ));
      }),
    ]);
  }

  Future<void> _autoRun(WidgetRef ref) async {
    ref.read(autoProvider.notifier).state = true;
    final total = steps.length;
    for (int i = ref.read(stepProvider); i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      ref.read(stepProvider.notifier).state = i + 1;
    }
    ref.read(autoProvider.notifier).state = false;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Play Store
// ══════════════════════════════════════════════════════════════════════════════
class _PlayStoreTab extends ConsumerWidget {
  const _PlayStoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(_expandedPreProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.android_rounded, color: const Color(0xFF3DDC84),
          text: '8-step Play Store submission pipeline. '
              'Tap each step to mark complete, or use "Auto-run". '
              'Review typically takes 1-3 business days for first submission.'),
      const SizedBox(height: ZapSpacing.lg),

      // Pre-flight
      const _SectionLabel('PRE-SUBMISSION FINAL CHECKS'),
      const SizedBox(height: ZapSpacing.md),
      ..._kPreChecklist.take(5).toList().asMap().entries.map((e) {
        final i = e.key;
        final (label, passes) = e.value;
        final isExp = expanded == i;
        return GestureDetector(
          onTap: () => ref.read(_expandedPreProvider.notifier).state =
              isExp ? null : i,
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF1E1E1E))),
            child: Row(children: [
              Icon(passes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: passes ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 14),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(label, style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 10))),
            ])));
      }),
      GestureDetector(
        onTap: () => ref.read(_expandedPreProvider.notifier).state =
            expanded == -1 ? null : -1,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('+ ${_kPreChecklist.length - 5} more checks (tap to expand)',
              style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 10)))),
      if (expanded == -1)
        ..._kPreChecklist.skip(5).map((c) {
          final (label, passes) = c;
          return Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF1E1E1E))),
            child: Row(children: [
              Icon(passes ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: passes ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 14),
              const SizedBox(width: ZapSpacing.sm),
              Expanded(child: Text(label, style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 10))),
            ]));
        }),
      const SizedBox(height: ZapSpacing.xl),

      // Pipeline
      const _SectionLabel('PLAY STORE SUBMISSION PIPELINE  ·  8 STEPS'),
      const SizedBox(height: ZapSpacing.md),
      _StepPipeline(
        steps: _kPlaySteps,
        stepProvider: _playStepProvider,
        autoProvider: _playAutoProvider,
        accentColor: const Color(0xFF3DDC84),
        storeName: 'Play Store',
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — App Store
// ══════════════════════════════════════════════════════════════════════════════
class _AppStoreTab extends StatelessWidget {
  const _AppStoreTab();

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    _infoBox(icon: Icons.apple_rounded, color: const Color(0xFF9CA3AF),
        text: '8-step App Store submission pipeline. '
            'Key differences from Play: no AAB (use IPA), '
            'must provide demo account in review notes, '
            'export compliance question. Review: 24-48 hours.'),
    const SizedBox(height: ZapSpacing.lg),

    // Key differences
    Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFF9CA3AF).withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF9CA3AF).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.compare_arrows_rounded, color: Color(0xFF9CA3AF), size: 14),
          SizedBox(width: ZapSpacing.sm),
          Text('App Store vs Play Store — key differences',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: ZapSpacing.sm),
        ...[
          ('Build format', 'IPA (not AAB)', const Color(0xFF9CA3AF)),
          ('Upload tool', 'Transporter / Xcode / fastlane', const Color(0xFF9CA3AF)),
          ('Review time', '24-48h (vs 1-3 days Play)', const Color(0xFF10B981)),
          ('Demo account', 'Required in review notes', const Color(0xFFEF4444)),
          ('Export compliance', 'Asked during submission', const Color(0xFFF59E0B)),
          ('Screenshot sizes', '6.9" required (vs any size Play)', const Color(0xFF9CA3AF)),
        ].map((t) {
          final (k, v, c) = t;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              SizedBox(width: 100, child: Text(k, style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 10))),
              Expanded(child: Text(v, style: TextStyle(
                  color: c, fontSize: 10, fontWeight: FontWeight.w600))),
            ]));
        }),
      ])),
    const SizedBox(height: ZapSpacing.lg),

    const _SectionLabel('APP STORE SUBMISSION PIPELINE  ·  8 STEPS'),
    const SizedBox(height: ZapSpacing.md),
    Consumer(builder: (context, ref, _) => _StepPipeline(
      steps: _kAppleSteps,
      stepProvider: _appleStepProvider,
      autoProvider: _appleAutoProvider,
      accentColor: const Color(0xFF9CA3AF),
      storeName: 'App Store',
    )),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Submission Status
// ══════════════════════════════════════════════════════════════════════════════
class _StatusTab extends ConsumerWidget {
  const _StatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(_statusProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoBox(icon: Icons.track_changes_rounded, color: const Color(0xFF3B82F6),
          text: 'Submission status tracker. '
              'After submitting, review typically takes 1-3 days (Play) '
              'or 24-48 hours (App Store). '
              'Day 200 celebrates the completed journey regardless of review status.'),
      const SizedBox(height: ZapSpacing.lg),

      // Status simulator
      const _SectionLabel('SIMULATE SUBMISSION STATUS'),
      const SizedBox(height: ZapSpacing.md),
      Row(children: [
        _statusBtn(_SubmitStatus.notSubmitted, _SubmitStatus.notSubmitted, status, ref),
        const SizedBox(width: ZapSpacing.sm),
        _statusBtn(_SubmitStatus.inReview, _SubmitStatus.inReview, status, ref),
        const SizedBox(width: ZapSpacing.sm),
        _statusBtn(_SubmitStatus.approved, _SubmitStatus.approved, status, ref),
      ]),
      const SizedBox(height: ZapSpacing.xl),

      // Status cards
      _StatusCard(
        icon: Icons.android_rounded, color: const Color(0xFF3DDC84),
        storeName: 'Google Play Store',
        appId: 'com.zapsafe.app',
        version: '1.0.0 (1)',
        status: status,
      ),
      const SizedBox(height: ZapSpacing.md),
      _StatusCard(
        icon: Icons.apple_rounded, color: const Color(0xFF9CA3AF),
        storeName: 'Apple App Store',
        appId: 'com.zapsafe.app (ID: 123456789)',
        version: '1.0.0 (150)',
        status: status,
      ),
      const SizedBox(height: ZapSpacing.xl),

      // Review timeline
      const _SectionLabel('TYPICAL REVIEW TIMELINE'),
      const SizedBox(height: ZapSpacing.md),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          ...[
            (Icons.android_rounded, const Color(0xFF3DDC84),
                'Play Store submitted', 'Today (Day 199)'),
            (Icons.hourglass_top_rounded, const Color(0xFFF59E0B),
                'Play Store In Review', 'Day 200-202'),
            (Icons.check_circle_rounded, const Color(0xFF10B981),
                'Play Store Published', 'Day 200-205 (estimated)'),
            (Icons.apple_rounded, const Color(0xFF9CA3AF),
                'App Store submitted', 'Today (Day 199)'),
            (Icons.hourglass_top_rounded, const Color(0xFFF59E0B),
                'App Store In Review', 'Day 200 (24-48h)'),
            (Icons.check_circle_rounded, const Color(0xFF10B981),
                'App Store Published', 'Day 200-201 (estimated)'),
          ].asMap().entries.map((e) {
            final i = e.key;
            final (icon, color, label, timing) = e.value;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(child: Text(label, style: const TextStyle(
                      color: Colors.white, fontSize: 11))),
                  Text(timing, style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.w700)),
                ])),
              if (i < 5) const Divider(height: 1, color: Color(0xFF1E1E1E)),
            ]);
          }),
        ])),
      const SizedBox(height: ZapSpacing.xl),

      // Day 200 teaser
      Container(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFFF59E0B).withOpacity(0.12),
            const Color(0xFF10B981).withOpacity(0.08),
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 2),
        ),
        child: const Column(children: [
          Text('🏆', style: TextStyle(fontSize: 44)),
          SizedBox(height: ZapSpacing.sm),
          Text('Tomorrow: Day 200',
              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 14,
                  fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.xs),
          Text('THE GRAND FINALE',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          SizedBox(height: ZapSpacing.md),
          Text(
            '200 days. 4 sections. 150+ screens. '
            'ZapSafe is submitted to both stores. '
            'The final day celebrates the complete journey '
            'from Day 1 Flutter scaffold to shipping a production app.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
            textAlign: TextAlign.center),
        ])),
    ]);
  }

  Widget _statusBtn(_SubmitStatus label, _SubmitStatus val,
      _SubmitStatus current, WidgetRef ref) {
    final isOn = current == val;
    final color = switch (val) {
      _SubmitStatus.notSubmitted => const Color(0xFF6B7280),
      _SubmitStatus.inReview     => const Color(0xFFF59E0B),
      _SubmitStatus.approved     => const Color(0xFF10B981),
    };
    return Expanded(child: GestureDetector(
      onTap: () => ref.read(_statusProvider.notifier).state = val,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.12) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: isOn ? color.withOpacity(0.5) : const Color(0xFF2A2A2A),
                width: isOn ? 2 : 1)),
        child: Text(_btnLabel(val), style: TextStyle(
            color: isOn ? color : const Color(0xFF6B7280),
            fontSize: 9, fontWeight: isOn ? FontWeight.w800 : FontWeight.w400),
            textAlign: TextAlign.center))));
  }

  String _btnLabel(_SubmitStatus s) => switch (s) {
    _SubmitStatus.notSubmitted => 'Not Submitted',
    _SubmitStatus.inReview     => 'In Review',
    _SubmitStatus.approved     => 'Approved 🎉',
  };
}

class _StatusCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String storeName, appId, version;
  final _SubmitStatus status;
  const _StatusCard({required this.icon, required this.color,
      required this.storeName, required this.appId,
      required this.version, required this.status});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = switch (status) {
      _SubmitStatus.notSubmitted => ('Not Submitted', const Color(0xFF6B7280), Icons.pending_rounded),
      _SubmitStatus.inReview     => ('In Review ⏳', const Color(0xFFF59E0B), Icons.hourglass_top_rounded),
      _SubmitStatus.approved     => ('Approved ✅  Live on Store!', const Color(0xFF10B981), Icons.check_circle_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
          color: statusColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: statusColor.withOpacity(0.35))),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: ZapSpacing.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(storeName, style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700)),
          Text('$appId  ·  v$version', style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 9)),
        ])),
        Row(children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 5),
          Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10,
              fontWeight: FontWeight.w700)),
        ]),
      ]));
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _primaryBtn({required String label, required Color color, VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            gradient: onTap != null
                ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                : null,
            color: onTap == null ? const Color(0xFF1A1A1A) : null,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            boxShadow: onTap != null
                ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12,
                    offset: const Offset(0, 3))]
                : null,
            border: onTap == null
                ? Border.all(color: const Color(0xFF2A2A2A)) : null),
        child: Center(child: Text(label, style: TextStyle(
            color: onTap != null ? Colors.white : const Color(0xFF4B5563),
            fontSize: 12, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis))));

Widget _outlineBtn(String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.4))),
        child: Center(child: Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)))));

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
