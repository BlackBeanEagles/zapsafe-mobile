/// Day 322 — DCS Pipeline Production Wire: fusion-score detection logging.
///
/// Real gap found by reading `live_detection_providers.dart` (Day 259-273):
/// every individual model pipeline (scream, motion, gunshot, motion_b,
/// crowd_panic, vehicle_crash, k_confinement) POSTs its confident results to
/// the real `POST /api/v1/ml/detection-events/` endpoint (Day 55) via
/// [liveDetectionEventSubmitterProvider] — but the M9 **DCS fusion** score
/// itself never did, even though `DetectionEventType.dcs` has existed in
/// `detection_event_service.dart`'s enum since Day 55. This file closes
/// that gap using the exact same real, already-existing endpoint — no new
/// backend route, no invented contract.
///
/// Wired the same way `triggerEventStreamProvider` consumes
/// [dcsStreamProvider] (`ref.listen` + `AsyncValue.whenData`, see
/// `inference_providers.dart` / `trigger_orchestrator_providers.dart` for
/// the same idiom already in production): watch the real audio+motion →
/// [DCSInferenceEngine] → [DCSScore] stream that already powers the
/// auto-SOS path, and submit every confident fusion score. A submission
/// failure (offline, 401, etc.) is logged and swallowed, matching the
/// sibling pipelines' policy — detection must keep running even when the
/// network doesn't cooperate.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dcs_score.dart';
import '../../data/services/detection_event_service.dart';
import '../../data/services/phone_capability_detector.dart';
import 'detection_event_providers.dart';
import 'inference_providers.dart';

/// Reading this provider (from [appBootstrapProvider]) is what turns the
/// DCS fusion-score logging on; it produces no widget output of its own —
/// same shape as `liveDetectionEventSubmitterProvider`.
final dcsDetectionLogSubmitterProvider = Provider<void>((ref) {
  final service = ref.watch(detectionEventServiceProvider);

  // Cached tier read is synchronous best-effort — falls back to `low` the
  // same way `liveDetectionEventSubmitterProvider` does, so a cold cache
  // never blocks fusion-score logging from starting.
  var tier = PhoneCapabilityTier.low;
  PhoneCapabilityDetector.cachedTier().then((t) {
    if (t != null) tier = t;
  });

  ref.listen<AsyncValue<DCSScore>>(dcsStreamProvider, (_, next) {
    next.whenData((score) => _submitFusion(service, score, () => tier));
  });
});

Future<void> _submitFusion(
  DetectionEventService service,
  DCSScore score,
  PhoneCapabilityTier Function() tier,
) async {
  if (!score.triggerCandidate) return; // only log confident fusion windows
  try {
    await service.submit(
      eventType: DetectionEventType.dcs,
      confidence: score.fusion.score,
      tier: tier().name,
      detectionMode: 'ai',
      inferenceMs: score.fusion.latencyMs.toDouble(),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[dcsDetectionLogSubmitter] submit failed: $e');
    }
  }
}
