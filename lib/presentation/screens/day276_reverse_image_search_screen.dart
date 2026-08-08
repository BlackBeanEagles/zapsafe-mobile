/// Day 276 — Reverse Image Search (Opt-In)
///
/// Section D (Days 261-280): on-device perceptual-hash demo for suspicious
/// person photos — opt-in gated, zero-upload privacy explainer, local index match.
///
/// Tag: 🟡 MOCK-NOW · wire to on-device ML + hash index when backend ships.
///
/// Route: [AppRoutes.reverseImageSearch] → `/reverse-image-search`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF0EA5E9);
const _kTabs = ['Scan', 'Privacy', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

class _PhotoPreset {
  const _PhotoPreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color tint;
}

class _HashMatch {
  const _HashMatch({
    required this.id,
    required this.title,
    required this.source,
    required this.confidence,
    required this.flagged,
    required this.summary,
  });

  final String id;
  final String title;
  final String source;
  final int confidence;
  final bool flagged;
  final String summary;
}

const _kPresets = [
  _PhotoPreset(
    id: 'report_2847',
    label: 'Community report #2847',
    subtitle: 'Mock photo from anonymous safety report.',
    icon: Icons.report_rounded,
    tint: Color(0xFFEA580C),
  ),
  _PhotoPreset(
    id: 'repeat_contact',
    label: 'Repeat contact silhouette',
    subtitle: 'Mock follow-up from a prior journey alert.',
    icon: Icons.person_search_rounded,
    tint: Color(0xFFDC2626),
  ),
  _PhotoPreset(
    id: 'unknown_walker',
    label: 'Unknown passerby',
    subtitle: 'Generic silhouette · expect no local match.',
    icon: Icons.directions_walk_rounded,
    tint: Color(0xFF64748B),
  ),
];

const _kLocalIndex = {
  'report_2847': _HashMatch(
    id: 'idx_2847',
    title: 'Near-miss report · Koramangala',
    source: 'Community hash index (local cache)',
    confidence: 87,
    flagged: false,
    summary:
        'Similar perceptual hash seen in 1 anonymized community report from Feb 2026.',
  ),
  'repeat_contact': _HashMatch(
    id: 'idx_repeat_12',
    title: 'Prior journey alert · HSR Layout',
    source: 'Personal safety hash vault (local only)',
    confidence: 92,
    flagged: true,
    summary:
        'Strong hash similarity to a contact flagged during journey mode on 18 Jan 2026.',
  ),
};

String _mockPHash(String presetId) {
  final seed = presetId.codeUnits.fold<int>(0, (a, b) => a + b * 31);
  final hex = seed.toRadixString(16).padLeft(16, '0');
  return 'phash:${hex.substring(0, 16)}';
}

Map<String, dynamic> _searchPayload({
  required bool optIn,
  required bool consentAck,
  required String? presetId,
  required String? hash,
  required _HashMatch? match,
}) =>
    {
      'endpoint': 'POST /api/v1/safety/reverse-image-search/',
      'opt_in': optIn,
      'consent_acknowledged': consentAck,
      'upload_mode': 'hash_only',
      'photo_uploaded': false,
      'preset_id': presetId,
      'perceptual_hash': hash,
      'match_found': match != null,
      if (match != null)
        'match': {
          'id': match.id,
          'confidence': match.confidence,
          'flagged': match.flagged,
          'source': match.source,
        },
      'privacy': {
        'on_device_hash': true,
        'raw_image_leaves_device': false,
        'index_scope': 'local_cache_only',
      },
      'wire_note': 'Mock demo · real flow uses on-device pHash + optional index sync',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d276TabProvider = StateProvider<int>((ref) => 0);
final _d276OptInProvider = StateProvider<bool>((ref) => false);
final _d276ConsentAckProvider = StateProvider<bool>((ref) => false);
final _d276PresetProvider = StateProvider<String?>((ref) => null);
final _d276HashProvider = StateProvider<String?>((ref) => null);
final _d276MatchProvider = StateProvider<_HashMatch?>((ref) => null);
final _d276SearchingProvider = StateProvider<bool>((ref) => false);
final _d276LastScanProvider = StateProvider<String?>((ref) => null);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day276ReverseImageSearchScreen extends ConsumerWidget {
  const Day276ReverseImageSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d276OptInProvider);
    final match = ref.watch(_d276MatchProvider);
    final searching = ref.watch(_d276SearchingProvider);
    final hash = ref.watch(_d276HashProvider);

    String badge;
    if (!optIn) {
      badge = 'OPT-IN OFF';
    } else if (searching) {
      badge = 'HASHING…';
    } else if (match != null) {
      badge = '${match.confidence}% MATCH';
    } else if (hash != null) {
      badge = 'NO MATCH';
    } else {
      badge = 'HASH ONLY';
    }

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 276 · Reverse Image Search'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: ref.watch(_d276TabProvider),
            onSelect: (i) => ref.read(_d276TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d276TabProvider)) {
              0 => const _ScanTab(),
              1 => const _PrivacyTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Scan ───────────────────────────────────────────────────────────────
class _ScanTab extends ConsumerWidget {
  const _ScanTab();

  Future<void> _runSearch(WidgetRef ref, String presetId) async {
    ref.read(_d276SearchingProvider.notifier).state = true;
    ref.read(_d276MatchProvider.notifier).state = null;
    ref.read(_d276HashProvider.notifier).state = null;

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final hash = _mockPHash(presetId);
    ref.read(_d276HashProvider.notifier).state = hash;
    ref.read(_d276MatchProvider.notifier).state = _kLocalIndex[presetId];
    ref.read(_d276LastScanProvider.notifier).state =
        DateTime.now().toIso8601String().substring(11, 19);
    ref.read(_d276SearchingProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d276OptInProvider);
    final consentAck = ref.watch(_d276ConsentAckProvider);
    final selectedId = ref.watch(_d276PresetProvider);
    final hash = ref.watch(_d276HashProvider);
    final match = ref.watch(_d276MatchProvider);
    final searching = ref.watch(_d276SearchingProvider);
    final lastScan = ref.watch(_d276LastScanProvider);
    final canScan = optIn && consentAck && selectedId != null && !searching;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟡 MOCK-NOW · Section D Day 16/20 · on-device pHash · local index · zero upload',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        if (!optIn || !consentAck) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !optIn
                      ? 'Reverse image search is disabled'
                      : 'Consent acknowledgement required',
                  style: const TextStyle(
                    color: ZapColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  !optIn
                      ? 'Enable opt-in on the Privacy tab before running any hash scan.'
                      : 'Review the privacy explainer and acknowledge before scanning.',
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: ZapSpacing.sm),
                FilledButton.icon(
                  onPressed: () =>
                      ref.read(_d276TabProvider.notifier).state = 1,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                  label: Text(!optIn ? 'Open Privacy tab' : 'Review privacy'),
                  style: FilledButton.styleFrom(backgroundColor: _kAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
        ],
        const _SectionTitle(
          title: 'Select mock photo',
          subtitle: 'Preset silhouettes · no camera roll access in demo',
        ),
        ..._kPresets.map((preset) {
          final selected = selectedId == preset.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: optIn
                    ? () {
                        ref.read(_d276PresetProvider.notifier).state =
                            preset.id;
                        ref.read(_d276HashProvider.notifier).state = null;
                        ref.read(_d276MatchProvider.notifier).state = null;
                      }
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  decoration: BoxDecoration(
                    color: selected
                        ? preset.tint.withOpacity(0.12)
                        : ZapColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? preset.tint.withOpacity(0.5)
                          : ZapColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: preset.tint.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(preset.icon, color: preset.tint),
                      ),
                      const SizedBox(width: ZapSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.label,
                              style: TextStyle(
                                color: optIn
                                    ? ZapColors.textPrimary
                                    : ZapColors.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              preset.subtitle,
                              style: const TextStyle(
                                color: ZapColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected ? _kAccent : ZapColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: ZapSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canScan
                ? () => _runSearch(ref, selectedId)
                : null,
            icon: searching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint_rounded, size: 16),
            label: Text(searching ? 'Computing hash…' : 'Run on-device hash'),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (hash != null) ...[
          const SizedBox(height: ZapSpacing.lg),
          const _SectionTitle(
            title: 'Perceptual hash (on-device)',
            subtitle: 'Mock pHash · raw image never leaves device',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: SelectableText(
              hash,
              style: const TextStyle(
                color: ZapColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (lastScan != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Computed at $lastScan · compared against local hash index',
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
        ],
        if (hash != null) ...[
          const SizedBox(height: ZapSpacing.lg),
          const _SectionTitle(
            title: 'Local index result',
            subtitle: 'Mock match against cached safety hash vault',
          ),
          if (match != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: match.flagged
                    ? ZapColors.warning.withOpacity(0.1)
                    : ZapColors.safe.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: match.flagged
                      ? ZapColors.warning.withOpacity(0.4)
                      : ZapColors.safe.withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        match.flagged
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: match.flagged
                            ? ZapColors.warning
                            : ZapColors.safe,
                        size: 18,
                      ),
                      const SizedBox(width: ZapSpacing.sm),
                      Expanded(
                        child: Text(
                          match.title,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${match.confidence}%',
                        style: TextStyle(
                          color: match.flagged
                              ? ZapColors.warning
                              : ZapColors.safe,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.source,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.summary,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(ZapSpacing.md),
              decoration: BoxDecoration(
                color: ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ZapColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_off_rounded,
                      color: ZapColors.textMuted, size: 18),
                  SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      'No matches in local hash index · photo hash stays on device.',
                      style: TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        const _FlowSteps(),
      ],
    );
  }
}

class _FlowSteps extends StatelessWidget {
  const _FlowSteps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('1', 'Opt in + acknowledge privacy explainer'),
      ('2', 'Pick mock photo · compute pHash on device'),
      ('3', 'Compare hash to local safety index · zero upload'),
    ];

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works (mock)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      step.$1,
                      style: const TextStyle(
                        color: _kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.sm),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tab 1: Privacy ────────────────────────────────────────────────────────────
class _PrivacyTab extends ConsumerWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d276OptInProvider);
    final consentAck = ref.watch(_d276ConsentAckProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.phone_android_rounded,
          title: 'On-device hash only',
          subtitle:
              'The demo computes a perceptual hash locally. Raw photos are never '
              'uploaded, stored in cloud, or shared with third parties.',
        ),
        const _PolicyRow(
          icon: Icons.storage_rounded,
          title: 'Local index comparison',
          subtitle:
              'Matches run against a cached hash index on your device — community '
              'reports and personal safety vault entries, anonymized.',
        ),
        const _PolicyRow(
          icon: Icons.block_rounded,
          title: 'What we do not do',
          subtitle:
              'No facial recognition training · no reverse image search against '
              'the open web · no law-enforcement database queries in this demo.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Enable reverse image search (opt-in)',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'Required before any hash scan · synced with Privacy Settings mock',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: optIn,
          activeColor: _kAccent,
          onChanged: (v) {
            ref.read(_d276OptInProvider.notifier).state = v;
            if (!v) {
              ref.read(_d276ConsentAckProvider.notifier).state = false;
              ref.read(_d276HashProvider.notifier).state = null;
              ref.read(_d276MatchProvider.notifier).state = null;
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I understand hash-only processing',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'Acknowledge that only perceptual hashes are compared locally',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: consentAck,
          activeColor: _kAccent,
          onChanged: optIn
              ? (v) => ref.read(_d276ConsentAckProvider.notifier).state = v
              : null,
        ),
        const SizedBox(height: ZapSpacing.md),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.privacySettings),
          icon: const Icon(Icons.settings_outlined, size: 16),
          label: const Text('Open Privacy Settings (Day 157)'),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.consentManagement),
          icon: const Icon(Icons.verified_user_outlined, size: 16),
          label: const Text('Consent Management (Day 155)'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Production note: wire opt-in to Day 157 privacy toggles and audit '
            'consent in Day 155 before enabling hash index sync.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optIn = ref.watch(_d276OptInProvider);
    final consentAck = ref.watch(_d276ConsentAckProvider);
    final presetId = ref.watch(_d276PresetProvider);
    final hash = ref.watch(_d276HashProvider);
    final match = ref.watch(_d276MatchProvider);
    final payload = _searchPayload(
      optIn: optIn,
      consentAck: consentAck,
      presetId: presetId,
      hash: hash,
      match: match,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.image_search_rounded,
          title: 'Reverse image search (opt-in)',
          subtitle:
              'Suspicious person photo workflow · on-device perceptual hash · '
              'local index match · privacy-first demo for safety reports.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reverse search spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy search spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 275 Year in Review'),
              onPressed: () => context.push(AppRoutes.yearInReview),
            ),
            ActionChip(
              label: const Text('Day 270 Community Heatmap'),
              onPressed: () => context.push(AppRoutes.communityHeatmap),
            ),
            ActionChip(
              label: const Text('Day 157 Privacy Settings'),
              onPressed: () => context.push(AppRoutes.privacySettings),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
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
