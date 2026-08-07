/// Runtime feature flags — compile-time via `--dart-define`.
///
/// `USE_MOCK_DATA=true` keeps v2 product screens on seeded mock providers
/// when the backend is unavailable (emulator QA without Django running).
///
/// `PRODUCTION_SHELL=true` switches the default home route from the Day 5
/// dev navigation index to the production dashboard and enables auth guards.
library;

/// When true, v2 providers fall back to in-memory mock data on API failure
/// or when explicitly forced via dart-define.
const bool kUseMockData = bool.fromEnvironment(
  'USE_MOCK_DATA',
  defaultValue: false,
);

/// When true, unauthenticated users are redirected to phone entry for
/// protected routes and `/dashboard` becomes the post-onboarding home.
const bool kProductionShell = bool.fromEnvironment(
  'PRODUCTION_SHELL',
  defaultValue: true,
);
