import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/data/services/permission_service.dart';
import 'package:zapsafe_mobile/domain/providers/permission_providers.dart';
import 'package:zapsafe_mobile/presentation/screens/onboarding/permissions_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

// ─── Fake PermissionService ──────────────────────────────────────────────────
//
// Subclasses [PermissionService] so the [permissionServiceProvider] override
// type-checks. Every method that would hit the platform channel is overridden
// to return canned values the test controls.

class _FakePermissionService extends PermissionService {
  PermissionsResult outcomes = const PermissionsResult(
    microphone: PermissionOutcome.denied,
    locationAlways: PermissionOutcome.denied,
    camera: PermissionOutcome.denied,
    notifications: PermissionOutcome.denied,
    activityRecognition: PermissionOutcome.denied,
  );

  PermissionOutcome nextRequestOutcome = PermissionOutcome.granted;
  int requestCount = 0;
  Object? lastRequestedId;

  @override
  Future<PermissionsResult> checkAll() async => outcomes;

  @override
  Future<PermissionOutcome> requestOne(Object id) async {
    requestCount++;
    lastRequestedId = id;
    return nextRequestOutcome;
  }

  @override
  Future<void> openSettings() async {
    // No-op in tests.
  }
}

// ─── Test rig ────────────────────────────────────────────────────────────────

Widget _wrap(_FakePermissionService fake) {
  final router = GoRouter(
    initialLocation: '/onboarding/permissions',
    routes: [
      GoRoute(
        path: '/onboarding/permissions',
        builder: (_, __) => const OnboardingPermissionsScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      permissionServiceProvider.overrideWithValue(fake),
    ],
    child: MaterialApp.router(
      theme: ZapTheme.darkTheme(),
      routerConfig: router,
    ),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late _FakePermissionService fake;

  setUp(() => fake = _FakePermissionService());

  testWidgets('renders all 5 permission rows and the hero', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    expect(find.text('Set up your safety net'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
    expect(find.text('Location (Always)'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Physical Activity'), findsOneWidget);
  });

  testWidgets('progress reads "0 of 5 granted" before any requests', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    expect(find.text('0 of 5 granted'), findsOneWidget);
  });

  testWidgets('CONTINUE is disabled until all 5 are granted', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    final continueBtn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'CONTINUE (0 / 5)'),
    );
    expect(continueBtn.onPressed, isNull);
  });

  testWidgets('tapping "Why we need this" expands the explanation', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    // Before tapping, the long-form description for microphone isn't shown.
    expect(find.textContaining('Audio is the most reliable evidence stream'),
        findsNothing);

    // Tap the first "Why we need this" link.
    await tester.tap(find.text('Why we need this').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Audio is the most reliable evidence stream'),
        findsOneWidget);
  });

  testWidgets('hero badge shows "WEEK 3 · DAY 12"', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    expect(find.text('WEEK 3 · DAY 12'), findsOneWidget);
  });

  testWidgets('grant flow: tapping ALLOW invokes requestOne with the right id',
      (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    // First ALLOW button == microphone (first row).
    final allowFinder = find.widgetWithText(ZapButton, 'ALLOW');
    expect(allowFinder, findsWidgets);

    await tester.tap(allowFinder.first);
    await tester.pumpAndSettle();

    expect(fake.requestCount, 1);
    expect(fake.lastRequestedId.toString(), endsWith('microphone'));
  });

  testWidgets('OPEN SETTINGS button replaces ALLOW when status is deniedForever',
      (tester) async {
    fake.outcomes = const PermissionsResult(
      microphone: PermissionOutcome.deniedForever,
      locationAlways: PermissionOutcome.denied,
      camera: PermissionOutcome.denied,
      notifications: PermissionOutcome.denied,
      activityRecognition: PermissionOutcome.denied,
    );

    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ZapButton, 'OPEN SETTINGS'), findsOneWidget);
  });

  testWidgets('all-granted state shows "You\'re all set" hero', (tester) async {
    fake.outcomes = const PermissionsResult(
      microphone: PermissionOutcome.granted,
      locationAlways: PermissionOutcome.granted,
      camera: PermissionOutcome.granted,
      notifications: PermissionOutcome.granted,
      activityRecognition: PermissionOutcome.granted,
    );

    await tester.pumpWidget(_wrap(fake));
    await tester.pumpAndSettle();

    expect(find.text("You're all set"), findsOneWidget);
    expect(find.text('5 of 5 granted'), findsOneWidget);

    // CONTINUE is now enabled.
    final btn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'CONTINUE'),
    );
    expect(btn.onPressed, isNotNull);
  });
}
