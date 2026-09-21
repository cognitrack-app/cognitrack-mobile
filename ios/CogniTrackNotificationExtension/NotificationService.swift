import UserNotifications
import os.log

/**
 * NotificationServiceExtension — intercepts push/local notifications to detect screen-on events.
 *
 * This extension runs when a notification is delivered, which happens when the screen
 * turns on (for local notifications scheduled by the app). We use this as a proxy
 * for screen-on detection since iOS doesn't provide a direct screen-on broadcast.
 *
 * Requirements (configured in Xcode):
 * 1. Target: Notification Service Extension named "CogniTrackNotificationExtension"
 * 2. App Group: "group.cognitrack" added to both Runner and this extension
 * 3. Info.plist: NSExtension with NSExtensionPointIdentifier = com.apple.usernotifications.service
 * 4. Main app must schedule a silent local notification that fires on screen unlock
 */
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private let logger = OSLog(subsystem: "com.cognitrack.notification", category: "NotificationService")
    private let appGroupId = "group.cognitrack"
    private let screenEventKey = "screen_events"

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        os_log("NotificationService received request: %{public}@", log: logger, request.identifier)
        
        // Check if this is our internal screen-on detection notification
        if request.identifier.hasPrefix("cognitrack.screen.") {
            recordScreenEvent()
            // Don't show the notification to user
            contentHandler(UNNotificationContent())
            return
        }
        
        // For other notifications, pass through
        if let content = bestAttemptContent {
            contentHandler(content)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func recordScreenEvent() {
        let now = Date()
        let timestamp = now.timeIntervalSince1970 * 1000 // milliseconds since epoch
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            os_log("Failed to get App Group container URL", log: logger, type: .error)
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("\(screenEventKey).json")
        
        var events: [ScreenEvent] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ScreenEvent].self, from: data) {
            events = decoded
        }
        
        events.append(ScreenEvent(timestamp: timestamp))
        
        // Keep only last 7 days of events
        let cutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        events = events.filter { $0.timestamp / 1000 > cutoff.timeIntervalSince1970 }
        
        do {
            let encoded = try JSONEncoder().encode(events)
            try encoded.write(to: fileURL, options: .atomic)
            os_log("Recorded screen event at %{public}f", log: logger, timestamp)
        } catch {
            os_log("Failed to write screen event: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
}

struct ScreenEvent: Codable {
    let timestamp: Double // Unix milliseconds
    
    init(timestamp: Double) {
        self.timestamp = timestamp
    }
}