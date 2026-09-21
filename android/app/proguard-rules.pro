# CogniTrack ProGuard / R8 Rules
# ─────────────────────────────────────────────────────────────────────────────
# This file is referenced in build.gradle.kts via:
#   proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
#
# R8 full-mode is enabled via gradle.properties:
#   android.enableR8.fullMode=true
#
# Key goals:
#  1. Keep MethodChannel / EventChannel classes and their MethodCall/EventSink
#     interfaces so Flutter ↔ Kotlin communication works after obfuscation.
#  2. Keep native plugin entry points (FlutterPlugin, BroadcastReceiver, Service).
#  3. Keep data classes used for JSON serialization (UsageEventBuffer, etc.).
#  4. Strip debug logging in release builds.
#  5. Preserve annotations for Firebase / Firestore.

# ─── Keep all public Flutter plugin entry points ───────────────────────────────
-keep public class com.cognitrack.cognitrack_mobile.** {
    public protected *;
}

# Specifically keep the plugin classes that Flutter instantiates by name
-keep class com.cognitrack.cognitrack_mobile.UsageStatsPlugin {
    <init>(...);
    public *;
}
-keep class com.cognitrack.cognitrack_mobile.ScreenStateReceiver {
    <init>(...);
    public *;
}
-keep class com.cognitrack.cognitrack_mobile.ForegroundService {
    <init>(...);
    public *;
}
-keep class com.cognitrack.cognitrack_mobile.BootReceiver {
    <init>(...);
    public *;
}
-keep class com.cognitrack.cognitrack_mobile.UsageEventBuffer {
    <init>(...);
    public *;
}

# ─── Keep MethodChannel / EventChannel invocation signatures ───────────────────
# These are called via reflection from Flutter's BinaryMessenger
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler *;
    @io.flutter.plugin.common.EventChannel$StreamHandler *;
}

# ─── Keep data classes for JSON serialization (SharedPreferences buffer) ───────
-keep class com.cognitrack.cognitrack_mobile.UsageEventBuffer {
    public static *;
}

# ─── Keep BroadcastReceiver / Service entry points ─────────────────────────────
# Android instantiates these via Intent — must not be obfuscated/removed
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.app.Service
-keep public class * extends android.app.Application

# ─── Keep native JNI methods ───────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ─── Keep Firebase / Firestore annotations ─────────────────────────────────────
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.firestore.* *;
}

# ─── Strip debug logging in release builds ─────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
}
# Also strip our custom debugPrint calls
-assumenosideeffects class io.flutter.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
}

# ─── Preserve line numbers for crash symbolication ─────────────────────────────
-keepattributes SourceFile,LineNumberTable

# ─── Keep Kotlin metadata for reflection used by kotlinx.serialization ─────────
-keep class kotlin.Metadata { *; }
-keep class kotlinx.serialization.** { *; }

# ─── Keep ConnectivityManager / Network callback classes ───────────────────────
-keep class android.net.ConnectivityManager { *; }
-keep class android.net.NetworkCallback { *; }

# ─── Keep DeviceInfoPlugin classes ─────────────────────────────────────────────
-keep class com.example.device_info_plus.** { *; }

# ─── Keep FlutterSecureStorage classes ─────────────────────────────────────────
-keep class com.flutter_secure_storage.** { *; }

# ─── Keep UUID generator ───────────────────────────────────────────────────────
-keep class java.util.UUID { *; }

# ─── Introspection / reflection used by Flutter ────────────────────────────────
-keepclassmembers class * {
    @io.flutter.embedding.engine.FlutterJNI *;
}

# ─── Prevent removal of empty constructors used by Gson/JSON ──────────────────
-keepclassmembers class * {
    <init>();
}