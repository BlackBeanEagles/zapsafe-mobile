import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/domain/providers/onboarding_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day42_onboarding_step2_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

GoRouter _router(ProviderContainer c) => GoRouter(
      initialLocation: '/onboarding/step2',
      routes: [
        GoRoute(
          path: '/onboarding/step1',
          builder: (_, __) => const Scaffold(body: Text('step1')),
        ),
        GoRoute(
          path: '/onboarding/step2',
          builder: (_, __) => const Day42OnboardingStep2Screen(),
        ),
        GoRoute(
          path: '/onboarding/step3',
          builder: (_, __) => const Scaffold(body: Text('step3')),
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
  group('Day42OnboardingStep2Screen', () {
    testWidgets('renders heading', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Emergency Contacts'), findsOneWidget);
    });

    testWidgets('shows all three tier section labels', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Tier 1 — Primary Contact'), findsOneWidget);
      expect(find.text('Tier 2 — Trusted Contacts'), findsOneWidget);
      expect(find.text('Tier 3 — Backup Contacts'), findsOneWidget);
    });

    testWidgets('Next button disabled with no contacts', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      final btn = tester.widget<ZapButton>(find.byType(ZapButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('addContact adds a contact row for tier 1', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Tap the "Add contact" button inside Tier 1 section
      final addBtns = find.text('Add contact');
      await tester.tap(addBtns.first);
      await tester.pump();

      expect(c.read(onboardingProvider).tier(1).length, equals(1));
    });

    testWidgets('hasRequiredContact false when name empty', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(1);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Phone filled but name still empty
      final phoneField = find.byKey(const Key('phone_0'));
      await tester.enterText(phoneField, '9876543210');
      await tester.pump();

      expect(c.read(onboardingProvider).hasRequiredContact, isFalse);
    });

    testWidgets('Next enabled after valid tier-1 contact', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(1);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name_0')), 'Alice');
      await tester.enterText(find.byKey(const Key('phone_0')), '9876543210');
      await tester.pump();

      final btn = tester.widget<ZapButton>(find.byType(ZapButton));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('remove contact button removes the row', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(1);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).contacts.length, equals(1));

      await tester.tap(find.byIcon(Icons.remove_circle_rounded));
      await tester.pump();

      expect(c.read(onboardingProvider).contacts.length, equals(0));
    });

    testWidgets('tier 1 capped at 1 contact', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      // Add 1 tier-1 contact
      final addBtns = find.text('Add contact');
      await tester.tap(addBtns.first);
      await tester.pump();

      // After reaching cap, "Add contact" for tier 1 should be gone
      expect(c.read(onboardingProvider).tier(1).length, equals(1));
      // Notifier enforces cap: adding again should not grow
      c.read(onboardingProvider.notifier).addContact(1);
      expect(c.read(onboardingProvider).tier(1).length, equals(1));
    });

    testWidgets('tier 2 can hold up to 2 contacts', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(2);
      c.read(onboardingProvider.notifier).addContact(2);
      c.read(onboardingProvider.notifier).addContact(2); // over cap

      expect(c.read(onboardingProvider).tier(2).length, equals(2));
    });

    testWidgets('Next advances step to 3 and navigates', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(onboardingProvider.notifier).addContact(1);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('name_0')), 'Alice');
      await tester.enterText(find.byKey(const Key('phone_0')), '9876543210');
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(c.read(onboardingProvider).currentStep, equals(3));
      expect(find.text('step3'), findsOneWidget);
    });

    testWidgets('back button navigates to step 1', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('step1'), findsOneWidget);
    });
  });

  group('OnboardingContact model', () {
    test('isValid false when name empty', () {
      const c = OnboardingContact(tier: 1, name: '', phone: '1234567');
      expect(c.isValid, isFalse);
    });

    test('isValid false when phone too short', () {
      const c = OnboardingContact(tier: 1, name: 'Alice', phone: '123');
      expect(c.isValid, isFalse);
    });

    test('isValid true with name and phone >= 7 digits', () {
      const c = OnboardingContact(tier: 1, name: 'Alice', phone: '9876543210');
      expect(c.isValid, isTrue);
    });

    test('copyWith preserves tier', () {
      const c = OnboardingContact(tier: 2, name: 'Bob', phone: '');
      final updated = c.copyWith(phone: '1234567');
      expect(updated.tier, equals(2));
      expect(updated.phone, equals('1234567'));
    });
  });
}
