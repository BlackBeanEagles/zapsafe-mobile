/// Day 117 — iOS TestFlight Build
///
/// Step-by-step guide for archiving the iOS app in Xcode, uploading to
/// App Store Connect, passing Apple review, and distributing via TestFlight.
/// Includes: build checklist, mock TestFlight invitation card, tester
/// instructions, and a simulated "Upload to App Store Connect" flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _uploadStateProvider  = StateProvider<_UploadState>((ref) => _UploadState.idle);
final _checklistProvider    = StateProvider<List<bool>>(
  (ref) => List.filled(_kChecklist.length, false),
);
final _activePhaseProvider  = StateProvider<int>((ref) => 0);

enum _UploadState { idle, archiving, validating, uploading, reviewing, done }

// ── Static data ────────────────────────────────────────────────────────────────
const _kChecklist = [
  'Apple Developer account active (\$99/year)',
  'Bundle ID registered: com.zapsafe.beta',
  'Provisioning profile: ZapSafe Beta (Distribution)',
  'Code signing: Distribution certificate installed',
  'App Store Connect project created',
  'Version: 0.5 · Build: 116',
  'Privacy policy URL linked in App Store Connect',
  'TestFlight internal group created',
];

const _kPhases = [
  (
    Icons.archive_rounded,
    Color(0xFF3B82F6),
    'Archive',
    'Xcode → Product → Archive\nBuilds release IPA for distribution',
    '~3 min',
  ),
  (
    Icons.verified_rounded,
    Color(0xFF8B5CF6),
    'Validate',
    'Xcode Organizer → Distribute App\n→ App Store Connect → Validate',
    '~1 min',
  ),
  (
    Icons.cloud_upload_rounded,
    Color(0xFFF59E0B),
    'Upload',
    'Xcode uploads IPA to App Store Connect.\nDSYMs uploaded for crash symbolication.',
    '~5 min',
  ),
  (
    Icons.rate_review_rounded,
    Color(0xFFEF4444),
    'Apple Review',
    'Apple reviews beta builds automatically.\nFirst build ~30 min. Subsequent: ~5 min.',
    '~30 min',
  ),
  (
    Icons.ios_share_rounded,
    Color(0xFF10B981),
    'Share Link',
    'TestFlight → Internal Group → Share Link\nhttps://testflight.apple.com/join/xxxxx',
    'Instant',
  ),
];

const _kTesterSteps = [
  (Icons.link_rounded,         Color(0xFF3B82F6),  'Open the TestFlight link on iPhone'),
  (Icons.download_rounded,     Color(0xFF8B5CF6),  'Tap "Start Testing" → Install TestFlight app'),
  (Icons.install_mobile_rounded, Color(0xFFF59E0B), 'Tap "Install" — ZapSafe Beta installs'),
  (Icons.update_rounded,       Color(0xFF10B981),  'Auto-updates when new build uploaded'),
  (Icons.feedback_rounded,     Color(0xFFF97316),  'Send feedback directly from TestFlight'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day117TestFlightScreen extends ConsumerWidget {
  const Day117TestFlightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 117 · iOS TestFlight'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Requirements checklist
            const _SectionLabel('PRE-FLIGHT CHECKLIST'),
            const SizedBox(height: ZapSpacing.md),
            const _Checklist(),
            const SizedBox(height: ZapSpacing.xl),

            // Phase stepper
            const _SectionLabel('BUILD & UPLOAD PHASES'),
            const SizedBox(height: ZapSpacing.md),
            const _PhaseStepper(),
            const SizedBox(height: ZapSpacing.xl),

            // Simulated upload flow
            const _SectionLabel('SIMULATE UPLOAD FLOW'),
            const SizedBox(height: ZapSpacing.md),
            const _UploadSimulator(),
            const SizedBox(height: ZapSpacing.xl),

            // Mock TestFlight invite card
            const _SectionLabel('TESTFLIGHT INVITE  ·  WHAT TESTERS SEE'),
            const SizedBox(height: ZapSpacing.md),
            const _TestFlightInviteCard(),
            const SizedBox(height: ZapSpacing.xl),

            // Tester instructions
            const _SectionLabel('TESTER STEPS'),
            const SizedBox(height: ZapSpacing.md),
            const _TesterSteps(),
            const SizedBox(height: ZapSpacing.xl),

            // Key facts
            const _SectionLabel('KEY FACTS'),
            const SizedBox(height: ZapSpacing.md),
            const _KeyFacts(),
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
          colors: [Color(0xFF0C2340), Color(0xFF06111E), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded, color: Color(0xFF3B82F6), size: 13),
                    SizedBox(width: 5),
                    Text(
                      '⚡  BETA  ·  DAY 117',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apple_rounded, color: Colors.white, size: 13),
                    SizedBox(width: ZapSpacing.xs),
                    Text('iOS Only', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'iOS TestFlight\nDistribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Archive in Xcode → upload to App Store Connect → '
            'Apple review (~30 min) → share TestFlight link with '
            'up to 10,000 external testers.',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('10K',   'Max testers',   Color(0xFF3B82F6)),
              _HeroStat('~30m',  'Apple review',  Color(0xFF8B5CF6)),
              _HeroStat('Auto',  'Updates',       Color(0xFF10B981)),
              _HeroStat('Free',  'Distribution',  Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ));
  }
}

// ── Checklist ──────────────────────────────────────────────────────────────────
class _Checklist extends ConsumerWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(_checklistProvider);
    final doneCount = checks.where((c) => c).length;

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(ZapSpacing.radius)),
            border: const Border(
              left: BorderSide(color: Color(0xFF2A2A2A)),
              right: BorderSide(color: Color(0xFF2A2A2A)),
              top: BorderSide(color: Color(0xFF2A2A2A)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$doneCount / ${_kChecklist.length} complete',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    doneCount == _kChecklist.length ? '✅ Ready to build' : 'Tap to check off',
                    style: TextStyle(
                      color: doneCount == _kChecklist.length
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: doneCount / _kChecklist.length,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: AlwaysStoppedAnimation(
                    doneCount == _kChecklist.length
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        // Items
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(ZapSpacing.radius)),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: List.generate(_kChecklist.length, (i) {
              final done = checks[i];
              return GestureDetector(
                onTap: () {
                  final updated = List<bool>.from(checks);
                  updated[i] = !updated[i];
                  ref.read(_checklistProvider.notifier).state = updated;
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: ZapSpacing.md, vertical: 14),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: done
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                            child: done
                                ? const Icon(Icons.check_rounded,
                                    color: Color(0xFF10B981), size: 14)
                                : null,
                          ),
                          const SizedBox(width: ZapSpacing.md),
                          Expanded(
                            child: Text(
                              _kChecklist[i],
                              style: TextStyle(
                                color: done ? const Color(0xFF6B7280) : Colors.white,
                                fontSize: 13,
                                decoration: done ? TextDecoration.lineThrough : null,
                                decorationColor: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < _kChecklist.length - 1)
                      const Divider(height: 1, color: Color(0xFF2A2A2A)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Phase stepper ──────────────────────────────────────────────────────────────
class _PhaseStepper extends ConsumerWidget {
  const _PhaseStepper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_activePhaseProvider);

    return Column(
      children: List.generate(_kPhases.length, (i) {
        final (icon, color, title, desc, duration) = _kPhases[i];
        final isActive = i == active;
        final isDone   = i < active;

        return GestureDetector(
          onTap: () => ref.read(_activePhaseProvider.notifier).state = i,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : isActive
                              ? color.withOpacity(0.15)
                              : const Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone
                            ? const Color(0xFF10B981).withOpacity(0.5)
                            : isActive
                                ? color.withOpacity(0.6)
                                : const Color(0xFF2A2A2A),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : icon,
                      color: isDone
                          ? const Color(0xFF10B981)
                          : isActive
                              ? color
                              : const Color(0xFF4B5563),
                      size: 20,
                    ),
                  ),
                  if (i < _kPhases.length - 1)
                    Container(
                      width: 2,
                      height: isActive ? 56 : 32,
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : const Color(0xFF2A2A2A),
                    ),
                ],
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: i < _kPhases.length - 1 ? ZapSpacing.sm : 0,
                      top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isActive ? Colors.white : const Color(0xFFD1D5DB),
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(duration,
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 6),
                        Text(desc,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5)),
                      ],
                      const SizedBox(height: ZapSpacing.sm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Upload simulator ───────────────────────────────────────────────────────────
class _UploadSimulator extends ConsumerWidget {
  const _UploadSimulator();

  static const _kStates = [
    _UploadState.idle,
    _UploadState.archiving,
    _UploadState.validating,
    _UploadState.uploading,
    _UploadState.reviewing,
    _UploadState.done,
  ];

  static const _kLabels = [
    '',
    'Archiving release build…',
    'Validating with App Store Connect…',
    'Uploading IPA + dSYMs…',
    'Waiting for Apple review…',
    'Approved! Link ready.',
  ];

  static const _kColors = [
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_uploadStateProvider);
    final idx   = _kStates.indexOf(state);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          if (state == _UploadState.idle)
            _ActionButton(
              label: 'Start upload simulation',
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () async {
                for (final s in _kStates.skip(1)) {
                  if (!context.mounted) return;
                  ref.read(_uploadStateProvider.notifier).state = s;
                  await Future.delayed(Duration(
                    milliseconds: s == _UploadState.reviewing ? 1800 : 900,
                  ));
                }
              },
            )
          else if (state == _UploadState.done) ...[
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
            const SizedBox(height: ZapSpacing.md),
            const Text('Build approved!',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.sm),
            const Text('TestFlight link is now active and shareable.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: ZapSpacing.md),
            // Mock link chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Text(
                'https://testflight.apple.com/join/zApSaFe',
                style: TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            GestureDetector(
              onTap: () => ref.read(_uploadStateProvider.notifier).state = _UploadState.idle,
              child: const Text('Reset simulation',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ] else ...[
            // Progress steps
            ...List.generate(_kStates.length - 1, (i) {
              final _ = _kStates[i + 1];
              final stepIdx   = i + 1;
              final isDone    = stepIdx < idx;
              final isActive  = stepIdx == idx;
              final stepColor = _kColors[stepIdx];

              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : isActive
                                ? stepColor.withOpacity(0.15)
                                : const Color(0xFF111111),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF10B981).withOpacity(0.5)
                              : isActive
                                  ? stepColor.withOpacity(0.6)
                                  : const Color(0xFF2A2A2A),
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14)
                          : isActive
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                      color: stepColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Text(
                      _kLabels[stepIdx],
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF6B7280)
                            : isActive
                                ? Colors.white
                                : const Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── TestFlight invite card ─────────────────────────────────────────────────────
class _TestFlightInviteCard extends StatelessWidget {
  const _TestFlightInviteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        children: [
          // TestFlight-style header
          Container(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF3A3A3C))),
            ),
            child: Row(
              children: [
                // App icon mock
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ZapColors.danger, Color(0xFFB01F2A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: ZapSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ZapSafe Beta',
                          style: TextStyle(
                              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('Anthropic Safety Labs',
                          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
                      SizedBox(height: ZapSpacing.xs),
                      Row(
                        children: [
                          _PillBadge('v0.5-beta', Color(0xFF0A84FF)),
                          SizedBox(width: 6),
                          _PillBadge('Build 116', Color(0xFF30D158)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Install button area
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Start Testing',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: ZapSpacing.md),
                const Text(
                  'By tapping "Start Testing", you agree to provide feedback '
                  'to the developer. Your usage data may be shared with them.',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ZapSpacing.md),
                const Divider(color: Color(0xFF3A3A3C)),
                const SizedBox(height: ZapSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _InfoCell(Icons.calendar_today_rounded, 'Expires', '90 days'),
                    _InfoCell(Icons.people_rounded,         'Testers', '1,000'),
                    _InfoCell(Icons.star_rounded,           'Rating',  'Beta'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoCell(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF8E8E93), size: 18),
        const SizedBox(height: ZapSpacing.xs),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11)),
      ],
    );
  }
}

// ── Tester steps ───────────────────────────────────────────────────────────────
class _TesterSteps extends StatelessWidget {
  const _TesterSteps();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(_kTesterSteps.length, (i) {
          final (icon, color, text) = _kTesterSteps[i];
          final isLast = i == _kTesterSteps.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(text,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Key facts ──────────────────────────────────────────────────────────────────
const _kFacts = [
  (Icons.group_rounded,         Color(0xFF3B82F6),  'Up to 10,000 external testers via TestFlight'),
  (Icons.update_rounded,        Color(0xFF10B981),  'App auto-updates when new build uploaded'),
  (Icons.timer_rounded,         Color(0xFFF97316),  'Beta builds expire after 90 days'),
  (Icons.feedback_rounded,      Color(0xFF8B5CF6),  'Testers can send feedback directly from TestFlight'),
  (Icons.no_photography_rounded, Color(0xFFEF4444), 'Cannot share beta builds or screenshots publicly'),
  (Icons.attach_money_rounded,  Color(0xFFF59E0B),  'Requires \$99/year Apple Developer account'),
];

class _KeyFacts extends StatelessWidget {
  const _KeyFacts();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(_kFacts.length, (i) {
          final (icon, color, text) = _kFacts[i];
          final isLast = i == _kFacts.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 13),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Text(text,
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB), fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
