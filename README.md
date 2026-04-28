# CogniTrack Android

A Flutter foreground-service agent that tracks app usage via Android's `UsageStatsManager`, computes cognitive load metrics locally, and syncs computed scalars to Firestore every 15 minutes. No raw usage data ever leaves the device.

All dashboard and analytics UI lives in this app. The CogniTrack Windows desktop agent reports into the same Firestore account and the two datasets are merged automatically by the `mergeAgentData` Cloud Function.

---

## How it connects to Windows Desktop

Both apps sign in with the same Firebase email and password. That shared UID is the only link. There is no pairing code, QR scan, or Bluetooth step. Once both agents have reported for a day, combined cognitive load, dual-device fragmentation, and overlap hours appear in the dashboard automatically.

> **Install order:** Android first — this is where the account is created. Install the Windows agent second and sign in with the same credentials.

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Flutter SDK | **≥ 3.3.0** | `sdk: '>=3.3.0 <4.0.0'` in pubspec.yaml |
| Dart | included with Flutter | — |
| Java | **17** | `compileOptions { sourceCompatibility = JavaVersion.VERSION_17 }` |
| Android Studio | **Hedgehog or later** | Or VS Code with Flutter extension |
| Android device or emulator | API 26+ (Android 8.0) | `UsageStatsManager` requires API 21+; foreground service targets API 26+ |
| Firebase project | — | Requires `google-services.json` (see step 3) |

Verify your environment:

```bash
flutter doctor
```

All items under **Android toolchain** and **Flutter** should show a green checkmark.

---

## 1 — Clone the repository

```bash
git clone https://github.com/your-org/cognitrack-mobile.git
cd cognitrack-mobile
```

---

## 2 — Install Flutter dependencies

```bash
flutter pub get
```

---

## 3 — Firebase configuration

The app uses `firebase_core`, `firebase_auth`, and `cloud_firestore`. A valid `google-services.json` must be placed in the Android app directory before building.

1. Open **Firebase Console → Project Settings → Your apps**
2. Select the Android app (`com.cognitrack.cognitrack_mobile`) or add it if it does not exist yet
3. Download `google-services.json`
4. Place it at:

```
cognitrack-mobile/
  android/
    app/
      google-services.json   ← here
```

> `google-services.json` is in `.gitignore`. Never commit it.

---

## 4 — Run in development

Connect an Android device via USB with **USB debugging enabled**, or start an emulator from Android Studio.

```bash
# List connected devices
flutter devices

# Run on the connected device
flutter run
```

For release-mode performance testing on a physical device:

```bash
flutter run --release
```

---

## 5 — Build for production

### Option A — APK (sideload / direct install)

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Option B — App Bundle (Play Store submission)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### Signing (required for release builds)

The `android/app/build.gradle.kts` reads signing credentials from environment variables. Set these before building:

```bash
export KEYSTORE_PATH=/path/to/your/keystore.jks
export KEYSTORE_PASSWORD=your_keystore_password
export KEY_ALIAS=your_key_alias
export KEY_PASSWORD=your_key_password
```

Then run `flutter build apk --release` or `flutter build appbundle --release` as above.

> If the environment variables are not set, the release build will be unsigned and cannot be installed on most devices.

#### Generating a keystore (first time only)

```bash
keytool -genkey -v -keystore cognitrack-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias cognitrack
```

Store the `.jks` file securely. If it is lost, you cannot update the app on any device that has it installed.

---

## 6 — Install the APK on an Android device

### Via ADB

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Via file transfer

1. Copy `app-release.apk` to the device (USB, cloud, or any transfer method)
2. On the device, open the APK in Files → tap **Install**
3. If prompted, enable **Install from unknown sources** in Settings → Security

---

## 7 — First launch flow

```
Splash screen
  └── OnboardingScreen  ("Know Your Brain. Own Your Focus." — shown once)
        └── SignUpScreen  ←  create account with email + password
              └── PermissionsScreen
                    ├── Grant Usage Access   (Settings → Special app access → Usage access)
                    └── Grant Battery Optimization exemption  (keep foreground service alive)
                          └── Dashboard  ←  15-minute sync timer starts
```

**Both permissions are required for tracking to function:**

- **Usage Access** — lets `UsageStatsManager` read which app is in the foreground
- **Battery Optimization exemption** — prevents Android from killing the foreground service on idle

The app opens the correct system Settings screen for each permission automatically.

---

## 8 — Architecture overview

```
Flutter UI (Provider + GoRouter)
    ├── /dashboard      ← local SQLite  (phone-only metrics)
    ├── /analytics
    ├── /recovery
    └── /sanctuary

Background layer
    ├── UsageStatsPoller     polls UsageStatsManager every 60 s  (Android ForegroundService)
    ├── ScreenOnReceiver     BroadcastReceiver — counts device pickups
    ├── CognitiveEngine      runs calculateCognitiveDebt() in a Dart isolate (compute())
    ├── SQLiteStore          app_events + daily_metrics + pending_sync  (7-day TTL, WAL mode)
    └── SyncEngine
            ├── 15-min periodic timer
            ├── AppLifecycleState.paused trigger
            ├── Connectivity-restore trigger
            └── Offline queue with exponential backoff (30s → 60s → 120s → 240s, max 4 retries)
                Always updates queued payload with latest data on each retry cycle

Firestore
    └── /users/{uid}/sessions/{date}/phoneMetrics
              ↑
         mergeAgentData Cloud Function fires → combined metrics in /derived/{date}
```

---

## 9 — Troubleshooting

**`flutter pub get` fails with workspace resolution errors**
Make sure you are running Flutter ≥ 3.3.0. Run `flutter upgrade` if needed.

**`google-services.json` not found build error**
Verify the file is at `android/app/google-services.json`, not in the project root or `android/` directory.

**App installs but shows "Tracking inactive" on dashboard**
Usage Access was not granted. Go to **Settings → Apps → Special app access → Usage access** and enable CogniTrack.

**Tracking stops after a few hours on battery**
The Battery Optimization exemption was not granted or was revoked by the OS. Go to **Settings → Apps → CogniTrack → Battery** and set to **Unrestricted**.

**Sync shows stale data after being offline all day**
The offline queue always updates the queued payload with the latest metrics on each retry cycle, so reconnection will push end-of-day data, not the stale snapshot from when connectivity was lost.

**Build error: `Execution failed for task ':app:signReleaseApk'`**
The `KEYSTORE_PATH` environment variable is not set or points to a file that does not exist. Verify all four signing environment variables are exported in the current shell session.

---

## License

MIT
