# CogniTrack Android — Build Guide

Two flavors exist. They can be installed **side-by-side** on the same device
because they have different package IDs.

---

## Flavor Overview

| | `demo` | `live` |
|---|---|---|
| **Purpose** | Presentations & demos | Production use |
| **Data** | Pre-seeded 14-day mock data | Real device Firestore data |
| **Firestore writes** | ❌ Disabled | ✅ Enabled |
| **Crashlytics** | ❌ Disabled | ✅ Enabled |
| **App label** | CogniTrack Demo | CogniTrack |
| **Package ID** | `com.cognitrack.cognitrack_mobile.demo` | `com.cognitrack.cognitrack_mobile` |
| **Signing** | Debug keystore (no setup needed) | Release keystore (env vars) |
| **Entrypoint** | `lib/main_demo.dart` | `lib/main_live.dart` |

---

## Demo Build (for presentations)

No keystore or env vars needed. Just run:

```bash
# Run on device (hot reload available)
flutter run --flavor demo -t lib/main_demo.dart

# Build installable APK
flutter build apk --flavor demo -t lib/main_demo.dart
# Output: build/app/outputs/flutter-apk/app-demo-debug.apk

# Install via ADB
adb install build/app/outputs/flutter-apk/app-demo-debug.apk
```

**What you get:**
- 14 days of pre-seeded mock data (Week 1: Apr 22–28, Week 2: Apr 29–May 5)
- All UI metrics fire with meaningful values (74% load today, peak at 3 PM, red badge)
- Live device activity still layers on top of mock history — realistic feel
- No data written to Firestore — demo runs are clean

---

## Live Build (production)

Requires a release keystore. Set env vars before building:

```bash
export KEYSTORE_PATH=/path/to/cognitrack-release.jks
export KEYSTORE_PASSWORD=your_keystore_password
export KEY_ALIAS=cognitrack
export KEY_PASSWORD=your_key_password
```

### Release APK — sideload / direct install

```bash
flutter build apk \
  --flavor live \
  -t lib/main_live.dart \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --tree-shake-icons \
  --split-per-abi
# Outputs (one per CPU arch — only upload the right one per device):
#   build/app/outputs/flutter-apk/app-live-armeabi-v7a-release.apk   (~15–20 MB)
#   build/app/outputs/flutter-apk/app-live-arm64-v8a-release.apk     (~18–25 MB)
```

> ⚠️ Save the `build/debug-info/` folder — it is required to symbolicate Crashlytics
> stack traces. Without it, production crashes will show obfuscated names.

### Release AAB — Play Store submission (recommended)

```bash
flutter build appbundle \
  --flavor live \
  -t lib/main_live.dart \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --tree-shake-icons
# Output: build/app/outputs/bundle/liveRelease/app-live-release.aab
```

The Play Store generates per-device APKs from the AAB, so each user only
downloads the ABI, language, and screen-density resources they actually need.
Typical user-visible install size is **15–40% smaller** than a universal APK.

---

## Size Analysis (run before every release)

```bash
# Generates build/app-code-size-analysis_01.json — open in Flutter DevTools
flutter build appbundle \
  --flavor live \
  -t lib/main_live.dart \
  --release \
  --analyze-size \
  --target-platform android-arm64
```

Open DevTools → App Size tab → drag in the JSON to see an interactive treemap
of every Dart package, native library, and asset by size.

---

## Generate a keystore (first time only)

```bash
keytool -genkey -v \
  -keystore cognitrack-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias cognitrack
```

Store `cognitrack-release.jks` securely. If lost, you cannot update the app
on devices that already have it installed.

---

## Quick reference

```
# ── Demo ──────────────────────────────────────────────────────────────────────
flutter run   --flavor demo -t lib/main_demo.dart
flutter build apk --flavor demo -t lib/main_demo.dart

# ── Live (dev) ────────────────────────────────────────────────────────────────
flutter run   --flavor live -t lib/main_live.dart

# ── Live (release APK, per-ABI) ───────────────────────────────────────────────
flutter build apk --flavor live -t lib/main_live.dart --release \
  --obfuscate --split-debug-info=build/debug-info \
  --tree-shake-icons --split-per-abi

# ── Live (Play Store AAB) ─────────────────────────────────────────────────────
flutter build appbundle --flavor live -t lib/main_live.dart --release \
  --obfuscate --split-debug-info=build/debug-info --tree-shake-icons
```

---

## Build Optimisations Applied

| Layer | What was done | Expected gain |
|---|---|---|
| `gradle.properties` | `org.gradle.parallel=true`, daemon, caching, config-cache | ~30–50 % faster incremental builds |
| `gradle.properties` | `android.enableR8.fullMode=true` | Deeper code shrinking (class merging, enum unboxing) |
| `gradle.properties` | `kotlin.incremental=true` | Avoids full Kotlin recompilation on small changes |
| `app/build.gradle.kts` | ABI filters: `armeabi-v7a` + `arm64-v8a` only | ~5–8 MB off universal APK |
| `app/build.gradle.kts` | `packaging.resources.excludes` — strips META-INF duplicates | ~1–2 MB |
| `app/build.gradle.kts` | `bundle { language, density, abi splits }` | Play Store per-device APKs 15–50 % smaller |
| `app/build.gradle.kts` | `debug.multiDexEnabled = true` | Faster debug dex merge |
| `proguard-rules.pro` | Full plugin coverage (sign-in, crashlytics, notifications, etc.) | Prevents R8 stripping crashes |
| Flutter CLI flags | `--obfuscate --split-debug-info` | Smaller string table + reverse-engineering protection |
| Flutter CLI flags | `--tree-shake-icons` | Trims unused MaterialIcon glyphs (~hundreds of KB) |
| Flutter CLI flags | `--split-per-abi` | ~30–40 % smaller per-arch APK for sideloading |
| Flutter CLI flags | AAB over APK for Play Store | 15–50 % smaller user install |

**Combined expected size reduction: 40–60 % vs. a naive `flutter build apk --release`.**

---

## What changed from the old single-build setup

| Before | After |
|---|---|
| `flutter run` used `kDebugMode` to decide seeding | Flavor decides — no `kDebugMode` coupling |
| Demo and live were the same binary | Two separate binaries, coexist on device |
| Mock seeder in `main.dart` `kDebugMode` block | `main_demo.dart` calls `seedAlways()`, `main_live.dart` never imports seeder |
| One app label "CogniTrack" | "CogniTrack Demo" vs "CogniTrack" |
| Basic R8 — no full-mode, no plugin keep rules | R8 full-mode + comprehensive proguard-rules.pro |
| No Gradle parallelism / caching | Parallel + daemon + config-cache enabled |
