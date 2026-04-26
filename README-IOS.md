# CogniTrack — iOS Installation & User Guide

CogniTrack on iOS is your **dashboard and manual session logger** for tracking cognitive load and focus quality. Unlike Android, iOS does not allow third-party apps to read system-wide app usage data, so CogniTrack on iOS focuses on **manual focus session logging** via the Sanctuary screen, combined with data synced from your desktop agent (macOS/Windows).

---

## Requirements

| Requirement | Minimum Version |
|---|---|
| iPhone / iPad | iOS 16.0 or later |
| Flutter SDK | 3.19 or later — [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| Xcode | 15.0 or later (macOS only) |
| Apple Developer Account | Free account works for personal device testing (7-day sideload limit) |
| macOS machine | Required to build for iOS (Xcode only runs on macOS) |
| CogniTrack account | Sign up at [cognitrack-dcede.firebaseapp.com](https://cognitrack-dcede.firebaseapp.com) |

---

## iOS Tracking — How It Works

iOS restricts which apps can read system-wide app usage. CogniTrack on iOS therefore works in **two complementary modes**:

1. **Synced metrics from desktop** — If you also run CogniTrack on your Mac or Windows PC, all tracking data flows from desktop → Firestore → iOS dashboard automatically.
2. **Manual focus sessions** — You can log focus and recovery sessions directly from the **Sanctuary** screen on iOS. These are stored locally and included in your cognitive debt calculations.

For the richest data, run CogniTrack desktop on your Mac/Windows machine and use iOS to view and supplement the data.

---

## Installation (Developer / Sideload)

### Step 1 — Install Flutter and Xcode

1. Install Xcode from the **Mac App Store** (free, ~15 GB download).
2. After installing, open Terminal and run:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
3. Install Flutter by following: [https://flutter.dev/docs/get-started/install/macos](https://flutter.dev/docs/get-started/install/macos)
4. Verify setup:
   ```bash
   flutter doctor
   ```
   **Xcode** and **Flutter** should both show green checkmarks. CocoaPods is also required:
   ```bash
   sudo gem install cocoapods
   ```

### Step 2 — Clone the repository

```bash
git clone https://github.com/cognitrack-app/cognitrack.git
cd cognitrack/cognitrack-mobile
```

### Step 3 — Install Flutter and iOS dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

> `pod install` downloads native iOS libraries. This takes 2–5 minutes on first run.

### Step 4 — Open the project in Xcode

```bash
open ios/Runner.xcworkspace
```

> ⚠️ Always open the `.xcworkspace` file, NOT `.xcodeproj`. The workspace includes CocoaPods dependencies.

### Step 5 — Configure signing

1. In Xcode, select the **Runner** target in the left sidebar.
2. Go to **Signing & Capabilities** tab.
3. Under **Team**, select your Apple ID (add it via **Xcode → Settings → Accounts** if needed).
4. Xcode will automatically create a provisioning profile for your device.

### Step 6 — Connect your iPhone

1. Connect your iPhone via USB.
2. On your iPhone, tap **Trust** when prompted.
3. In Xcode, select your iPhone from the device list at the top.

### Step 7 — Run the app

**Option A — via Xcode:**
Click the **▶ Run** button in Xcode.

**Option B — via Terminal:**
```bash
flutter run
```

First build takes 3–6 minutes. Subsequent builds are faster.

### Step 8 — Trust the developer certificate on your iPhone

If you see "Untrusted Developer" when opening the app:
1. On your iPhone, go to **Settings → General → VPN & Device Management**.
2. Tap your Apple ID email address under **Developer App**.
3. Tap **Trust "[your email]"**.
4. Open CogniTrack — it will launch normally.

> **Note:** Free Apple Developer accounts have a 7-day signing limit. After 7 days, reinstall the app from Xcode.

---

## Build a Release IPA (TestFlight / Distribution)

```bash
flutter build ipa
```

The `.ipa` file will be at `build/ios/ipa/`. Upload to **App Store Connect** for TestFlight distribution.

---

## First Launch Setup

### Sign In

1. Open CogniTrack on your iPhone.
2. On the sign-in screen, enter your **CogniTrack account email and password**.
3. Tap **Sign In**.

> Use the **same account** you signed in with on your macOS or Windows desktop agent to see your synced data.

---

## Daily Usage

### Dashboard Screen

Shows your cognitive snapshot. If you are running the **CogniTrack desktop agent** on your Mac or Windows PC with the same account, your data appears here automatically within 15 minutes of syncing.

- **Cognitive Load %** — overall mental load for today
- **Context Switches** — total app/task switches tracked
- **WM Capacity** — remaining working memory capacity
- **Screen Time** — total active time today
- **Neural Observation** — AI-generated recommendation

Pull down to force refresh data from Firestore.

### Analytics Screen

- **Hourly Load Bars** — hour-by-hour breakdown of today’s load
- **7-Day Heatmap** — visual grid of cognitive intensity by day and hour
- **Brain Load Panel** — WM strain, attention decay, neural noise
- **Recovery Coefficients** — morning / noon / afternoon / evening efficiency ratings

### Recovery Screen

- **Neural Radar** — pentagon chart of Dopamine, Focus, Recovery, WM Strain, Sleep proxies
- **Countdown to Neural Reset** — estimated time until cognitive load baseline resets
- **Cognitive Debt Arc** — hourly debt accumulation curve
- **Tomorrow’s Readiness** — predicted recovery score for next day

### Sanctuary Screen — Manual Session Logging

This is iOS’s primary data input mechanism. Use it to log focus sessions and recovery breaks:

1. Open the **Sanctuary** tab (the breathing orb screen).
2. Follow the animated breathing orb — it pulses with 4-second INHALE / EXHALE cycles.
3. Choose a recovery protocol:
   - **Box Breathing** — 5 minutes, reduces cognitive debt by −12 pts
   - **NSDR / Yoga Nidra** — 15 minutes, reduces cognitive debt by −35 pts
   - **Visual Defocus** — 2 minutes, reduces cognitive debt by −8 pts
4. Tap **START PROTOCOL** to begin the session timer.
5. When the session completes, the data is written to your local SQLite database and included in the next sync.

> **Tip:** Use Sanctuary after every 90-minute focus block. The neural system recommends a break after each deep work session to prevent attention residue buildup.

---

## Syncing with Desktop

For the best experience on iOS:

1. Install and run the **CogniTrack desktop agent** on your Mac or Windows machine (see `README-MACOS.md` or `README-WINDOWS.md`).
2. Sign in with the **same account** on both devices.
3. Desktop automatically uploads hourly batch metrics to Firestore.
4. iOS fetches and displays them every 15 minutes, or instantly on pull-to-refresh.

Without the desktop agent, the iOS dashboard will only show data from manually logged Sanctuary sessions.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Untrusted Developer" on launch | Settings → General → VPN & Device Management → Trust your Apple ID |
| App won’t install — "device not registered" | In Xcode → Devices, click **+** and register your device UDID |
| `pod install` fails | Run `sudo gem install cocoapods` then try again. If still failing: `pod repo update` |
| Dashboard shows all zeros | No desktop agent connected. Use Sanctuary to log sessions manually, or set up the desktop app |
| Sign-in fails | Check internet. Verify credentials at [cognitrack-dcede.firebaseapp.com](https://cognitrack-dcede.firebaseapp.com) |
| App expired after 7 days | Reconnect iPhone to Mac, open Xcode, and run again to re-sign |
| `flutter doctor` shows Xcode issues | Run `sudo xcodebuild -runFirstLaunch` and accept the license agreement |
| CocoaPods version conflict | Run `pod install --repo-update` from the `ios/` directory |

---

## Data & Privacy

- Manually logged session data is stored **locally** in SQLite on your iPhone
- Dashboard data is fetched from Firestore (encrypted in transit via HTTPS)
- No microphone, camera, location, or contact access is requested
- iOS system app usage is **never** collected (iOS does not permit this for third-party apps)
- Delete your  remove the app from your iPhone and delete your Firebase account
