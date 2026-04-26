# CogniTrack Mobile

Flutter app for Android and iOS that tracks cognitive load and focus quality through device usage metrics.

## Architecture

CogniTrack mobile runs as a background service to collect device usage:
- **Android**: Uses `UsageStatsManager` and a `ForegroundService` to poll active apps.
- **iOS**: Uses Screen Time API via `DeviceActivityMonitor` extension (Family Controls).

Data is aggregated locally in an SQLite database, calculating metrics such as cognitive debt and velocity. It is then synchronized with Firestore every 15 minutes.

## Setup & Running

### Android
Requires `PACKAGE_USAGE_STATS` permission to track active apps.
1. Run `flutter run` on an Android device.
2. The app will prompt you to grant Usage Access in system settings.
3. Once granted, tracking will run in the background.

### iOS
Requires the `com.apple.developer.family-controls` entitlement.
1. Open the project in Xcode.
2. Ensure you have a valid provisioning profile with Family Controls capability.
3. Run `flutter run` on an iOS device.

## Status
- Core sync engine implemented.
- Android background polling active.
- iOS Screen Time integration pending.
