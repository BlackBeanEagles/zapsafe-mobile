/// Day 123 — Hotfix Release & Post-Release Verification
///
/// Second half of the Day 122-123 crash-fix cycle. Day 122 applied
/// the code fixes. Day 123 ships v0.5.1 to testers and verifies it worked:
///   • Write release notes (v0.5.1 changelog)
///   • Distribute to TestFlight + Play Console internal track
///   • Notify 847 active testers
///   • Monitor crash rate 24h post-release
///   • Confirm P0/P1 crashes no longer appear in Sentry
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _distStateProvider    = StateProvider<_DistState>((ref) => _DistState.idle);
final _notifyStateProvider  = StateProvider<_NotifyState>((ref) => _NotifyState.idle);
final _hoursProvider        = StateProvider<int>((ref) => 0);
final _notesEditProvider    = StateProvider<bool>((ref) => false);
final _verifyChecksProvider = StateProvider<List<bool>>(
  (ref) => List.filled(_kVerifyChecks.length, false),
);

enum _DistState   { idle, uploading, reviewing, live }
enum _NotifyState { idle, sending, sent }

// ── Data ───────────────────────────────────────────────────────────────────────
const _kReleaseNotes = [
  ('🐛 Fixed', 'Android 11 SMS crash on SOS send',
      'Migrated to ActivityResultContracts.RequestPermission + '
      'graceful push fallback when SMS denied.'),
  ('🐛 Fixed', 'iPhone 7 OOM after 20 min (location leak)',
      'CLLocationManager.stopUpdatingLocation() now called in dispose(); '
      'GPS buffer capped at 500 entries; LITE tier uses lower accuracy.'),
  ('🐛 Fixed', 'TFLite scream model OOM on < 2 GB RAM',
      'LITE-tier devices now load StubScreamClassifier; '
      '"AI detection unavailable" notice shown in settings.'),
  ('⚡ Improved', 'LITE-tier stability',
      'Memory usage on low-RAM devices reduced by ~60 MB.'),
];

const _kDistSteps = [
  (Icons.build_rounded,         Color(0xFF3B82F6), 'Build release AAB + IPA'),
  (Icons.verified_rounded,      Color(0xFF8B5CF6), 'Code-sign both artefacts'),
  (Icons.cloud_upload_rounded,  Color(0xFFF59E0B), 'Upload to TestFlight + Play'),
  (Icons.rate_review_rounded,   Color(0xFFEF4444), 'Apple review (~30 min)'),
  (Icons.check_circle_rounded,  Color(0xFF10B981), 'Both tracks live → notify testers'),
];

const _kVerifyChecks = [
  'Sentry: android_11_sms_crash — 0 new events in last 24h',
  'Sentry: ios_oom_location — 0 new events in last 24h',
  'Sentry: tflite_oom_lite — 0 new events in last 24h',
  'Overall crash rate < 0.10% (was 0.31%)',
  'No new P0 issues opened since v0.5.1 ship',
  'TestFlight tester feedback — no new crash reports',
  'Play Console ANR rate unchanged (no regression)',
];

// 24-hour crash trend (per-hour counts, after v0.5.1 at hour 0)
const _kHourlyCrashes = [3, 2, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0,
                          1, 0, 0, 0, 0, 0, 0, 1];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day123HotfixReleaseScreen extends ConsumerWidget {
  const Day123HotfixReleaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distState   = ref.watch(_distStateProvider);
    final notifyState = ref.watch(_notifyStateProvider);
    final hours       = ref.watch(_hoursProvider);
    final verifChecks = ref.watch(_verifyChecksProvider);
    final verifiedAll = verifChecks.every((c) => c);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 123 · Hotfix Release'),
        elevation: 0,
        actions: [
          if (distState == _DistState.live || notifyState == _NotifyState.sent)
            TextButton(
              onPressed: () {
                ref.read(_distStateProvider.notifier).state   = _DistState.idle;
                ref.read(_notifyStateProvider.notifier).state = _NotifyState.idle;
                ref.read(_hoursProvider.notifier).state       = 0;
                ref.read(_verifyChecksProvider.notifier).state =
                    List.filled(_kVerifyChecks.length, false);
              },
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
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

            // Release notes
            const _SectionLabel('RELEASE NOTES  ·  v0.5.1'),
            const SizedBox(height: ZapSpacing.md),
            const _ReleaseNotesCard(),
            const SizedBox(height: ZapSpacing.xl),

            // Distribution
            const _SectionLabel('DISTRIBUTE TO TESTERS'),
            const SizedBox(height: ZapSpacing.md),
            _DistributionPanel(state: distState),
            const SizedBox(height: ZapSpacing.xl),

            // Tester notification (shows after dist live)
            if (distState == _DistState.live) ...[
              const _SectionLabel('NOTIFY 847 ACTIVE TESTERS'),
              const SizedBox(height: ZapSpacing.md),
              _NotifyPanel(state: notifyState, hours: hours),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // Post-release monitoring (shows after notified)
            if (notifyState == _NotifyState.sent) ...[
              const _SectionLabel('24-HOUR CRASH RATE MONITOR'),
              const SizedBox(height: ZapSpacing.md),
              _CrashMonitor(hours: hours),
              const SizedBox(height: ZapSpacing.xl),

              const _SectionLabel('VERIFICATION CHECKLIST'),
              const SizedBox(height: ZapSpacing.md),
              _VerifyChecklist(verifiedAll: verifiedAll),
              const SizedBox(height: ZapSpacing.xl),

              if (verifiedAll) ...[
                const _SectionLabel('DAY 123 COMPLETE'),
                const SizedBox(height: ZapSpacing.md),
                const _CompletionCard(),
                const SizedBox(height: ZapSpacing.xl),
              ],
            ],

            // Next steps
            const _SectionLabel('NEXT  ·  DAYS 124-125'),
            const SizedBox(height: ZapSpacing.md),
            const _NextStepsCard(),
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
          colors: [Color(0xFF0A2010), Color(0xFF051008), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 123', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5.1 Hotfix', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Hotfix Release\n& Verification',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Fixes from Day 122 are committed. Today: write release '
            'notes, ship v0.5.1 to both platforms, notify 847 testers, '
            'and monitor crash rate over 24h to confirm fixes held.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('3',     'Crashes fixed',  Color(0xFF10B981)),
            _HStat('847',   'Testers to notify', Color(0xFF3B82F6)),
            _HStat('0.31→\n0.10%', 'Rate drop', Color(0xFFF59E0B)),
            _HStat('24h',   'Monitor window', Color(0xFF8B5CF6)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
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
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Release notes card ─────────────────────────────────────────────────────────
class _ReleaseNotesCard extends ConsumerWidget {
  const _ReleaseNotesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = ref.watch(_notesEditProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('v0.5.1',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ),
              const SizedBox(width: ZapSpacing.sm),
              const Text('Hotfix — 2026-05-31',
                  style: TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => ref
                    .read(_notesEditProvider.notifier)
                    .state = !editing,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(editing ? 'Done' : 'Edit',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 11)),
                ),
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),

          if (editing)
            const _NotesEditor()
          else
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                children: _kReleaseNotes.map((note) {
                  final (type, title, desc) = note;
                  final isFix = type.contains('Fixed');
                  final color = isFix
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: ZapSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(desc,
                                  style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 11,
                                      height: 1.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesEditor extends StatelessWidget {
  const _NotesEditor();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const TextField(
          maxLines: 8,
          style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.6),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.all(ZapSpacing.md),
            hintText: '## v0.5.1\n\n🐛 Fixed: ...\n⚡ Improved: ...',
            hintStyle: TextStyle(
                color: Color(0xFF4B5563), fontSize: 12, fontFamily: 'monospace'),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

// ── Distribution panel ─────────────────────────────────────────────────────────
class _DistributionPanel extends ConsumerWidget {
  final _DistState state;
  const _DistributionPanel({required this.state});

  static const _kStates = [
    _DistState.idle,
    _DistState.uploading,
    _DistState.reviewing,
    _DistState.live,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _DistState.live
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Platform targets
        Row(children: [
          _PlatformChip(Icons.apple_rounded, 'TestFlight', const Color(0xFF3B82F6),
              state == _DistState.live),
          const SizedBox(width: ZapSpacing.sm),
          _PlatformChip(Icons.android_rounded, 'Play Console', const Color(0xFF3DDC84),
              state == _DistState.live),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        if (state == _DistState.idle)
          _actionButton(
            label: 'Upload v0.5.1 to both platforms',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              for (final s in _kStates.skip(1)) {
                if (!context.mounted) return;
                ref.read(_distStateProvider.notifier).state = s;
                await Future.delayed(Duration(
                  milliseconds: s == _DistState.reviewing ? 1400 : 900,
                ));
              }
            },
          )
        else if (state == _DistState.live) ...[
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 42),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5.1 live on both platforms!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _linkChip('testflight.apple.com/join/zApSaFe', const Color(0xFF3B82F6)),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _linkChip('play.google.com/apps/testing/com.zapsafe.beta',
                  const Color(0xFF3DDC84)),
            ],
          ),
        ] else
          _DistProgress(state: state),
      ]),
    );
  }

  Widget _linkChip(String url, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Text(url,
            style: TextStyle(
                color: color, fontSize: 10, fontFamily: 'monospace')),
      );
}

class _PlatformChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool live;
  const _PlatformChip(this.icon, this.label, this.color, this.live);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: live ? color.withOpacity(0.1) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
              color: live ? color.withOpacity(0.4) : const Color(0xFF2A2A2A)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: live ? color : const Color(0xFF4B5563), size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: live ? color : const Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: live ? FontWeight.w700 : FontWeight.w400)),
          if (live) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_rounded, color: color, size: 14),
          ],
        ]),
      ),
    );
  }
}

class _DistProgress extends StatelessWidget {
  final _DistState state;
  const _DistProgress({required this.state});

  static const _steps = [
    (Color(0xFF3B82F6), 'Uploading artefacts…'),
    (Color(0xFFEF4444), 'Waiting for Apple review…'),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = state == _DistState.uploading ? 0 : 1;
    return Column(
      children: List.generate(_steps.length, (i) {
        final (color, label) = _steps[i];
        final isDone   = i < idx;
        final isActive = i == idx;
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981).withOpacity(0.15)
                    : isActive
                        ? color.withOpacity(0.15)
                        : const Color(0xFF111111),
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : isActive
                            ? color.withOpacity(0.6)
                            : const Color(0xFF2A2A2A)),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFF10B981), size: 14)
                  : isActive
                      ? Padding(
                          padding: const EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                              color: color, strokeWidth: 2))
                      : null,
            ),
            const SizedBox(width: ZapSpacing.md),
            Text(label,
                style: TextStyle(
                    color: isDone
                        ? const Color(0xFF6B7280)
                        : isActive
                            ? Colors.white
                            : const Color(0xFF4B5563),
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400)),
          ]),
        );
      }),
    );
  }
}

// ── Notify panel ───────────────────────────────────────────────────────────────
class _NotifyPanel extends ConsumerWidget {
  final _NotifyState state;
  final int hours;
  const _NotifyPanel({required this.state, required this.hours});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _NotifyState.sent
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Notification preview
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [ZapColors.danger, Color(0xFFB01F2A)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ZapSafe Beta · Update available',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(
                    'v0.5.1 fixes 3 crashes including the Android 11 '
                    'SOS send bug. Update now.',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (state == _NotifyState.idle)
          _actionButton(
            label: 'Send update notification to 847 testers',
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () async {
              ref.read(_notifyStateProvider.notifier).state =
                  _NotifyState.sending;
              await Future.delayed(const Duration(milliseconds: 1200));
              if (!context.mounted) return;
              ref.read(_notifyStateProvider.notifier).state =
                  _NotifyState.sent;
              // Start simulating hours post-release
              _simulateHours(ref, context);
            },
          )
        else if (state == _NotifyState.sending)
          _statusChip(Icons.send_rounded, const Color(0xFF8B5CF6),
              'Sending FCM push to 847 devices…', loading: true)
        else ...[
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              '847 testers notified via FCM push'),
          const SizedBox(height: ZapSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('847', 'Sent', const Color(0xFF10B981)),
              _miniStat('${(hours * 31).clamp(0, 812)}',
                  'Opened', const Color(0xFF3B82F6)),
              _miniStat('${(hours * 18).clamp(0, 614)}',
                  'Updated', const Color(0xFF8B5CF6)),
              _miniStat('${hours}h', 'Post-release', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ]),
    );
  }

  void _simulateHours(WidgetRef ref, BuildContext context) async {
    for (int h = 1; h <= 24; h++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!context.mounted) return;
      ref.read(_hoursProvider.notifier).state = h;
    }
  }
}

Widget _miniStat(String value, String label, Color color) => Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      Text(label,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9)),
    ]);

// ── Crash monitor ──────────────────────────────────────────────────────────────
class _CrashMonitor extends ConsumerWidget {
  final int hours;
  const _CrashMonitor({required this.hours});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleHours = hours.clamp(1, 24);
    final visible = _kHourlyCrashes.take(visibleHours).toList();
    final total   = visible.fold(0, (a, b) => a + b);
    final rate    = visibleHours > 0 ? (total / (847 * visibleHours) * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        // Stats row
        Row(children: [
          Expanded(child: _MetricBox('${total}', 'Total crashes', const Color(0xFFEF4444))),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _MetricBox(
              '${rate.toStringAsFixed(3)}%', 'Crash rate', const Color(0xFF10B981))),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(child: _MetricBox(
              '${visibleHours}h', 'Monitored', const Color(0xFF3B82F6))),
        ]),
        const SizedBox(height: ZapSpacing.lg),

        // Bar chart
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (i) {
            final hasData = i < visibleHours;
            final count   = hasData ? _kHourlyCrashes[i] : 0;
            final maxVal  = 3.0;
            final h       = hasData ? (count / maxVal * 48).clamp(4.0, 48.0) : 4.0;
            final color   = count == 0
                ? const Color(0xFF10B981)
                : count == 1
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasData && count > 0)
                      Text('$count',
                          style: TextStyle(
                              color: color, fontSize: 8, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: hasData ? h : 4,
                      decoration: BoxDecoration(
                        color: hasData ? color : const Color(0xFF2A2A2A),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.sm),
        // X axis labels
        Row(children: [
          const Expanded(child: Text('0h',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 8))),
          const Expanded(
              flex: 11,
              child: Center(
                child: Text('→ Hours post-release',
                    style: TextStyle(color: Color(0xFF4B5563), fontSize: 8)),
              )),
          const Expanded(child: Text('24h',
              style: TextStyle(color: Color(0xFF4B5563), fontSize: 8),
              textAlign: TextAlign.end)),
        ]),
        const SizedBox(height: ZapSpacing.md),
        // Interpretation
        Container(
          padding: const EdgeInsets.all(ZapSpacing.sm),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.trending_down_rounded,
                color: Color(0xFF10B981), size: 16),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: Text(
                'Crash rate holding at ~${rate.toStringAsFixed(3)}% — '
                '${total == 0 ? "no crashes in this window ✓" : "residual noise only, P0s eliminated ✓"}',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11, height: 1.5),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _MetricBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            vertical: ZapSpacing.sm, horizontal: ZapSpacing.sm),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Verification checklist ─────────────────────────────────────────────────────
class _VerifyChecklist extends ConsumerWidget {
  final bool verifiedAll;
  const _VerifyChecklist({required this.verifiedAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_verifyChecksProvider);
    final doneCount = checks.where((c) => c).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: verifiedAll
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(ZapSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$doneCount / ${_kVerifyChecks.length} verified',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(
                verifiedAll ? '✅ Hotfix confirmed' : 'Check each item',
                style: TextStyle(
                    color: verifiedAll
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: verifiedAll ? FontWeight.w700 : FontWeight.w400),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(ZapSpacing.radius - 1)),
          child: LinearProgressIndicator(
            value: doneCount / _kVerifyChecks.length,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              verifiedAll ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
            ),
            minHeight: 4,
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        ...List.generate(_kVerifyChecks.length, (i) {
          final done   = checks[i];
          final isLast = i == _kVerifyChecks.length - 1;
          return GestureDetector(
            onTap: () {
              final updated = List<bool>.from(checks);
              updated[i] = !updated[i];
              ref.read(_verifyChecksProvider.notifier).state = updated;
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 13),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: done
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4B5563)),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFF10B981), size: 14)
                        : null,
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Text(_kVerifyChecks[i],
                        style: TextStyle(
                          color: done
                              ? const Color(0xFF6B7280)
                              : Colors.white,
                          fontSize: 13,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF6B7280),
                        )),
                  ),
                ]),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Completion card ────────────────────────────────────────────────────────────
class _CompletionCard extends StatelessWidget {
  const _CompletionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF10B981).withOpacity(0.12),
          const Color(0xFF10B981).withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
            color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(children: [
        const Icon(Icons.verified_rounded,
            color: Color(0xFF10B981), size: 48),
        const SizedBox(height: ZapSpacing.md),
        const Text('Days 122-123 Complete!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: ZapSpacing.sm),
        const Text(
          'v0.5.1 shipped and verified.\n'
          'Crash rate: 0.31% → 0.10% · All 3 P0/P1 issues resolved.',
          style: TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 13, height: 1.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Summary chips
        Wrap(
          spacing: ZapSpacing.sm,
          runSpacing: ZapSpacing.sm,
          alignment: WrapAlignment.center,
          children: const [
            _Chip('3 crashes fixed',       Color(0xFF10B981)),
            _Chip('102 users unblocked',   Color(0xFF3B82F6)),
            _Chip('0.10% crash rate',      Color(0xFFF59E0B)),
            _Chip('847 testers notified',  Color(0xFF8B5CF6)),
            _Chip('24h monitoring passed', Color(0xFF10B981)),
          ],
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

// ── Next steps ─────────────────────────────────────────────────────────────────
class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard();

  static const _steps = [
    (Color(0xFFF97316), 'Days 124-125',
        'Fix false-positive confusion — add post-SOS explanation screen, raise M1 threshold 0.80 → 0.88'),
    (Color(0xFFF59E0B), 'Day 126',
        'Fix UI bugs — Hindi text overflow, WCAG contrast issues, API 29 icon tint'),
    (Color(0xFF3B82F6), 'Days 127-128',
        'Fix Samsung Android 13 notification delay — Doze mode workaround + SCHEDULE_EXACT_ALARM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: _steps.asMap().entries.map((e) {
          final i = e.key;
          final (color, days, action) = e.value;
          final isLast = i == _steps.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(days,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        Text(action,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ]);
        }).toList(),
      ),
    );
  }
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius:
              BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );

Widget _statusChip(
  IconData icon,
  Color color,
  String label, {
  bool loading = false,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          loading
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
