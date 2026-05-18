# GymPass Android ProGuard / R8 rules.
#
# `isMinifyEnabled = true` in build.gradle.kts means R8 strips
# unused classes + obfuscates names. Anything reachable only via
# reflection / generated code is invisible to R8's static
# analysis and must be explicitly preserved. The libs below all
# generate or reflectively access code at runtime; without these
# rules, a release build either fails to compile (R8 finds
# obvious missing refs) or compiles silently and then crashes
# on first use of the affected feature.
#
# Reference: every entry below corresponds to a package GymPass
# actually depends on in pubspec.yaml. Add new entries the same
# day a new dependency lands — chasing R8 missing-class crashes
# from production logs is much slower than this 1-line discipline.


# ── Flutter core / engine ─────────────────────────────────────
# The Flutter team's official `proguard-android-optimize.txt`
# default file handles most of this. Belt-and-braces for the
# embedding API in case we ever ship a platform channel from
# the Java side.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }


# ── Dio + httpClientAdapter ───────────────────────────────────
# Dio uses runtime reflection inspection only for the IO adapter
# selection (HttpClientAdapter); the main client surface is
# pure Dart and doesn't need rules. Keep the optional native
# adapters in case we ever flip to OkHttp.
-keep class io.flutter.plugins.connectivity.** { *; }


# ── json_serializable + freezed (when used) ───────────────────
# These generate concrete fromJson/toJson methods at build-time;
# the generated classes are normal Dart and don't need rules.
# This block is here as a no-op placeholder so the next person to
# enable freezed adds Java-side rules underneath it if needed.


# ── google_sign_in / Google APIs ──────────────────────────────
# Google's auth lib uses reflection to wire its callbacks. The
# official rule set ships with the lib; mirror the load-bearing
# subset here so a transitive upgrade doesn't accidentally
# regress us.
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**


# ── flutter_secure_storage ────────────────────────────────────
# Uses AndroidKeyStore via reflection on older API levels.
-keep class com.it_nomads.fluttersecurestorage.** { *; }


# ── mobile_scanner / MLKit barcode ────────────────────────────
# MLKit's barcode dynamite module is loaded at runtime.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**


# ── url_launcher / share_plus / image_picker / app_links ─────
# Platform-channel-only libs; default rules cover them.


# ── local_auth ────────────────────────────────────────────────
# FragmentActivity reflective callback bridge.
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }


# ── geolocator ────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }


# ── connectivity_plus ─────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }


# ── sentry_flutter (when DSN compiled in) ─────────────────────
# Sentry's transport thread + native crash bridge use reflection
# for serialisation. Without these rules a `flutter build apk
# --release --dart-define=SENTRY_DSN=...` ships an APK that
# silently drops every error event.
-keep class io.sentry.** { *; }
-keep interface io.sentry.** { *; }
-dontwarn io.sentry.**


# ── General ──────────────────────────────────────────────────
# Strip log calls below ERROR in release. Drops a measurable
# amount of bytecode and prevents accidental PII leak via
# leftover Log.d / Log.v calls in plugin code we don't control.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}

# Suppress R8 warnings for missing optional deps the Flutter
# engine references (java.beans, sun.reflect.*) — these are
# desktop-JVM classes that don't exist on Android and the
# engine guards them at runtime.
-dontwarn java.beans.**
-dontwarn sun.reflect.**
-dontwarn sun.misc.**

# Flutter Play Core split-install / deferred-components SDK.
# The Flutter engine ALWAYS references these classes (in
# `FlutterPlayStoreSplitApplication` + `PlayStoreDeferredComponentManager`)
# even when the app ships as a single APK with no deferred
# components — which is our case. Without these `-dontwarn`s,
# R8 release builds fail with "Missing class
# com.google.android.play.core.splitcompat.SplitCompatApplication".
#
# The deferred-components path is dead code at runtime when no
# splits are declared; R8 just needs permission to leave the
# unresolved refs alone.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
