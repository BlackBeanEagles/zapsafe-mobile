/// Day 392 — Model & Dataset Attributions
///
/// ## Why this screen is an obligation, not a nicety
///
/// Day 359 and 359B retrained the glass and gunshot detectors on the
/// **CC0 / CC BY 4.0 subset of FSD50K only**, dropping UrbanSound8K
/// (CC BY-NC) and AudioSet. That cleared the non-commercial flag on both —
/// but CC BY is not CC0. It permits commercial use *on condition that the
/// work is attributed*, and an attribution the user cannot reach does not
/// discharge the condition.
///
/// So shipping those two models without this screen would have replaced a
/// licence problem we knew about with one we did not. That is the whole
/// reason it exists. `verify_shipped_models.py` records the same obligation
/// in its own comment:
///
///     "CC BY obliges the app to credit FSD50K contributors somewhere a
///      user can reach; that is a real product task and cheaper than NC,
///      which forbids commercial use outright."
///
/// ## This is not a legal opinion
///
/// The terms below are what was recorded when each corpus was obtained,
/// reproduced so a reader can check them — not advice, and not a warranty
/// that the combination is clear. `DAY350_TRAINING_DATA_LICENCES.md` is the
/// long form.
///
/// ## The table is pinned, not copied
///
/// [kModelAttributions] mirrors `TRAINING_DATA` in
/// `tools/verify_shipped_models.py`, which is the single source of truth for
/// provenance. Hand-copying it would guarantee drift — a model gets
/// retrained, the gate is updated, and this screen keeps crediting a corpus
/// that is no longer used, or omits one that now is.
/// `test/day392_model_attributions_test.dart` parses the Python table and
/// asserts the two agree, so the drift fails CI instead of shipping.
///
/// ## Non-commercial models are shown, and marked
///
/// Two models still train on NC data (`m5_vocal_stress_v3`,
/// `scream_classifier_v5`). They are listed with the flag visible rather
/// than omitted, because the honest state of the project is "2 remaining,
/// down from 5", not "all clear".
///
/// 🟢 FRONTEND-ONLY — static content, no network, no backend.
/// Reachable at Settings → Privacy & Legal → Model & Dataset Attributions.
library;

import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';

// ── Data ───────────────────────────────────────────────────────────────────

/// One shipped model and the corpora it was trained on.
///
/// [corpora] entries are `(name, licence)` exactly as the gate records them.
class ModelAttribution {
  const ModelAttribution({
    required this.asset,
    required this.purpose,
    required this.corpora,
    this.note,
  });

  /// Filename under `assets/models/`, matching the gate's key.
  final String asset;

  /// Plain-language description of what the model does in the app.
  final String purpose;

  /// `(corpus, licence terms as recorded)`.
  final List<(String, String)> corpora;

  /// Shown under the row when there is something a reader should know.
  final String? note;

  /// True when any corpus carries a non-commercial term.
  ///
  /// Matches `nc` as a **token**, mirroring the gate's own fix: its first
  /// version tested `startswith("nc ") || contains("-nc-")`, which missed
  /// "CC BY-NC 3.0" entirely and silently unflagged two models.
  bool get isNonCommercial => corpora.any((c) {
        final low = c.$2.toLowerCase();
        return RegExp(r'(?<![a-z])nc(?![a-z])').hasMatch(low);
      });

  /// True when every corpus is CC0, CC BY, ODbL, MIT or Apache — i.e. usable
  /// commercially, though CC BY/ODbL still require the credit on this screen.
  bool get isPermissive => !isNonCommercial &&
      corpora.every((c) {
        final low = c.$2.toLowerCase();
        return low.contains('cc0') ||
            low.contains('cc by') ||
            low.contains('apache') ||
            low.contains('mit') ||
            low.contains('open database');
      });
}

/// Mirrors `TRAINING_DATA` in `tools/verify_shipped_models.py`.
/// Pinned by `test/day392_model_attributions_test.dart` — do not edit one
/// without the other.
const List<ModelAttribution> kModelAttributions = [
  ModelAttribution(
    asset: 'm_glass_breaking_v4.tflite',
    purpose: 'Detects breaking glass as a Danger Confidence Score signal.',
    corpora: [('FSD50K (CC0 + CC BY subset only)', 'CC0 / CC BY 4.0')],
    note: 'CC BY: this credit is the licence condition. Retrained on the '
        'permissive subset on Day 359, replacing a model that used '
        'UrbanSound8K (CC BY-NC).',
  ),
  ModelAttribution(
    asset: 'mg_gunshot_v2.tflite',
    purpose: 'Detects gunshots as a Danger Confidence Score signal.',
    corpora: [('FSD50K (CC0 + CC BY subset only)', 'CC0 / CC BY 4.0')],
    note: 'CC BY: this credit is the licence condition. Retrained on the '
        'permissive subset on Day 359.',
  ),
  ModelAttribution(
    asset: 'trac_aggression_v1.tflite',
    purpose: 'Message Safety Check — reads a message you received and '
        'estimates whether it is hostile. User-initiated only.',
    corpora: [('TRAC-1 (COLING 2018)', 'Apache-2.0')],
  ),
  ModelAttribution(
    asset: 'h_aggressive_v6_38.tflite',
    purpose: 'Scores vocal aggression in nearby speech.',
    corpora: [
      ('CREMA-D', 'Open Database License'),
      ('SAVEE', 'research'),
      ('MELD', 'research; audio from copyrighted broadcast'),
    ],
    note: 'TESS and RAVDESS (both CC BY-NC) were dropped on Day 360 at no '
        'measured accuracy cost.',
  ),
  ModelAttribution(
    asset: 'm4_vocal_stress_v3_38.tflite',
    purpose: 'Scores vocal stress in nearby speech.',
    corpora: [('MELD', 'research; audio from copyrighted broadcast')],
  ),
  ModelAttribution(
    asset: 'm5_vocal_stress_v3_38.tflite',
    purpose: 'Scores vocal stress in Mandarin speech.',
    corpora: [
      ('EmotionTalk', 'NC - CC BY-NC-SA 4.0 (source repo README badge)'),
    ],
  ),
  ModelAttribution(
    asset: 'scream_classifier_v5.tflite',
    purpose: 'Detects screaming as a Danger Confidence Score signal.',
    corpora: [
      ('VocalAffectBench', 'MIT'),
      ('FSD50K', 'per-clip CC (CC0/BY/BY-NC mix)'),
      ('AudioSet', 'labels CC-BY; audio YouTube-sourced'),
      ('ASVP-ESD', 'research'),
      ('ESC-50', 'CC BY-NC 3.0'),
    ],
  ),
  ModelAttribution(
    asset: 'motion_fall_v2.tflite',
    purpose: 'Detects a fall from phone motion.',
    corpora: [('UniMiB-SHAR', 'research')],
  ),
  ModelAttribution(
    asset: 'm3_violence_temporal_v1.tflite',
    purpose: 'Scores violent motion in camera frames.',
    corpora: [('RWF-2000', 'research')],
  ),
  ModelAttribution(
    asset: 'i_vehicle_crash.tflite',
    purpose: 'Vehicle-crash signal from phone motion.',
    corpora: [('UCI-HAR', 'research')],
  ),
  ModelAttribution(
    asset: 'k_confinement_decorrelated.tflite',
    purpose: 'Confinement / enclosure signal from phone motion.',
    corpora: [('PAMAP2', 'research')],
  ),
  ModelAttribution(
    asset: 'mobilenetv3small_encoder_float16.tflite',
    purpose: 'Shared image encoder used by the camera-based signals.',
    corpora: [('ImageNet', 'research')],
  ),
];

/// The credit FSD50K's CC BY 4.0 clips actually require.
const String kFsd50kCredit =
    'Glass-breaking and gunshot detection in ZapSafe are trained on clips '
    'from FSD50K, contributed by the Freesound community and released under '
    'Creative Commons CC0 and CC BY 4.0 licences. FSD50K was assembled by the '
    'Music Technology Group, Universitat Pompeu Fabra, Barcelona. '
    'Individual clips remain the work of their original uploaders. '
    'No endorsement of ZapSafe by those contributors is implied.';

// ── Screen ─────────────────────────────────────────────────────────────────

class Day392ModelAttributionsScreen extends StatelessWidget {
  const Day392ModelAttributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permissive =
        kModelAttributions.where((m) => m.isPermissive).toList();
    final nc = kModelAttributions.where((m) => m.isNonCommercial).toList();
    final research = kModelAttributions
        .where((m) => !m.isPermissive && !m.isNonCommercial)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Model & Dataset Attributions')),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.md),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(ZapSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Required credit',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: ZapSpacing.sm),
                  Text(kFsd50kCredit, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.sm),
            child: Text(
              'ZapSafe runs its safety detection on your device. The models '
              'below were trained on public research datasets. Terms are '
              'reproduced as recorded when each dataset was obtained; this '
              'is not legal advice.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          _Section(
            title: 'Commercially licensed',
            subtitle:
                'CC0, CC BY, Apache-2.0, MIT or ODbL. Where the licence '
                'requires credit, this screen is that credit.',
            models: permissive,
          ),
          _Section(
            title: 'Research-use datasets',
            subtitle: 'Released for research. Terms vary by dataset.',
            models: research,
          ),
          _Section(
            title: 'Non-commercial datasets',
            subtitle:
                'These carry a non-commercial term and are tracked as open '
                'work. Two remain, down from five.',
            models: nc,
          ),
          const SizedBox(height: ZapSpacing.lg),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.models,
  });

  final String title;
  final String subtitle;
  final List<ModelAttribution> models;

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ZapSpacing.sm, ZapSpacing.md, ZapSpacing.sm, ZapSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title (${models.length})',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        ...models.map((m) => _ModelCard(model: m)),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model});

  final ModelAttribution model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: ZapSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(model.purpose, style: theme.textTheme.bodyMedium),
            const SizedBox(height: ZapSpacing.xs),
            Text(model.asset,
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: ZapSpacing.sm),
            ...model.corpora.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: c.$1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        TextSpan(
                            text: '  —  ${c.$2}',
                            style: theme.textTheme.bodySmall),
                      ])),
                    ),
                  ],
                ),
              ),
            ),
            if (model.note != null) ...[
              const SizedBox(height: ZapSpacing.sm),
              Text(model.note!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
