import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/domain/providers/onboarding_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day45_onboarding_step5_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

GoRouter _router(ProviderContainer c) => GoRouter(
      initialLocation: '/onboarding/step5',
      routes: [
        GoRoute(
          path: '/onboarding/step2',
          builder: (_, __) => const Scaffold(body: Text('step2')),
        ),
        GoRoute(
          path: '/onboarding/step3',
          builder: (_, __) => const Scaffold(body: Text('step3')),
        ),
        GoRoute(
          path: '/onboarding/step4',
          builder: (_, __) => const Scaffold(body: Text('step4')),
        ),
        GoRoute(
          path: '/onboarding/step5',
          builder: (_, __) => const Day45OnboardingStep5Screen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('dashboard')),
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
  group('Day45OnboardingStep5Screen', () {
    testWidgets('renders Review heading', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('contacts card present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('contacts_review_card')), findsOneWidget);
    });

    testWidgets('locations card present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('locations_review_card')), findsOneWidget);
    });

    testWidgets('accessibility card present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('accessibility_review_card')), findsOneWidget);
    });

    testWidgets('shows No contacts added when empty', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('No contacts added'), findsOneWidget);
    });

    testWidgets('shows No locations added when empty', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('No locations added'), findsOneWidget);
    });

    testWidgets('shows contact name when contact added', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(1);
      c.read(onboardingProvider.notifier).updateContact(
            0,
            const OnboardingContact(tier: 1, name: 'Alice', phone: '1234567'),
          );
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows location chip when location added', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addPresetLocation('Home');
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows language name in accessibility card', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Complete Setup button is present and enabled', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byType(ZapButton), findsOneWidget);
      expect(find.text('Complete Setup'), findsOneWidget);
    });

    testWidgets('tapping Complete Setup calls completeOnboarding', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).completed, isFalse);

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(c.read(onboardingProvider).completed, isTrue);
    });

    testWidgets('tapping Complete Setup navigates to dashboard', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(find.text('dashboard'), findsOneWidget);
    });

    testWidgets('back button navigates to step 4', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('step4'), findsOneWidget);
    });
  });
}
