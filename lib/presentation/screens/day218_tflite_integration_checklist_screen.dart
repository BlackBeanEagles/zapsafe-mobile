/// Day 218 — TFLite Real Model Integration Checklist
///
/// Section A (Days 201-220): track replacing placeholder `.tflite` assets with
/// trained M1–M8 models — load mock, status per slot, links to assets + service.
///
/// Tag: 🟣 POLISH — integration checklist, mock load only.
///
/// Route: [AppRoutes.tfliteIntegrationChecklist] → `/tflite-integration-checklist`
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum TfliteSlotStatus { placeholder, trained, loaded }

extension TfliteSlotStatusX on TfliteSlotStatus {
  String get label => switch (this) {
        TfliteSlotStatus.placeholder => 'Placeholder',
        TfliteSlotStatus.trained => 'Trained',
        TfliteSlotStatus.loaded => 'Loaded',
      };

  Color get color => switch (this) {
        TfliteSlotStatus.placeholder => ZapColors.textMuted,
        TfliteSlotStatus.trained => ZapColors.warning,
        TfliteSlotStatus.loaded => ZapColors.safe,
      };

  IconData get icon => switch (this) {
        TfliteSlotStatus.placeholder => Icons.hourglass_empty_rounded,
        TfliteSlotStatus.trained => Icons.cloud_download_rounded,
        TfliteSlotStatus.loaded => Icons.check_circle_rounded,
      };
}

class TfliteSlotSpec {
  final String id;
  final String name;
  final String purpose;
  final String assetFile;
  final String assetPath;
  final double sizeMb;
  final double accuracyPct;
  final Color accent;
  final IconData icon;
  final TfliteSlotStatus initialStatus;
  final String registryKey;

  const TfliteSlotSpec({
    required this.id,
    required this.name,
    required this.purpose,
    required this.assetFile,
    required this.assetPath,
    required this.sizeMb,
    required this.accuracyPct,
    required this.accent,
    required this.icon,
    required this.initialStatus,
    required this.registryKey,
  });
}

const _kSlots = [
  TfliteSlotSpec(
    id: 'M1',
    name: 'Scream Classifier',
    purpose: 'Distress vocalisations · MFCC + ZCR',
    assetFile: 'scream_classifier_v1.tflite',
    assetPath: 'assets/models/scream_classifier_v1.tflite',
    sizeMb: 1.1,
    accuracyPct: 91,
    accent: Color(0xFFEF4444),
    icon: Icons.hearing_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'scream',
  ),
  TfliteSlotSpec(
    id: 'M2',
    name: 'Motion Anomaly',
    purpose: 'Fall / struggle · IMU 6-DOF',
    assetFile: 'motion_anomaly_v1.tflite',
    assetPath: 'assets/models/motion_anomaly_v1.tflite',
    sizeMb: 1.0,
    accuracyPct: 88,
    accent: Color(0xFFF97316),
    icon: Icons.vibration_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'motion',
  ),
  TfliteSlotSpec(
    id: 'M3',
    name: 'Scene Analyser',
    purpose: 'Weapon / blood context · camera',
    assetFile: 'scene_analyser_v1.tflite',
    assetPath: 'assets/models/scene_analyser_v1.tflite',
    sizeMb: 0.9,
    accuracyPct: 86,
    accent: Color(0xFF8B5CF6),
    icon: Icons.image_search_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'scene',
  ),
  TfliteSlotSpec(
    id: 'M4',
    name: 'Vocal Stress EN',
    purpose: 'English vocal stress detection',
    assetFile: 'vocal_stress_en_v1.tflite',
    assetPath: 'assets/models/vocal_stress_en_v1.tflite',
    sizeMb: 0.9,
    accuracyPct: 87,
    accent: Color(0xFF3B82F6),
    icon: Icons.mic_rounded,
    initialStatus: TfliteSlotStatus.trained,
    registryKey: 'vocal_en',
  ),
  TfliteSlotSpec(
    id: 'M5',
    name: 'Vocal Stress APAC',
    purpose: 'Hindi / Tamil / Telugu stress',
    assetFile: 'vocal_stress_apac_v1.tflite',
    assetPath: 'assets/models/vocal_stress_apac_v1.tflite',
    sizeMb: 0.8,
    accuracyPct: 84,
    accent: Color(0xFF10B981),
    icon: Icons.language_rounded,
    initialStatus: TfliteSlotStatus.trained,
    registryKey: 'vocal_apac',
  ),
  TfliteSlotSpec(
    id: 'M6',
    name: 'Fall Detector',
    purpose: 'Hard fall vs normal movement',
    assetFile: 'fall_detector_v1.tflite',
    assetPath: 'assets/models/fall_detector_v1.tflite',
    sizeMb: 0.7,
    accuracyPct: 89,
    accent: Color(0xFF06B6D4),
    icon: Icons.accessibility_new_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'fall',
  ),
  TfliteSlotSpec(
    id: 'M7',
    name: 'Ambient Threat',
    purpose: 'Glass break / siren / gunshot audio',
    assetFile: 'ambient_threat_v1.tflite',
    assetPath: 'assets/models/ambient_threat_v1.tflite',
    sizeMb: 0.8,
    accuracyPct: 85,
    accent: Color(0xFFEC4899),
    icon: Icons.graphic_eq_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'ambient',
  ),
  TfliteSlotSpec(
    id: 'M8',
    name: 'DCS Fusion',
    purpose: 'Combines M1–M7 scores → DCS',
    assetFile: 'dcs_fusion_v1.tflite',
    assetPath: 'assets/models/dcs_fusion_v1.tflite',
    sizeMb: 0.5,
    accuracyPct: 96,
    accent: Color(0xFFF59E0B),
    icon: Icons.hub_rounded,
    initialStatus: TfliteSlotStatus.placeholder,
    registryKey: 'fusion',
  ),
];

Map<String, TfliteSlotStatus> _initialStatuses() => {
      for (final s in _kSlots) s.id: s.initialStatus,
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d218TabProvider = StateProvider<int>((ref) => 0);
final _d218StatusProvider = StateProvider<Map<String, TfliteSlotStatus>>(
  (ref) => _initialStatuses(),
);
final _d218LoadingProvider = StateProvider<Set<String>>((ref) => {});

const _kTabs = ['Models', 'Integration', 'Spec'];

// ── Screen ────────────────────────────────────────────────────────────────────
class Day218TfliteIntegrationChecklistScreen extends ConsumerWidget {
  const Day218TfliteIntegrationChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d218TabProvider);
    final statuses = ref.watch(_d218StatusProvider);
    final loaded =
        statuses.values.where((s) => s == TfliteSlotStatus.loaded).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 218 · TFLite Integration'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$loaded/${_kSlots.length}',
                style: TextStyle(
                  color: loaded == _kSlots.length
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
            onSelect: (i) => ref.read(_d218TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _ModelsTab(),
              1 => const _IntegrationTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _mockLoadModel(WidgetRef ref, TfliteSlotSpec slot) async {
  if (ref.read(_d218LoadingProvider).contains(slot.id)) return;
  ref.read(_d218LoadingProvider.notifier).update((s) => {...s, slot.id});
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  ref.read(_d218StatusProvider.notifier).update((map) {
    final current = map[slot.id] ?? TfliteSlotStatus.placeholder;
    final next = current == TfliteSlotStatus.placeholder
        ? TfliteSlotStatus.trained
        : TfliteSlotStatus.loaded;
    return {...map, slot.id: next};
  });
  ref.read(_d218LoadingProvider.notifier).update((s) {
    final next = {...s}..remove(slot.id);
    return next;
  });
}

// ── Tab 0: Models ─────────────────────────────────────────────────────────────
class _ModelsTab extends ConsumerWidget {
  const _ModelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d218StatusProvider);
    final loading = ref.watch(_d218LoadingProvider);
    final loaded =
        statuses.values.where((s) => s == TfliteSlotStatus.loaded).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
          ),
          child: const Text(
            '🟣 POLISH · Section A Day 18/20 · Replace 1 KB placeholders with trained weights',
            style: TextStyle(color: ZapColors.warning, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: loaded / _kSlots.length,
                  minHeight: 8,
                  backgroundColor: ZapColors.bgElevated,
                  color: loaded == _kSlots.length
                      ? ZapColors.safe
                      : ZapColors.warning,
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              '$loaded/${_kSlots.length} loaded',
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ..._kSlots.map((slot) {
          final status = statuses[slot.id] ?? slot.initialStatus;
          final isLoading = loading.contains(slot.id);
          return _ModelCard(
            slot: slot,
            status: status,
            isLoading: isLoading,
            onLoad: status == TfliteSlotStatus.loaded
                ? null
                : () => _mockLoadModel(ref, slot),
          );
        }),
        const SizedBox(height: ZapSpacing.md),
        Semantics(
          label: 'Reset all model statuses',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(_d218StatusProvider.notifier).state = _initialStatuses();
              ref.read(_d218LoadingProvider.notifier).state = {};
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset all slots'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  final TfliteSlotSpec slot;
  final TfliteSlotStatus status;
  final bool isLoading;
  final VoidCallback? onLoad;

  const _ModelCard({
    required this.slot,
    required this.status,
    required this.isLoading,
    this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: ZapSpacing.md),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status == TfliteSlotStatus.loaded
              ? ZapColors.safe.withOpacity(0.5)
              : ZapColors.border,
          width: status == TfliteSlotStatus.loaded ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: slot.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(slot.icon, color: slot.accent, size: 24),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          slot.id,
                          style: TextStyle(
                            color: slot.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            slot.name,
                            style: const TextStyle(
                              color: ZapColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      slot.purpose,
                      style: const TextStyle(
                        color: ZapColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _InfoChip(label: 'Size', value: '${slot.sizeMb} MB'),
              _InfoChip(
                label: 'Recall',
                value: '${slot.accuracyPct.toStringAsFixed(0)}%',
              ),
              _InfoChip(label: 'Registry', value: slot.registryKey),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            slot.assetPath,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          if (onLoad != null) ...[
            const SizedBox(height: ZapSpacing.md),
            Semantics(
              label: 'Load model ${slot.id}',
              button: true,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onLoad,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        status == TfliteSlotStatus.placeholder
                            ? Icons.download_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                label: Text(
                  isLoading
                      ? 'Loading…'
                      : status == TfliteSlotStatus.placeholder
                          ? 'Fetch trained weights'
                          : 'Load model',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 75),
                  backgroundColor: slot.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TfliteSlotStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ZapColors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.border),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: ZapColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Tab 1: Integration ────────────────────────────────────────────────────────
class _IntegrationTab extends StatelessWidget {
  const _IntegrationTab();

  @override
  Widget build(BuildContext context) {
    const assetFiles = [
      ('scream_classifier_v1.tflite', '1 KB placeholder · real ~1.1 MB'),
      ('dcs_fusion_v1.tflite', '1 KB placeholder · real ~0.5 MB'),
      ('motion_anomaly_v1.tflite', 'Missing from bundle · OTA via Day 56'),
      ('scene_analyser_v1.tflite', 'Missing · Month 4 SageMaker drop'),
    ];

    const serviceSteps = [
      ('POST /api/v1/ml/model-downloads/', 'Report successful .tflite install'),
      ('GET /api/v1/ml/model-downloads/', 'Fetch device download history'),
      ('sha256_verified', 'Toggle integrity check on install'),
      ('DownloadModelType', 'scream · motion · scene · dcs wire enum'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Integration paths',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.folder_rounded, color: ZapColors.warning, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'assets/models/',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                'Bundled .tflite files referenced by ModelRegistry and '
                'Interpreter.fromAsset(). Replace placeholders without code changes.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.md),
              ...assetFiles.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.insert_drive_file_rounded,
                          size: 14, color: ZapColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: ZapColors.textSecondary,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text: '${f.$1}\n',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: ZapColors.textPrimary,
                                ),
                              ),
                              TextSpan(text: f.$2),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_download_rounded,
                      color: ZapColors.info, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'model_download_service.dart',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.sm),
              const Text(
                'lib/data/services/model_download_service.dart — reports OTA '
                'installs to backend after HuggingFace / CDN drop.',
                style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: ZapSpacing.md),
              ...serviceSteps.map(
                (s) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(ZapSpacing.sm),
                  decoration: BoxDecoration(
                    color: ZapColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ZapColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.$1,
                          style: const TextStyle(
                            color: ZapColors.info,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.$2,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Open Day 31 TFLite models screen',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.tfliteModels),
            icon: const Icon(Icons.psychology_rounded, size: 18),
            label: const Text('Open Day 31 · Model registry'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Semantics(
          label: 'Open Day 56 model downloads screen',
          button: true,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.modelDownloads),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Open Day 56 · Download history'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends ConsumerWidget {
  const _SpecTab();

  String _buildReport(Map<String, TfliteSlotStatus> statuses) {
    final buf = StringBuffer()
      ..writeln('ZapSafe TFLite Integration — Day 218')
      ..writeln('M1–M8 slot checklist')
      ..writeln('');
    for (final slot in _kSlots) {
      final status = statuses[slot.id] ?? slot.initialStatus;
      buf.writeln(
        '${slot.id} ${slot.name}: ${status.label} · '
        '${slot.sizeMb} MB · ${slot.accuracyPct}% recall',
      );
      buf.writeln('  ${slot.assetPath}');
    }
    final loaded =
        statuses.values.where((s) => s == TfliteSlotStatus.loaded).length;
    buf.writeln('');
    buf.writeln('Loaded: $loaded/${_kSlots.length}');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(_d218StatusProvider);
    final report = _buildReport(statuses);

    const flow = [
      ('Placeholder', '1 KB stub in assets/models/ — Interpreter throws or uses EnergyStub'),
      ('Trained', 'Real weights on CDN / HuggingFace — verified sha256'),
      ('Loaded', 'Interpreter.fromAsset succeeds · slot active in DCS pipeline'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Status lifecycle',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...flow.map(
          (f) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    f.$1,
                    style: const TextStyle(
                      color: ZapColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    f.$2,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Semantics(
          label: 'Copy integration report',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy report'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 220 — Section A milestone polish sign-off.',
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
                        color: selected ? ZapColors.warning : Colors.transparent,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
