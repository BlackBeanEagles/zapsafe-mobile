import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/monitoring/crash_reporting.dart';
import 'core/theme/app_theme.dart';
import 'domain/providers/app_bootstrap_providers.dart';
import 'domain/providers/i18n_providers.dart';
import 'domain/providers/push_providers.dart';
import 'presentation/navigation/app_router.dart';

// Day 257 — Sentry wraps the whole boot so errors thrown during
// initialisation are captured too, not just ones after the first frame.
// CrashReporting.init always runs the app exactly once, with or without a
// DSN, so a missing SENTRY_DSN can never stop the app starting.
Future<void> main() async => CrashReporting.init(_bootstrap);

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Days 101-102 — Easy Localization must initialise before runApp.
  await EasyLocalization.ensureInitialized();

  // Best-effort Firebase init. If google-services.json / GoogleService-Info.plist
  // are missing, this throws — we catch it so the rest of the app still boots
  // in "stub mode". PushService re-checks Firebase.apps internally before any
  // FCM call, so this graceful fallback is safe end-to-end.
  try {
    await Firebase.initializeApp();
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('[boot] Firebase.initializeApp failed → push runs in stub mode: $e');
    }
    // Day 257 — previously swallowed silently. Push failing is a real
    // degradation (no SOS push to contacts), so it should be visible in
    // crash reporting rather than only in a debug console nobody reads in
    // production. Still non-fatal: the app continues in stub mode.
    if (CrashReporting.isEnabled) {
      await Sentry.captureException(e, stackTrace: stack);
    }
  }

  runApp(
    EasyLocalization(
      // Days 101-102 — 15 supported locales (ur + ar are RTL)
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ta'),
        Locale('te'),
        Locale('ml'),
        Locale('bn'),
        Locale('mr'),
        Locale('gu'),
        Locale('pa'),
        Locale('ur'),
        Locale('ar'),
        Locale('es'),
        Locale('fr'),
        Locale('pt'),
        Locale('de'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(
        child: ZapSafeApp(),
      ),
    ),
  );
}

/// Root widget. Uses [MaterialApp.router] + go_router for navigation
/// (set up in [routerProvider]).
class ZapSafeApp extends ConsumerWidget {
  const ZapSafeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Day 17 — eagerly subscribe to the push navigation listener so taps and
    // cold-start payloads drive the GoRouter even before any screen watches it.
    ref.watch(pushNavigationListenerProvider);

    // Production wiring — SOS orchestrator, GPS bridge, backend + navigation.
    ref.watch(appBootstrapProvider);

    // Day 305 — bridge EasyLocalization's real active locale into the
    // Riverpod-backed provider api_client.dart reads on every request.
    // Deferred to post-frame: writing to a provider synchronously during
    // another provider's build is disallowed by Riverpod.
    final localeCode = context.locale.languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(currentLanguageCodeProvider.notifier);
      if (notifier.state != localeCode) notifier.state = localeCode;
    });

    return MaterialApp.router(
      title: 'ZapSafe',
      theme: ZapTheme.darkTheme(),
      darkTheme: ZapTheme.darkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Days 101-102 — wire EasyLocalization delegates into MaterialApp
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
