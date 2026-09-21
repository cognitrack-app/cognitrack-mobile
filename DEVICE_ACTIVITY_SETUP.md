# CogniTrack iOS — DeviceActivity & App Group Setup Guide

This document describes the Xcode configuration required to enable automated Screen Time
tracking on iOS via the DeviceActivity framework and Notification Service Extension.

---

## Prerequisites

- Xcode 15+
- iOS 16+ deployment target (DeviceActivity requires iOS 16+)
- Apple Developer Account (for App Groups, Family Controls entitlement)

---

## 1. App Group Configuration

### 1.1 Create App Group in Developer Portal

1. Go to [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list)
2. Navigate to **Identifiers** → **App Groups**
3. Click **+** to create new App Group:
   - **Name**: `CogniTrack Shared Data`
   - **Identifier**: `group.cognitrack`
4. Save and download updated provisioning profiles.

### 1.2 Enable App Group in Xcode (Runner Target)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities**
3. Click **+ Capability** → **App Groups**
4. Check `group.cognitrack`
5. Repeat for **CogniTrackMonitorExtension** and **CogniTrackNotificationExtension** targets.

---

## 2. DeviceActivityMonitorExtension (Automated Screen Time Tracking)

### 2.1 Create Extension Target

1. File → New → Target...
2. Choose **Device Activity Monitor Extension**
3. **Product Name**: `CogniTrackMonitorExtension`
4. **Language**: Swift
5. **Embed in Application**: Runner
6. Click **Finish**

### 2.2 Configure Extension Capabilities

Select **CogniTrackMonitorExtension** target → **Signing & Capabilities**:

1. **+ Capability** → **App Groups** → Check `group.cognitrack`
2. **+ Capability** → **Family Controls** (required for DeviceActivity)
   - This adds `com.apple.developer.family-controls` entitlement

### 2.3 Info.plist Configuration

The extension target's `Info.plist` must include:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.deviceactivity.monitor</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
</dict>
```

### 2.4 Schedule DeviceActivity in Main App

In `AppDelegate.swift` (or via Flutter MethodChannel), schedule the monitoring:

```swift
import DeviceActivity

func scheduleDeviceActivityMonitoring() {
    let center = DeviceActivityCenter()
    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
    )
    
    let activityName = DeviceActivityName("cognitrack.daily")
    
    do {
        try center.startMonitoring(activityName, during: schedule)
        print("[CogniTrack] DeviceActivity monitoring scheduled")
    } catch {
        print("[CogniTrack] Failed to schedule DeviceActivity: \(error)")
    }
}
```

Call this from Flutter after permissions are granted:

```dart
// In Flutter, after Screen Time permission granted
await MethodChannel('com.cognitrack/device_activity')
    .invokeMethod('scheduleMonitoring');
```

---

## 3. NotificationServiceExtension (Screen-On Detection)

### 3.1 Create Extension Target

1. File → New → Target...
2. Choose **Notification Service Extension**
3. **Product Name**: `CogniTrackNotificationExtension`
4. **Language**: Swift
5. **Embed in Application**: Runner
6. Click **Finish**

### 3.2 Configure Extension Capabilities

Select **CogniTrackNotificationExtension** target → **Signing & Capabilities**:

1. **+ Capability** → **App Groups** → Check `group.cognitrack`

### 3.3 Info.plist Configuration

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.usernotifications.service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
</dict>
```

### 3.4 Schedule Silent Screen-On Notification

In the main app, schedule a silent local notification that fires when the device unlocks:

```swift
import UserNotifications

func scheduleScreenOnDetection() {
    let content = UNMutableNotificationContent()
    content.title = ""
    content.body = ""
    content.sound = nil
    content.categoryIdentifier = "cognitrack.screen"
    content.threadIdentifier = "cognitrack.screen"
    
    // Silent notification - no alert, sound, or badge
    content.badge = 0
    content.sound = nil
    
    // Trigger on device unlock (requires iOS 15+)
    // Note: There's no direct "screen on" trigger. Best approximation:
    // Use a repeating notification with a short interval, or rely on
    // applicationDidBecomeActive in AppDelegate for foreground detection.
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
    let request = UNNotificationRequest(
        identifier: "cognitrack.screen.detection",
        content: content,
        trigger: trigger
    )
    
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("[CogniTrack] Failed to schedule screen detection: \(error)")
        }
    }
}
```

**Note**: iOS doesn't provide a direct "screen on" broadcast. The Notification Service Extension
approach works when a notification is delivered. For true screen-on detection, you would need:
- A silent push notification from your server on device wake (requires backend)
- OR rely on `applicationDidBecomeActive` in `AppDelegate` for foreground detection

### 3.5 Alternative: Use AppDelegate for Foreground Detection

Since iOS 13+, `applicationDidBecomeActive` fires when the app comes to foreground
(including from locked screen). This is already implemented in `AppDelegate.swift`:

```swift
override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    // ForegroundSync Dart observer handles sync trigger
    scheduleBackgroundSync()
}
```

The Dart `ForegroundSync` observer (`lib/platform/ios/foreground_sync.dart`) listens for
`AppLifecycleState.resumed` which fires on unlock/foreground.

---

## 4. Family Controls Authorization (Required for DeviceActivity)

The main app must request Family Controls authorization before scheduling DeviceActivity:

```swift
import FamilyControls

func requestFamilyControlsAuthorization() async -> Bool {
    let center = AuthorizationCenter.shared
    do {
        try await center.requestAuthorization(for: .individual)
        return true
    } catch {
        print("[CogniTrack] Family Controls authorization failed: \(error)")
        return false
    }
}
```

From Flutter:

```dart
static const platform = MethodChannel('com.cognitrack/device_activity');

Future<bool> requestScreenTimePermission() async {
  try {
    final result = await platform.invokeMethod<bool>('requestAuthorization');
    return result ?? false;
  } catch (e) {
    return false;
  }
}
```

---

## 5. Entitlements Files

### 5.1 Runner.entitlements (Main App)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.cognitrack</string>
    </array>
    <key>com.apple.developer.family-controls</key>
    <true/>
</dict>
</plist>
```

### 5.2 CogniTrackMonitorExtension.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.cognitrack</string>
    </array>
    <key>com.apple.developer.family-controls</key>
    <true/>
</dict>
</plist>
```

### 5.3 CogniTrackNotificationExtension.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.cognitrack</string>
    </array>
</dict>
</plist>
```

---

## 6. Build Settings

### 6.1 Deployment Target

All targets (Runner, CogniTrackMonitorExtension, CogniTrackNotificationExtension):
- **iOS Deployment Target**: 16.0 (minimum for DeviceActivity)

### 6.2 Swift Version

- **Swift Language Version**: 5.0+

### 6.3 Code Signing

- Use **Automatic** code signing with the Development Team that has the App Group
- Ensure provisioning profiles include the App Group and Family Controls entitlement

---

## 7. Testing Checklist

| Feature | Test Method | Expected |
|---------|-------------|----------|
| App Group access | Read/write file in `group.cognitrack` from both app and extensions | ✅ File visible to all |
| Family Controls auth | Request authorization in app → Settings → Screen Time | ✅ Authorization granted |
| DeviceActivity schedule | Schedule daily monitoring → wait 24h | ✅ Events written to App Group |
| Monitor extension | Reboot device → open app → check events | ✅ Events captured during reboot |
| Notification extension | Lock/unlock device → open app → check screen_events.json | ✅ Screen events recorded |
| Background sync | App in background 15+ min → unlock | ✅ BGAppRefresh fires, sync runs |

---

## 8. Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "App Group not found" | Provisioning profile doesn't include App Group | Re-download profiles, ensure all targets use same team |
| DeviceActivity not firing | Family Controls not authorized | Request authorization before scheduling |
| Extension not launching | NSExtensionPointIdentifier wrong | Verify `com.apple.deviceactivity.monitor` / `com.apple.usernotifications.service` |
| No events in App Group | Extension can't write | Check container URL, ensure App Group enabled on all targets |
| "Family Controls not available" | iOS < 16 or not supervised | DeviceActivity requires iOS 16+ |

---

## 9. Files in This Repository

| File | Purpose |
|------|---------|
| `ios/CogniTrackMonitorExtension/DeviceActivityMonitorExtension.swift` | DeviceActivity monitor implementation |
| `ios/CogniTrackNotificationExtension/NotificationService.swift` | Notification Service Extension |
| `ios/Runner/AppDelegate.swift` | BGAppRefresh scheduling, foreground sync |
| `lib/platform/ios/foreground_sync.dart` | Dart foreground sync observer |
| `lib/platform/ios/screen_event_reader.dart` | Dart screen event reader (App Group) |
| `lib/platform/ios/manual_session_logger.dart` | Manual iOS logging fallback |

---

## 10. Next Steps (Phase 5)

1. ✅ Create extension targets in Xcode
2. ✅ Configure App Groups & Family Controls
3. ✅ Implement DeviceActivityMonitorExtension
4. ✅ Implement NotificationServiceExtension
5. 🔄 Add Flutter MethodChannel for authorization + scheduling
6. 🔄 Integrate screen_event_reader into SyncEngine
7. 🔄 End-to-end test on physical device (simulator doesn't support DeviceActivity)
8. 🔄 Ship to TestFlight for beta testing