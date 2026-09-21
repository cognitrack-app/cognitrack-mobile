import UIKit
import Flutter
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let bgSyncTaskIdentifier = "com.cognitrack.sync"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Register BGAppRefresh task for background sync
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgSyncTaskIdentifier, using: nil) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ── iOS foreground sync ───────────────────────────────────────────────
    // As per Architecture v6.0: sync fires on applicationDidBecomeActive.
    // Full DeviceActivityMonitor extension is wired in Phase 5.
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        // ForegroundSync Dart observer handles sync trigger via
        // AppLifecycleState.resumed — no additional native code needed here.
        
        // Schedule next background refresh
        scheduleBackgroundSync()
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        // Schedule background sync when app enters background
        scheduleBackgroundSync()
    }
    
    private func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: bgSyncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[CogniTrack] Failed to schedule BGAppRefresh: \(error)")
        }
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleBackgroundSync()
        
        // Create a semaphore to wait for the sync to complete
        let semaphore = DispatchSemaphore(value: 0)
        var syncCompleted = false
        
        // Set expiration handler
        task.expirationHandler = {
            if !syncCompleted {
                print("[CogniTrack] BGAppRefresh task expired")
                semaphore.signal()
            }
        }
        
        // Trigger sync via method channel
        let controller = window?.rootViewController as? FlutterViewController
        let channel = FlutterMethodChannel(name: "com.cognitrack/sync", binaryMessenger: controller!.binaryMessenger)
        
        channel.invokeMethod("triggerBackgroundSync", arguments: nil) { result in
            syncCompleted = true
            if let error = result as? FlutterError {
                print("[CogniTrack] Background sync failed: \(error.message ?? "unknown")")
                task.setTaskCompleted(success: false)
            } else {
                print("[CogniTrack] Background sync completed")
                task.setTaskCompleted(success: true)
            }
            semaphore.signal()
        }
        
        // Wait for sync to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 25) // 25 seconds max
    }
}
