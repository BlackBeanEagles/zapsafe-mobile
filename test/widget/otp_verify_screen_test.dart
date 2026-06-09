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
import 'package:zapsafe_mobile/presentation/screens/auth/otp_verify_screen.dart';
import 'package:zapsafe_mobile/presentation/widgets/zap_button.dart';

// ─── Fake notifier ────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier()
      : super(
          storage: TokenStorage(),
          service: AuthService(ApiClient.build()),
        );

  bool _willSucceed = true;
  String _errorCode = 'OTP_INVALID';
  String _errorMsg = 'Incorrect code. Please try again.';

  void willSucceed() => _willSucceed = true;

  void willFail({
    String code = 'OTP_INVALID',
    String message = 'Incorrect code. Please try again.',
  }) {
    _willSucceed = false;
    _errorCode = code;
    _errorMsg = message;
  }

  void willFailExpired() => willFail(
        code: 'OTP_EXPIRED',
        message: 'Code expired. Tap Resend to get a new one.',
      );

  @override
  Future<void> hydrate() async {
    state = const AuthUnauthenticated();
  }

  @override
  Future<bool> verifyOtp({required String phone, required String otp}) async {
    if (_willSucceed) {
      state = AuthAuthenticated(AuthTokens(
        access: 'fake.access.token',
        refresh: 'fake.refresh.token',
        user: const User(id: 'u1', phone: '+919876543210', isOnboarded: false),
      ));
      return true;
    }
    state = AuthFailure(message: _errorMsg, code: _errorCode, previous: state);
    return false;
  }

  @override
  Future<OtpRequestResponse?> requestOtp(String phone) async =>
      OtpRequestResponse(phone: phone, expiresIn: 120, message: 'Sent.');

  @override
  void clearError() {
    if (state is AuthFailure) state = (state as AuthFailure).previous;
  }
}

// ─── Wrapper ──────────────────────────────────────────────────────────────────

Widget _wrap(_FakeAuthNotifier fake, {int expiresIn = 120}) {
  final router = GoRouter(
    initialLocation: '/otp-verify',
    routes: [
      GoRoute(
        path: '/otp-verify',
        builder: (_, __) => OtpVerifyScreen(
          phone: '+919876543210',
          expiresIn: expiresIn,
        ),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(body: Text('DASHBOARD')),
      ),
      GoRoute(
        path: '/phone-entry',
        builder: (_, __) => const Scaffold(body: Text('PHONE_ENTRY')),
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

Future<void> _fillAllBoxes(WidgetTester tester, String digit) async {
  final boxes = find.byType(TextFormField);
  expect(boxes, findsNWidgets(6));
  for (var i = 0; i < 6; i++) {
    await tester.enterText(boxes.at(i), digit);
    await tester.pump();
  }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeAuthNotifier fake;
  setUp(() => fake = _FakeAuthNotifier());

  testWidgets('renders 6 digit boxes and screen header', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.textContaining('Check your messages'), findsOneWidget);
    expect(find.textContaining('+919876543210'), findsOneWidget);
  });

  testWidgets('VERIFY button disabled when boxes are empty', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    final btn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'VERIFY'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('VERIFY button enables when all 6 boxes are filled', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    await _fillAllBoxes(tester, '1');

    final btn = tester.widget<ZapButton>(
      find.widgetWithText(ZapButton, 'VERIFY'),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('navigates to /dashboard on correct OTP', (tester) async {
    fake.willSucceed();
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    await _fillAllBoxes(tester, '1');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);
  });

  testWidgets('shows inline error and clears boxes on wrong OTP', (tester) async {
    fake.willFail(code: 'OTP_INVALID', message: 'Incorrect code. Please try again.');
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    await _fillAllBoxes(tester, '9');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Incorrect'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      final field = tester.widget<TextFormField>(find.byType(TextFormField).at(i));
      expect(field.controller?.text ?? '', isEmpty);
    }
  });

  testWidgets('shows expired-specific message on OTP_EXPIRED', (tester) async {
    fake.willFailExpired();
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();

    await _fillAllBoxes(tester, '1');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.textContaining('expired'), findsOneWidget);
  });

  testWidgets('shows Paste code button', (tester) async {
    await tester.pumpWidget(_wrap(fake));
    await tester.pump();
    expect(find.textContaining('Paste'), findsOneWidget);
  });

  testWidgets('shows resend timer countdown when expiresIn > 0', (tester) async {
    await tester.pumpWidget(_wrap(fake, expiresIn: 60));
    await tester.pump();

    expect(find.textContaining("Didn't get"), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && RegExp(r'^\d+s$').hasMatch(w.data ?? '')),
      findsOneWidget,
    );
  });

  testWidgets('Resend OTP link appears when timer reaches zero', (tester) async {
    await tester.pumpWidget(_wrap(fake, expiresIn: 0));
    await tester.pump();
    expect(find.text('Resend OTP'), findsOneWidget);
  });

  testWidgets('tapping Resend OTP resets timer and hides Resend link', (tester) async {
    await tester.pumpWidget(_wrap(fake, expiresIn: 0));
    await tester.pump();

    await tester.tap(find.text('Resend OTP'));
    await tester.pumpAndSettle();

    // After resend, timer is running again — Resend OTP link should be gone.
    expect(find.text('Resend OTP'), findsNothing);
  });
}
