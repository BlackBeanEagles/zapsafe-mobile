import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/domain/providers/detection_settings_provider.dart';

void main() {
  // ── DetectionSettings defaults ─────────────────────────────────────────────
  group('DetectionSettings defaults', () {
    test('all flags true by default', () {
      const s = DetectionSettings();
      expect(s.aiEnabled,        isTrue);
      expect(s.screamEnabled,    isTrue);
      expect(s.motionEnabled,    isTrue);
      expect(s.sceneEnabled,     isTrue);
      expect(s.heuristicFallback, isTrue);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────
  group('DetectionSettings.copyWith', () {
    test('flips aiEnabled only', () {
      const s = DetectionSettings();
      final s2 = s.copyWith(aiEnabled: false);
      expect(s2.aiEnabled,     isFalse);
      expect(s2.screamEnabled, isTrue);
      expect(s2.motionEnabled, isTrue);
      expect(s2.sceneEnabled,  isTrue);
    });

    test('flips screamEnabled only', () {
      const s = DetectionSettings();
      final s2 = s.copyWith(screamEnabled: false);
      expect(s2.aiEnabled,     isTrue);
      expect(s2.screamEnabled, isFalse);
      expect(s2.motionEnabled, isTrue);
    });

    test('flips motionEnabled only', () {
      const s = DetectionSettings();
      final s2 = s.copyWith(motionEnabled: false);
      expect(s2.motionEnabled, isFalse);
      expect(s2.screamEnabled, isTrue);
    });

    test('flips sceneEnabled only', () {
      const s = DetectionSettings();
      final s2 = s.copyWith(sceneEnabled: false);
      expect(s2.sceneEnabled,  isFalse);
      expect(s2.screamEnabled, isTrue);
    });

    test('all false at once', () {
      const s = DetectionSettings(
        aiEnabled:     false,
        screamEnabled: false,
        motionEnabled: false,
        sceneEnabled:  false,
      );
      expect(s.aiEnabled,     isFalse);
      expect(s.screamEnabled, isFalse);
      expect(s.motionEnabled, isFalse);
      expect(s.sceneEnabled,  isFalse);
    });
  });

  // ── equality ───────────────────────────────────────────────────────────────
  group('DetectionSettings equality', () {
    test('identical defaults are equal', () {
      expect(const DetectionSettings(), equals(const DetectionSettings()));
    });

    test('different aiEnabled are not equal', () {
      expect(
        const DetectionSettings(aiEnabled: false),
        isNot(equals(const DetectionSettings(aiEnabled: true))),
      );
    });

    test('hashCode matches for equal objects', () {
      expect(
        const DetectionSettings().hashCode,
        equals(const DetectionSettings().hashCode),
      );
    });
  });

  // ── heuristicFallback is always true (cannot be disabled) ──────────────────
  group('heuristicFallback invariant', () {
    test('defaults to true', () {
      expect(const DetectionSettings().heuristicFallback, isTrue);
    });

    test('copyWith preserves heuristicFallback when not explicitly set', () {
      const s = DetectionSettings();
      final s2 = s.copyWith(aiEnabled: false);
      expect(s2.heuristicFallback, isTrue);
    });
  });
}
