import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/domain/providers/live_detection_providers.dart';

/// Day 328 — the remaining dual-input fusion pipelines must stay off.
///
/// Each was measured against its shipped asset on real local data and none
/// can produce a usable detection on a phone:
///
/// `s_crowd_panic` was in this set too and has since been **deleted**
/// outright (Day 336) — the shipped scream detector scores 0.8230 on the
/// AudioSet classes it targets against its own 0.6062, so it was a strictly
/// worse duplicate of a detector the app already runs. (Both figures come
/// from the 45-positive AudioSet fixture Day 345 retired; on the 287-positive
/// FSD50K set the shipped model is 0.8284. The comparison still holds — it
/// was a large gap, not a marginal one — but neither number is the honest
/// one, and the scream slot is `scream_classifier_v5` as of Day 346.)
/// * `k_confinement_decorrelated` uses the same contaminated slice and
///   outputs ~0.019 on realistic input, never firing at any light value.
/// * `i_vehicle_crash` has an int8 output collapsed to a single quantization
///   step, and was trained in `g` while the pipeline feeds m/s².
///
/// See `assets/models/DAY328_DUAL_INPUT_DEAD_ON_PHONE.md`.
///
/// These tests read the providers rather than only asserting the flag,
/// because the guard has to sit *before* the `ref.watch` calls to be worth
/// anything — a pipeline that still resolved its detector and audio stream
/// would keep paying the start-up cost this change exists to remove. That
/// ordering is what makes the providers resolvable in a plain unit test with
/// no platform channels at all, so the test failing to construct a container
/// would itself be the signal.
void main() {
  group('Day 328 — dual-input pipelines are disabled', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('the flag is on', () {
      expect(kDualInputModelsDisabled, isTrue,
          reason: 'flipping this back on requires a retrained asset — see '
              'DAY328_DUAL_INPUT_DEAD_ON_PHONE.md for what "retrained" has '
              'to mean here (the training data is what is broken, not the '
              'weights)');
    });

    test('vehicle crash pipeline resolves to null', () {
      expect(container.read(vehicleCrashFusionPipelineProvider), isNull);
    });

    test('k_confinement pipeline resolves to null', () {
      expect(container.read(kConfinementFusionPipelineProvider), isNull);
    });

    test('the guard precedes any ref.watch, so nothing is constructed', () {
      // Reading both in one container must not touch the audio channel
      // or the detector futures. If the guard were placed after the watches,
      // this would throw a MissingPluginException rather than return null,
      // so a passing test here pins the *ordering* and not just the result.
      expect(
        [
          container.read(vehicleCrashFusionPipelineProvider),
          container.read(kConfinementFusionPipelineProvider),
        ],
        everyElement(isNull),
      );
    });
  });
}
