import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/domain/providers/onboarding_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day43_onboarding_step3_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

GoRouter _router(ProviderContainer c) => GoRouter(
      initialLocation: '/onboarding/step3',
      routes: [
        GoRoute(
          path: '/onboarding/step2',
          builder: (_, __) => const Scaffold(body: Text('step2')),
        ),
        GoRoute(
          path: '/onboarding/step3',
          builder: (_, __) => const Day43OnboardingStep3Screen(),
        ),
        GoRoute(
          path: '/onboarding/step4',
          builder: (_, __) => const Scaffold(body: Text('step4')),
        ),
      ],
    );

Widget _wrap(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        theme: ZapTheme.darkTheme(),
        routerConfig: _router(c),
      ),
    );

void main() {
  group('Day43OnboardingStep3Screen', () {
    testWidgets('renders heading', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Trusted Locations'), findsOneWidget);
    });

    testWidgets('shows preset quick-add chips', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      for (final label in OnboardingLocation.presets) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('button label is Skip with no locations', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('button label becomes Next after adding a location',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.text('Home'));
      await tester.pump();

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('tapping preset chip adds location to notifier', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.text('Work'));
      await tester.pump();

      expect(c.read(onboardingProvider).locations.length, equals(1));
      expect(c.read(onboardingProvider).locations.first.label, equals('Work'));
    });

    testWidgets('preset chip deduplication — tapping twice stays at 1',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addPresetLocation('Home');
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Home chip shows check-mark — tap again should do nothing
      c.read(onboardingProvider.notifier).addPresetLocation('Home');
      expect(c.read(onboardingProvider).locations.length, equals(1));
    });

    testWidgets('remove button deletes a location', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addPresetLocation('Gym');
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).locations.length, equals(1));
      await tester.tap(find.byIcon(Icons.remove_circle_rounded));
      await tester.pump();

      expect(c.read(onboardingProvider).locations.length, equals(0));
    });

    testWidgets('max 5 locations cap enforced', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(onboardingProvider.notifier);
      notifier.addPresetLocation('Home');
      notifier.addPresetLocation('Work');
      notifier.addPresetLocation('Gym');
      notifier.addPresetLocation('School');
      notifier.addCustomLocation();
      notifier.addCustomLocation(); // over cap — should be ignored

      expect(c.read(onboardingProvider).locations.length,
          equals(OnboardingState.maxLocations));
    });

    testWidgets('custom location text field updates name', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addCustomLocation();
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('custom_name_0')), 'Parents house');
      await tester.pump();

      expect(
        c.read(onboardingProvider).locations.first.customName,
        equals('Parents house'),
      );
    });

    testWidgets('Skip navigates to step 4', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(find.text('step4'), findsOneWidget);
      expect(c.read(onboardingProvider).currentStep, equals(4));
    });

    testWidgets('Next navigates to step 4 after adding a location',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addPresetLocation('Home');
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(find.text('step4'), findsOneWidget);
    });

    testWidgets('back button navigates to step 2', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('step2'), findsOneWidget);
    });
  });

  group('OnboardingLocation model', () {
    test('preset displayName equals label', () {
      const loc = OnboardingLocation(label: 'Gym');
      expect(loc.displayName, equals('Gym'));
    });

    test('custom displayName uses customName when set', () {
      const loc = OnboardingLocation(label: 'Custom', customName: 'Grandma');
      expect(loc.displayName, equals('Grandma'));
    });

    test('custom displayName fallback when customName empty', () {
      const loc = OnboardingLocation(label: 'Custom');
      expect(loc.displayName, equals('Custom'));
    });

    test('preset isValid always true', () {
      const loc = OnboardingLocation(label: 'Home');
      expect(loc.isValid, isTrue);
    });

    test('custom isValid false when customName empty', () {
      const loc = OnboardingLocation(label: 'Custom');
      expect(loc.isValid, isFalse);
    });

    test('custom isValid true when customName filled', () {
      const loc = OnboardingLocation(label: 'Custom', customName: 'Beach');
      expect(loc.isValid, isTrue);
    });

    test('hasLocation deduplication on state', () {
      final n = OnboardingNotifier();
      n.addPresetLocation('Home');
      n.addPresetLocation('Home');
      expect(n.state.locations.length, equals(1));
    });
  });
}
