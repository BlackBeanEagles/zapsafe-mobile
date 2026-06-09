import '../../data/models/auth_models.dart';

/// What the rest of the app subscribes to. Sealed pattern so the UI is forced
/// to handle every case — no "what if I forget the loading state" bugs.
sealed class AuthState {
  const AuthState();
}

/// App just started; we haven't checked secure storage yet.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Hydrating from secure storage (cold start) — usually <100ms.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// No session. Show onboarding / phone entry.
class AuthUnauthenticated extends AuthState {
  /// Optional message — e.g. "Session expired, please log in again."
  final String? message;
  const AuthUnauthenticated({this.message});
}

/// Logged in with a valid JWT pair.
class AuthAuthenticated extends AuthState {
  final AuthTokens tokens;
  const AuthAuthenticated(this.tokens);

  User get user => tokens.user;
}

/// An auth-related operation failed mid-flight (e.g. OTP send failed).
/// The UI shows the message and offers retry; we stay in the previous
/// state for the underlying session.
class AuthFailure extends AuthState {
  final String message;
  final String? code;
  final AuthState previous;
  const AuthFailure({required this.message, this.code, required this.previous});
}
