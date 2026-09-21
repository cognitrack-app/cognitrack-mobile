import DeviceActivity
import ManagedSettings
import Foundation
import os.log

/**
 * DeviceActivityMonitorExtension — monitors Screen Time / app usage via Apple's DeviceActivity framework.
 *
 * This extension runs in a separate process and receives callbacks when DeviceActivity
 * intervals start/end or when thresholds are reached. It writes usage data to the
 * App Group shared container so the main app can read it on next launch.
 *
 * Requirements (configured in Xcode):
 * 1. Target: Device Activity Monitor Extension named "CogniTrackMonitorExtension"
 * 2. Capability: Family Controls (required for DeviceActivity)
 * 3. App Group: "group.cognitrack" added to both Runner and this extension
 * 4. Info.plist: NSExtension with NSExtensionPointIdentifier = com.apple.deviceactivity.monitor
 */
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = OSLog(subsystem: "com.cognitrack.monitor", category: "DeviceActivity")
    private let appGroupId = "group.cognitrack"
    private let defaultsKey = "device_activity_events"
    
    // Minimum interval between writes to avoid excessive I/O
    private let minWriteInterval: TimeInterval = 30.0
    private var lastWriteTime: Date = Date.distantPast

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        os_log("DeviceActivity interval started: %{public}@", log: logger, activity.rawValue)
        
        // Record interval start time for duration calculation
        let event = DeviceActivityEvent(
            activityName: activity.rawValue,
            eventType: .intervalStart,
            timestamp: Date(),
            applicationToken: nil,
            duration: 0
        )
        appendEvent(event)
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        os_log("DeviceActivity interval ended: %{public}@", log: logger, activity.rawValue)
        
        let event = DeviceActivityEvent(
            activityName: activity.rawValue,
            eventType: .intervalEnd,
            timestamp: Date(),
            applicationToken: nil,
            duration: 0
        )
        appendEvent(event)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        os_log("DeviceActivity threshold reached: %{public}@ for %{public}@", log: logger, event.rawValue, activity.rawValue)
        
        // Threshold events indicate significant usage - capture immediately
        let thresholdEvent = DeviceActivityEvent(
            activityName: activity.rawValue,
            eventType: .thresholdReached,
            timestamp: Date(),
            applicationToken: nil,
            duration: 0
        )
        appendEvent(thresholdEvent)
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        os_log("DeviceActivity interval will start warning: %{public}@", log: logger, activity.rawValue)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        os_log("DeviceActivity interval will end warning: %{public}@", log: logger, activity.rawValue)
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        os_log("DeviceActivity threshold warning: %{public}@ for %{public}@", log: logger, event.rawValue, activity.rawValue)
    }
    
    // MARK: - Event Persistence
    
    private func appendEvent(_ event: DeviceActivityEvent) {
        let now = Date()
        guard now.timeIntervalSince(lastWriteTime) >= minWriteInterval else { return }
        lastWriteTime = now
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("Failed to get App Group container URL", log: logger, type: .error)
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("\(defaultsKey).json")
        
        var events: [DeviceActivityEvent] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DeviceActivityEvent].self, from: data) {
            events = decoded
        }
        
        events.append(event)
        
        // Keep only last 7 days of events (matching TTL)
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        events = events.filter { $0.timestamp > cutoff }
        
        do {
            let encoded = try JSONEncoder().encode(events)
            try encoded.write(to: fileURL, options: .atomic)
            os_log("Wrote %{public}d DeviceActivity events to App Group", log: logger, events.count)
        } catch {
            os_log("Failed to write DeviceActivity events: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}

// MARK: - Codable Event Model

struct DeviceActivityEvent: Codable {
    let activityName: String
    let eventType: EventType
    let timestamp: Date
    let applicationToken: String? // Bundle identifier if available
    let duration: TimeInterval
    
    enum EventType: String, Codable {
        case intervalStart
        case intervalEnd
        case thresholdReached
    }
    
    // For JSON encoding/decoding of DeviceActivityName/DeviceActivityEvent.Name
    init(activityName: String, eventType: EventType, timestamp: Date, applicationToken: String?, duration: TimeInterval) {
        self.activityName = activityName
        self.eventType = eventType
        self.timestamp = timestamp
        self.applicationToken = applicationToken
        self.duration = duration
    }
}