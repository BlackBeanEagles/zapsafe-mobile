import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_models.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/token_storage.dart';
import '../state/auth_state.dart';

// ─── Singletons ───────────────────────────────────────────────────────

/// Secure key/value storage for tokens + cached user.
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// The configured Dio instance. Reads the current access token via
/// [TokenStorage] on every request, and delegates 401 refreshes back to
/// the auth service.
///
/// Provider<ApiClient> annotated explicitly because [authServiceProvider]
/// below references it (and is referenced by it via `ref.read` in the
/// refresher closure), which trips Dart's type inference.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient.build(
    tokenProvider: () => storage.readAccessToken(),
    refresher: () async {
      // Pull the *latest* refresh token from storage each time — by the time
      // a 401 fires, the user may have logged out, in which case we abort
      // the refresh attempt cleanly.
      final refresh = await storage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;
      try {
        final svc = ref.read(authServiceProvider);
        final res = await svc.refresh(refresh);
        // Write once: either both tokens (rotation) or just access. Writing
        // access twice in sequence opens a window where storage briefly holds
        // (new access, old refresh) — fine in practice, but a single atomic
        // write is cleaner.
        final rotated = res.refresh != null && res.refresh!.isNotEmpty;
        if (rotated) {
          await storage.saveAccessAndRefresh(res.access, res.refresh!);
        } else {
          await storage.saveAccessToken(res.access);
        }
        return res.access;
      } catch (_) {
        // Refresh failed — drop the session so the UI bounces the user
        // back to /onboarding on the next route guard pass.
        await storage.clear();
        return null;
      }
    },
  );
});

/// Pure transport. Methods correspond 1:1 to backend endpoints.
final Provider<AuthService> authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

// ─── Auth state controller ───────────────────────────────────────────

/// The single source of truth for whether the user is logged in.
///
/// Used by:
/// - `app_router.dart` to redirect unauthenticated users to /onboarding.
/// - UI to show user name, "log out", etc.
final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    storage: ref.watch(tokenStorageProvider),
    service: ref.watch(authServiceProvider),
  )..hydrate();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final TokenStorage storage;
  final AuthService service;

  AuthNotifier({required this.storage, required this.service})
      : super(const AuthInitial());

  /// Cold-start hydration — read tokens from secure storage and either
  /// resolve to authenticated or unauthenticated. Never throws.
  ///
  /// If the stored access token is already expired but a refresh token exists,
  /// we silently refresh before setting [AuthAuthenticated] so the first API
  /// call the user makes never hits a 401.
  Future<void> hydrate() async {
    state = const AuthLoading();
    try {
      String? access = await storage.readAccessToken();
      String? refresh = await storage.readRefreshToken();
      final user = await storage.readUser();

      if (access == null || refresh == null || user == null) {
        state = const AuthUnauthenticated();
        return;
      }

      // Proactive refresh on cold start if the access token is expired.
      if (await storage.isAccessTokenExpired()) {
        try {
          final res = await service.refresh(refresh);
          access = res.access;
          await storage.saveAccessToken(access);
          if (res.refresh != null && res.refresh!.isNotEmpty) {
            refresh = res.refresh!;
            await storage.saveAccessAndRefresh(access, refresh);
          }
        } catch (_) {
          // Refresh failed — session is dead, force re-login.
          await storage.clear();
          state = const AuthUnauthenticated(message: 'Session expired. Please sign in again.');
          return;
        }
      }

      state = AuthAuthenticated(
        AuthTokens(access: access, refresh: refresh, user: user),
      );
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  /// Request an OTP. Returns the server response so the UI can seed its
  /// resend timer; sets [AuthFailure] state on error.
  Future<OtpRequestResponse?> requestOtp(String phone) async {
    final prev = state;
    try {
      return await service.requestOtp(phone);
    } on ApiError catch (e) {
      state = AuthFailure(message: e.message, code: e.code, previous: prev);
      return null;
    } catch (e) {
      state = AuthFailure(message: e.toString(), previous: prev);
      return null;
    }
  }

  /// Verify the OTP — on success, persists the JWT pair and the user, and
  /// flips state to [AuthAuthenticated].
  Future<bool> verifyOtp({required String phone, required String otp}) async {
    final prev = state;
    try {
      final tokens = await service.verifyOtp(phone: phone, otp: otp);
      await storage.saveTokens(tokens);
      state = AuthAuthenticated(tokens);
      return true;
    } on ApiError catch (e) {
      state = AuthFailure(message: e.message, code: e.code, previous: prev);
      return false;
    } catch (e) {
      state = AuthFailure(message: e.toString(), previous: prev);
      return false;
    }
  }

  /// Logout — call backend to blacklist, then wipe local storage regardless
  /// of whether the network call succeeded (user expects to be logged out).
  Future<void> logout() async {
    final current = state;
    try {
      if (current is AuthAuthenticated) {
        await service.logout(current.tokens.refresh);
      }
    } catch (_) {
      // Ignore — the local wipe below is what matters.
    } finally {
      await storage.clear();
      state = const AuthUnauthenticated(message: 'Logged out.');
    }
  }

  /// Clear a transient [AuthFailure] (e.g. after the user dismisses an error
  /// banner). Restores the previous state so the session isn't lost.
  void clearError() {
    final s = state;
    if (s is AuthFailure) state = s.previous;
  }
}

// ─── Convenience derived providers ────────────────────────────────────

/// `true` when the user has a session — used by router redirects.
final isLoggedInProvider = Provider<bool>((ref) {
  final s = ref.watch(authStateProvider);
  return s is AuthAuthenticated;
});

/// The currently-logged-in user, or `null`. Watched by UI that wants
/// the user's name/phone without caring about the full state machine.
final currentUserProvider = Provider<User?>((ref) {
  final s = ref.watch(authStateProvider);
  if (s is AuthAuthenticated) return s.user;
  return null;
});
