/// Day 162 — Consent Flow Test Scenarios & Onboarding Integration
///
/// Second half of the Days 161-162 First-Launch Consent Gate block.
/// Day 161: the gate screen UI + policy update mode + GoRouter redirect.
/// Day 162: completing the block with:
///
///   1. Test Scenarios — 5 distinct user states that must each be
///      handled correctly by the consent gate logic.
///
///   2. Onboarding Integration Map — exactly WHERE in the onboarding
///      flow the consent gate appears, and what happens to deep links
///      and returning users.
///
///   3. Edge Case Handler — what to do if the user:
///      - Force-closes mid-acceptance
///      - Accepts on one device and signs in on another
///      - Has a very old Hive record (pre v1.0)
///      - Clears app data
///
/// All 🟢 FRONTEND-ONLY — zero backend.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _activeTabProvider     = StateProvider<int>((ref) => 0);
final _scenarioProvider      = StateProvider<int>((ref) => 0);
final _scenarioRunProvider   = StateProvider<bool>((ref) => false);
final _scenarioStepProvider  = StateProvider<int>((ref) => 0);

// ── Data ───────────────────────────────────────────────────────────────────────
class _Scenario {
  final String   title;
  final String   description;
  final Color    color;
  final IconData icon;
  final String   hiveBefore;   // what Hive contains before the gate runs
  final String   expectedBehaviour;
  final String   gateMode;     // 'first_launch' | 'policy_update' | 'none'
  final List<String> steps;   // what happens step by step
  final String   hiveAfter;   // what Hive contains after
  const _Scenario({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.hiveBefore,
    required this.expectedBehaviour,
    required this.gateMode,
    required this.steps,
    required this.hiveAfter,
  });
}

const _kScenarios = [
  _Scenario(
    title: 'Brand-New User',
    description: 'No Hive record. First time opening the app.',
    color: Color(0xFF10B981),
    icon: Icons.fiber_new_rounded,
    hiveBefore: 'policy_consent box: empty (null)',
    expectedBehaviour: 'Consent gate shows in FIRST_LAUNCH mode. '
        'Both checkboxes required. "I Agree" leads to Dashboard.',
    gateMode: 'first_launch',
    steps: [
      'User opens app for first time',
      'GoRouter: needsConsentGate() → true (no Hive record)',
      'Redirect → /consent-gate (FIRST_LAUNCH mode)',
      'User reads Privacy Policy + Terms via in-app links',
      'User ticks both checkboxes',
      'Taps "I Agree — Enter ZapSafe"',
      'PolicyConsentService.recordAcceptance() saves to Hive',
      'context.go(dashboard) → dashboard loads',
    ],
    hiveAfter:
        '{ privacy_version: "2.0", terms_version: "1.0",\n'
        '  accepted_at: "2026-09-01T14:30:00Z",\n'
        '  record_hash: "sha256:..." }',
  ),
  _Scenario(
    title: 'Returning User — Policies Current',
    description: 'Hive record exists. Accepted current versions.',
    color: Color(0xFF3B82F6),
    icon: Icons.person_rounded,
    hiveBefore:
        '{ privacy_version: "2.0", terms_version: "1.0" }',
    expectedBehaviour: 'Gate NOT shown. GoRouter redirect returns null. '
        'User goes directly to Dashboard.',
    gateMode: 'none',
    steps: [
      'User opens app (returning, e.g. after 3 days)',
      'GoRouter: needsConsentGate() → false (versions match)',
      'Redirect returns null → proceeds to dashboard',
      'No consent gate shown',
      'Dashboard loads normally',
    ],
    hiveAfter: '(unchanged — no write)',
  ),
  _Scenario(
    title: 'Returning User — Policy Updated',
    description: 'Hive has v1.0 but current is v2.0.',
    color: Color(0xFFF59E0B),
    icon: Icons.published_with_changes_rounded,
    hiveBefore:
        '{ privacy_version: "1.0", terms_version: "1.0" }',
    expectedBehaviour: 'Gate shows in POLICY_UPDATE mode. '
        '"What changed" banner. Only Privacy Policy checkbox required.',
    gateMode: 'policy_update',
    steps: [
      'User opens app after Privacy Policy updated to v2.0',
      'GoRouter: needsConsentGate() → true (privacy 1.0 ≠ 2.0)',
      'Redirect → /consent-gate (POLICY_UPDATE mode)',
      'Banner: "Privacy Policy updated — what changed" shown',
      'Only Privacy Policy checkbox required (ToS unchanged)',
      'User accepts',
      'PolicyConsentService.recordAcceptance() updates privacy_version to 2.0',
      'Dashboard loads',
    ],
    hiveAfter:
        '{ privacy_version: "2.0", terms_version: "1.0",\n'
        '  accepted_at: "2026-09-15T09:00:00Z" }',
  ),
  _Scenario(
    title: 'User Force-Closes Mid-Acceptance',
    description: 'Ticked both boxes but killed app before tapping "I Agree".',
    color: Color(0xFFEF4444),
    icon: Icons.close_rounded,
    hiveBefore: 'policy_consent box: empty (null)',
    expectedBehaviour: 'Next launch: gate shown again in FIRST_LAUNCH mode. '
        'Checkboxes reset (not pre-checked). Must re-read and re-accept.',
    gateMode: 'first_launch',
    steps: [
      'User opens app, sees consent gate',
      'Ticks Privacy Policy checkbox ✅',
      'Ticks Terms of Service checkbox ✅',
      'BEFORE tapping "I Agree" → force-closes app',
      '(Hive write never happened — nothing saved)',
      'User re-opens app',
      'GoRouter: needsConsentGate() → true (still null)',
      'Gate shown again — checkboxes reset, must re-accept',
    ],
    hiveAfter: '(null — no write occurred before force-close)',
  ),
  _Scenario(
    title: 'App Data Cleared (Reset)',
    description: 'User clears app data in Android Settings.',
    color: Color(0xFF8B5CF6),
    icon: Icons.cleaning_services_rounded,
    hiveBefore: '(cleared — all Hive data deleted)',
    expectedBehaviour: 'Same as brand-new user. '
        'Auth tokens, consent record, and all local data gone. '
        'User must re-authenticate AND re-accept policies.',
    gateMode: 'first_launch',
    steps: [
      'User goes to Android Settings → Apps → ZapSafe → Clear Data',
      'All Hive boxes deleted (consent, auth tokens, settings)',
      'User opens app',
      'GoRouter: isLoggedIn() → false (tokens gone)',
      'Redirect → /auth/phone (re-authentication)',
      'User re-authenticates',
      'GoRouter: needsConsentGate() → true (consent gone)',
      'Redirect → /consent-gate (FIRST_LAUNCH mode)',
      'User re-accepts → Dashboard',
    ],
    hiveAfter:
        '{ privacy_version: "2.0", terms_version: "1.0",\n'
        '  accepted_at: "[today]", fresh_install: false }',
  ),
];

class _OnboardingStep {
  final int    step;
  final String title;
  final String description;
  final Color  color;
  final bool   isConsentGate;
  const _OnboardingStep({
    required this.step,
    required this.title,
    required this.description,
    required this.color,
    this.isConsentGate = false,
  });
}

const _kOnboardingFlow = [
  _OnboardingStep(
    step: 1,
    title: 'Welcome + OTP',
    description: 'Value proposition + phone entry + OTP verification. '
        'Authentication established. No consent gate yet.',
    color: Color(0xFF10B981),
  ),
  _OnboardingStep(
    step: 2,
    title: '🔒 CONSENT GATE',
    description: 'Privacy Policy + Terms of Service. '
        'Shown immediately after successful OTP. '
        'BLOCKS progression until both accepted.',
    color: Color(0xFF8B5CF6),
    isConsentGate: true,
  ),
  _OnboardingStep(
    step: 3,
    title: 'Microphone Permission',
    description: 'Single permission — rationale first, then system dialog. '
        'Other permissions deferred to first use.',
    color: Color(0xFF3B82F6),
  ),
  _OnboardingStep(
    step: 4,
    title: 'First Contact (Optional)',
    description: 'Add one emergency contact — optional. '
        '"I\'ll add later" skip available.',
    color: Color(0xFFF59E0B),
  ),
  _OnboardingStep(
    step: 5,
    title: 'You\'re Protected',
    description: 'Dashboard preview + optional SOS test drill. '
        'Detection calibration runs silently in background.',
    color: Color(0xFF10B981),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day162ConsentFlowTestsScreen extends ConsumerWidget {
  const Day162ConsentFlowTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_activeTabProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Consent Flow: Tests & Integration'),
        elevation: 0,
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
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),
            if (tab == 0) const _ScenariosTab(),
            if (tab == 1) const _OnboardingMapTab(),
            if (tab == 2) const _EdgeCasesTab(),
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
          colors: [Color(0xFF0A0A12), Color(0xFF050509), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  DAY 162', const Color(0xFF8B5CF6)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('🟢 FRONTEND-ONLY', const Color(0xFF10B981)),
            _badge(' D161-162 Final', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Consent Flow\nTests & Integration',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '5 user scenarios, onboarding placement map, '
            'and edge case handling. Completes the Days 161-162 block.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('5',    'Scenarios',      Color(0xFF8B5CF6)),
            _HStat('Step 2','In onboarding', Color(0xFF10B981)),
            _HStat('4',    'Edge cases',     Color(0xFFEF4444)),
            _HStat('A→B',  'Section B next', Color(0xFF9CA3AF)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.science_rounded,       Color(0xFF8B5CF6), 'Scenarios'),
      (Icons.account_tree_rounded,  Color(0xFF10B981), 'Onboarding'),
      (Icons.warning_amber_rounded, Color(0xFFEF4444), 'Edge Cases'),
    ];
    return Row(
      children: List.generate(3, (i) {
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
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(icon, color: isActive ? color : const Color(0xFF6B7280), size: 18),
                const SizedBox(height: ZapSpacing.xs),
                Text(label,
                    style: TextStyle(
                        color: isActive ? color : const Color(0xFF6B7280),
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

// ── Scenarios Tab ──────────────────────────────────────────────────────────────
class _ScenariosTab extends ConsumerWidget {
  const _ScenariosTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_scenarioProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.science_rounded,
          color: const Color(0xFF8B5CF6),
          text: '5 scenarios that the consent gate logic MUST handle correctly. '
              'Test each to confirm the right mode is shown and Hive is '
              'written (or not written) as expected.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Scenario selector
        const _SectionLabel('SELECT SCENARIO'),
        const SizedBox(height: ZapSpacing.md),
        ..._kScenarios.asMap().entries.map((e) {
          final i        = e.key;
          final scenario = e.value;
          final isActive = i == selected;

          return GestureDetector(
            onTap: () {
              ref.read(_scenarioProvider.notifier).state = i;
              ref.read(_scenarioRunProvider.notifier).state = false;
              ref.read(_scenarioStepProvider.notifier).state = 0;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: isActive
                    ? scenario.color.withOpacity(0.1)
                    : const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? scenario.color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: scenario.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(scenario.icon,
                      color: scenario.color, size: 18),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scenario.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(scenario.description,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 10)),
                    ],
                  ),
                ),
                // Gate mode badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: scenario.gateMode == 'none'
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : scenario.gateMode == 'first_launch'
                            ? const Color(0xFF3B82F6).withOpacity(0.1)
                            : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scenario.gateMode == 'none'
                        ? 'No gate'
                        : scenario.gateMode == 'first_launch'
                            ? 'First launch'
                            : 'Update',
                    style: TextStyle(
                      color: scenario.gateMode == 'none'
                          ? const Color(0xFF10B981)
                          : scenario.gateMode == 'first_launch'
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF59E0B),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.xl),

        // Selected scenario detail
        _ScenarioDetail(scenario: _kScenarios[selected]),
      ],
    );
  }
}

class _ScenarioDetail extends ConsumerStatefulWidget {
  final _Scenario scenario;
  const _ScenarioDetail({required this.scenario});

  @override
  ConsumerState<_ScenarioDetail> createState() =>
      _ScenarioDetailState();
}

class _ScenarioDetailState extends ConsumerState<_ScenarioDetail> {
  bool _running = false;
  int  _step    = 0;

  @override
  void didUpdateWidget(_ScenarioDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scenario != widget.scenario) {
      setState(() {
        _running = false;
        _step    = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final allDone = _step >= s.steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SCENARIO DETAIL'),
        const SizedBox(height: ZapSpacing.md),

        // Hive before
        _stateBox('HIVE BEFORE', s.hiveBefore, const Color(0xFFEF4444)),
        const SizedBox(height: ZapSpacing.sm),
        // Expected
        _stateBox('EXPECTED BEHAVIOUR', s.expectedBehaviour,
            const Color(0xFF10B981)),
        const SizedBox(height: ZapSpacing.lg),

        // Step-through runner
        const _SectionLabel('STEP-THROUGH SIMULATION'),
        const SizedBox(height: ZapSpacing.md),

        if (!_running)
          _actionButton(
            label: 'Run scenario step by step',
            icon: Icons.play_arrow_rounded,
            color: s.color,
            onTap: () => setState(() {
              _running = true;
              _step    = 0;
            }),
          )
        else ...[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: s.steps.asMap().entries.map((e) {
                final i    = e.key;
                final step = e.value;
                final isDone   = i < _step;
                final isActive = i == _step;
                final isLast   = i == s.steps.length - 1;

                return Column(children: [
                  GestureDetector(
                    onTap: isActive
                        ? () => setState(() => _step++)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(ZapSpacing.md),
                      color: isActive
                          ? s.color.withOpacity(0.07)
                          : Colors.transparent,
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFF10B981).withOpacity(0.15)
                                : isActive
                                    ? s.color.withOpacity(0.15)
                                    : const Color(0xFF111111),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone
                                  ? const Color(0xFF10B981).withOpacity(0.5)
                                  : isActive
                                      ? s.color.withOpacity(0.6)
                                      : const Color(0xFF2A2A2A),
                            ),
                          ),
                          child: isDone
                              ? const Icon(Icons.check_rounded,
                                  color: Color(0xFF10B981), size: 14)
                              : Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: isActive
                                              ? s.color
                                              : const Color(0xFF4B5563),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                        ),
                        const SizedBox(width: ZapSpacing.md),
                        Expanded(
                          child: Text(step,
                              style: TextStyle(
                                color: isDone
                                    ? const Color(0xFF6B7280)
                                    : isActive
                                        ? Colors.white
                                        : const Color(0xFF4B5563),
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: s.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Tap →',
                                style: TextStyle(
                                    color: s.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ]);
              }).toList(),
            ),
          ),
          if (allDone) ...[
            const SizedBox(height: ZapSpacing.md),
            _stateBox('HIVE AFTER', s.hiveAfter, const Color(0xFF10B981)),
            const SizedBox(height: ZapSpacing.sm),
            GestureDetector(
              onTap: () => setState(() {
                _running = false;
                _step    = 0;
              }),
              child: const Center(
                child: Text('↺ Reset scenario',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _stateBox(String label, String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 9,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11,
                  fontFamily: 'monospace', height: 1.5)),
        ]),
      );
}

// ── Onboarding Map Tab ─────────────────────────────────────────────────────────
class _OnboardingMapTab extends StatelessWidget {
  const _OnboardingMapTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.account_tree_rounded,
          color: const Color(0xFF10B981),
          text: 'The consent gate is Step 2 of the simplified 4-step '
              'onboarding (Day 133 redesign). It appears AFTER OTP '
              'verification (user is authenticated) but BEFORE permissions.',
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Onboarding flow
        const _SectionLabel('ONBOARDING FLOW  ·  WHERE CONSENT GATE FITS'),
        const SizedBox(height: ZapSpacing.md),
        ..._kOnboardingFlow.asMap().entries.map((e) {
          final i    = e.key;
          final step = e.value;
          final isLast = i == _kOnboardingFlow.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: step.isConsentGate ? 44 : 36,
                  height: step.isConsentGate ? 44 : 36,
                  decoration: BoxDecoration(
                    color: step.color.withOpacity(step.isConsentGate ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step.color.withOpacity(step.isConsentGate ? 0.6 : 0.3),
                      width: step.isConsentGate ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: step.isConsentGate
                        ? const Icon(Icons.privacy_tip_rounded,
                            color: Color(0xFF8B5CF6), size: 20)
                        : Text('${step.step}',
                            style: TextStyle(
                                color: step.color,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                if (!isLast)
                  Container(
                      width: 2,
                      height: step.isConsentGate ? 44 : 36,
                      color: const Color(0xFF2A2A2A)),
              ]),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: ZapSpacing.sm, top: 6),
                  child: Container(
                    padding: step.isConsentGate
                        ? const EdgeInsets.all(ZapSpacing.md)
                        : EdgeInsets.zero,
                    decoration: step.isConsentGate
                        ? BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.08),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                width: 2),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(step.title,
                              style: TextStyle(
                                color: step.isConsentGate
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.white,
                                fontSize: step.isConsentGate ? 13 : 12,
                                fontWeight: step.isConsentGate
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              )),
                          if (step.isConsentGate) ...[
                            const SizedBox(width: ZapSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('MANDATORY',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(step.description,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: ZapSpacing.xl),

        // Returning user path
        const _SectionLabel('RETURNING USER PATH'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(children: [
            _flowRow(Icons.login_rounded, const Color(0xFF3B82F6),
                'Open app', 'GoRouter redirect runs'),
            _flowRow(Icons.check_rounded, const Color(0xFF10B981),
                'Auth check', 'isLoggedIn() → true'),
            _flowRow(Icons.check_rounded, const Color(0xFF10B981),
                'Consent check', 'needsConsentGate() → false (versions match)'),
            _flowRow(Icons.check_rounded, const Color(0xFF10B981),
                'Onboard check', 'isOnboarded() → true'),
            _flowRow(Icons.dashboard_rounded, const Color(0xFF8B5CF6),
                'Dashboard loads', 'redirect returns null — proceed'),
          ]),
        ),
        const SizedBox(height: ZapSpacing.xl),

        // Deep link handling
        const _SectionLabel('DEEP LINK + CONSENT GATE'),
        const SizedBox(height: ZapSpacing.md),
        _codeNote('deep_link_with_gate',
            '// Push notification: "View evidence from SOS #42"\n'
            '// Deep link: zapsafe://vault/sos_42\n'
            '//\n'
            '// GoRouter calls redirect:\n'
            '//   authed=true, consented=FALSE → /consent-gate\n'
            '//\n'
            '// GoRouter stores the original intent internally.\n'
            '// After consent accepted:\n'
            '//   context.go(AppRoutes.dashboard)  ← simple approach\n'
            '//   OR\n'
            '//   context.go(state.location)  ← resume original deep link\n'
            '//\n'
            '// Recommendation: go to dashboard (simpler, safer).\n'
            '// User sees evidence vault in nav and can tap it.'),
      ],
    );
  }

  Widget _flowRow(IconData icon, Color color, String label, String desc) =>
      Padding(
        padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(desc,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 10)),
            ]),
          ),
        ]),
      );
}

// ── Edge Cases Tab ─────────────────────────────────────────────────────────────
class _EdgeCasesTab extends StatelessWidget {
  const _EdgeCasesTab();

  static const _cases = [
    (
      Color(0xFFEF4444),
      Icons.device_unknown_rounded,
      'Old Hive record (pre-versioning)',
      'A user on a very old app version (before Day 152 versioning) '
          'has a Hive record with no version fields.',
      'Treat as no record: version fields missing → null → needsConsentGate() returns true '
          '→ show FIRST_LAUNCH mode.',
      'if (record.privacyVersion == null) return true; // treat as new',
    ),
    (
      Color(0xFFF97316),
      Icons.wifi_off_rounded,
      'No internet during first launch',
      'User opens app for the first time with no internet. '
          'Cannot complete OTP verification.',
      'User never reaches the consent gate. '
          'OTP screen shows "No internet — check connection". '
          'Consent gate shown only after successful auth.',
      '// Consent gate loads from LOCAL assets (Day 151)\n'
          '// No backend call needed — works offline ✅',
    ),
    (
      Color(0xFFF59E0B),
      Icons.multiple_stop_rounded,
      'Multi-device: accepted on phone A, signs into phone B',
      'User accepts on their main phone. Gets a new phone. '
          'Signs in on the new phone — no Hive record there.',
      'FIRST_LAUNCH mode on new phone. Must accept again. '
          'This is intentional: consent is device-specific + DPDP requires explicit act. '
          'When backend syncs consent (Days 166+), can skip the gate.',
      'needsConsentGate() → true (no Hive on new device)\n'
          '// Future: if server says consented → skip gate',
    ),
    (
      Color(0xFF8B5CF6),
      Icons.security_rounded,
      'Tampered Hive record',
      'A malicious party modifies the Hive record directly '
          '(only possible on rooted device) to skip the consent gate.',
      'record_hash mismatch detected → treat as no record → show gate. '
          'On rooted devices, a warning is shown (Day 185-186).',
      'if (record.recordHash != computeHash(record)) {\n'
          '  return true; // tampered → re-show gate\n'
          '}',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBox(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          text: '4 edge cases that must be handled. '
              'Each has a defined behaviour so the app never enters '
              'an undefined state regarding consent.',
        ),
        const SizedBox(height: ZapSpacing.lg),

        ..._cases.map((c) {
          final (color, icon, title, situation, handling, code) = c;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: _EdgeCaseCard(
              color: color,
              icon: icon,
              title: title,
              situation: situation,
              handling: handling,
              code: code,
            ),
          );
        }),

        const SizedBox(height: ZapSpacing.xl),

        // Section A complete
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF10B981).withOpacity(0.12),
              const Color(0xFF10B981).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.45)),
          ),
          child: Column(children: [
            const Icon(Icons.verified_rounded,
                color: Color(0xFF10B981), size: 40),
            const SizedBox(height: ZapSpacing.md),
            const Text('Days 161-162: Consent Gate Block Complete ✅',
                style: TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Day 161: gate UI + legal checkboxes + Hive storage + GoRouter redirect\n'
              'Day 162: 5 test scenarios + onboarding placement + 4 edge cases',
              style: TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.lg),
            const Wrap(
              spacing: ZapSpacing.sm, runSpacing: ZapSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _Chip('Gate screen ✅',        Color(0xFF8B5CF6)),
                _Chip('Policy update mode ✅', Color(0xFFF59E0B)),
                _Chip('GoRouter redirect ✅',  Color(0xFF3B82F6)),
                _Chip('5 scenarios tested ✅', Color(0xFF10B981)),
                _Chip('Onboarding Step 2 ✅', Color(0xFF10B981)),
                _Chip('4 edge cases ✅',      Color(0xFFEF4444)),
              ],
            ),
            const SizedBox(height: ZapSpacing.lg),
            _infoBox(
              icon: Icons.arrow_forward_rounded,
              color: const Color(0xFF3B82F6),
              text: 'Days 163-165: Tracking & Analytics Preferences — '
                  'iOS App Tracking Transparency (ATT), Sentry opt-in, '
                  'usage analytics toggle.',
            ),
          ]),
        ),
      ],
    );
  }
}

class _EdgeCaseCard extends StatefulWidget {
  final Color    color;
  final IconData icon;
  final String   title, situation, handling, code;
  const _EdgeCaseCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.situation,
    required this.handling,
    required this.code,
  });

  @override
  State<_EdgeCaseCard> createState() => _EdgeCaseCardState();
}

class _EdgeCaseCardState extends State<_EdgeCaseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _expanded
              ? widget.color.withOpacity(0.07)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: _expanded
                ? widget.color.withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 16),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Column(children: [
                      const Divider(height: ZapSpacing.md,
                          color: Color(0xFF2A2A2A)),
                      _row(Icons.info_outline_rounded,
                          const Color(0xFF3B82F6),
                          'Situation', widget.situation),
                      const SizedBox(height: ZapSpacing.sm),
                      _row(Icons.build_rounded,
                          const Color(0xFF10B981),
                          'Handling', widget.handling),
                      const SizedBox(height: ZapSpacing.md),
                      _codeNote('implementation', widget.code),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, Color color, String label, String text) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: ZapSpacing.sm),
        Text('$label: ',
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 11, height: 1.4)),
        ),
      ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _infoBox({required IconData icon, required Color color, required String text}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(child: Text(text,
            style: const TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6))),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF), fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3), fontSize: 10,
                fontFamily: 'monospace', height: 1.6)),
      ]),
    );
