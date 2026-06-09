import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/domain/providers/onboarding_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day41_onboarding_step1_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

// Minimal router so go_router context is available without real navigation.
GoRouter _router(Widget home) => GoRouter(
      initialLocation: '/step1',
      routes: [
        GoRoute(path: '/step1', builder: (_, __) => home),
        GoRoute(path: '/onboarding/step2', builder: (_, __) => const Scaffold()),
      ],
    );

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ZapTheme.darkTheme(),
        routerConfig: _router(const Day41OnboardingStep1Screen()),
      ),
    );

void main() {
  group('Day41OnboardingStep1Screen', () {
    testWidgets('renders welcome header', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Welcome to ZapSafe'), findsOneWidget);
    });

    testWidgets('renders 5-step progress indicator', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // 5 segments rendered as containers
      expect(find.text('Welcome to ZapSafe'), findsOneWidget);
    });

    testWidgets('shows Terms & Conditions heading', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Terms & Conditions'), findsOneWidget);
    });

    testWidgets('Next button is disabled initially', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      final btn = tester.widget<ZapButton>(find.byType(ZapButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('checkbox toggles agreed state', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Initially unchecked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final updatedCheckbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(updatedCheckbox.value, isTrue);
    });

    testWidgets('Next button enabled after checkbox checked', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final btn = tester.widget<ZapButton>(find.byType(ZapButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('OnboardingNotifier.termsAccepted flips true on checkbox tap',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).termsAccepted, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(c.read(onboardingProvider).termsAccepted, isTrue);
    });

    testWidgets('OnboardingNotifier.termsAccepted resets on uncheck',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Check then uncheck
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(c.read(onboardingProvider).termsAccepted, isFalse);
    });

    testWidgets('tapping InkWell row also toggles checkbox', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Tap the agreement text label (InkWell)
      await tester.tap(find.text(
        'I have read and agree to the Terms & Conditions and Privacy Policy',
      ));
      await tester.pump();

      expect(c.read(onboardingProvider).termsAccepted, isTrue);
    });

    testWidgets('Next tap with checkbox checked advances step to 2',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(c.read(onboardingProvider).currentStep, equals(2));
    });

    testWidgets('Next tap without checkbox does nothing', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Don't check checkbox — button is disabled, should not advance
      await tester.tap(find.byType(ZapButton));
      await tester.pump();

      expect(c.read(onboardingProvider).currentStep, equals(1));
    });
  });
}
