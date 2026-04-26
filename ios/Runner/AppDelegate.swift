import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ── iOS foreground sync ───────────────────────────────────────────────
    // As per Architecture v6.0: sync fires on applicationDidBecomeActive.
    // Full DeviceActivityMonitor extension is wired in Phase 5.
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        // ForegroundSync Dart observer handles sync trigger via
        // AppLifecycleState.resumed — no additional native code needed here.
    }
}
