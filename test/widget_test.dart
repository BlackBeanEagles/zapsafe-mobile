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

    // Hero banner headline. Was 'Month 3 Underway' (Day 41 text) until the
    // Day 274-stash rescue merge brought in the Day 300 _Hero rewrite
    // ('300 Screens Shipped' / 'DAY 300 · SECTION E COMPLETE') that had
    // been sitting uncommitted this whole time — same stale-assertion
    // pattern as the kZapsafeModels count fix in month2_runner_test.dart.
    // _Hero itself could be freshened again to a Day 310 banner later;
    // this just re-syncs the test to the real, already-shipped content.
    expect(find.text('300 Screens Shipped'), findsOneWidget);

    // Key nav tiles are present.
    expect(find.text('Day 7 · Phone Entry'), findsOneWidget);
    expect(find.text('Day 8 · OTP Verify'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
