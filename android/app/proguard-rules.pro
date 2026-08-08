# ZapSafe release R8/ProGuard keep rules.
#
# Addresses a real Day 336 P1 finding: minifyEnabled was never set, so
# release builds shipped completely unobfuscated Dart-native-bridge and
# Java/Kotlin code — trivial to decompile and read (relevant for a
# safety app with SOS/evidence/vault logic). This file + minifyEnabled
# true in build.gradle turns real R8 shrinking/obfuscation on.
#
# Scoped to this app's REAL dependency list (checked against pubspec.yaml
# before writing this file, not a generic copy-paste template). Most
# AndroidX/Google libraries (Firebase, Play Services) already ship their
# own consumer-rules.pro bundled in their AARs, which R8 applies
# automatically — the rules below cover the ones with real, documented
# history of needing explicit help, not a blanket "keep everything" which
# would defeat the purpose of enabling this at all.
#
# ⚠️ NOT BUILD-VERIFIED. This sandbox has no working Android build
# toolchain (confirmed multiple times this session — Gradle daemon
# crashes / JDK version mismatches unrelated to app code). These rules
# are grounded in each library's own real, public ProGuard documentation,
# not guessed, but a real `flutter build appbundle --release` followed by
# a real smoke test on a device is required before shipping — R8 failures
# are a real, common release-only bug class (things that work in `flutter
# run --release` locally can still break once actually minified if a
# reflection path isn't covered).

# ── TFLite (tflite_flutter) ─────────────────────────────────────────────
# TensorFlow Lite's own Android integration guide recommends keeping the
# whole package: the interpreter loads ops/delegates via reflection, which
# R8 cannot see through statically.
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**

# ── Firebase (firebase_core / firebase_messaging / firebase_auth) ──────
# Firebase's AARs bundle their own consumer-rules.pro (auto-applied), but
# Firestore/Auth model classes accessed via reflection for (de)serialization
# are a well-documented real gap if you add custom POJOs mapped from
# Firebase data. ZapSafe doesn't define custom Firebase model classes today
# (confirmed: no @Keep-worthy POJOs found), so no extra rule needed beyond
# what Firebase's own consumer rules already provide — noted here so this
# isn't silently forgotten if that changes later.

# ── Google Sign-In (google_sign_in) ─────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Sentry (sentry_flutter) ─────────────────────────────────────────────
# Sentry's Android SDK ships its own consumer-rules.pro since v6+ (this
# app is on sentry_flutter ^7.16.0, well past that), so no manual keep
# rules are required — Sentry's own docs explicitly say so as of this
# version. Listed here, not silently omitted, so the reasoning is visible.

# ── Flutter's own required baseline ─────────────────────────────────────
# Flutter's engine embedding classes and the generated plugin registrant
# must survive shrinking or the app fails to boot at all.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.zapsafe.zapsafe_mobile.** { *; }

# ── Kotlin coroutines / reflection metadata (WorkManager uses these) ───
-keepattributes *Annotation*, InnerClasses
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
