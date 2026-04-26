# CogniTrack — Android Installation & User Guide

CogniTrack on Android is your **main dashboard** for visualising cognitive load, context-switch velocity, pickup counts, and recovery quality. It also runs a background tracking service that monitors your app usage throughout the day — no extra steps required once set up.

---

## Requirements

| Requirement | Minimum Version |
|---|---|
| Android OS | Android 8.0 (Oreo, API 26) or later |
| Flutter SDK | 3.19 or later — [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| Android Studio | Hedgehog (2023.1) or later, OR VS Code with Flutter extension |
| Java (JDK) | 17 (bundled with Android Studio) |
| CogniTrack account | Sign up at [cognitrack-dcede.firebaseapp.com](https://cognitrack-dcede.firebaseapp.com) |

---

## Installation (Developer / Sideload)

### Step 1 — Install Flutter

1. Follow the official guide for your OS: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
2. After installation, run the doctor to confirm everything is set up:
   ```bash
   flutter doctor
   ```
   All items under **Android toolchain** should show a green checkmark.

### Step 2 — Clone the repository

```bash
git clone https://github.com/cognitrack-app/cognitrack.git
cd cognitrack/cognitrack-mobile
```

### Step 3 — Get Flutter dependencies

```bash
flutter pub get
```

### Step 4 — Connect your Android device

1. On your Android phone, go to **Settings → About Phone**.
2. Tap **Build Number** 7 times until you see "Developer mode enabled".
3. Go to **Settings → Developer Options** and enable **USB Debugging**.
4. Connect your phone to your computer via USB.
5. Confirm the connection:
   ```bash
   flutter devices
   ```
   Your phone should appear in the list.

### Step 5 — Run the app

```bash
flutter run
```

The app will build and install on your phone automatically. First build takes 2–4 minutes.

### Step 6 — Build a release APK (optional)

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`. Transfer it to your phone and install it (you may need to enable **Install unknown apps** for your file manager in phone settings).

---

## First Launch Setup

### 1. Sign In

1. Open CogniTrack on your phone.
2. On the sign-in screen, enter your **CogniTrack account email and password**.
3. Tap **Sign In**.

> Don’t have an account? Register at [cognitrack-dcede.firebaseapp.com](https://cognitrack-dcede.firebaseapp.com)

### 2. Grant Usage Access (Critical)

This is the most important permission. Without it, CogniTrack cannot see which apps you use.

1. After sign-in, CogniTrack will detect that Usage Access is not granted and prompt you.
2. Tap **Grant Permission**. Your phone will open **Settings → Usage Access** (or **Apps with Usage Access**).
3. Find **CogniTrack** in the list and toggle it **ON**.
4. Press the back button to return to CogniTrack.
5. The app will now start the background tracking service automatically.

> **Why this permission?** Android restricts which apps can read app usage data. This permission is required for the app to know you switched from Chrome to YouTube, for example. CogniTrack never uploads raw app names — only aggregated metrics.

### 3. Allow Notifications (Android 13+)

When prompted, allow CogniTrack to send notifications. This is required for the **persistent foreground service notification** (the small "Monitoring focus quality" notification) that keeps tracking alive when the app is in the background.

> This notification cannot be dismissed while tracking is active — this is an Android requirement for background services. You can set it to **Silent** in your notification settings so it doesn’t make sounds.

---

## Daily Usage

CogniTrack runs automatically in the background once set up. You don’t need to open it for tracking to work. Open it when you want to review your metrics.

### Dashboard Screen

The main screen shows today’s cognitive snapshot:

- **Cognitive Load %** — how mentally taxed you are right now (0–100%)
- **Context Switches** — total app switches since midnight
- **WM Capacity** — remaining working memory capacity (%)
- **Screen Time** — total active screen time today
- **Switch Velocity** — how fast you’re switching apps (per 5-minute window)
- **Peak Load Hour** — the hour today with highest cognitive demand
- **Neural Observation** — AI-generated recommendation based on your current state

**Pull down** on the Dashboard to force a sync with the desktop agent.

### Analytics Screen

- **Hourly Load Bars** — 24-hour breakdown of cognitive load
- **7-Day Heatmap** — colour grid showing which days and hours are most intense
- **Brain Load Panel** — WM strain, attention decay level, neural noise score
- **Recovery Coefficients** — morning / noon / afternoon / evening efficiency

### Recovery Screen

- **Neural Radar** — pentagon chart of Dopamine, Focus, Recovery, WM Strain, Sleep
- **Countdown to Reset** — time until your neural load resets (8h after peak)
- **Debt Arc** — hourly cognitive debt curve for today
- **Break Quality** — analysis of breaks taken today
- **Tomorrow’s Readiness** — predicted readiness score for the next day

### Sanctuary Screen

Guided recovery protocols to reduce cognitive debt:

- **Box Breathing** (5 min, −12 pts) — tap **Start Protocol** to begin
- **NSDR / Yoga Nidra** (15 min, −35 pts)
- **Visual Defocus** (2 min, −8 pts)

Follow the breathing orb animation: expand on INHALE, contract on EXHALE.

---

## Background Tracking

CogniTrack uses a **Foreground Service** that stays alive even when you lock your screen or switch to another app. This is what keeps tracking accurate.

- The service polls app usage every **60 seconds**
- After reboot, it restarts automatically — no action needed
- If Android kills the service to save battery, it will restart itself (`START_STICKY`)

**To disable tracking temporarily:**
- Go to **Settings → Apps → CogniTrack → Force Stop**

**To permanently disable:**
- Revoke Usage Access in **Settings → Usage Access**

---

## Syncing with Desktop

CogniTrack mobile syncs with the desktop agent (macOS/Windows) through Firestore:

1. Sign in with the **same account** on desktop and mobile
2. Desktop computes and uploads hourly batch metrics
3. Mobile fetches and displays them within 15 minutes
4. Pull-to-refresh on Dashboard forces an immediate sync

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Dashboard shows all zeros | Grant Usage Access (see First Launch Step 2 above) |
| Tracking stopped after reboot | Should auto-restart via BootReceiver. If not, open the app once to re-trigger |
| "Monitoring focus quality" notification missing | Go to Settings → Apps → CogniTrack → Notifications → enable all |
| Data not syncing to desktop | Check you are signed in with the same account on both. Check internet connection |
| App crashes on launch | Run `flutter run` via USB and check the debug console for errors |
| Battery drain | CogniTrack is designed to be low-impact (polls every 60s only). If drain is high, check if another process is interfering |
| `flutter doctor` shows Android SDK issues | Open Android Studio → SDK Manager and install **Android 14 SDK Platform** |

---

## Data & Privacy

- Raw usage events are stored **locally** in SQLite on your phone
- Only computed daily metrics are uploaded to Firestore (no individual app names)
- Pickup counts (phone unlocks) are stored in SharedPreferences and reset at midnight
- All data is tied to your Firebase account — delete it anytime via Firebase Console
