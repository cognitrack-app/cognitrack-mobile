# ════════════════════════════════════════════════════════════════════════════
#  CogniTrack Mobile — ProGuard / R8 rules
#
#  Philosophy:
#   • Keep rules only where R8 cannot infer safety automatically.
#   • Flutter's Gradle plugin injects its own keep rules — no need to duplicate.
#   • All -dontwarn entries are intentional; they silence warnings from
#     dependencies that reference APIs not present on older API levels but
#     that are never exercised at runtime on those devices.
# ════════════════════════════════════════════════════════════════════════════


# ── Stack Trace Readability ───────────────────────────────────────────────────
# Preserves line numbers so Crashlytics / Sentry can symbolicate crashes.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Required for Kotlin reflection and Firebase serialisation.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations


# ── Firebase ──────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Crashlytics — must not rename the crash reporter internals.
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Firestore model classes use reflection to read/write fields — keep them.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}


# ── Google Sign-In ────────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.auth.**


# ── SQLite / sqflite ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sqflite.** { *; }
-dontwarn io.flutter.plugins.sqflite.**


# ── Kotlin Coroutines ─────────────────────────────────────────────────────────
# Coroutines use reflection to resume continuations — volatile fields must be kept.
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-keep class kotlinx.coroutines.android.** { *; }
-dontwarn kotlinx.coroutines.**


# ── Kotlin Serialization ──────────────────────────────────────────────────────
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}
-dontwarn kotlinx.serialization.**


# ── Connectivity Plus ──────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**


# ── Permission Handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**


# ── Flutter Local Notifications ───────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**


# ── Device Info Plus ──────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn dev.fluttercommunity.plus.device_info.**


# ── Package Info Plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }


# ── URL Launcher ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**


# ── Shared Preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }


# ── Path Provider ────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }


# ── fl_chart ─────────────────────────────────────────────────────────────────
# Pure-Dart package — no native Android code; no keep rule needed.
# R8 handles the Dart layer automatically through Flutter's AOT compiler.


# ── go_router ─────────────────────────────────────────────────────────────────
# Pure-Dart package — no native Android code.


# ── google_fonts ──────────────────────────────────────────────────────────────
# Pure-Dart package — no native Android code.


# ── R8 Full Mode — Aggressive Optimisations ───────────────────────────────────
# These rules are only required with android.enableR8.fullMode=true
# (set in gradle.properties). They prevent R8 from removing classes/members
# that are accessed via reflection or class-loading patterns we cannot
# statically annotate.

# Keep any class that has a no-arg constructor and is referenced as a
# Parcelable — used by Flutter/Android interop bundles.
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Enum members are accessed by name from Kotlin/Dart bridge code.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Suppress harmless warnings from transitive dependencies.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn sun.misc.Unsafe
