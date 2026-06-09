import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/data/services/device_tier_service.dart';
import 'package:zapsafe_mobile/domain/providers/feature_flags_provider.dart';

void main() {
  group('FeatureFlags.forTier', () {
    test('Tier A enables every feature', () {
      final flags = FeatureFlags.forTier(DeviceTier.tierA);
      for (final f in Feature.values) {
        expect(flags.canUse(f), isTrue, reason: '$f should be enabled on Tier A');
      }
      expect(flags.locked, isEmpty);
    });

    test('Tier B keeps baseline + Tier-B features, locks Tier-A-only', () {
      final flags = FeatureFlags.forTier(DeviceTier.tierB);

      // Always-on baseline.
      expect(flags.canUse(Feature.manualSos), isTrue);
      expect(flags.canUse(Feature.audioEvidence), isTrue);
      expect(flags.canUse(Feature.pushNotifications), isTrue);

      // Tier-B additions.
      expect(flags.canUse(Feature.backgroundLocation), isTrue);
      expect(flags.canUse(Feature.liveLocationShare), isTrue);
      expect(flags.canUse(Feature.liveChat), isTrue);
      expect(flags.canUse(Feature.sdVideoEvidence), isTrue);
      expect(flags.canUse(Feature.impactDetection), isTrue);

      // Tier-A-only locked.
      expect(flags.canUse(Feature.aiInference), isFalse);
      expect(flags.canUse(Feature.hdVideoEvidence), isFalse);
      expect(flags.canUse(Feature.blinkCodeTrigger), isFalse);
      expect(flags.canUse(Feature.passiveAudioMonitor), isFalse);
    });

    test('Tier C keeps only the baseline three', () {
      final flags = FeatureFlags.forTier(DeviceTier.tierC);
      expect(flags.enabled.toSet(), {
        Feature.manualSos,
        Feature.audioEvidence,
        Feature.pushNotifications,
      });
      // Everything else is locked.
      expect(flags.locked.length, equals(Feature.values.length - 3));
    });
  });

  group('FeatureFlags.isLocked + lockedReason', () {
    test('isLocked is the inverse of canUse', () {
      final flags = FeatureFlags.forTier(DeviceTier.tierC);
      for (final f in Feature.values) {
        expect(flags.isLocked(f), equals(!flags.canUse(f)));
      }
    });

    test('every locked feature has a non-empty lockedReason', () {
      final flags = FeatureFlags.forTier(DeviceTier.tierC);
      for (final f in flags.locked) {
        expect(f.lockedReason, isNotEmpty,
            reason: '$f should have a lockedReason');
      }
    });
  });

  group('Feature labels', () {
    test('every feature has a non-empty label', () {
      for (final f in Feature.values) {
        expect(f.label, isNotEmpty);
      }
    });
  });
}
