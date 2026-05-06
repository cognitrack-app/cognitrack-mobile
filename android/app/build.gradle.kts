plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.cognitrack.cognitrack_mobile"
    compileSdk = flutter.compileSdkVersion
    // flutter.ndkVersion resolves to 25.0.1 which is not installed.
    // Pin to the NDK version installed at ~/Library/Android/sdk/ndk/
    // Run: ls ~/Library/Android/sdk/ndk/ to verify. Common Flutter-compatible versions:
    // 27.0.12077973 (recommended), 26.3.11579264, 25.2.9519653
    ndkVersion = "28.2.13676358"

    // AGP 8.x disables BuildConfig generation by default.
    // Required by productFlavors that use buildConfigField() (IS_DEMO flag).
    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
        // Enable Kotlin's strict null-safety checks and generate no debug metadata
        // in release bytecode — reduces output .dex size slightly.
        freeCompilerArgs = freeCompilerArgs + listOf("-Xjvm-default=all")
    }

    defaultConfig {
        applicationId = "com.cognitrack.cognitrack_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ── ABI Filters ───────────────────────────────────────────────────────
        // Restrict to the two ABIs that cover >99 % of real Android devices.
        // x86_64 is excluded from production builds; use an emulator-targeted
        // debug build or add it back if you test on x86_64 AVDs routinely.
        // NOTE: Flutter's Gradle plugin also sets these, but explicit declaration
        // ensures plugins (e.g. sqlite3, camera) respect the same filter and
        // don't silently bundle x86 .so files.
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    // ─── Build Flavors ────────────────────────────────────────────────────────
    // demo  — pre-seeded mock data (14 days), debug-signed, for presentations.
    //         App label : "CogniTrack Demo"   App ID suffix: .demo
    //         Build cmd : flutter build apk --flavor demo -t lib/main_demo.dart
    //
    // live  — real Firestore data, release-signed, no mock seeder.
    //         App label : "CogniTrack"         no ID suffix
    //         Build cmd : flutter build apk --flavor live -t lib/main_live.dart --release
    //
    // Both flavors can coexist on the same device (different package IDs).
    // ─────────────────────────────────────────────────────────────────────────
    flavorDimensions += "environment"

    productFlavors {
        create("demo") {
            dimension = "environment"
            applicationIdSuffix = ".demo"
            versionNameSuffix = "-demo"
            resValue("string", "app_name", "CogniTrack Demo")
            buildConfigField("boolean", "IS_DEMO", "true")
        }
        create("live") {
            dimension = "environment"
            // No suffix — clean production package ID
            resValue("string", "app_name", "CogniTrack")
            buildConfigField("boolean", "IS_DEMO", "false")
        }
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            storeFile = if (!keystorePath.isNullOrEmpty()) file(keystorePath) else null
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // ── Security ──────────────────────────────────────────────────────
            isDebuggable = false

            // ── R8 / Code Shrinking ────────────────────────────────────────────
            // R8 full-mode is activated globally via gradle.properties
            // (android.enableR8.fullMode=true). These flags enable the
            // per-build-type shrinking passes:
            //   isMinifyEnabled  — R8 dead-code elimination + obfuscation
            //   isShrinkResources — AGP resource shrinker removes unused XML/drawables
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                // proguard-android-optimize.txt enables R8's full optimisation
                // pass (vs. proguard-android.txt which contains -dontoptimize).
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            val keystorePath = System.getenv("KEYSTORE_PATH")
            signingConfig = if (!keystorePath.isNullOrEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }

        debug {
            // ── Demo / dev builds ─────────────────────────────────────────────
            // Keep minify off so hot-reload and stack traces work without
            // re-symbolication. isShrinkResources requires isMinifyEnabled.
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            // Note: multiDex is automatic when minSdk >= 21 (Flutter default).
            // No explicit multiDexEnabled needed in AGP 8.x.
        }
    }

    // ── Packaging Options ─────────────────────────────────────────────────────
    // Strip native debug symbols from release .so files.
    // The symbols are kept in the companion unstripped .so files that the NDK
    // produces — those are what you upload to the Play Console / Crashlytics for
    // symbolication. Stripping from the APK/AAB saves ~5–15 MB depending on the
    // number of native plugins.
    packaging {
        // jniLibs: AGP 8 release builds strip native debug symbols by default
        // (useLegacyPackaging = false). No explicit keepDebugSymbols needed.
        resources {
            // Remove duplicate license/notice files contributed by Firebase & GMS.
            // excludes is a MutableSet<String> — must use setOf(), not listOf().
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/*.kotlin_module",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "**/kotlin/**.kotlin_builtins",
            )
        }
    }

    // ── Bundle Options ────────────────────────────────────────────────────────
    // When building an AAB (flutter build appbundle), the Play Store generates
    // per-device APKs. These options configure what the bundle splits on.
    bundle {
        language {
            // Ship all languages; Play Store will split by language at delivery.
            enableSplit = true
        }
        density {
            // Split by screen density — users only download the dpi tier they need.
            enableSplit = true
        }
        abi {
            // Split by ABI — arm64-v8a users don't download the armeabi-v7a .so.
            enableSplit = true
        }
    }

    // NOTE: ABI splits are intentionally omitted. Flutter's Gradle plugin sets
    // ndk.abiFilters automatically (armeabi-v7a, arm64-v8a, x86_64) and AGP
    // forbids having both ndk.abiFilters AND splits.abi set simultaneously.
    // Per-ABI APK splitting is handled at the flutter build apk level:
    //   flutter build apk --split-per-abi
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring: backports java.time.* and other APIs to pre-API-26.
    // Required because we target minSdk < 26 and use java.time in plugins.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
