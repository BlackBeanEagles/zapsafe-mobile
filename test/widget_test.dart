// ZapSafe smoke test — verifies the home screen mounts without crashing.
// Deeper tests live in test/unit/ and test/widget/.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/presentation/screens/day5_navigation_index_screen.dart';

void main() {
  testWidgets('Home index screen renders without errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ZapTheme.darkTheme(),
          home: const Day5NavigationIndexScreen(),
        ),
      ),
    );
    await tester.pump();

    // Hero banner headline (updated in Day 41).
    expect(find.text('Month 3 Underway'), findsOneWidget);

    // Key nav tiles are present.
    expect(find.text('Day 7 · Phone Entry'), findsOneWidget);
    expect(find.text('Day 8 · OTP Verify'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
