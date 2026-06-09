import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/domain/providers/onboarding_provider.dart';
import 'package:zapsafe_mobile/presentation/screens/day44_onboarding_step4_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

GoRouter _router(ProviderContainer c) => GoRouter(
      initialLocation: '/onboarding/step4',
      routes: [
        GoRoute(
          path: '/onboarding/step3',
          builder: (_, __) => const Scaffold(body: Text('step3')),
        ),
        GoRoute(
          path: '/onboarding/step4',
          builder: (_, __) => const Day44OnboardingStep4Screen(),
        ),
        GoRoute(
          path: '/onboarding/step5',
          builder: (_, __) => const Scaffold(body: Text('step5')),
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
  group('Day44OnboardingStep4Screen', () {
    testWidgets('renders Accessibility heading', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.text('Accessibility'), findsOneWidget);
    });

    testWidgets('language dropdown is present with default English',
        (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('language_dropdown')), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('simple mode toggle is present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('simple_mode_toggle')), findsOneWidget);
    });

    testWidgets('high contrast toggle is present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('high_contrast_toggle')), findsOneWidget);
    });

    testWidgets('font scale slider is present', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('font_scale_slider')), findsOneWidget);
    });

    testWidgets('Next button is always enabled (optional step)', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(find.byType(ZapButton), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('toggling simple mode updates notifier', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).accessibility.simpleMode, isFalse);

      final switchWidget = find.descendant(
        of: find.byKey(const Key('simple_mode_toggle')),
        matching: find.byType(Switch),
      );
      await tester.tap(switchWidget);
      await tester.pump();

      expect(c.read(onboardingProvider).accessibility.simpleMode, isTrue);
    });

    testWidgets('toggling high contrast updates notifier', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      expect(c.read(onboardingProvider).accessibility.highContrast, isFalse);

      final switchWidget = find.descendant(
        of: find.byKey(const Key('high_contrast_toggle')),
        matching: find.byType(Switch),
      );
      await tester.tap(switchWidget);
      await tester.pump();

      expect(c.read(onboardingProvider).accessibility.highContrast, isTrue);
    });

    testWidgets('Next navigates to step 5', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byType(ZapButton));
      await tester.pumpAndSettle();

      expect(find.text('step5'), findsOneWidget);
      expect(c.read(onboardingProvider).currentStep, equals(5));
    });

    testWidgets('back button navigates to step 3', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(c));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('step3'), findsOneWidget);
    });
  });

  group('OnboardingAccessibility model', () {
    test('default language is en', () {
      const a = OnboardingAccessibility();
      expect(a.language, equals('en'));
      expect(a.languageName, equals('English'));
    });

    test('default simpleMode and highContrast are false', () {
      const a = OnboardingAccessibility();
      expect(a.simpleMode, isFalse);
      expect(a.highContrast, isFalse);
    });

    test('default fontScale is 1.0', () {
      const a = OnboardingAccessibility();
      expect(a.fontScale, equals(1.0));
    });

    test('copyWith updates language', () {
      const a = OnboardingAccessibility();
      final b = a.copyWith(language: 'hi');
      expect(b.language, equals('hi'));
      expect(b.languageName, equals('Hindi'));
    });

    test('setFontScale clamps to 1.0–2.0', () {
      final n = OnboardingNotifier();
      n.setFontScale(0.5);
      expect(n.state.accessibility.fontScale, equals(1.0));
      n.setFontScale(3.0);
      expect(n.state.accessibility.fontScale, equals(2.0));
      n.setFontScale(1.5);
      expect(n.state.accessibility.fontScale, equals(1.5));
    });

    test('supportedLanguages contains LP20 APAC codes', () {
      final codes = OnboardingAccessibility.supportedLanguages
          .map((l) => l['code'])
          .toSet();
      for (final code in ['en', 'hi', 'ta', 'te', 'kn', 'bn', 'id']) {
        expect(codes, contains(code));
      }
    });
  });
}
