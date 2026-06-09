import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zapsafe_mobile/domain/providers/detection_settings_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day46_detection_settings_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap({DetectionSettings? initial}) {
  final notifier = DetectionSettingsNotifier();
  return ProviderScope(
    overrides: [
      if (initial != null)
        detectionSettingsProvider.overrideWith((_) {
          final n = DetectionSettingsNotifier();
          // Apply initial state via reflection-free approach:
          // We can't directly set state from outside, so we use defaults
          // and test toggling from there.
          return n;
        }),
    ],
    child: const MaterialApp(
      home: Day46DetectionSettingsScreen(),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Day46DetectionSettingsScreen', () {
    testWidgets('renders Detection Settings title', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Detection Settings'), findsOneWidget);
    });

    testWidgets('shows DAY 46 badge', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('DAY 46'), findsOneWidget);
    });

    testWidgets('shows AI-Powered Detection master toggle', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('AI-Powered Detection'), findsOneWidget);
    });

    testWidgets('shows all 3 model toggles', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Scream Detection'), findsOneWidget);
      expect(find.text('Motion Detection'), findsOneWidget);
      expect(find.text('Scene Detection'),  findsOneWidget);
    });

    testWidgets('shows phone capability section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('PHONE CAPABILITY'), findsOneWidget);
    });

    testWidgets('shows heuristic fallback section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('HEURISTIC FALLBACK'), findsOneWidget);
      expect(find.text('Always Active'), findsOneWidget);
    });

    testWidgets('shows Reset to Defaults button', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.text('Reset to Defaults'), findsOneWidget);
    });

    testWidgets('phone capability shows Test Now when not probed', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      // Without a cached tier the button says Test Now
      expect(find.text('Test Now'), findsOneWidget);
    });

    testWidgets('has 4 Switch widgets (master + 3 models)', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(4));
    });
  });

  group('DetectionSettings model', () {
    test('default state: all enabled', () {
      const s = DetectionSettings();
      expect(s.aiEnabled,     isTrue);
      expect(s.screamEnabled, isTrue);
      expect(s.motionEnabled, isTrue);
      expect(s.sceneEnabled,  isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      const s = DetectionSettings();
      final updated = s.copyWith(screamEnabled: false);
      expect(updated.screamEnabled, isFalse);
      expect(updated.aiEnabled,     isTrue);  // unchanged
      expect(updated.motionEnabled, isTrue);  // unchanged
    });

    test('equality works', () {
      const a = DetectionSettings();
      const b = DetectionSettings();
      expect(a, equals(b));
    });

    test('inequality on changed field', () {
      const a = DetectionSettings();
      final b = a.copyWith(motionEnabled: false);
      expect(a, isNot(equals(b)));
    });
  });
}
