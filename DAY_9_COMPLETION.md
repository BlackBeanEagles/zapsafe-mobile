# ZapSafe Frontend - Day 9 Completion Summary

**Date:** 2026-05-19 | **Status:** ✅ COMPLETE
**Day 9 (Thursday) — Week 2 of Month 1**

---

## ✅ Deliverables

### 1. JWT Utility — `lib/core/utils/jwt_utils.dart` (NEW)

Pure Dart, zero external packages. Decodes the JWT payload (base64url → JSON)
and exposes helpers used by the interceptor and storage layer:

| Method | Returns | Purpose |
|---|---|---|
| `decodePayload(token)` | `Map?` | Full decoded payload |
| `expiry(token)` | `DateTime?` | When the token expires |
| `isExpired(token)` | `bool` | Already past expiry |
| `isExpiredOrExpiringSoon(token, buffer: 30s)` | `bool` | Expired or <30s left |
| `secondsRemaining(token)` | `int?` | Seconds until expiry |

Edge cases handled: malformed tokens, missing `exp` claim, fractional
seconds — all treated as expired (fail-safe default).

---

### 2. Proactive Refresh in `ApiClient` (UPGRADED)

**Before (reactive only):**
```
request → server → 401 → refresh → retry request
```
Two network round-trips minimum on every expired-token request.

**After (proactive + reactive):**
```
request → check exp locally → if <30s left → refresh first → attach fresh token → server → 200
```
Zero extra round-trips for normal expiry. Reactive 401 path kept as safety net
for clock skew or server-side token revocation.

Changes to `_AuthInterceptor.onRequest`:
- Reads current access token
- Calls `JwtUtils.isExpiredOrExpiringSoon(token)` (no network)
- If true and not already refreshing → calls `_proactiveRefresh()` → gets fresh token
- Attaches whichever token is freshest to `Authorization: Bearer`

---

### 3. Token Inspection Helpers — `TokenStorage` (UPGRADED)

New methods on `TokenStorage` so any screen or provider can query token health
without importing `JwtUtils` directly:

```dart
await storage.isAccessTokenExpired()           // bool
await storage.accessTokenSecondsRemaining()    // int? (negative = expired)
await storage.accessTokenExpiry()              // DateTime?
```

---

### 4. Cold-Start Hydration — `AuthNotifier.hydrate()` (UPGRADED)

On app launch, if the stored access token is already expired:
1. Try to refresh using the stored refresh token (30-day lifetime)
2. If refresh succeeds → store new tokens → set `AuthAuthenticated`
3. If refresh fails → wipe storage → set `AuthUnauthenticated("Session expired")`

Result: users who haven't opened the app in up to 30 days are silently
re-authenticated. Users whose refresh token has also expired (>30 days) are
cleanly bounced to the login screen with an explanatory message.

---

## Security Summary (Day 9 Complete Picture)

| Requirement | How it's met |
|---|---|
| Tokens never in SharedPreferences | `FlutterSecureStorage` only — Android EncryptedSharedPrefs (AES + AndroidKeystore), iOS Keychain |
| Tokens never in plain files | `FlutterSecureStorage` delegates to OS secure enclaves |
| Auto-refresh on expiry | Proactive check (<30s buffer) in every `onRequest` + reactive 401 fallback |
| Refresh token rotation | `saveAccessAndRefresh()` called if backend returns a new refresh token |
| Expired session on cold start | `hydrate()` refreshes silently, or clears and redirects to login |
| Log sanitisation | `_LoggingInterceptor._sanitize()` masks `otp`, `pin`, `access`, `refresh` |
| Public paths skip auth header | `_isPublicPath()` excludes `/auth/register/`, `/auth/verify-otp/`, `/token/refresh/` |

---

## Build Status

```
flutter analyze   → No issues found! ✅
```

---

## Days 1–9 Complete

| Day | Deliverable | Status |
|-----|-------------|--------|
| 1 | Design system (colors, fonts, spacing, themes) | ✅ |
| 2–5 | Widget library, navigation, routing | ✅ |
| 6 | Auth models, services, Riverpod providers | ✅ |
| 7 | Phone entry screen (OTP request flow) | ✅ |
| 8 | OTP verify screen (6-digit, auto-focus, resend timer) | ✅ |
| **9** | **JWT secure storage + proactive auto-refresh** | **✅** |

---

## What's Next — Day 10 (Friday): Integration Test + Week 2 Review

- [ ] Widget tests: OTP box auto-focus, backspace, paste, auto-submit
- [ ] Integration test: phone entry → OTP → JWT → cold-start hydration → dashboard
- [ ] Error path tests: wrong OTP, expired OTP, rate-limited resend
- [ ] Proactive refresh test: forge an expired-looking JWT, verify interceptor refreshes
- [ ] Week 2 milestone review:
  - ✅ Auth flow (OTP → JWT, secure token storage)
  - ✅ Proactive + reactive token refresh
  - ✅ Cold-start hydration with silent re-auth
