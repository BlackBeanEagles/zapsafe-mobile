import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zapsafe_mobile/core/theme/app_theme.dart';
import 'package:zapsafe_mobile/data/models/auth_models.dart';
import 'package:zapsafe_mobile/data/services/api_client.dart';
import 'package:zapsafe_mobile/data/services/auth_service.dart';
import 'package:zapsafe_mobile/data/services/token_storage.dart';
import 'package:zapsafe_mobile/domain/providers/auth_providers.dart';
import 'package:zapsafe_mobile/domain/state/auth_state.dart';
import 'package:zapsafe_mobile/presentation/screens/auth/phone_entry_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

// ─── Fake notifier ────────────────────────────────────────────────────────────
// Extends AuthNotifier so overrideWith accepts it.
// The real storage/service are constructed but never called — all methods
// that would hit the network are overridden below.

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier()
      : super(
          storage: TokenStorage(),
          service: AuthService(ApiClient.build()),
        );

  OtpRequestResponse? _nextResponse;
  String? _nextError;

  void willSucceed({int expiresIn = 120}) {
    _nextResponse = OtpRequestResponse(
      phone: '+919876543210',
      expiresIn: expiresIn,
      message: 'OTP sent.',
    );
    _nextError = null;
  }

  void willFail(String message) {
    _nextResponse = null;
    _nextError = message;
  }

  @override
  Future<void> hydrate() async {
    state = const AuthUnauthenticated();
  }

  @override
  Future<OtpRequestResponse?> requestOtp(String phone) async {
    if (_nextError != null) {
      state = AuthFailure(
        message: _nextError!,
        code: 'RATE_LIMITED',
        previous: state,
      );
      return null;
    }
    return _nextResponse;
  }
}

// ─── Wrapper ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, _FakeAuthNotifier fake) {
  final router = GoRouter(
    initialLocation: '/phone-entry',
    routes: [
      GoRoute(path: '/phone-entry', builder: (_, __) => child),
      GoRoute(
        path: '/otp-verify',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return Scaffold(body: Text('OTP:${args['phone'] ?? 'none'}'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [authStateProvider.overrideWith((_) => fake)],
    child: MaterialApp.router(
      theme: ZapTheme.darkTheme(),
      routerConfig: router,
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAuthNotifier fake;

  setUp(() => fake = _FakeAuthNotifier());

  testWidgets('renders headline and SEND OTP button', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    expect(find.textContaining("What's your phone number"), findsOneWidget);
    expect(find.text('SEND OTP'), findsOneWidget);
  });

  testWidgets('SEND OTP disabled when field is empty', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    final btn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'SEND OTP'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('SEND OTP enables after valid 10-digit India number', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pump();

    final btn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'SEND OTP'),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('shows validation error for short number after typing', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '98765');
    await tester.pump();

    expect(
      find.byWidgetPredicate((w) {
        if (w is Text) {
          final t = (w.data ?? '').toLowerCase();
          return t.contains('digit') || t.contains('short');
        }
        return false;
      }),
      findsWidgets,
    );
  });

  testWidgets('shows E.164 preview once a number is typed', (tester) async {
    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pump();

    expect(find.textContaining('+91'), findsWidgets);
  });

  testWidgets('navigates to /otp-verify on successful OTP request', (tester) async {
    fake.willSucceed(expiresIn: 120);

    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pump();
    await tester.tap(find.text('SEND OTP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OTP:'), findsOneWidget);
  });

  testWidgets('shows danger snackbar on rate-limit error', (tester) async {
    fake.willFail('Too many attempts. Wait 60 seconds.');

    await tester.pumpWidget(_wrap(const PhoneEntryScreen(), fake));
    await tester.pump();

    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pump();
    await tester.tap(find.text('SEND OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Wait'), findsOneWidget);
  });
}
