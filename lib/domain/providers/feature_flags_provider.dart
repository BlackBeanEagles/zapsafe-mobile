import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/device_tier_service.dart';
import 'device_providers.dart';

/// Discrete capability flags the app gates on at runtime.
///
/// Each feature is independently checkable — UI code asks
/// `featureFlags.canUse(Feature.aiInference)` rather than checking the tier
/// directly. This means tier-thresholds can change in one place
/// ([FeatureFlags._forTier]) without sprinkling tier checks across screens.
enum Feature {
  /// On-device AI inference (TFLite models).
  aiInference,

  /// 1080p video evidence (vs 720p / off).
  hdVideoEvidence,

  /// 720p video evidence (Tier B fallback).
  sdVideoEvidence,

  /// Passive blink-code SOS trigger via front camera.
  blinkCodeTrigger,

  /// IMU-based fall / impact detection.
  impactDetection,

  /// Continuous passive audio monitoring for voice trigger.
  passiveAudioMonitor,

  /// Background GPS tracking during active SOS.
  backgroundLocation,

  /// Real-time location sharing with Tier 1 contacts.
  liveLocationShare,

  /// Two-way live chat with responding contact during SOS.
  liveChat,

  /// Push notifications via FCM / APNs.
  pushNotifications,

  /// Audio evidence recording.
  audioEvidence,

  /// Manual SOS button (always-on baseline).
  manualSos,
}

extension FeatureLabel on Feature {
  String get label => switch (this) {
        Feature.aiInference         => 'On-device AI inference',
        Feature.hdVideoEvidence     => 'HD video evidence (1080p)',
        Feature.sdVideoEvidence     => 'SD video evidence (720p)',
        Feature.blinkCodeTrigger    => 'Blink-code trigger',
        Feature.impactDetection     => 'Impact detection (IMU)',
        Feature.passiveAudioMonitor => 'Passive audio monitor',
        Feature.backgroundLocation  => 'Background location',
        Feature.liveLocationShare   => 'Real-time location share',
        Feature.liveChat            => 'Live chat with contact',
        Feature.pushNotifications   => 'Push notifications',
        Feature.audioEvidence       => 'Audio evidence',
        Feature.manualSos           => 'Manual SOS button',
      };

  /// Plain-language reason shown when this feature is locked.
  String get lockedReason => switch (this) {
        Feature.aiInference         => 'Requires Tier A device (Android 12+ / iOS 16+)',
        Feature.hdVideoEvidence     => 'HD recording needs Tier A hardware',
        Feature.sdVideoEvidence     => 'Video evidence needs Tier B or higher',
        Feature.blinkCodeTrigger    => 'Camera-based trigger needs Tier A',
        Feature.impactDetection     => 'IMU sensors not supported below Tier B',
        Feature.passiveAudioMonitor => 'Continuous audio needs Tier A',
        Feature.backgroundLocation  => 'Background services unavailable on this tier',
        Feature.liveLocationShare   => 'Live sharing requires Tier B or higher',
        Feature.liveChat            => 'Live chat requires Tier B or higher',
        Feature.pushNotifications   => 'Always available',
        Feature.audioEvidence       => 'Always available',
        Feature.manualSos           => 'Always available',
      };
}

/// Snapshot of which features are usable for the current device tier.
///
/// Decision matrix:
///
/// | Feature                | Tier A | Tier B | Tier C |
/// |------------------------|:------:|:------:|:------:|
/// | manualSos              |   ✅   |   ✅   |   ✅   |
/// | audioEvidence          |   ✅   |   ✅   |   ✅   |
/// | pushNotifications      |   ✅   |   ✅   |   ✅   |
/// | backgroundLocation     |   ✅   |   ✅   |   ❌   |
/// | liveLocationShare      |   ✅   |   ✅   |   ❌   |
/// | liveChat               |   ✅   |   ✅   |   ❌   |
/// | sdVideoEvidence        |   ✅   |   ✅   |   ❌   |
/// | impactDetection        |   ✅   |   ✅   |   ❌   |
/// | aiInference            |   ✅   |   ❌   |   ❌   |
/// | hdVideoEvidence        |   ✅   |   ❌   |   ❌   |
/// | blinkCodeTrigger       |   ✅   |   ❌   |   ❌   |
/// | passiveAudioMonitor    |   ✅   |   ❌   |   ❌   |
class FeatureFlags {
  final DeviceTier tier;
  final Set<Feature> _enabled;

  const FeatureFlags._(this.tier, this._enabled);

  /// Builds flags from the device tier classification.
  factory FeatureFlags.forTier(DeviceTier tier) {
    return FeatureFlags._(tier, _forTier(tier));
  }

  static Set<Feature> _forTier(DeviceTier tier) {
    const baseline = {
      Feature.manualSos,
      Feature.audioEvidence,
      Feature.pushNotifications,
    };
    const tierBPlus = {
      ...baseline,
      Feature.backgroundLocation,
      Feature.liveLocationShare,
      Feature.liveChat,
      Feature.sdVideoEvidence,
      Feature.impactDetection,
    };
    const tierAOnly = {
      ...tierBPlus,
      Feature.aiInference,
      Feature.hdVideoEvidence,
      Feature.blinkCodeTrigger,
      Feature.passiveAudioMonitor,
    };
    return switch (tier) {
      DeviceTier.tierA => tierAOnly,
      DeviceTier.tierB => tierBPlus,
      DeviceTier.tierC => baseline,
    };
  }

  /// Returns true if the feature is usable on the current tier.
  bool canUse(Feature f) => _enabled.contains(f);

  /// Inverse of [canUse]. Useful for tooltip rendering.
  bool isLocked(Feature f) => !canUse(f);

  /// All features enabled on this tier.
  List<Feature> get enabled => _enabled.toList(growable: false);

  /// All features locked on this tier.
  List<Feature> get locked =>
      Feature.values.where((f) => !_enabled.contains(f)).toList(growable: false);
}

/// Riverpod provider — depends on [deviceTierProvider]. Reads as
/// `AsyncValue<FeatureFlags>`.
final featureFlagsProvider = Provider<AsyncValue<FeatureFlags>>((ref) {
  final tier = ref.watch(deviceTierProvider);
  return tier.whenData((result) => FeatureFlags.forTier(result.tier));
});
