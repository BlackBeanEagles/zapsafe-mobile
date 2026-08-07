/// Day 118 — Android APK Distribution
///
/// Two distribution options for Android beta:
///   Option A: Google Play Internal Testing (recommended) — auto-updates,
///             Play Store install, track metrics
///   Option B: Direct APK Download — faster, no review, manual install
///
/// Includes: option comparison, Play Console setup guide, APK build
/// commands, mock internal testing invitation, release notes form,
/// and simulated "Upload to Play Console" flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _selectedOptionProvider  = StateProvider<_DistOption>((ref) => _DistOption.playStore);
final _uploadStateProvider     = StateProvider<_UploadState>((ref) => _UploadState.idle);
final _setupStepProvider       = StateProvider<int>((ref) => 0);
final _checklistProvider       = StateProvider<List<bool>>(
  (ref) => List.filled(_kChecklist.length, false),
);

enum _DistOption  { playStore, directApk }
enum _UploadState { idle, building, signing, uploading, processing, done }

// ── Static data ────────────────────────────────────────────────────────────────
const _kChecklist = [
  'Google Play Developer account (\$25 one-time)',
  'App created in Google Play Console',
  'Bundle ID: com.zapsafe.beta',
  'Keystore file generated & backed up securely',
  'key.properties configured in android/app/',
  'Version: 0.5 · Build: 117',
  'Internal testers group created in Play Console',
  'Minimum SDK: 24 (Android 7.0)',
];

const _kPlaySetupSteps = [
  (
    Icons.open_in_browser_rounded,
    Color(0xFF3B82F6),
    'Open Play Console',
    'play.google.com/console → select your app (or create new)',
    'Step 1',
  ),
  (
    Icons.science_rounded,
    Color(0xFF10B981),
    'Go to Internal Testing',
    'Testing → Internal Testing → Create new release',
    'Step 2',
  ),
  (
    Icons.upload_file_rounded,
    Color(0xFF8B5CF6),
    'Upload AAB/APK',
    'Drag .aab file (preferred) or .apk → Play validates signing',
    'Step 3',
  ),
  (
    Icons.group_add_rounded,
    Color(0xFFF59E0B),
    'Add testers',
    'Add email addresses or share the opt-in link directly',
    'Step 4',
  ),
  (
    Icons.share_rounded,
    Color(0xFFF97316),
    'Share test link',
    'Copy opt-in URL → testers click → join internal testing group',
    'Step 5',
  ),
];

const _kBuildCommands = [
  ('Build release APK',    'flutter build apk --flavor beta --release',           Color(0xFF3B82F6)),
  ('Build release AAB',    'flutter build appbundle --flavor beta --release',      Color(0xFF10B981)),
  ('Analyze APK size',     'flutter build apk --analyze-size',                     Color(0xFF8B5CF6)),
  ('Check signing',        'keytool -list -v -keystore zapsafe.keystore',          Color(0xFFF59E0B)),
];

const _kUploadLabels = [
  '',
  'Building release AAB…',
  'Signing with keystore…',
  'Uploading to Play Console…',
  'Play validates & processes…',
  'Live on Internal Testing track!',
];

const _kUploadColors = [
  Color(0xFF3B82F6),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFF59E0B),
  Color(0xFFF97316),
  Color(0xFF10B981),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day118AndroidDistributionScreen extends ConsumerWidget {
  const Day118AndroidDistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = ref.watch(_selectedOptionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 118 · Android Distribution'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Option picker
            const _SectionLabel('CHOOSE DISTRIBUTION METHOD'),
            const SizedBox(height: ZapSpacing.md),
            const _OptionPicker(),
            const SizedBox(height: ZapSpacing.xl),

            // Comparison table
            const _SectionLabel('OPTION COMPARISON'),
            const SizedBox(height: ZapSpacing.md),
            const _ComparisonTable(),
            const SizedBox(height: ZapSpacing.xl),

            // Checklist
            const _SectionLabel('PRE-RELEASE CHECKLIST'),
            const SizedBox(height: ZapSpacing.md),
            const _Checklist(),
            const SizedBox(height: ZapSpacing.xl),

            // Build commands
            const _SectionLabel('BUILD COMMANDS'),
            const SizedBox(height: ZapSpacing.md),
            const _BuildCommands(),
            const SizedBox(height: ZapSpacing.xl),

            // Setup guide (changes based on option)
            _SectionLabel(
              option == _DistOption.playStore
                  ? 'PLAY CONSOLE SETUP  ·  5 STEPS'
                  : 'DIRECT APK SETUP  ·  3 STEPS',
            ),
            const SizedBox(height: ZapSpacing.md),
            option == _DistOption.playStore
                ? const _PlaySetupGuide()
                : const _DirectApkGuide(),
            const SizedBox(height: ZapSpacing.xl),

            // Upload simulator
            const _SectionLabel('SIMULATE UPLOAD TO PLAY CONSOLE'),
            const SizedBox(height: ZapSpacing.md),
            const _UploadSimulator(),
            const SizedBox(height: ZapSpacing.xl),

            // Mock invitation card
            const _SectionLabel('INTERNAL TESTING INVITE  ·  WHAT TESTERS SEE'),
            const SizedBox(height: ZapSpacing.md),
            const _PlayInviteCard(),
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
          colors: [Color(0xFF0D2818), Color(0xFF061410), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded, color: Color(0xFF10B981), size: 13),
                    SizedBox(width: 5),
                    Text(
                      '⚡  BETA  ·  DAY 118',
                      style: TextStyle(
                        color: Color(0xFF10B981),
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
                    Icon(Icons.android_rounded, color: Color(0xFF3DDC84), size: 13),
                    SizedBox(width: ZapSpacing.xs),
                    Text('Android', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Android APK\nDistribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Two paths: Google Play Internal Testing (recommended — '
            'auto-updates, metrics, Play Store install) or direct APK '
            'download (faster, no review, manual install).',
            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('AAB',   'Preferred format', Color(0xFF10B981)),
              _HeroStat('Auto',  'Updates',          Color(0xFF3B82F6)),
              _HeroStat('\$25',  'Play Console',     Color(0xFFF59E0B)),
              _HeroStat('Free',  'Direct APK',       Color(0xFF8B5CF6)),
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
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
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

// ── Option picker ──────────────────────────────────────────────────────────────
class _OptionPicker extends ConsumerWidget {
  const _OptionPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_selectedOptionProvider);

    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            icon: Icons.play_arrow_rounded,
            iconBg: const Color(0xFF3DDC84),
            title: 'Google Play\nInternal Testing',
            badge: 'Recommended',
            badgeColor: const Color(0xFF10B981),
            selected: selected == _DistOption.playStore,
            onTap: () => ref.read(_selectedOptionProvider.notifier).state =
                _DistOption.playStore,
          ),
        ),
        const SizedBox(width: ZapSpacing.sm),
        Expanded(
          child: _OptionCard(
            icon: Icons.download_rounded,
            iconBg: const Color(0xFF8B5CF6),
            title: 'Direct APK\nDownload',
            badge: 'Simpler',
            badgeColor: const Color(0xFF8B5CF6),
            selected: selected == _DistOption.directApk,
            onTap: () => ref.read(_selectedOptionProvider.notifier).state =
                _DistOption.directApk,
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, badgeColor;
  final String title, badge;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: selected ? iconBg.withOpacity(0.1) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: selected ? iconBg.withOpacity(0.5) : const Color(0xFF2A2A2A),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconBg, size: 20),
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: iconBg, size: 18),
              ],
            ),
            const SizedBox(height: ZapSpacing.sm),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFD1D5DB),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge,
                  style: TextStyle(
                      color: badgeColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comparison table ───────────────────────────────────────────────────────────
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Auto-updates',       true,  false),
      ('Play Store install', true,  false),
      ('Track metrics',      true,  false),
      ('Requires review',    false, false),
      ('Setup cost',         false, true),
      ('Instant share',      false, true),
      ('No Play account',    false, true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.md, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Feature',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Center(
                    child: Text('Play',
                        style: TextStyle(
                            color: Color(0xFF3DDC84),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Direct',
                        style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final (label, play, direct) = e.value;
            final isLast = i == rows.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      Expanded(
                        child: Center(
                          child: Icon(
                            play ? Icons.check_rounded : Icons.close_rounded,
                            color: play
                                ? const Color(0xFF10B981)
                                : const Color(0xFF4B5563),
                            size: 18,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Icon(
                            direct ? Icons.check_rounded : Icons.close_rounded,
                            color: direct
                                ? const Color(0xFF10B981)
                                : const Color(0xFF4B5563),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Checklist ──────────────────────────────────────────────────────────────────
class _Checklist extends ConsumerWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks    = ref.watch(_checklistProvider);
    final doneCount = checks.where((c) => c).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Progress header
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$doneCount / ${_kChecklist.length} complete',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                      doneCount == _kChecklist.length
                          ? '✅ Ready to ship'
                          : 'Tap to check off',
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
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: doneCount / _kChecklist.length,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: AlwaysStoppedAnimation(
                      doneCount == _kChecklist.length
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3DDC84),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          ...List.generate(_kChecklist.length, (i) {
            final done   = checks[i];
            final isLast = i == _kChecklist.length - 1;
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
                        horizontal: ZapSpacing.md, vertical: 13),
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
                              color: done
                                  ? const Color(0xFF6B7280)
                                  : Colors.white,
                              fontSize: 13,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              decorationColor: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, color: Color(0xFF2A2A2A)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Build commands ─────────────────────────────────────────────────────────────
class _BuildCommands extends StatelessWidget {
  const _BuildCommands();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kBuildCommands.asMap().entries.map((e) {
          final i = e.key;
          final (label, cmd, color) = e.value;
          final isLast = i == _kBuildCommands.length - 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('# $label',
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: ZapSpacing.xs),
              Text(cmd,
                  style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4)),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  child: Divider(
                      height: 1, color: const Color(0xFF30363D).withOpacity(0.5)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Play Console setup guide ───────────────────────────────────────────────────
class _PlaySetupGuide extends ConsumerWidget {
  const _PlaySetupGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_setupStepProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(_kPlaySetupSteps.length, (i) {
          final (icon, color, title, desc, step) = _kPlaySetupSteps[i];
          final isActive = i == active;
          final isDone   = i < active;
          final isLast   = i == _kPlaySetupSteps.length - 1;

          return GestureDetector(
            onTap: () => ref.read(_setupStepProvider.notifier).state = i,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: isActive ? color.withOpacity(0.08) : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF10B981).withOpacity(0.15)
                              : color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF10B981).withOpacity(0.4)
                                : isActive
                                    ? color.withOpacity(0.5)
                                    : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : icon,
                          color: isDone ? const Color(0xFF10B981) : color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                  color: isActive ? Colors.white : const Color(0xFFD1D5DB),
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                )),
                            if (isActive) ...[
                              const SizedBox(height: ZapSpacing.xs),
                              Text(desc,
                                  style: const TextStyle(
                                      color: Color(0xFF9CA3AF), fontSize: 11, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                      Text(step,
                          style: const TextStyle(
                              color: Color(0xFF4B5563), fontSize: 10)),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Direct APK guide ───────────────────────────────────────────────────────────
class _DirectApkGuide extends StatelessWidget {
  const _DirectApkGuide();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        Icons.build_rounded,
        Color(0xFF8B5CF6),
        'Build release APK',
        'flutter build apk --flavor beta --release\nOutput: build/app/outputs/flutter-apk/app-beta-release.apk',
      ),
      (
        Icons.cloud_upload_rounded,
        Color(0xFFF59E0B),
        'Upload to hosting',
        'Upload APK to Firebase Hosting, S3, or Google Drive.\nShare the download link with testers.',
      ),
      (
        Icons.install_mobile_rounded,
        Color(0xFF10B981),
        'Testers install manually',
        'Download APK → Settings → Unknown sources → Install.\nNo auto-updates — testers must reinstall each new version.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final (icon, color, title, desc) = e.value;
          final isLast = i == steps.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(ZapSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(icon, color: color, size: 16),
                              const SizedBox(width: 6),
                              Text(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(desc,
                              style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  height: 1.5,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Upload simulator ───────────────────────────────────────────────────────────
class _UploadSimulator extends ConsumerWidget {
  const _UploadSimulator();

  static const _kStates = [
    _UploadState.idle,
    _UploadState.building,
    _UploadState.signing,
    _UploadState.uploading,
    _UploadState.processing,
    _UploadState.done,
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
              label: 'Simulate Play Console upload',
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF3DDC84),
              onTap: () async {
                for (final s in _kStates.skip(1)) {
                  if (!context.mounted) return;
                  ref.read(_uploadStateProvider.notifier).state = s;
                  await Future.delayed(const Duration(milliseconds: 900));
                }
              },
            )
          else if (state == _UploadState.done) ...[
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 48),
            const SizedBox(height: ZapSpacing.md),
            const Text('Live on Internal Testing track!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'Testers will receive an update notification via Play Store.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ZapSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Text(
                'https://play.google.com/apps/testing/com.zapsafe.beta',
                style: TextStyle(
                    color: Color(0xFF79C0FF),
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            GestureDetector(
              onTap: () => ref
                  .read(_uploadStateProvider.notifier)
                  .state = _UploadState.idle,
              child: const Text('Reset simulation',
                  style: TextStyle(
                      color: Color(0xFF6B7280), fontSize: 12)),
            ),
          ] else
            ...List.generate(_kStates.length - 1, (i) {
              final stepIdx  = i + 1;
              final isDone   = stepIdx < idx;
              final isActive = stepIdx == idx;
              final stepColor = _kUploadColors[stepIdx];

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
                          ? const Icon(Icons.check_rounded,
                              color: Color(0xFF10B981), size: 14)
                          : isActive
                              ? Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: CircularProgressIndicator(
                                      color: stepColor, strokeWidth: 2),
                                )
                              : null,
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Text(
                      _kUploadLabels[stepIdx],
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF6B7280)
                            : isActive
                                ? Colors.white
                                : const Color(0xFF4B5563),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Play invite card ───────────────────────────────────────────────────────────
class _PlayInviteCard extends StatelessWidget {
  const _PlayInviteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Row(
              children: [
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
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: ZapSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ZapSafe Beta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text('Anthropic Safety Labs',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 12)),
                      SizedBox(height: ZapSpacing.xs),
                      Row(
                        children: [
                          _Badge('v0.5-beta',  Color(0xFF3DDC84)),
                          SizedBox(width: 6),
                          _Badge('Build 117',  Color(0xFF3B82F6)),
                          SizedBox(width: 6),
                          _Badge('Internal',   Color(0xFFF59E0B)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Stats row
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _InfoCell(Icons.people_rounded,     'Testers',   '1,000'),
                _InfoCell(Icons.update_rounded,      'Updates',   'Auto'),
                _InfoCell(Icons.star_rounded,        'Track',     'Internal'),
                _InfoCell(Icons.storage_rounded,     'Size',      '28 MB'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Install button
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84),
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              ),
              child: const Center(
                child: Text('Join Internal Testing',
                    style: TextStyle(
                        color: Color(0xFF0A0A0A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
                left: ZapSpacing.lg,
                right: ZapSpacing.lg,
                bottom: ZapSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(ZapSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Text(
                'https://play.google.com/apps/testing/com.zapsafe.beta',
                style: TextStyle(
                    color: Color(0xFF79C0FF),
                    fontSize: 11,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
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
        Icon(icon, color: const Color(0xFF6B7280), size: 16),
        const SizedBox(height: ZapSpacing.xs),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10)),
      ],
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
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
            Icon(icon, color: Colors.black87, size: 18),
            const SizedBox(width: ZapSpacing.sm),
            Text(label,
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
